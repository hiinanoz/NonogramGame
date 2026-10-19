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
                Text("Meow Sort")
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
