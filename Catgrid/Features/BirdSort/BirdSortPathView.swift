import NonogramKit
import SwiftUI

/// Bir adanın 75 bölümü: adanın yol görseli alt alta eklenir (her görselde 10 bölüm) ve bölümler
/// yolun üstüne dizilir. 1. bölüm en altta, yukarı doğru ilerler; açılışta sıradaki bölüm ortalanır.
@MainActor
struct BirdSortPathView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    let island: BirdSortIsland

    private static let nodesPerTile = 10
    private var tileCount: Int {
        (BirdSortCatalog.levelsPerIsland + Self.nodesPerTile - 1) / Self.nodesPerTile
    }

    var body: some View {
        let birds = model.birds
        let range = birds.islandRange(island.index)
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let aspect: CGFloat = Self.aspect(of: island.pathImage)
            let tileHeight: CGFloat = width * aspect
            let viewport: CGFloat = proxy.size.height
            let content: CGFloat = tileHeight * CGFloat(tileCount)
            ScrollView(showsIndicators: false) {
                // Görseller alt alta; yol ve bölümler hepsinin üstünde, zeminle birlikte kayar
                VStack(spacing: 0) {
                    ForEach(0..<tileCount, id: \.self) { _ in
                        Image(island.pathImage)
                            .resizable()
                            .frame(width: width, height: tileHeight)
                    }
                }
                .overlay(alignment: .topLeading) {
                    levelLayer(range: range, birds: birds, width: width, tileHeight: tileHeight)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Açılışta kaldığı bölüm (ada bittiyse ya da henüz gelinmediyse ilk bölüm) ekranın
            // ortasında: ilk kaydırma konumu bölümün içerikteki yerinden hesaplanır
            .defaultScrollAnchor(UnitPoint(x: 0.5, y: centeringAnchor(range: range, birds: birds, width: width,
                                                                       tileHeight: tileHeight, viewport: viewport,
                                                                       content: content)))
        }
        // Harita üst menünün altından başlar (tam sayfa değil)
        .background(theme.background.ignoresSafeArea())
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BirdSortRoundButton(symbol: "chevron.left") { router.pop() }
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("birds.path.back")
            }
            ToolbarItem(placement: .principal) {
                BirdSortTitleCapsule(title: Text(island.title))
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Gold.mid)
                    Text(verbatim: "\(birds.stars(inIsland: island.index))/\(BirdSortCatalog.levelsPerIsland * 3)")
                }
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(theme.surface.opacity(0.95)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }

    /// Bölümleri sırayla bağlayan yol ve bölüm düğmeleri (içeriğin tamamı boyunca).
    private func levelLayer(range: ClosedRange<Int>, birds: BirdSortModel, width: CGFloat, tileHeight: CGFloat) -> some View {
        let points: [CGPoint] = range.map { number in
            let spot = spot(of: number - range.lowerBound)
            return CGPoint(x: spot.node.x * width, y: (CGFloat(spot.tile) + spot.node.y) * tileHeight)
        }
        // Yol sıradaki bölüme kadar canlı; ada bittiyse tamamı
        let current = birds.currentLevel
        let reached: Int = current > range.upperBound || birds.completed(inIsland: island.index) == range.count
            ? points.count - 1 : (range.contains(current) ? current - range.lowerBound : 0)
        return ZStack(alignment: .topLeading) {
            BirdSortRoad(points: points, reached: reached)
            ForEach(Array(range), id: \.self) { number in
                BirdSortLevelNode(number: number, stars: birds.stars(for: number),
                                  isUnlocked: birds.isUnlocked(number), isCurrent: birds.currentLevel == number,
                                  tint: island.tint) {
                    router.push(.birdGame(level: number))
                }
                .position(points[number - range.lowerBound])
            }
        }
        .frame(width: width, height: tileHeight * CGFloat(tileCount), alignment: .topLeading)
    }

    /// Kaydırma bağlantı noktası: içeriğin `a` oranındaki noktası ekranın `a` oranına gelir. Hedef
    /// bölümün ekranın ortasına gelmesi için a = (y − ekran/2) / (içerik − ekran).
    private func centeringAnchor(range: ClosedRange<Int>, birds: BirdSortModel, width: CGFloat,
                                 tileHeight: CGFloat, viewport: CGFloat, content: CGFloat) -> CGFloat {
        guard content > viewport, tileHeight > 0 else { return 1 }
        let current = birds.currentLevel
        let target = range.contains(current) ? current : range.lowerBound
        let spot = spot(of: target - range.lowerBound)
        let y: CGFloat = (CGFloat(spot.tile) + spot.node.y) * tileHeight
        return min(max((y - viewport / 2) / (content - viewport), 0), 1)
    }

    /// `index`: adadaki 0'dan başlayan bölüm sırası. Alttaki parçadan başlar, her parçada aşağıdan
    /// yukarı (görselin noktaları yukarıdan aşağı verildiğinden ters sırada).
    private func spot(of index: Int) -> (tile: Int, node: CGPoint) {
        let nodes = island.pathNodes
        let node = nodes[nodes.count - 1 - index % Self.nodesPerTile]
        return (tileCount - 1 - index / Self.nodesPerTile, node)
    }

    private static func aspect(of name: String) -> CGFloat {
        guard let image = UIImage(named: name), image.size.width > 0 else { return 1.75 }
        return image.size.height / image.size.width
    }
}

/// Yol üstündeki bölüm düğmesi: numara, kazanılan yıldızlar; kilitliyse kilit, sıradakiyse parlar.
struct BirdSortLevelNode: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let number: Int
    let stars: Int
    let isUnlocked: Bool
    let isCurrent: Bool
    let tint: Color
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: -2) {
                ZStack {
                    Circle()
                        .fill(isUnlocked
                              ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color(hex: "#B9B4BE")))
                    Circle().strokeBorder(.white, lineWidth: 3)
                    if isUnlocked {
                        Text(verbatim: "\(number)")
                            .font(.system(size: isCurrent ? 22 : (number >= 100 ? 15 : 17), weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                // Sıradaki bölüm daha büyük ve nefes alır
                .frame(width: isCurrent ? 60 : 46, height: isCurrent ? 60 : 46)
                .scaleEffect(isCurrent && pulse ? 1.12 : 1)
                .shadow(color: isCurrent ? tint.opacity(0.8) : .black.opacity(0.25), radius: isCurrent ? 8 : 3, y: 2)
                if stars > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(index < stars ? Gold.mid : Color.white.opacity(0.7))
                                .shadow(color: .black.opacity(0.3), radius: 0.5, y: 0.5)
                        }
                    }
                }
            }
            .frame(minWidth: 48, minHeight: 48)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isUnlocked)
        .accessibilityLabel(Text("Level \(number)"))
        .accessibilityValue(isUnlocked ? Text("\(stars) of 3 stars") : Text("Locked"))
        .accessibilityIdentifier("birds.level.\(number)")
        .onAppear {
            guard isCurrent, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Bölümleri birbirine bağlayan kum rengi yol (Kedi Bulmaca haritasındaki gibi): koyu kenar, açık
/// dolgu ve ortada basamak taşları. Geçilen kısım daha canlı, ilerisi soluk.
struct BirdSortRoad: View {
    let points: [CGPoint]
    /// Açılmış son bölüme kadar olan nokta sayısı (o noktaya kadar yol canlı).
    let reached: Int

    var body: some View {
        ZStack {
            road(points)
                .opacity(0.55)
            road(Array(points.prefix(reached + 1)))
        }
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func road(_ points: [CGPoint]) -> some View {
        let path = Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for (start, end) in zip(points, points.dropFirst()) {
                let dy = end.y - start.y
                path.addCurve(to: end,
                              control1: CGPoint(x: start.x, y: start.y + dy * 0.55),
                              control2: CGPoint(x: end.x, y: end.y - dy * 0.55))
            }
        }
        return ZStack {
            path.stroke(Color(hex: "#B8956A").opacity(0.7), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
            path.stroke(Color(hex: "#F6E8CC"), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
            path.stroke(Color(hex: "#D9BF8F"), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [1, 14]))
        }
    }
}
