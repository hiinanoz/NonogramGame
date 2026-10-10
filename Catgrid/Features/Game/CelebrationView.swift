import NonogramKit
import SwiftUI

/// Kutlama ekranında "Kazandıkların" altındaki tek ödül (mevcut ödül sisteminden gelir).
struct CelebrationReward: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let value: Text?
    let label: Text
}

/// Bulmaca çözülünce tam sayfa kutlama: sevinen kedi, "Tebrikler!", çözülen resim,
/// süre/zorluk/hata, kazanılanlar ve devam düğmeleri. "celebrate-hero" çizimi varsa üstte o,
/// yoksa Muffin sevinç pozunda.
@MainActor
struct CelebrationView<Actions: View>: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let subtitle: Text
    let artwork: Matrix<RGBColor?>
    let time: TimeInterval?
    let difficulty: Text
    let mistakes: Int?
    var stars: Int?
    var starNote: Text?
    var rewards: [CelebrationReward] = []
    @ViewBuilder let actions: () -> Actions
    @State private var appeared = false

    private var hasArt: Bool { Illustration.exists("celebrate-hero") }

    var body: some View {
        ZStack(alignment: .top) {
            background
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    VStack(spacing: 6) {
                        Text("Congratulations!")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.5)
                        subtitle
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                    }
                    ArtworkThumbnail(artwork: artwork)
                        .padding(10)
                        .frame(maxWidth: 170, maxHeight: 150)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.surface))
                        .shadow(color: theme.cardShadow, radius: 8, y: 3)
                    if let stars {
                        StarsView(count: stars, size: 26)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                        if let starNote {
                            starNote
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    statsRow
                    if !rewards.isEmpty {
                        rewardsSection
                    }
                    VStack(spacing: 10) {
                        actions()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { appeared = true }
        }
    }

    private var background: some View {
        ZStack(alignment: .top) {
            theme.background
            LinearGradient(
                colors: [Color(hex: theme.isDark ? "#3A2E2A" : "#FFE9D2"), theme.background],
                startPoint: .top, endPoint: .center
            )
            if !hasArt && !reduceMotion {
                RaysView()
                    .frame(width: 560, height: 560)
                    .offset(y: -200)
                    .opacity(appeared ? 0.35 : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var hero: some View {
        if hasArt {
            IllustrationView(name: "celebrate-hero", contentMode: .fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.top, 8)
        } else {
            MuffinView(pose: .cheer, speechID: 1)
                .frame(height: 150)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                .padding(.top, 8)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(title: "Time", value: time.map { Text(formatDuration($0)) } ?? Text(verbatim: "–"))
            Rectangle().fill(theme.separator).frame(width: 1, height: 34)
            stat(title: "Difficulty", value: difficulty)
            Rectangle().fill(theme.separator).frame(width: 1, height: 34)
            stat(title: "Mistakes", value: mistakes.map { Text(verbatim: "\($0)") } ?? Text(verbatim: "–"))
        }
        .padding(.vertical, 12)
        .card(cornerRadius: 20)
    }

    private func stat(title: LocalizedStringKey, value: Text) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            value
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Rewards")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(rewards) { reward in
                    VStack(spacing: 6) {
                        Image(systemName: reward.icon)
                            .font(.title2)
                            .foregroundStyle(reward.tint)
                        if let value = reward.value {
                            value
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(theme.textPrimary)
                        }
                        reward.label
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .padding(8)
                    .card(cornerRadius: 18)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("result.reward.\(reward.id)")
                }
            }
        }
    }
}
