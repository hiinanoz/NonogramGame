import SwiftUI

/// Odada dolaşan küçük piksel kedi (oyun ekranındaki yardımcı kedinin pozları ve tür renkleri).
/// Kendi başına yürür, oturur, yalanır, uyur; arada mobilyanın üstüne çıkıp oturur. Uykucu kedi
/// çoğunlukla minderde uyur. Uyurken başının üstünde "Zzz" yükselir. Görev, kat ekrandan çıkınca
/// iptal olur (tembel kule); "Hareketi Azalt" açıkken oturur (uykucu kedi uyur).
@MainActor
struct CatTowerPixelCat: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let coat: CatCoat
    /// Odanın boyutu ve mobilyanın oturma yeri (kedi oraya zıplayabilir).
    let room: CGSize
    let seat: CGRect
    /// Zeminin odadaki yüksekliği (oran); kedinin ayakları buraya basar.
    var floorLine: CGFloat = 0.9
    /// Bu kattaki kedi çoğunlukla uyur.
    var isSleepy = false
    /// Kata göre başlangıç ve davranış çeşitliliği.
    let seed: Int

    @State private var x: CGFloat = 0.3
    @State private var isOnSeat = false
    @State private var pose: CatPose = .sit
    @State private var facingRight = true

    /// Kedinin boyu odanın yaklaşık beşte biri.
    private var pixel: CGFloat { max(1.4, room.height * 0.2 / CGFloat(CatPose.rows)) }
    private var size: CGSize { CGSize(width: CGFloat(CatPose.columns) * pixel, height: CGFloat(CatPose.rows) * pixel) }
    private var floorY: CGFloat { room.height * floorLine - size.height }
    /// Minder hizası: mobilyanın üst kenarından biraz aşağısı (sırtlığın önünde oturur).
    private var seatY: CGFloat { seat.minY + seat.height * 0.45 - size.height }

    var body: some View {
        CatSprite(pose: pose, pixel: pixel, coat: coat)
            .scaleEffect(x: facingRight ? 1 : -1)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: facingRight ? .topTrailing : .topLeading) {
                if pose == .sleep {
                    CatTowerZzz(size: size.height * 0.55, isAnimated: !reduceMotion)
                        .offset(x: facingRight ? size.width * 0.15 : -size.width * 0.15, y: -size.height * 0.55)
                }
            }
            .offset(x: xOffset(x), y: isOnSeat ? seatY : floorY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                x = CGFloat((seed * 37) % 100) / 100
                facingRight = seed % 2 == 0
                if isSleepy {
                    // Uykucu kedi açılışta zaten yerinde uyuyor
                    x = seatX
                    isOnSeat = true
                    pose = .sleep
                }
                try? await Task.sleep(for: .seconds(Double(seed % 7) * 0.3))
                await live()
            }
    }

    /// 0…1 konumunu odanın yürünebilir genişliğine çevirir.
    private func xOffset(_ value: CGFloat) -> CGFloat {
        let minX = room.width * 0.08
        let maxX = room.width * 0.92 - size.width
        return minX + (maxX - minX) * value
    }

    private var seatX: CGFloat {
        let minX = room.width * 0.08
        let maxX = room.width * 0.92 - size.width
        let center = seat.midX - size.width / 2
        return max(0, min(1, (center - minX) / max(maxX - minX, 1)))
    }

    private func live() async {
        while !Task.isCancelled {
            if reduceMotion {
                pose = isSleepy ? .sleep : .sit
                await pause(1)
                continue
            }
            if isSleepy {
                await sleepyLoop()
                continue
            }
            switch Int.random(in: 0..<10) {
            case 0..<4: await walk(to: CGFloat.random(in: 0...1))
            case 4..<6: await groom()
            case 6: await nap()
            case 7: await hopOnSeat()
            default:
                pose = .sit
                await pause(Double.random(in: 1.5...3))
            }
        }
    }

    /// Uykucu kedi: uzun uykular, arada kısa bir uyanıp yalanma ya da yer değiştirme.
    private func sleepyLoop() async {
        pose = .sleep
        await pause(Double.random(in: 10...18))
        switch Int.random(in: 0..<4) {
        case 0: await groom()
        case 1:
            await walk(to: CGFloat.random(in: 0...1))
            pose = .sleep
            await pause(Double.random(in: 8...14))
            await hopOnSeat(thenSleep: true)
        default:
            pose = .sit
            await pause(Double.random(in: 1.5...3))
        }
    }

    private func walk(to target: CGFloat) async {
        if isOnSeat { await hopDown() }
        let distance = abs(target - x) * room.width * 0.84
        guard distance > 6 else { return }
        facingRight = target > x
        // Yaklaşık 18 pt/sn: telaşsız bir yürüyüş
        let duration = Double(distance / 18)
        withAnimation(.linear(duration: duration)) { x = target }
        var elapsed = 0.0
        var step = false
        while elapsed < duration, !Task.isCancelled {
            step.toggle()
            pose = step ? .walk1 : .walk2
            await pause(0.2)
            elapsed += 0.2
        }
        pose = .sit
    }

    private func hopOnSeat(thenSleep: Bool = false) async {
        guard !isOnSeat else {
            await nap()
            return
        }
        await walk(to: seatX)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { isOnSeat = true }
        await pause(0.4)
        if thenSleep {
            pose = .sleep
        } else if Bool.random() {
            await nap()
        } else {
            await groom()
        }
    }

    private func hopDown() async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isOnSeat = false }
        await pause(0.35)
    }

    private func groom() async {
        pose = .sit
        for _ in 0..<Int.random(in: 3...5) where !Task.isCancelled {
            pose = .lick1
            await pause(0.35)
            pose = .lick2
            await pause(0.35)
        }
        pose = .sit
        await pause(1)
    }

    private func nap() async {
        pose = .sleep
        await pause(Double.random(in: 4...8))
        pose = .sit
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

/// Uyuyan kedinin üstünde yükselip sönen "z" harfleri.
struct CatTowerZzz: View {
    let size: CGFloat
    let isAnimated: Bool

    var body: some View {
        if isAnimated {
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                letters(time: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            letters(time: nil)
        }
    }

    private func letters(time: TimeInterval?) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<3, id: \.self) { index in
                let phase: Double = time.map { ($0 / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1) } ?? Double(index) / 3
                let scale: CGFloat = 0.55 + CGFloat(phase) * 0.6
                Text("z")
                    .font(.system(size: size * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#6E8BD8"))
                    .shadow(color: .white.opacity(0.9), radius: 0.5)
                    .offset(x: CGFloat(phase) * size * 0.7, y: -CGFloat(phase) * size * 1.2)
                    .opacity(time == nil ? 1 : (phase < 0.8 ? 1 : (1 - phase) * 5))
            }
        }
        .frame(width: size * 1.4, height: size * 1.6, alignment: .bottomLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
