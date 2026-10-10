import NonogramKit
import SwiftUI

/// Bir türün sayfası: üstte portre ve ilerleme, altında "Bulmacalar | Kartlar" sekmeleri.
/// Bulmacalar: standart bulmacalar (çözülenler küçük resim, sıradaki vurgulu, gerisi kilitli)
/// ve ayrı bölümde Altın bulmacalar. Kartlar: türün kartı ve Altın Kartı (ön/arka yüz).
@MainActor
struct ChapterView: View {
    enum Tab: Hashable {
        case puzzles
        case cards
    }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    let chapterID: String
    @State private var isShowingPaywall = false
    @State private var tab = Tab.puzzles

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    var body: some View {
        if let chapter = model.chapter(withID: chapterID) {
            let progression = model.progression
            ScrollView {
                VStack(spacing: 20) {
                    header(chapter, progression: progression)

                    if chapter.card != nil {
                        PillPicker(selection: $tab, options: [(.puzzles, Text("Puzzles")), (.cards, Text("Cards"))])
                    }

                    switch tab {
                    case .puzzles:
                        puzzlesTab(chapter, progression: progression)
                    case .cards:
                        cardsTab(chapter)
                    }
                }
                .padding(20)
            }
            .themedScreen()
            .screenTitle(verbatim: chapter.title.resolved)
            .sheet(isPresented: $isShowingPaywall) {
                PremiumPaywall()
            }
        } else {
            ContentUnavailableView("Chapter not found", systemImage: "questionmark.circle")
                .themedScreen()
        }
    }

    private func header(_ chapter: Chapter, progression: Progression) -> some View {
        HStack(spacing: 14) {
            if chapter.kind == .tutorial {
                ChapterBadge(chapter: chapter, size: 64)
            } else {
                BreedTile(chapter: chapter, isCollected: model.isCollected(chapter), isGolden: model.isGoldenCollected(chapter))
                    .frame(width: 84)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let subtitle = chapter.subtitle {
                    Text(verbatim: subtitle.resolved)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                }
                Text("\(progression.completedCount(in: chapter)) of \(chapter.puzzles.count) solved")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                ProgressBar(
                    value: Double(progression.completedCount(in: chapter)) / Double(max(chapter.puzzles.count, 1)),
                    tint: chapter.accentColor.map { Color($0) }
                )
            }
        }
        .padding(14)
        .card(cornerRadius: 22)
    }

    @ViewBuilder
    private func puzzlesTab(_ chapter: Chapter, progression: Progression) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(chapter.puzzles.enumerated()), id: \.element.id) { offset, puzzle in
                let state = PuzzleTile.TileState(
                    isCompleted: progression.isCompleted(puzzle.id),
                    isUnlocked: progression.isUnlocked(puzzle.id)
                )
                Button {
                    router.push(.game(puzzleID: puzzle.id))
                } label: {
                    PuzzleTile(
                        puzzle: puzzle,
                        number: offset + 1,
                        state: state,
                        isInProgress: model.progress.hasSavedGame(for: puzzle.id),
                        stars: model.stars(for: puzzle)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(state == .locked)
            }
        }

        if !chapter.premiumPuzzles.isEmpty {
            if model.canPlayGolden(chapter, isPremium: store.isPremium) {
                premiumSection(chapter, progression: progression)
            } else if model.isGoldenGift(chapter) {
                // Hediye tür: tamamı bitince Altın bulmacalar ücretsiz açılır
                GoldenGiftTeaser(chapterTitle: chapter.title.resolved)
            } else {
                // Abone olmayanlar bulmacaları görmez; yalnızca kısa bir tanıtım
                PremiumTeaser { isShowingPaywall = true }
            }
        }
    }

    /// Türün kartı ve (varsa) Altın Kartı; kazanılmamışsa nasıl kazanılacağı.
    @ViewBuilder
    private func cardsTab(_ chapter: Chapter) -> some View {
        if let card = chapter.card {
            VStack(spacing: 18) {
                if model.isCollected(chapter) {
                    FlippableBreedCard(chapter: chapter, card: card)
                        .frame(maxWidth: 360)
                    Label("Tap the card to flip it", systemImage: "hand.tap.fill")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    LockedCardPlaceholder(chapter: chapter, message: Text("Finish all puzzles of a breed to win its card."))
                }
                if !chapter.premiumPuzzles.isEmpty {
                    if model.isGoldenCollected(chapter) {
                        FlippableBreedCard(chapter: chapter, card: card, isGolden: true)
                            .frame(maxWidth: 360)
                    } else {
                        LockedCardPlaceholder(chapter: chapter, message: Text("Solve all golden puzzles to win this breed's Golden Card."), isGolden: true)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Henüz kazanılmamış kart: soluk portre, kilit ve nasıl kazanılacağı.
@MainActor
struct LockedCardPlaceholder: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    let message: Text
    var isGolden = false

    var body: some View {
        VStack(spacing: 12) {
            BreedTile(chapter: chapter, isCollected: false, isLocked: true)
                .frame(width: 120)
            Label {
                message
            } icon: {
                Image(systemName: isGolden ? "crown.fill" : "lock.fill")
                    .foregroundStyle(isGolden ? Gold.deep : theme.textSecondary)
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isGolden ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.separator), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        )
    }
}

extension ChapterView {
    /// Abonelere özel 9 Altın bulmaca; hepsi çözülünce türün Altın Kartı.
    private func premiumSection(_ chapter: Chapter, progression: Progression) -> some View {
        let solved = progression.completedPremiumCount(in: chapter)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Gold.deep)
                Text("Golden Puzzles")
                    .font(.title3.bold())
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(solved) of \(chapter.premiumPuzzles.count) solved")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            if model.isGoldenGift(chapter) && !store.isPremium {
                Label("A gift for you: these golden puzzles are free!", systemImage: "gift.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Gold.deep)
            }
            Text(model.isGoldenCollected(chapter)
                 ? LocalizedStringKey("You won the Golden Card of this breed!")
                 : LocalizedStringKey("Solve all golden puzzles to win this breed's Golden Card."))
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(chapter.premiumPuzzles.enumerated()), id: \.element.id) { offset, puzzle in
                    let state = PuzzleTile.TileState(
                        isCompleted: progression.isCompleted(puzzle.id),
                        isUnlocked: progression.isPremiumUnlocked(puzzle.id)
                    )
                    Button {
                        router.push(.game(puzzleID: puzzle.id))
                    } label: {
                        PuzzleTile(
                            puzzle: puzzle,
                            number: offset + 1,
                            state: state,
                            isInProgress: model.progress.hasSavedGame(for: puzzle.id),
                            isGolden: true,
                            stars: model.stars(for: puzzle)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(state == .locked)
                }
            }
        }
        .padding(.top, 8)
        .accessibilityIdentifier("chapter.premium")
    }
}

/// Abone olmayanlara bölüm ekranında: "Bu türün 9 Altın bulmacası Premium'da".
@MainActor
struct PremiumTeaser: View {
    @Environment(\.appTheme) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(Gold.deep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Golden Puzzles")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text("9 extra puzzles and a Golden Card with Premium")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "lock.fill")
                    .foregroundStyle(Gold.deep)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Gold.foil, lineWidth: 2)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 8)
        .accessibilityIdentifier("chapter.premiumTeaser")
    }
}

/// Hediye türde, tür bitmeden önce: "Tüm bulmacaları çöz, Altın bulmacalar hediye".
@MainActor
struct GoldenGiftTeaser: View {
    @Environment(\.appTheme) private var theme
    let chapterTitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.title3)
                .foregroundStyle(Gold.deep)
            VStack(alignment: .leading, spacing: 2) {
                Text("Golden Puzzles: a gift!")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Solve every \(chapterTitle) puzzle to unlock its 9 golden puzzles for free.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "lock.fill")
                .foregroundStyle(Gold.deep)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Gold.foil, lineWidth: 2)
        )
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chapter.goldenGift")
    }
}

@MainActor
struct PuzzleTile: View {
    enum TileState: Equatable {
        case locked
        case playable
        case completed

        init(isCompleted: Bool, isUnlocked: Bool) {
            self = isCompleted ? .completed : (isUnlocked ? .playable : .locked)
        }
    }

    @Environment(\.appTheme) private var theme
    let puzzle: Puzzle
    let number: Int
    let state: TileState
    /// Yarım bırakılmış: köşede küçük bir rozet gösterilir.
    var isInProgress = false
    /// Abonelere özel Altın bulmaca: altın zemin/çerçeve.
    var isGolden = false
    /// Çözülmüşse en iyi yıldız sayısı; karonun altında gösterilir.
    var stars: Int?

    var body: some View {
        VStack(spacing: 5) {
            tile
            // Satırlar hizalı kalsın: yıldızı olmayan karoda da aynı yükseklik
            StarsView(count: stars ?? 0, size: 10)
                .opacity(stars == nil ? 0 : 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack {
            switch state {
            case .completed:
                ArtworkThumbnail(artwork: puzzle.artwork)
                    .padding(8)
            case .playable:
                Text(verbatim: "\(number)")
                    .font(.title2.bold())
                    .foregroundStyle(isGolden ? Gold.ink : theme.onAccent)
            case .locked:
                Image(systemName: isGolden ? "crown.fill" : "lock.fill")
                    .foregroundStyle(isGolden ? Gold.deep.opacity(0.6) : theme.textSecondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        // Çözülmüş karo nötr yüzey renginde: renkli resim zeminle karışmasın
        .background {
            if isGolden && state == .playable {
                shape.fill(Gold.foil)
            } else {
                shape.fill(state == .playable ? theme.accent : theme.surface)
            }
        }
        .overlay {
            if isGolden {
                shape.strokeBorder(Gold.foil, lineWidth: state == .locked ? 1.5 : 2.5)
            } else {
                shape.strokeBorder(theme.separator, lineWidth: state == .playable ? 0 : 1)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isInProgress && state != .locked {
                Image(systemName: "hourglass.circle.fill")
                    .font(.body)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.onAccent, theme.textPrimary)
                    .offset(x: 4, y: -4)
            }
        }
        .shadow(color: state == .locked ? .clear : theme.cardShadow, radius: 6, y: 2)
    }

    private var accessibilityText: Text {
        switch state {
        case .completed:
            Text("Puzzle \(number), solved: \(puzzle.title.resolved)")
                + Text(verbatim: ", ") + Text("\(stars ?? 0) of 4 stars")
        case .playable: isInProgress ? Text("Puzzle \(number), in progress") : Text("Puzzle \(number)")
        case .locked: Text("Puzzle \(number), locked")
        }
    }
}
