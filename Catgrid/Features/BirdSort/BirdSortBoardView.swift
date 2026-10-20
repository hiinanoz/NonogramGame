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
    /// Dalın üst yüzeyi (bkz. `BirdSortIsland.branchSurface`).
    var branchSurface: [CGFloat] = []

    var body: some View {
        GeometryReader { proxy in
            let layout = BirdSortBoardLayout(size: proxy.size, branches: viewModel.branchCount, capacity: viewModel.capacity,
                                             branchAspect: Self.aspect(of: branchImage), surface: branchSurface)
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
            .frame(width: frame.width, height: frame.height)
            .scaleEffect(x: isLeft ? 1 : -1)
            // Arka plandan ayrışsın: hafif koyu gölge
            .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
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

    static func aspect(of name: String) -> CGFloat {
        guard let image = UIImage(named: name), image.size.height > 0 else { return 3 }
        return image.size.width / image.size.height
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
            // Ayaklar karenin altında: geniş kuşlar da dala basar
            .frame(width: size, height: size, alignment: .bottom)
            .scaleEffect(x: isLeft ? 1 : -1)
            .position(point)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Dal ve kuş konumları. Dallar ekranın kenarından başlar (gövde ucu kenarın biraz dışında) ve
/// ortaya doğru uzanır; kuşlar dalın üst yüzeyine basar.
struct BirdSortBoardLayout {
    let size: CGSize
    let branches: Int
    let capacity: Int
    /// Dal görselinin en/boy oranı.
    var branchAspect: CGFloat = 3
    /// Dal görselinde tahtanın üst yüzeyi (gövdeden uca 10 nokta, görselin %10'u ile %95'i arası).
    var surface: [CGFloat] = []

    var rows: Int { max((branches + 1) / 2, 1) }
    var rowHeight: CGFloat { size.height / CGFloat(rows) }
    var sideWidth: CGFloat { size.width / 2 }

    /// Dal genişliği: yarım ekrandan biraz uzun; gövdenin kesik ucu ekran kenarının dışında kalır.
    var branchWidth: CGFloat { sideWidth * 1.04 }
    var branchHeight: CGFloat { min(branchWidth / branchAspect, rowHeight * 0.62) }
    private var overhang: CGFloat { sideWidth * 0.06 }

    /// Kuşların dizildiği bölüm: gövdeden sonra, ucun biraz gerisine kadar.
    private var perchStart: CGFloat { sideWidth * 0.1 }
    private var perchLength: CGFloat { sideWidth * 0.82 }

    /// Kuş boyu: dalın uzunluğuna ve satır yüksekliğine sığar.
    var birdSize: CGFloat {
        let along = perchLength / CGFloat(capacity)
        return min(along * 1.38, rowHeight * 0.8, 82)
    }

    /// Dalın üst yüzeyi (kuşların ayak bastığı çizgi).
    func perchY(row: Int) -> CGFloat {
        CGFloat(row) * rowHeight + rowHeight * 0.68
    }

    func branchFrame(_ index: Int) -> CGRect {
        let row = index / 2
        let y = perchY(row: row) - branchHeight * 0.36
        let x = index % 2 == 0 ? -overhang : size.width - branchWidth + overhang
        return CGRect(x: x, y: y, width: branchWidth, height: branchHeight)
    }

    func hitFrame(_ index: Int) -> CGRect {
        let row = index / 2
        return CGRect(x: index % 2 == 0 ? 0 : sideWidth, y: CGFloat(row) * rowHeight, width: sideWidth, height: rowHeight)
    }

    /// Yuva 0 gövde tarafı; uç tarafa doğru dizilir.
    func birdPoint(branch: Int, slot: Int) -> CGPoint {
        let row = branch / 2
        let step = perchLength / CGFloat(capacity)
        let fromEdge = perchStart + step * (CGFloat(slot) + 0.5)
        let x = branch % 2 == 0 ? fromEdge : size.width - fromEdge
        // Kuşun ayakları dalın o noktadaki üst yüzeyine (biraz içine) basar
        let frame = branchFrame(branch)
        let along = (fromEdge + overhang) / branchWidth
        let feet = frame.minY + surfaceY(at: along) * branchHeight + birdSize * 0.05
        return CGPoint(x: x, y: feet - birdSize / 2)
    }

    /// Dal görselinin `fraction` (0…1) noktasında tahtanın üstü; ölçü yoksa ortalama değer.
    private func surfaceY(at fraction: CGFloat) -> CGFloat {
        guard surface.count > 1 else { return 0.48 }
        let position = (min(max(fraction, 0.1), 0.95) - 0.1) / 0.85 * CGFloat(surface.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, surface.count - 1)
        let t = position - CGFloat(lower)
        return surface[lower] * (1 - t) + surface[upper] * t
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
