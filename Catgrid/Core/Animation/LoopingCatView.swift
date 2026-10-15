import ImageIO
import SwiftUI

/// Videodan hazırlanmış, arka planı temizlenmiş kedi animasyonları (döngülü, saydam WebP).
/// Dosyalar `Resources/Animations` altında; ad ile çağrılır.
enum LoopingCatAnimation {
    /// Ana sayfadaki Kedi Bulmaca kartında yumakla oynayan kedi.
    static let yarnCat = "yarn-cat-loop"
    /// Kart Koleksiyonu (ana sayfa kartı ve iç ekran): kartlarıyla oynayan tekir.
    static let cardsCat = "cards-cat-loop"
    /// Günlük Bulmaca ana sayfa kartı: takvimin arkasından el sallayan sarman.
    static let dailyCat = "daily-cat-loop"
    /// Günlük Bulmaca iç ekranı, Bugünün Bulmacası: uyuyan sarman (sevince mırlar).
    static let sleepyCat = "sleepy-cat-loop"
    /// Premium şeridi: şeridin kenarından bakan üç renkli kedi.
    static let peekCat = "peek-cat-loop"

    /// Videonun kare hızı.
    static let frameRate: Double = 24
    /// Kareler ekrandaki boyutun en fazla bu katı çözülür (yumuşak çizimlerde 2x yeterli,
    /// bellek üçte bir azalır).
    static let maxPixelScale: CGFloat = 2

    static func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "webp")
    }

    static func isAvailable(_ name: String) -> Bool {
        url(name) != nil
    }

    /// Sevilince çıkan ses: uyuyan kedi mırlar, diğerleri miyavlar.
    static func petSound(for name: String) -> SoundEffect {
        name == sleepyCat ? .purr : (Bool.random() ? .meow : .meow2)
    }

    /// Bütün kareleri bir kez, ekrandaki boyuta küçülterek çözer (arka planda); oynatırken
    /// yalnızca hazır kare seçilir.
    static func decodeFrames(_ name: String, maxPixelSize: Int) async -> [CGImage] {
        guard let url = url(name) else { return [] }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [CGImage]() }
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 64),
            ] as CFDictionary
            return (0..<CGImageSourceGetCount(source)).compactMap {
                CGImageSourceCreateThumbnailAtIndex(source, $0, options)
            }
        }.value
    }
}

/// Döngülü kedi animasyonunu oynatır.
/// - Ekranda değilken, uygulama arka plandayken ya da "Hareketi Azalt" açıkken durur
///   (Hareketi Azalt'ta ilk kare sabit görünür).
/// - Kareler önceden, ekrandaki boyuta göre çözülür; her karede yalnızca hazır görüntü değişir.
/// - Kediyi sevmek (üstünde parmağı gezdirmek; `tapToPet` ise dokunmak da) ses çıkarır ve
///   küçük kalpler uçurur. Düğme içindeyken dokunuş düğmeye kalır, sevmek sürüklemeyle olur.
@MainActor
struct LoopingCatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    /// Testlerdeki ön izlemelerde ses yöneticisi olmayabilir
    @Environment(AudioManager.self) private var audio: AudioManager?
    let name: String
    /// Düğme içinde değilse dokunmak da sever.
    var tapToPet = false

    @State private var frames: [CGImage] = []
    @State private var isVisible = false
    @State private var pixelSize = 0
    @State private var hearts: [PetHeart] = []
    @State private var strokeDistance: CGFloat = 0
    @State private var lastStroke: CGPoint?
    @State private var lastPet = Date.distantPast

    private var isRunning: Bool {
        isVisible && !reduceMotion && scenePhase == .active && frames.count > 1
    }

    private var aspectRatio: CGFloat {
        guard let first = frames.first, first.height > 0 else { return 360.0 / 190.0 }
        return CGFloat(first.width) / CGFloat(first.height)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / LoopingCatAnimation.frameRate, paused: !isRunning)) { timeline in
            let index = isRunning
                ? Int(timeline.date.timeIntervalSinceReferenceDate * LoopingCatAnimation.frameRate) % frames.count
                : 0
            if frames.indices.contains(index) {
                Image(decorative: frames[index], scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay { heartsLayer }
        .contentShape(Rectangle())
        .simultaneousGesture(strokeGesture)
        .simultaneousGesture(TapGesture().onEnded { if tapToPet { pet(at: nil) } })
        .onGeometryChange(for: Int.self) { proxy in
            Int(max(proxy.size.width, proxy.size.height) * min(displayScale, LoopingCatAnimation.maxPixelScale))
        } action: { pixelSize = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: pixelSize) {
            // İlk ölçüden sonra bir kez çözülür; boyut çok büyürse (dönme vb.) yeniden
            guard pixelSize > 0 else { return }
            if let first = frames.first, max(first.width, first.height) >= pixelSize * 9 / 10 { return }
            frames = await LoopingCatAnimation.decodeFrames(name, maxPixelSize: pixelSize)
        }
        .accessibilityHidden(true)
    }

    /// Parmak kedinin üstünde bir miktar gezince bir kez "sevildi" sayılır.
    private var strokeGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                // Yalnızca yatay okşama sayılır: sayfayı dikey kaydırırken kedi miyavlamasın
                if let last = lastStroke {
                    let dx = abs(value.location.x - last.x)
                    let dy = abs(value.location.y - last.y)
                    if dx > dy { strokeDistance += dx }
                }
                lastStroke = value.location
                if strokeDistance > 40 {
                    strokeDistance = 0
                    pet(at: value.location)
                }
            }
            .onEnded { _ in
                lastStroke = nil
                strokeDistance = 0
            }
    }

    private func pet(at location: CGPoint?) {
        let now = Date()
        // Mırlama uzun: bitmeden yeniden başlamasın
        let cooldown = name == LoopingCatAnimation.sleepyCat ? 2.6 : 1.0
        guard now.timeIntervalSince(lastPet) > cooldown else { return }
        lastPet = now
        audio?.play(LoopingCatAnimation.petSound(for: name))
        Haptics.selection()
        guard !reduceMotion else { return }
        let heart = PetHeart(location: location)
        hearts.append(heart)
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            hearts.removeAll { $0.id == heart.id }
        }
    }

    private var heartsLayer: some View {
        GeometryReader { proxy in
            ForEach(hearts) { heart in
                PetHeartView()
                    .position(heart.location ?? CGPoint(x: proxy.size.width * 0.45, y: proxy.size.height * 0.3))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PetHeart: Identifiable {
    let id = UUID()
    let location: CGPoint?
}

/// Sevilince kedinin üstünden yükselip kaybolan kalpler.
private struct PetHeartView: View {
    @State private var isFloating = false

    var body: some View {
        ZStack {
            heart(size: 18, x: 0, delay: 0)
            heart(size: 12, x: -14, delay: 0.12)
            heart(size: 10, x: 13, delay: 0.22)
        }
        .onAppear { isFloating = true }
    }

    private func heart(size: CGFloat, x: CGFloat, delay: Double) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(Color(hex: "#FF6F91"))
            .shadow(color: .white.opacity(0.8), radius: 2)
            .offset(x: x, y: isFloating ? -44 : 0)
            .opacity(isFloating ? 0 : 1)
            .scaleEffect(isFloating ? 1.15 : 0.5)
            .animation(.easeOut(duration: 1.1).delay(delay), value: isFloating)
    }
}
