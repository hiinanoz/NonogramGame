import SwiftUI
import UIKit

/// Kedi animasyonlarının merkezi ayarları: hızlar, tekrar aralıkları ve açık/kapalı durumları.
/// Bütün ekranlar buradan okur; bir değeri değiştirmek uygulamanın tamamına yansır.
enum CatAnimationSettings {
    /// Göz kırpma: rastgele aralık, kapalı kalma süresi, bazen arka arkaya iki kez.
    static let blinkEnabled = true
    static let blinkInterval: ClosedRange<Double> = 4...8
    static let blinkClosed: Double = 0.09
    static let blinkHalf: Double = 0.05
    static let doubleBlinkChance = 0.25

    /// Nefes alma: gövde katmanı çok hafif büyüyüp küçülür (tabanı sabit).
    static let breathEnabled = true
    static let breathPeriod: Double = 3.6
    static let breathAmount: CGFloat = 0.012

    /// Kuyruk: bağlantı noktası etrafında yavaş salınım.
    static let tailEnabled = true
    static let tailPeriod: Double = 2.8
    static let tailAngle: Double = 7

    /// Yumakla oynama: pati yumağa dokunur, yumak hafifçe yuvarlanıp geri gelir.
    static let yarnEnabled = true
    static let yarnCycle: Double = 5.5
    static let yarnRoll: CGFloat = 0.035
    static let pawAngle: Double = 14

    /// Aynı anda en fazla kaç kedinin "canlı" (yumak, esneme gibi büyük) hareket yapabileceği;
    /// gerisi yalnızca göz kırpar ve nefes alır.
    static let maxLivelyCats = 1
}

/// Bir kedinin katman görselleri (aynı tuval boyutunda, üst üste konunca tam kedi olan
/// şeffaf PNG'ler). Pivot noktaları tuvale oranla verilir (0…1).
struct CatRig {
    let body: String
    let head: String
    var eyesHalf: String?
    var eyesClosed: String?
    var tail: String?
    var tailPivot = UnitPoint(x: 0.5, y: 0.5)
    var paw: String?
    var pawPivot = UnitPoint(x: 0.5, y: 0.5)
    var yarn: String?

    /// Asset kataloğunda bütün zorunlu katmanlar varsa kullanılabilir.
    var isAvailable: Bool {
        [body, head].allSatisfy { UIImage(named: $0) != nil }
    }

    /// Kedi Bulmaca'nın yumakla oynayan kedisi (ana sayfa prototipi). Katmanlar gelene kadar
    /// `isAvailable` yanlış kalır ve ekranda bugünkü tek parça çizim gösterilir.
    static let yarnCat = CatRig(
        body: "rig-yarn-body",
        head: "rig-yarn-head",
        eyesHalf: "rig-yarn-eyes-half",
        eyesClosed: "rig-yarn-eyes-closed",
        tail: "rig-yarn-tail",
        tailPivot: UnitPoint(x: 0.78, y: 0.62),
        paw: "rig-yarn-paw",
        pawPivot: UnitPoint(x: 0.36, y: 0.58),
        yarn: "rig-yarn-yarn"
    )
}

/// Katmanlı, canlı kedi: göz kırpar, nefes alır, kuyruğunu sallar, yumakla oynar.
/// - Ekranda görünmezken, uygulama arka plandayken ve "Hareketi Azalt" açıkken durur.
/// - Zaman tek bir `TimelineView` saatinden okunur; kareler 60 FPS'te yalnızca dönüşüm
///   (döndürme/ölçek/kaydırma) hesaplar, görseller yeniden çizilmez.
@MainActor
struct LivingCatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let rig: CatRig
    /// Yumak gibi büyük hareketler (aynı anda yalnızca bir kedide).
    var isLively = false

    @State private var isVisible = false
    @State private var eyes: EyeState = .open

    private enum EyeState {
        case open, half, closed
    }

    private var isRunning: Bool {
        isVisible && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isRunning)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            layers(time: isRunning ? t : 0)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: isRunning) { await blinkLoop() }
        .accessibilityHidden(true)
    }

    private func layers(time t: Double) -> some View {
        let s = CatAnimationSettings.self
        let breath = s.breathEnabled ? 1 + s.breathAmount * CGFloat(sin(t * 2 * .pi / s.breathPeriod)) : 1
        let tail = s.tailEnabled ? s.tailAngle * sin(t * 2 * .pi / s.tailPeriod) : 0
        // Yumak döngüsü: kısa bir dokunuş (pati iner), yumak yuvarlanıp geri gelir, uzun bekleme
        let phase = (t.truncatingRemainder(dividingBy: s.yarnCycle)) / s.yarnCycle
        let tap = isLively && s.yarnEnabled ? max(0, sin(min(phase / 0.18, 1) * .pi)) : 0
        let roll = isLively && s.yarnEnabled ? sin(min(max((phase - 0.1) / 0.5, 0), 1) * .pi) : 0
        return GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let tailName = rig.tail {
                    Image(tailName).resizable().scaledToFit()
                        .rotationEffect(.degrees(tail), anchor: rig.tailPivot)
                }
                Image(rig.body).resizable().scaledToFit()
                    .scaleEffect(x: 1 + (breath - 1) * 0.5, y: breath, anchor: .bottom)
                if let yarn = rig.yarn {
                    Image(yarn).resizable().scaledToFit()
                        .rotationEffect(.degrees(roll * 25), anchor: .center)
                        .offset(x: size.width * s.yarnRoll * CGFloat(roll))
                }
                Image(rig.head).resizable().scaledToFit()
                    .offset(y: -size.height * (breath - 1) * 0.6)
                if eyes != .open, let lid = eyes == .closed ? rig.eyesClosed : rig.eyesHalf {
                    Image(lid).resizable().scaledToFit()
                        .offset(y: -size.height * (breath - 1) * 0.6)
                }
                if let paw = rig.paw {
                    Image(paw).resizable().scaledToFit()
                        .rotationEffect(.degrees(-s.pawAngle * tap), anchor: rig.pawPivot)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// Rastgele aralıklarla göz kırpma; bazen iki kez üst üste.
    private func blinkLoop() async {
        guard isRunning, CatAnimationSettings.blinkEnabled, rig.eyesClosed != nil else {
            eyes = .open
            return
        }
        let s = CatAnimationSettings.self
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: s.blinkInterval)))
            guard !Task.isCancelled else { return }
            let times = Double.random(in: 0...1) < s.doubleBlinkChance ? 2 : 1
            for _ in 0..<times {
                eyes = .half
                try? await Task.sleep(for: .seconds(s.blinkHalf))
                eyes = .closed
                try? await Task.sleep(for: .seconds(s.blinkClosed))
                eyes = .half
                try? await Task.sleep(for: .seconds(s.blinkHalf))
                eyes = .open
                try? await Task.sleep(for: .seconds(0.12))
            }
        }
    }
}

/// Katmanları varsa canlı kediyi, yoksa bugünkü tek parça çizimi gösterir.
struct CatIllustration: View {
    let rig: CatRig?
    let fallback: String
    var isLively = false

    var body: some View {
        if let rig, rig.isAvailable {
            LivingCatView(rig: rig, isLively: isLively)
        } else {
            IllustrationView(name: fallback)
        }
    }
}
