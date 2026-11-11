import Foundation
import NonogramKit
import SwiftUI

/// Yumak Taksi oyun durumu: dokunuşlar, geri alma, yardımcılar ve kedinin ruh hâli.
@MainActor
@Observable
final class YarnTaxiGameViewModel {
    let level: YarnTaxiLevel
    private let start: YarnTaxiGame
    private(set) var game: YarnTaxiGame
    private var history: [YarnTaxiGame] = []
    /// Kullanılan ipucu ve ek yer sayısı (yıldızı düşürür; geri almak serbest).
    private(set) var boostersUsed: Int
    private(set) var mood: BirdSortCatMood = .idle
    /// İpucunun gösterdiği araba.
    private(set) var hintCar: Int?
    /// Önü kapalı olduğu için sallanan araba.
    private(set) var shakingCar: Int?
    private(set) var shakeID = 0
    /// Araba durağa gidiyor ya da yumaklar biniyor: bu sırada yeni dokunuş beklenir.
    private(set) var isAnimating = false
    /// Sıradan durağa uçan yumak (sıra içindeki yeri, rengi, hedef durak yeri).
    private(set) var flyingYarn: (index: Int, color: Int, slot: Int)?
    /// Otoparktan durağa yoldan giden araba (ekranda ayrı çizilir; durakta varınca belirir).
    private(set) var traveling: (car: YarnCar, slot: Int)?
    /// Önü kapalı arabayı engelleyen araba (kısa süre kırmızı yanar).
    private(set) var blockerCar: Int?
    /// Dolan arabanın ayrıldığı yerde konfeti.
    private(set) var confetti: [YarnConfettiBurst] = []
    /// 1. bölümde elin gösterdiği araba (her hamleden sonra bir kez hesaplanır).
    private(set) var guideCar: Int?
    /// Yumak binince zıplayan durak yeri.
    private(set) var bouncingSlot: Int?
    private(set) var bounceID = 0

    var onMove: (() -> Void)?
    var onBoard: ((Int) -> Void)?
    var onDepart: (() -> Void)?
    var onBlocked: (() -> Void)?
    var onWin: (() -> Void)?
    var onStuck: (() -> Void)?

    private var moodTask: Task<Void, Never>?
    private var boardingTask: Task<Void, Never>?

    init(level: YarnTaxiLevel, resuming saved: YarnTaxiSavedGame? = nil) {
        self.level = level
        start = YarnTaxiCatalog.game(for: level)
        game = saved?.game ?? start
        boostersUsed = saved?.boostersUsed ?? 0
        updateGuide()
    }

    var isWon: Bool { game.status == .won }
    var isStuck: Bool { game.status == .stuck }
    var canUndo: Bool { !history.isEmpty && !isWon && !isAnimating }
    var hasProgress: Bool { game.moves > 0 }
    var savedState: YarnTaxiSavedGame { YarnTaxiSavedGame(level: level.number, game: game, boostersUsed: boostersUsed) }

    /// 3 yıldız: yardımcısız; 2: bir yardımcı; 1: daha fazla.
    var stars: Int { max(1, 3 - boostersUsed) }

    private func updateGuide() {
        guideCar = level.number == 1 && game.status == .playing ? YarnTaxiSolver.hint(game) : nil
    }

    func tap(_ car: YarnCar) {
        guard game.status == .playing, !isAnimating else { return }
        var next = game
        switch next.park(carID: car.id) {
        case .blocked:
            shakingCar = car.id
            shakeID += 1
            // Engelleyen araba kırmızı yanar
            let blocker = game.blocker(of: car)?.id
            withAnimation(.easeInOut(duration: 0.18).repeatCount(3, autoreverses: true)) { blockerCar = blocker }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                if blockerCar == blocker { withAnimation { blockerCar = nil } }
            }
            setMood(.sad)
            onBlocked?()
        case .noSpace:
            setMood(.sad)
            onBlocked?()
        case .ignored:
            break
        case .moved:
            history.append(game)
            hintCar = nil
            isAnimating = true
            guideCar = nil
            onMove?()
            // 1. Araba baktığı yöne çıkar, yoldan dolaşıp durağa girer (ekranda ayrı çizilir)
            let slot = next.station.firstIndex { $0?.car.id == car.id } ?? 0
            traveling = (car, slot)
            withAnimation(.easeOut(duration: 0.25)) { game = next }
            boardingTask = Task { await boardYarns() }
        }
    }

    /// 2. Yumaklar sıradan tek tek uçup biner; dolan araba yola çıkar. 3. Durum güncellenir.
    private func boardYarns() async {
        try? await Task.sleep(for: .milliseconds(Int(Self.travelTime * 1000)))
        traveling = nil
        var boardedAny = false
        while !Task.isCancelled {
            var next = game
            guard let step = next.boardNext() else { break }
            boardedAny = true
            // Yumak sıradan çıkar ve yay çizerek arabaya atlar; sayı indiğinde artar
            flyingYarn = (step.yarnIndex, step.color, step.slot)
            withAnimation(.easeOut(duration: 0.2)) { game = next }
            try? await Task.sleep(for: .milliseconds(Int(Self.hopTime * 1000)))
            flyingYarn = nil
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                bouncingSlot = step.slot
                bounceID += 1
            }
            onBoard?(1)
            if step.filled {
                setMood(.delighted)
                try? await Task.sleep(for: .milliseconds(200))
                onDepart?()
                confetti.append(YarnConfettiBurst(slot: step.slot, color: step.color))
                withAnimation(.easeIn(duration: 0.5)) { _ = game.departFullCars() }
                try? await Task.sleep(for: .milliseconds(450))
                confetti.removeAll { Date().timeIntervalSince($0.start) > 1 }
            } else {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        guard !Task.isCancelled else { return }
        if boardedAny, mood == .idle { setMood(.pleased) }
        game.finishTurn()
        isAnimating = false
        updateGuide()
        if game.status == .won {
            mood = .celebrating
            onWin?()
        } else if game.status == .stuck {
            setMood(.sad, hold: true)
            onStuck?()
        }
    }

    func undo() {
        guard !isAnimating, let previous = history.popLast() else { return }
        hintCar = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { game = previous }
        mood = .idle
        updateGuide()
    }

    /// Arabanın durağa gidiş ve yumağın atlayış süreleri (saniye).
    static let travelTime = 0.75
    static let hopTime = 0.26

    /// Ek durak yeri.
    func addSlot() {
        guard !isWon, !isAnimating else { return }
        history.append(game)
        boostersUsed += 1
        withAnimation(.spring(response: 0.4)) { game.addSlot() }
        setMood(.pleased)
    }

    /// İpucu: sıradaki doğru araba parlar. Çözücü arka planda çalışır (büyük bölümlerde ekran takılmasın).
    @discardableResult
    func showHint() async -> Bool {
        guard game.status == .playing, !isAnimating else { return false }
        let current = game
        let car = await Task.detached(priority: .userInitiated) { YarnTaxiSolver.hint(current) }.value
        guard let car, game == current else { return false }
        boostersUsed += 1
        withAnimation { hintCar = car }
        setMood(.pointing)
        return true
    }

    func restart() {
        boardingTask?.cancel()
        isAnimating = false
        flyingYarn = nil
        traveling = nil
        confetti = []
        history = []
        boostersUsed = 0
        hintCar = nil
        withAnimation { game = start }
        mood = .idle
        updateGuide()
    }

    private func setMood(_ new: BirdSortCatMood, hold: Bool = false) {
        moodTask?.cancel()
        mood = new
        guard !hold else { return }
        moodTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self, self.game.status == .playing else { return }
            self.mood = .idle
        }
    }
}

struct YarnConfettiBurst: Identifiable {
    let id = UUID()
    let slot: Int
    let color: Int
    let start = Date()
}
