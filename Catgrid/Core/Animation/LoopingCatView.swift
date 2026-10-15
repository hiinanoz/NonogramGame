import ImageIO
import SwiftUI

/// Videodan hazırlanmış, arka planı temizlenmiş kedi animasyonları (döngülü, saydam WebP).
/// Dosyalar `Resources/Animations` altında; ad ile çağrılır.
enum LoopingCatAnimation {
    /// Ana sayfadaki Kedi Bulmaca kartında yumakla oynayan kedi.
    static let yarnCat = "yarn-cat-loop"
    /// Videonun kare hızı.
    static let frameRate: Double = 24

    static func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "webp")
    }

    static func isAvailable(_ name: String) -> Bool {
        url(name) != nil
    }

    /// Bütün kareleri bir kez çözer (arka planda); oynatırken yalnızca hazır kare seçilir.
    static func decodeFrames(_ name: String) async -> [CGImage] {
        guard let url = url(name) else { return [] }
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [CGImage]() }
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            return (0..<CGImageSourceGetCount(source)).compactMap {
                CGImageSourceCreateImageAtIndex(source, $0, options)
            }
        }.value
    }
}

/// Döngülü kedi animasyonunu oynatır.
/// - Ekranda değilken, uygulama arka plandayken ya da "Hareketi Azalt" açıkken durur
///   (Hareketi Azalt'ta ilk kare sabit görünür).
/// - Kareler önceden çözülür; her karede yalnızca hazır görüntü değişir.
@MainActor
struct LoopingCatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let name: String

    @State private var frames: [CGImage] = []
    @State private var isVisible = false

    private var isRunning: Bool {
        isVisible && !reduceMotion && scenePhase == .active && frames.count > 1
    }

    private var aspectRatio: CGFloat {
        guard let first = frames.first, first.height > 0 else { return 360.0 / 187.0 }
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
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task {
            if frames.isEmpty {
                frames = await LoopingCatAnimation.decodeFrames(name)
            }
        }
        .accessibilityHidden(true)
    }
}
