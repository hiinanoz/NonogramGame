import NonogramKit
import SwiftUI

/// Kuş Sıralama ada haritası: altı ada denizde; açık adaya dokununca o adanın bölüm yolu açılır.
/// Altta sıradaki bölümü oynatan düğme.
@MainActor
struct BirdSortHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lockedNote: Int?
    @State private var bob = false

    var body: some View {
        let birds = model.birds
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                BirdSortMapLayout.background(size: size)
                ForEach(BirdSortIsland.all) { island in
                    islandButton(island, birds: birds, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, spacing: 0) { footer(birds: birds) }
        .overlay(alignment: .top) {
            if let island = lockedNote {
                Text("Finish \(Text(BirdSortIsland(index: island - 1).title)) to sail here")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.surface).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BirdSortRoundButton(symbol: "chevron.left") { router.pop() }
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("birds.hub.back")
            }
            ToolbarItem(placement: .principal) {
                BirdSortTitleCapsule(title: Text("Bird Sort"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Gold.mid)
                    Text(verbatim: "\(birds.totalStars)")
                }
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    private func islandButton(_ island: BirdSortIsland, birds: BirdSortModel, size: CGSize) -> some View {
        let unlocked = birds.isIslandUnlocked(island.index)
        let isCurrent = birds.currentIsland == island.index
        let point = BirdSortMapLayout.point(island.mapPosition, in: size)
        let width: CGFloat = min(size.width * 0.44, 210)
        let done = birds.completed(inIsland: island.index)
        return Button {
            if unlocked {
                birds.selectedIsland = island.index
                router.push(.birdIsland(island.index))
            } else {
                Haptics.selection()
                withAnimation(.spring(response: 0.3)) { lockedNote = island.index }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { if lockedNote == island.index { lockedNote = nil } }
                }
            }
        } label: {
            VStack(spacing: -10) {
                Color.clear.frame(width: width, height: width * 0.62)
                VStack(spacing: 2) {
                    Text(island.title)
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        if unlocked {
                            Image(systemName: "star.fill").foregroundStyle(Gold.mid)
                            Text(verbatim: "\(birds.stars(inIsland: island.index))")
                            Text(verbatim: "·")
                            Text(verbatim: "\(done)/\(BirdSortCatalog.levelsPerIsland)")
                        } else {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .font(.caption.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(unlocked ? Color(hex: "#4A3426") : Color(hex: "#6E6A70"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(unlocked ? Color.white.opacity(0.94) : Color(hex: "#E6E3EA").opacity(0.94))
                )
                .overlay(Capsule().strokeBorder(isCurrent ? island.tint : .clear, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            }
            .saturation(unlocked ? 1 : 0.35)
            .offset(y: isCurrent && bob ? -4 : 0)
        }
        .buttonStyle(PressableButtonStyle())
        .position(x: point.x, y: point.y + width * 0.12)
        .accessibilityLabel(Text(island.title))
        .accessibilityValue(unlocked ? Text("\(done) of \(BirdSortCatalog.levelsPerIsland) levels") : Text("Locked"))
        .accessibilityIdentifier("birds.island.\(island.index + 1)")
    }

    private func footer(birds: BirdSortModel) -> some View {
        let level = birds.currentLevel
        return Button {
            router.push(.birdGame(level: level))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Play Level \(level)")
            }
            .font(.title3.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 2))
            .shadow(color: Color(hex: "#C25A1E").opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
        .accessibilityIdentifier("birds.hub.play")
    }
}

/// Ada haritası görseli ekranı doldurur; adaların konumu görselin kırpılmasına göre hesaplanır.
enum BirdSortMapLayout {
    static let imageSize = CGSize(width: 900, height: 1601)

    static func background(size: CGSize) -> some View {
        Image("birdsort-islands")
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    static func point(_ fraction: CGPoint, in size: CGSize) -> CGPoint {
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let shown = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (size.width - shown.width) / 2, y: (size.height - shown.height) / 2)
        return CGPoint(x: origin.x + fraction.x * shown.width, y: origin.y + fraction.y * shown.height)
    }
}

/// Kuş Sıralama ekranlarındaki yuvarlak beyaz düğme.
struct BirdSortRoundButton: View {
    @Environment(\.appTheme) private var theme
    let symbol: String
    var badge: Int?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(theme.textPrimary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.94)))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Text(verbatim: "\(badge)")
                            .font(.caption2.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(Color(hex: "#F07A3C")))
                            .offset(x: 6, y: -4)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct BirdSortTitleCapsule: View {
    @Environment(\.appTheme) private var theme
    let title: Text

    var body: some View {
        title
            .font(.headline)
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.92)))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}
