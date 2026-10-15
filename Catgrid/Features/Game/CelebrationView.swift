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
    /// Sağ üstte paylaş düğmesi (çözülen resim ve bu satırla bir kart görseli).
    var shareHeadline: Text?
    @ViewBuilder let actions: () -> Actions
    @State private var appeared = false

    private var hasArt: Bool { Illustration.exists("celebrate-hero") }

    var body: some View {
        ZStack(alignment: .top) {
            background
            ScrollView {
                VStack(spacing: 12) {
                    hero
                    VStack(spacing: 4) {
                        Text("Congratulations!")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .scaleEffect(appeared || reduceMotion ? 1 : 0.5)
                        subtitle
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                    }
                    HStack(spacing: 14) {
                        ArtworkThumbnail(artwork: artwork)
                            .padding(8)
                            .frame(width: 104, height: 92)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surface))
                            .shadow(color: theme.cardShadow, radius: 6, y: 3)
                        if let stars {
                            VStack(spacing: 6) {
                                StarsView(count: stars, size: 22)
                                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                                    .opacity(appeared ? 1 : 0)
                                if let starNote {
                                    starNote
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: 170)
                        }
                    }
                    statsRow
                    if !rewards.isEmpty {
                        rewardsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Devam düğmeleri hep görünür: içerik uzarsa yalnızca üst kısım kayar
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    actions()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .background(theme.background.opacity(0.96).ignoresSafeArea(edges: .bottom))
            }
        }
        .overlay(alignment: .topTrailing) {
            if let shareHeadline {
                ShareResultButton(headline: shareHeadline) {
                    ArtworkThumbnail(artwork: artwork)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
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
            Color.clear
                .frame(height: 170)
                .overlay {
                    IllustrationView(name: "celebrate-hero", contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.top, 6)
        } else {
            MuffinView(pose: .cheer, speechID: 1)
                .frame(height: 120)
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
        .padding(.vertical, 10)
        .card(cornerRadius: 18)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Rewards")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(rewards) { reward in
                    HStack(spacing: 10) {
                        Image(systemName: reward.icon)
                            .font(.title3)
                            .foregroundStyle(reward.tint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            if let value = reward.value {
                                value
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(theme.textPrimary)
                            }
                            reward.label
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 52)
                    .card(cornerRadius: 16)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("result.reward.\(reward.id)")
                }
            }
        }
    }
}
