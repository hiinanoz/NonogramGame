import ImageIO
import SwiftUI
import UIKit

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
    /// Miyav Crush ana sayfa kartı: telefonda oyun oynayan tekir yavru.
    static let crushCat = "crush-cat-loop"

    /// Videonun kare hızı.
    static let frameRate: Double = 24
    /// Kareler ekrandaki boyutun en fazla bu katı çözülür (yumuşak çizimlerde 2x yeterli,
    /// bellek azalır).
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

    /// Yüklenmeden önce yer ayırmak için en-boy oranı (kareler gelince düzen kaymasın).
    static func aspectRatio(_ name: String) -> CGFloat {
        switch name {
        case peekCat: 300.0 / 338.0
        case crushCat: 360.0 / 296.0
        default: 360.0 / 194.0
        }
    }

    /// Tek kareyi çözer; ekrandaki boyuttan büyükse küçültür.
    static func decodeFrame(_ source: CGImageSource, at index: Int, maxPixelSize: Int) -> CGImage? {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let image = CGImageSourceCreateImageAtIndex(source, index, options) else { return nil }
        let longest = max(image.width, image.height)
        guard maxPixelSize > 0, longest > maxPixelSize * 23 / 20 else { return image }
        let scale = CGFloat(maxPixelSize) / CGFloat(longest)
        let width = max(Int(CGFloat(image.width) * scale), 1)
        let height = max(Int(CGFloat(image.height) * scale), 1)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    /// Yalnızca ilk kare: kedi ekrana hemen gelir, hareket kareler hazır olunca başlar.
    static func decodeFirstFrame(_ name: String, maxPixelSize: Int) async -> CGImage? {
        guard let url = url(name) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return decodeFrame(source, at: 0, maxPixelSize: maxPixelSize)
        }.value
    }
}

/// Çözülmüş kareler uygulama boyunca saklanır: ekrana geri dönünce yeniden çözülmez; aynı
/// animasyonu isteyen ikinci görünüm de aynı işi bekler. Bellek uyarısında boşaltılır.
@MainActor
final class LoopingFrameStore {
    static let shared = LoopingFrameStore()

    private var cache: [String: [CGImage]] = [:]
    private var tasks: [String: Task<[CGImage], Never>] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in LoopingFrameStore.shared.cache.removeAll() }
        }
    }

    private static func key(_ name: String, _ size: Int) -> String {
        // Boyutlar 32 piksellik basamaklara yuvarlanır: küçük düzen farkları yeniden çözdürmesin
        "\(name)@\((size + 31) / 32)"
    }

    func cached(_ name: String, maxPixelSize: Int) -> [CGImage]? {
        cache[Self.key(name, maxPixelSize)]
    }

    func frames(_ name: String, maxPixelSize: Int) async -> [CGImage] {
        let key = Self.key(name, maxPixelSize)
        if let frames = cache[key] { return frames }
        let task: Task<[CGImage], Never>
        if let running = tasks[key] {
            task = running
        } else {
            let size = (maxPixelSize + 31) / 32 * 32
            let url = LoopingCatAnimation.url(name)
            task = Task.detached(priority: .userInitiated) { () -> [CGImage] in
                guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
                // Kareler sırayla çözülür (her kare bağımsız; sıralı okuma en hızlısı)
                return (0..<CGImageSourceGetCount(source)).compactMap {
                    LoopingCatAnimation.decodeFrame(source, at: $0, maxPixelSize: size)
                }
            }
            tasks[key] = task
        }
        let frames = await task.value
        tasks[key] = nil
        if !frames.isEmpty { cache[key] = frames }
        return frames
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
        guard let first = frames.first, first.height > 0 else { return LoopingCatAnimation.aspectRatio(name) }
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
        // Dokunarak sevmek yalnızca düğme dışındaki kedilerde: düğmenin içinde dokunuşu yutup
        // kartın açılmasını engellerdi
        .modifier(TapToPet(isEnabled: tapToPet) { pet(at: nil) })
        .onGeometryChange(for: Int.self) { proxy in
            Int(max(proxy.size.width, proxy.size.height) * min(displayScale, LoopingCatAnimation.maxPixelScale))
        } action: { pixelSize = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: pixelSize) {
            guard pixelSize > 0 else { return }
            let store = LoopingFrameStore.shared
            // Daha önce çözüldüyse hemen; değilse önce ilk kare, sonra bütün kareler
            if let cached = store.cached(name, maxPixelSize: pixelSize) {
                frames = cached
                return
            }
            if frames.isEmpty, let first = await LoopingCatAnimation.decodeFirstFrame(name, maxPixelSize: pixelSize) {
                frames = [first]
            }
            let all = await store.frames(name, maxPixelSize: pixelSize)
            if !all.isEmpty { frames = all }
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

private struct TapToPet: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.onTapGesture(perform: action)
        } else {
            content
        }
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
