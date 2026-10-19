import NonogramKit
import SwiftUI

/// Dallar ve kuşlar: dallar iki sütunda (sol dallar soldan, sağ dallar aynalanmış sağdan uzanır).
/// Dal i: çift numaralar solda, tekler sağda; satır i/2. Kuşlar tek bir katmanda çizilir, dal ve
/// yuva değişince yeni yerlerine uçar.
@MainActor
struct BirdSortBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: BirdSortGameViewModel
    let branchImage: String

    var body: some View {
        GeometryReader { proxy in
            let layout = BirdSortBoardLayout(size: proxy.size, branches: viewModel.branchCount, capacity: viewModel.capacity)
            ZStack(alignment: .topLeading) {
                ForEach(0..<viewModel.branchCount, id: \.self) { index in
                    branch(index, layout: layout)
                }
                ForEach(viewModel.birds) { token in
                    bird(token, layout: layout)
                }
                ForEach(0..<viewModel.branchCount, id: \.self) { index in
                    hitArea(index, layout: layout)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func branch(_ index: Int, layout: BirdSortBoardLayout) -> some View {
        let frame = layout.branchFrame(index)
        let isLeft = index % 2 == 0
        let isSelected = viewModel.selected == index
        let hint = viewModel.hint
        let isHinted = hint?.source == index || hint?.target == index
        return Image(branchImage)
            .resizable()
            .scaledToFit()
            .frame(width: frame.width, height: frame.height, alignment: .center)
            .scaleEffect(x: isLeft ? 1 : -1)
            .shadow(color: isSelected ? Color.white.opacity(0.95) : (isHinted ? Color(hex: "#FFD54A") : .clear), radius: 8)
            .shadow(color: isHinted ? Color(hex: "#FFD54A").opacity(0.9) : .clear, radius: 14)
            .modifier(BirdSortShake(amount: viewModel.shaking == index ? CGFloat(viewModel.shakeCount) : 0))
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }

    /// Dokunma alanı: dalın bütün satırı (yarım ekran genişliği).
    private func hitArea(_ index: Int, layout: BirdSortBoardLayout) -> some View {
        let hit = layout.hitFrame(index)
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: hit.width, height: hit.height)
            .onTapGesture { viewModel.tap(branch: index) }
            .offset(x: hit.minX, y: hit.minY)
            .accessibilityElement()
            .accessibilityLabel(Text("Branch \(index + 1)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("birds.branch.\(index)")
    }

    private func bird(_ token: BirdToken, layout: BirdSortBoardLayout) -> some View {
        let isLeft = token.branch % 2 == 0
        let size = layout.birdSize
        var point = layout.birdPoint(branch: token.branch, slot: token.slot)
        if viewModel.isLifted(token) { point.y -= size * 0.22 }
        if token.phase == .leaving {
            // Sürü yukarı ve dışarı uçar
            point = CGPoint(x: isLeft ? -size * 2 : layout.size.width + size * 2, y: -size * 2 - CGFloat(token.slot) * size * 0.4)
        }
        return BirdSprite(species: token.species, phase: token.phase, isAnimated: !reduceMotion, seed: token.id)
            .frame(width: size, height: size)
            .scaleEffect(x: isLeft ? 1 : -1)
            .position(point)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Dal ve kuş konumları.
struct BirdSortBoardLayout {
    let size: CGSize
    let branches: Int
    let capacity: Int

    var rows: Int { max((branches + 1) / 2, 1) }
    var rowHeight: CGFloat { size.height / CGFloat(rows) }
    var sideWidth: CGFloat { size.width / 2 }

    /// Kuş boyu: dalın uzunluğuna ve satır yüksekliğine sığar.
    var birdSize: CGFloat {
        let along = (sideWidth * 0.78) / CGFloat(capacity)
        return min(along * 1.38, rowHeight * 0.82, 80)
    }

    /// Dalın üst yüzeyi (kuşların ayak bastığı çizgi).
    func perchY(row: Int) -> CGFloat {
        CGFloat(row) * rowHeight + rowHeight * 0.74
    }

    func branchFrame(_ index: Int) -> CGRect {
        let row = index / 2
        let width = sideWidth * 0.98
        let height = min(rowHeight * 0.5, width * 0.36)
        let y = perchY(row: row) - height * 0.32
        let x = index % 2 == 0 ? 0 : size.width - width
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func hitFrame(_ index: Int) -> CGRect {
        let row = index / 2
        return CGRect(x: index % 2 == 0 ? 0 : sideWidth, y: CGFloat(row) * rowHeight, width: sideWidth, height: rowHeight)
    }

    /// Yuva 0 gövde tarafı; uç tarafa doğru dizilir.
    func birdPoint(branch: Int, slot: Int) -> CGPoint {
        let row = branch / 2
        let step = (sideWidth * 0.78) / CGFloat(capacity)
        let fromTrunk = sideWidth * 0.12 + step * (CGFloat(slot) + 0.5)
        let x = branch % 2 == 0 ? fromTrunk : size.width - fromTrunk
        return CGPoint(x: x, y: perchY(row: row) - birdSize * 0.42)
    }
}

/// Kuş çizimi: dururken arada göz kırpar, uçarken kanat çırpar.
struct BirdSprite: View {
    let species: Int
    let phase: BirdToken.Phase
    let isAnimated: Bool
    let seed: Int

    var body: some View {
        if phase == .perched {
            if isAnimated {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 4) + seed * 7
                    // Yaklaşık 5 saniyede bir kısa göz kırpma
                    let blink = tick % 21 == 0
                    image(blink ? "blink" : "stand")
                }
            } else {
                image("stand")
            }
        } else {
            TimelineView(.periodic(from: .now, by: 0.09)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.09)
                image(tick % 2 == 0 || !isAnimated ? "fly1" : "fly2")
            }
        }
    }

    private func image(_ pose: String) -> some View {
        Image("bird-\(BirdSortSpecies.asset(for: species))-\(pose)")
            .resizable()
            .scaledToFit()
    }
}

/// Bölümün tür numarası → kuş görseli. İlk adada ilk 10 tür; her adada sıradaki tür eklenir.
enum BirdSortSpecies {
    static let count = 16

    static func asset(for species: Int) -> Int {
        min(max(species, 0), count - 1)
    }
}

/// Geçersiz hamlede dal sağa sola sallanır.
struct BirdSortShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(amount * .pi * 4), y: 0))
    }
}
