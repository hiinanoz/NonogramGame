import SwiftUI

/// Bölüm bitti kartı: yıldızlar, hamle sayısı, ödül; sonraki bölüm ya da harita.
struct BirdSortWinOverlay: View {
    @Environment(\.appTheme) private var theme
    let level: Int
    let stars: Int
    let moves: Int
    let reward: BirdSortReward?
    let hasNext: Bool
    let onNext: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Level \(level) Complete!")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: index == 1 ? 46 : 36, weight: .bold))
                            .foregroundStyle(index < stars ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Color.gray.opacity(0.3)))
                            .offset(y: index == 1 ? -6 : 0)
                    }
                }
                Image("sortcat-cheer-4")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                Text("in \(moves) moves")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                if let reward {
                    HStack(spacing: 6) {
                        Image(systemName: reward == .hint ? "lightbulb.fill" : "plus.rectangle.on.rectangle")
                        Text(reward == .hint ? "+1 Hint" : "+1 Extra Branch")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "#C25A1E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#FFE7C7")))
                }
                VStack(spacing: 10) {
                    if hasNext {
                        Button(action: onNext) {
                            Text("Next Level")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("birds.result.next")
                    }
                    Button(action: onMap) {
                        Text("Back to Map")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Capsule().fill(theme.surfaceMuted))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("birds.result.map")
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
        }
    }
}

/// İlk bölümde nasıl oynanır kartı.
struct BirdSortIntroOverlay: View {
    @Environment(\.appTheme) private var theme
    let capacity: Int
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack(spacing: -8) {
                    ForEach(0..<4, id: \.self) { index in
                        Image("bird-0-stand")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .offset(y: index % 2 == 0 ? 0 : -4)
                    }
                }
                Text("Bird Sort")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                VStack(alignment: .leading, spacing: 10) {
                    rule("hand.tap.fill", Text("Tap a branch, then tap another one. The birds at the tip fly over."))
                    rule("arrow.triangle.swap", Text("Birds can only land on an empty branch or next to the same kind of bird."))
                    rule("bird.fill", Text("Gather \(capacity) of the same bird on one branch and they fly away together."))
                    rule("cat.fill", Text("Clear every branch to finish the level. The cat cheers you on!"))
                }
                Button(action: onStart) {
                    Text("Let's Play!")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("birds.intro.play")
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .padding(24)
        }
    }

    private func rule(_ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(Color(hex: "#F07A3C"))
                .frame(width: 26)
            text
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Ana sayfadaki Kuş Sıralama kartı.
@MainActor
struct BirdSortHomeCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    var compact = false
    let action: () -> Void

    var body: some View {
        let birds = model.birds
        let ink = theme.isDark ? Color(hex: "#BFE6F7") : Color(hex: "#1E5B7A")
        Button(action: action) {
            HStack(spacing: 10) {
                Image("bird-0-stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 32 : 38, height: compact ? 32 : 38)
                    .background(Circle().fill(.white.opacity(0.85)).padding(-3))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bird Sort")
                        .font(compact ? Font.headline.bold() : .title3.bold())
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Text("Level \(birds.currentLevel)")
                        Text(verbatim: "·")
                        Image(systemName: "star.fill")
                            .foregroundStyle(Gold.mid)
                        Text(verbatim: "\(birds.totalStars)")
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.85))
                    .lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: -10) {
                    ForEach([1, 4, 6], id: \.self) { species in
                        Image("bird-\(species)-stand")
                            .resizable()
                            .scaledToFit()
                            .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                    }
                }
                .scaleEffect(x: -1)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color(hex: "#2E8FC0")))
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: theme.isDark ? [Color(hex: "#1F3A4A"), Color(hex: "#18303D")]
                                                              : [Color(hex: "#DDF3FB"), Color(hex: "#BFE6F7")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(theme.isDark ? 0.06 : 0.7), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#2E8FC0").opacity(theme.isDark ? 0 : 0.16), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
