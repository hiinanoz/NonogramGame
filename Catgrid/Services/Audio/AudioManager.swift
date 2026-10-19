import AVFoundation
import Foundation

enum SoundEffect: String, CaseIterable {
    case fill
    case cross
    case erase
    case mistake
    case line
    case solved
    case failed
    case tap
    /// Bir türün tüm bulmacaları bitince, yeni kart kazanılınca.
    case card
    /// Oyun ekranındaki küçük kediye dokununca.
    case mew
    /// Dopamin modu: satır/sütun tamamlanınca parıltı.
    case combo
    /// Dopamin modu: bulmaca çözülünce fanfar.
    case fanfare
    // Kedi Bulmaca
    case catX = "cat_x"
    case catFound = "cat_found"
    case catWrong = "cat_wrong"
    case catHint = "cat_hint"
    case catCombo = "cat_combo"
    case catWin = "cat_win"
    // Animasyonlu kedileri sevince: uyuyan kedi mırlar, diğerleri miyavlar
    case purr
    case meow
    case meow2
    // Kuş Sıralama: kuşlar uçarken kanat sesi, dal dolunca sürü uçup gider
    case wingFlap = "wing_flap"
    case birdsAway = "birds_away"
}

/// Bir müzik parçası. `gain`: parçalar arası ses farkını dengeler (ses ayarıyla çarpılır).
struct MusicTrack: Equatable {
    let name: String
    let fileExtension: String
    var gain: Float = 1
}

/// Oyun modunun müzik listesi.
struct MusicPlaylist: Equatable {
    let tracks: [MusicTrack]
    /// Doluysa her parça bu süre boyunca kendi içinde döner, sonra sıradakine geçilir;
    /// boşsa her parça bir kez çalar ve sıradakine geçilir (liste sonsuz döner).
    let segmentDuration: TimeInterval?
}

/// Arka plan müziği ve ses efektleri. Ayarlar (aç/kapa, seviye) kalıcıdır.
///
/// Ses oturumu `.ambient`: telefonun sessiz anahtarına uyar ve oyuncunun kendi
/// müziğini/podcast'ini kesmez.
@MainActor
@Observable
final class AudioManager {
    enum Keys {
        static let musicEnabled = "audio.musicEnabled"
        static let musicVolume = "audio.musicVolume"
        static let effectsEnabled = "audio.effectsEnabled"
        static let effectsVolume = "audio.effectsVolume"
    }

    var musicEnabled: Bool {
        didSet {
            defaults.set(musicEnabled, forKey: Keys.musicEnabled)
            if musicEnabled {
                resumeMusic()
            } else {
                musicPlayer?.pause()
            }
        }
    }

    /// 0...1
    var musicVolume: Double {
        didSet {
            defaults.set(musicVolume, forKey: Keys.musicVolume)
            musicPlayer?.volume = musicLevel
        }
    }

    var effectsEnabled: Bool {
        didSet { defaults.set(effectsEnabled, forKey: Keys.effectsEnabled) }
    }

    /// 0...1
    var effectsVolume: Double {
        didSet { defaults.set(effectsVolume, forKey: Keys.effectsVolume) }
    }

    /// Müzik efektlerin altında kalsın diye tam seviyede bile kısık çalar.
    private static let musicHeadroom: Float = 0.45
    /// Sürüklerken her karede ses çıkmasın: aynı efekt bu aralıktan sık çalınmaz.
    private static let minimumEffectInterval: TimeInterval = 0.045

    private let defaults: UserDefaults
    private let bundle: Bundle
    private var musicPlayer: AVAudioPlayer?
    private var effectPlayers: [SoundEffect: [AVAudioPlayer]] = [:]
    private var lastPlayed: [SoundEffect: Date] = [:]
    private var isMusicRequested = false
    /// Çalan liste ve sıradaki parça.
    private var playlist = MusicPlaylist(tracks: [MusicTrack(name: "music_cozy", fileExtension: "m4a")], segmentDuration: nil)
    private var trackIndex = 0
    /// Süreli listelerde (Sakin) parçanın çaldığı süre.
    private var segmentElapsed: TimeInterval = 0
    private var segmentTask: Task<Void, Never>?
    private let finishObserver = MusicFinishObserver()

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
        musicEnabled = defaults.object(forKey: Keys.musicEnabled) as? Bool ?? true
        // Varsayılan %40: hareketli parçalar çok yüksek başlamasın; oyuncu Ayarlar'dan değiştirebilir
        musicVolume = defaults.object(forKey: Keys.musicVolume) as? Double ?? 0.4
        effectsEnabled = defaults.object(forKey: Keys.effectsEnabled) as? Bool ?? true
        effectsVolume = defaults.object(forKey: Keys.effectsVolume) as? Double ?? 0.8
    }

    /// Uygulama açılınca bir kez çağrılır.
    func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            // Hızlı art arda çalınabilsin diye her efekt için küçük bir oynatıcı havuzu
            effectPlayers[effect] = (0..<3).compactMap { _ in makePlayer(effect.rawValue, extension: "wav") }
        }
    }

    // MARK: - Müzik

    func startMusic() {
        isMusicRequested = true
        resumeMusic()
    }

    /// Arka plana geçerken.
    func pauseMusic() {
        musicPlayer?.pause()
    }

    /// Oyun moduna göre müzik listesini değiştirir; aynıysa bir şey yapmaz.
    func setPlaylist(_ newPlaylist: MusicPlaylist) {
        guard newPlaylist != playlist else { return }
        playlist = newPlaylist
        trackIndex = 0
        restartTrack()
    }

    func resumeMusic() {
        guard isMusicRequested, musicEnabled, !playlist.tracks.isEmpty else { return }
        if musicPlayer == nil {
            let track = playlist.tracks[trackIndex % playlist.tracks.count]
            musicPlayer = makePlayer(track.name, extension: track.fileExtension)
            // Süreli listede parça kendi içinde döner; süresizde bitince sıradakine geçilir
            musicPlayer?.numberOfLoops = playlist.segmentDuration == nil ? 0 : -1
            finishObserver.onFinish = { [weak self] in
                Task { @MainActor in self?.advanceTrack() }
            }
            musicPlayer?.delegate = finishObserver
            segmentElapsed = 0
            startSegmentClock()
        }
        musicPlayer?.volume = musicLevel
        if musicPlayer?.isPlaying == false { musicPlayer?.play() }
    }

    private var musicLevel: Float {
        let gain = playlist.tracks.isEmpty ? 1 : playlist.tracks[trackIndex % playlist.tracks.count].gain
        return min(Float(musicVolume) * Self.musicHeadroom * gain, 1)
    }

    private func advanceTrack() {
        guard !playlist.tracks.isEmpty else { return }
        trackIndex = (trackIndex + 1) % playlist.tracks.count
        restartTrack()
    }

    private func restartTrack() {
        musicPlayer?.stop()
        musicPlayer = nil
        segmentTask?.cancel()
        segmentTask = nil
        resumeMusic()
    }

    /// Sakin modda parçanın çaldığı süreyi sayar (duraklamalar sayılmaz); süre dolunca sıradaki.
    private func startSegmentClock() {
        segmentTask?.cancel()
        guard let duration = playlist.segmentDuration, playlist.tracks.count > 1 else { return }
        segmentTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                if self.musicPlayer?.isPlaying == true {
                    self.segmentElapsed += 5
                }
                if self.segmentElapsed >= duration {
                    self.advanceTrack()
                    return
                }
            }
        }
    }

    // MARK: - Efektler

    func play(_ effect: SoundEffect) {
        guard effectsEnabled, effectsVolume > 0 else { return }
        let now = Date()
        if let last = lastPlayed[effect], now.timeIntervalSince(last) < Self.minimumEffectInterval { return }
        lastPlayed[effect] = now
        guard let player = effectPlayers[effect]?.first(where: { !$0.isPlaying }) ?? effectPlayers[effect]?.first else { return }
        player.volume = Float(effectsVolume)
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(_ name: String, extension ext: String) -> AVAudioPlayer? {
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

/// AVAudioPlayer bitince haber verir (parça listesinde sıradakine geçmek için).
final class MusicFinishObserver: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
