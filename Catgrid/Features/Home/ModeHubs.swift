import NonogramKit
import SwiftUI

// MARK: - Ortak parçalar

/// Mod ekranının üstündeki büyük kart: modun pastel renginde başlık, kısa açıklama, ilerleme.
@MainActor
struct HubHero<Art: View>: View {
    @Environment(\.appTheme) private var theme
    let title: LocalizedStringResource
    let subtitle: Text
    let progress: Double
    let style: ModeStyle
    /// Çizimin alanı (yatay hareketli kediler için daha geniş).
    var artSize = CGSize(width: 92, height: 92)
    @ViewBuilder let art: () -> Art

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    ModeIcon(style: style, size: 40)
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(style.ink(theme))
                    subtitle
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(style.ink(theme).opacity(0.8))
                }
                Spacer(minLength: 8)
                art()
                    .frame(width: artSize.width, height: artSize.height)
            }
            ProgressBar(value: min(max(progress, 0), 1), tint: style.tint(theme))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(style.background(theme)))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(theme.isDark ? 0.06 : 0.7), lineWidth: 1)
        )
        .shadow(color: style.tint(theme).opacity(theme.isDark ? 0 : 0.16), radius: 10, y: 5)
    }
}

/// Mod ekranındaki satır düğmesi (Tüm Bölümler, İstatistikler, Rozetlerim).
@MainActor
struct HubRow: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let title: LocalizedStringKey
    var detail: Text?
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint ?? theme.accent)
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if let detail {
                    detail
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .card(cornerRadius: 20)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// "Kaldığın yerden devam et" kartı.
@MainActor
struct ContinueCard<Icon: View>: View {
    @Environment(\.appTheme) private var theme
    let title: LocalizedStringKey
    let detail: Text
    let isResuming: Bool
    /// Simgenin genişliği (Kedi Bulmaca'da tema görseli için daha geniş).
    var iconWidth: CGFloat = 48
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                icon()
                    .frame(width: iconWidth, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    detail
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }
            Button(action: action) {
                Label(isResuming ? "Resume" : "Continue", systemImage: isResuming ? "arrow.clockwise" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("hub.continue")
        }
        .padding(16)
        .card()
    }
}

// MARK: - Kedi Kart Koleksiyonu

@MainActor
struct CollectionHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        let mode = BadgeMode.collection
        let badgeCount = Badge.all(in: mode).filter { model.badges.isEarned($0) }.count
        ScrollView {
            VStack(spacing: 16) {
                HubHero(
                    title: mode.title,
                    subtitle: Text("\(model.collectedBreeds.count) of \(model.breeds.count) breeds collected"),
                    progress: model.breeds.isEmpty ? 0 : Double(model.collectedBreeds.count) / Double(model.breeds.count),
                    style: .collection,
                    artSize: LoopingCatAnimation.isAvailable(LoopingCatAnimation.cardsCat) ? CGSize(width: 160, height: 92) : CGSize(width: 92, height: 92)
                ) {
                    if LoopingCatAnimation.isAvailable(LoopingCatAnimation.cardsCat) {
                        LoopingCatView(name: LoopingCatAnimation.cardsCat, tapToPet: true)
                    } else if Illustration.exists(ModeStyle.collection.illustration) {
                        IllustrationView(name: ModeStyle.collection.illustration)
                    } else if let chapter = model.collectedBreeds.last ?? model.breeds.first {
                        ChapterBadge(chapter: chapter, size: 92)
                    }
                }

                if let puzzle = model.resumablePuzzle, let chapter = model.catalog.chapter(containing: puzzle.id) {
                    ContinueCard(
                        title: "Continue where you left off",
                        detail: Text("\(chapter.title.resolved) · Puzzle \(model.number(of: puzzle))"),
                        isResuming: model.progress.hasSavedGame(for: puzzle.id),
                        icon: { ChapterBadge(chapter: chapter, size: 48) },
                        action: { router.push(.game(puzzleID: puzzle.id)) }
                    )
                } else {
                    AllDoneCard(message: "New breeds are on their way.")
                }

                HubRow(icon: "square.grid.2x2.fill", title: "All Levels") { router.push(.chapters) }
                    .accessibilityIdentifier("hub.levels")
                HubRow(icon: "chart.bar.fill", title: "Statistics") { router.push(.stats) }
                    .accessibilityIdentifier("hub.stats")
                HubRow(
                    icon: "medal.fill",
                    title: "My Badges",
                    detail: Text(verbatim: "\(badgeCount)/\(Badge.all(in: mode).count)"),
                    tint: Gold.deep
                ) { router.push(.badges(mode)) }
                .accessibilityIdentifier("hub.badges")
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle(mode.title)
    }
}

@MainActor
struct AllDoneCard: View {
    @Environment(\.appTheme) private var theme
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(theme.success)
            Text("You solved every puzzle!")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .card()
    }
}

// MARK: - Kedi Bulmaca

/// Kalan ipucu hakları.
@MainActor
struct HelperChargesCard: View {
    @Environment(\.appTheme) private var theme
    let find: Int
    let mark: Int
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                Label {
                    Text("Cat Finder: \(find)")
                } icon: {
                    Image(systemName: "cat.fill").foregroundStyle(theme.accent)
                }
                Label {
                    Text("Hints: \(mark)")
                } icon: {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(Color(red: 0.55, green: 0.42, blue: 0.82))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.textPrimary)
            Text(isPremium
                ? "Premium refills both to 6 every day at midnight."
                : "When they run out, watch a short video for one more. Premium refills them to 6 every day.")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(cornerRadius: 20)
    }
}

/// Kedi Bulmaca'yı anlatan küçük renkli tahta resmi.
struct CatGridArt: View {
    private let pattern = [
        [0, 0, 1, 1],
        [2, 0, 1, 3],
        [2, 2, 3, 3],
        [4, 2, 2, 3],
    ]
    private let cats: Set<Int> = [1, 7, 8, 14]

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(0..<4, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CatPalette.color(pattern[row][column]))
                            .overlay {
                                if cats.contains(row * 4 + column) {
                                    Image(systemName: "cat.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.9)))
        .accessibilityHidden(true)
    }
}

@MainActor
struct CatStatsView: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let cats = model.cats
        let stats = cats.stats
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(icon: "checkmark.seal.fill", title: "Levels Solved", value: Text(verbatim: "\(cats.solvedCount)/\(cats.levels.count)"))
                StatTile(icon: "cat.fill", title: "Cats Found", value: Text(stats.catsFound, format: .number))
                StatTile(icon: "sparkles", title: "Flawless", value: Text(verbatim: "\(cats.results.values.filter(\.flawless).count)"))
                StatTile(icon: "flame.fill", title: "Best Flawless Run", value: Text(verbatim: "\(stats.bestFlawlessRun)"))
                StatTile(icon: "bolt.fill", title: "Best Combo", value: Text(verbatim: "\(stats.bestCombo)"))
                StatTile(icon: "eye.fill", title: "Perfectly Marked", value: Text(verbatim: "\(stats.perfectlyMarked)"))
                StatTile(icon: "star.fill", title: "Total Score", value: Text(stats.totalScore, format: .number))
                StatTile(icon: "clock.fill", title: "Total Time", value: Text(formatDuration(stats.playTime)))
                StatTile(icon: "hare.fill", title: "Fastest", value: Text(stats.fastestSolve.map(formatDuration) ?? "–"))
                StatTile(icon: "xmark.circle.fill", title: "Mistakes", value: Text(verbatim: "\(stats.mistakes)"))
                StatTile(icon: "cat.circle.fill", title: "Cat Finders Used", value: Text(verbatim: "\(stats.findHintsUsed)"))
                StatTile(icon: "questionmark.circle.fill", title: "Hints Used", value: Text(verbatim: "\(stats.markHintsUsed)"))
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Statistics")
    }
}

/// Kedi Bulmaca temasının küçük afişi (Bahar Bahçesi, Yaz Sahili…); çizim yoksa temanın renkleri ve simgesi.
@MainActor
struct CatThemeThumbnail: View {
    @Environment(\.appTheme) private var theme
    let catTheme: CatTheme

    var body: some View {
        LinearGradient(colors: catTheme.colors(theme), startPoint: .leading, endPoint: .trailing)
            .overlay {
                if Illustration.exists(catTheme.illustration) {
                    Color.clear
                        .overlay(alignment: .trailing) {
                            IllustrationView(name: catTheme.illustration, contentMode: .fill)
                        }
                        .clipped()
                } else {
                    Image(systemName: catTheme.icon)
                        .font(.title2)
                        .foregroundStyle(catTheme.tint(theme))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(Text(catTheme.title))
    }
}
