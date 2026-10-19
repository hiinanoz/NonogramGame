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
            ScrollViewReader { reader in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(0..<tileCount, id: \.self) { _ in
                                Image(island.pathImage)
                                    .resizable()
                                    .frame(width: width, height: tileHeight)
                            }
                        }
                        ForEach(Array(range), id: \.self) { number in
                            let point = position(of: number - range.lowerBound, width: width, tileHeight: tileHeight)
                            BirdSortLevelNode(number: number, stars: birds.stars(for: number),
                                              isUnlocked: birds.isUnlocked(number), isCurrent: birds.currentLevel == number,
                                              tint: island.tint) {
                                router.push(.birdGame(level: number))
                            }
                            .position(point)
                            .id(number)
                        }
                    }
                    .frame(width: width, height: tileHeight * CGFloat(tileCount))
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear {
                    let target = min(max(birds.currentLevel, range.lowerBound), range.upperBound)
                    reader.scrollTo(target, anchor: .center)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(hex: "#7FC9E6").ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
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
                .background(Capsule().fill(.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }

    /// `index`: adadaki 0'dan başlayan bölüm sırası. Alttaki görselden başlar, her görselde aşağıdan
    /// yukarı (görselin noktaları yukarıdan aşağı verildiğinden ters sırada).
    private func position(of index: Int, width: CGFloat, tileHeight: CGFloat) -> CGPoint {
        let tileFromBottom = index / Self.nodesPerTile
        let nodes = island.pathNodes
        let node = nodes[nodes.count - 1 - index % Self.nodesPerTile]
        let tile = tileCount - 1 - tileFromBottom
        return CGPoint(x: node.x * width, y: (CGFloat(tile) + node.y) * tileHeight)
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
                            .font(.system(size: number >= 100 ? 15 : 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 46, height: 46)
                .scaleEffect(isCurrent && pulse ? 1.1 : 1)
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
