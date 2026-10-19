import SwiftUI

/// Odada dolaşan küçük piksel kedi (oyun ekranındaki yardımcı kedinin pozları ve tür renkleri).
/// Kendi başına yürür, oturur, yalanır, uyur; arada mobilyanın üstüne çıkıp oturur. Görev, kat
/// ekrandan çıkınca iptal olur (tembel kule); "Hareketi Azalt" açıkken oturur.
@MainActor
struct CatTowerPixelCat: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let coat: CatCoat
    /// Odanın boyutu ve mobilyanın oturma yeri (kedi oraya zıplayabilir).
    let room: CGSize
    let seat: CGRect
    /// Kata göre başlangıç ve davranış çeşitliliği.
    let seed: Int

    @State private var x: CGFloat = 0.3
    @State private var isOnSeat = false
    @State private var pose: CatPose = .sit
    @State private var facingRight = true

    /// Kedinin boyu odanın yaklaşık beşte biri.
    private var pixel: CGFloat { max(1.4, room.height * 0.2 / CGFloat(CatPose.rows)) }
    private var size: CGSize { CGSize(width: CGFloat(CatPose.columns) * pixel, height: CGFloat(CatPose.rows) * pixel) }
    private var floorY: CGFloat { room.height * 0.9 - size.height }
    private var seatY: CGFloat { seat.minY + seat.height * 0.3 - size.height }

    var body: some View {
        CatSprite(pose: pose, pixel: pixel, coat: coat)
            .scaleEffect(x: facingRight ? 1 : -1)
            .frame(width: size.width, height: size.height)
            .offset(x: xOffset(x), y: isOnSeat ? seatY : floorY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                x = CGFloat((seed * 37) % 100) / 100
                facingRight = seed % 2 == 0
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
                pose = .sit
                await pause(1)
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

    private func hopOnSeat() async {
        guard !isOnSeat else {
            await nap()
            return
        }
        await walk(to: seatX)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { isOnSeat = true }
        await pause(0.4)
        if Bool.random() {
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
