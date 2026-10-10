import NonogramKit
import SwiftUI

/// Kedi kartları: kazanılanlar (Altın Kartlar ayrı) kazanma sırasıyla, ardından henüz
/// tanışılmayan türler soluk ve kilitli. Kazanılan karta dokununca kart açılır.
@MainActor
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var selected: CardSelection?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        let others = model.breeds.filter { !model.isCollected($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CollectionSummary()
                ProgressBar(
                    value: model.breeds.isEmpty ? 0 : Double(model.collectedBreeds.count) / Double(model.breeds.count),
                    tint: ModeStyle.collection.tint(theme)
                )

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.collectedCards) { selection in
                        Button {
                            selected = selection
                        } label: {
                            BreedTile(chapter: selection.chapter, isCollected: true, isGolden: selection.isGolden)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("collection.card.\(selection.id)")
                    }
                    ForEach(others) { chapter in
                        Button {
                            router.push(.chapter(id: chapter.id))
                        } label: {
                            BreedTile(chapter: chapter, isCollected: false, isLocked: true)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(!model.progression.isUnlocked(chapter))
                    }
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Card Collection")
        .sheet(item: $selected) { selection in
            CardDetailSheet(chapter: selection.chapter, isGolden: selection.isGolden)
        }
    }
}

/// "3 kedi türü topladın. Hâlâ tanışmadığın kediler var!"
@MainActor
struct CollectionSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    var body: some View {
        let count = model.collectedBreeds.count
        Group {
            if count == 0 {
                Text("Finish all puzzles of a breed to win its card.")
            } else if model.hasUnmetBreeds {
                Text("You've collected \(count) cat breeds. There are still cats you haven't met!")
            } else {
                Text("You've met every cat. New breeds are on their way!")
            }
        }
        .font(.subheadline)
        .foregroundStyle(theme.textSecondary)
    }
}

/// Kartın tam hali (koleksiyondan dokununca).
@MainActor
struct CardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chapter: Chapter
    var isNewCard = false
    var isGolden = false
    /// Hediye tür bitti: kartla birlikte Altın bulmacaları da açıldı.
    var unlocksGoldenGift = false
    /// Yeni kartın ekrana geliş animasyonu bitti mi? Bitene kadar düğme görünmez.
    @State private var hasArrived = false
    @AppStorage(SettingsKeys.playMode) private var playMode = PlayMode.dopamine
    /// Dopamin modu: "Koleksiyona Ekle"ye basınca kart küçülüp yukarı, koleksiyona uçar.
    @State private var isFlyingAway = false

    /// Dopamin modunda yeni kart önce koleksiyona uçar, sonra pencere kapanır.
    private func addToCollection() {
        guard isNewCard, playMode == .dopamine, !reduceMotion, !isFlyingAway else {
            dismiss()
            return
        }
        Haptics.selection()
        withAnimation(.easeIn(duration: 0.45)) { isFlyingAway = true }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isNewCard {
                    VStack(spacing: 6) {
                        Image(systemName: isGolden ? "crown.fill" : "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(isGolden ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.accent))
                        Text(isGolden ? LocalizedStringKey("Golden Card unlocked!") : LocalizedStringKey("New card unlocked!"))
                            .font(.title2.bold())
                            .foregroundStyle(theme.textPrimary)
                        Text(isGolden
                             ? LocalizedStringKey("You solved every golden \(chapter.title.resolved) puzzle.")
                             : LocalizedStringKey("You solved every \(chapter.title.resolved) puzzle."))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                        if unlocksGoldenGift {
                            Label("Gift: this breed's 9 golden puzzles are now unlocked!", systemImage: "gift.fill")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Gold.deep)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 8)
                }
                if let card = chapter.card {
                    FlippableBreedCard(chapter: chapter, card: card, isGolden: isGolden)
                        .frame(maxWidth: 360)
                        .background { if isNewCard { arrivalGlow } }
                        // Yeni kart: küçük ve dönük gelir, ışık patlamasıyla yerine oturur
                        .scaleEffect(isNewCard && !hasArrived && !reduceMotion ? 0.25 : 1)
                        .rotation3DEffect(
                            .degrees(isNewCard && !hasArrived && !reduceMotion ? -200 : 0),
                            axis: (x: 0, y: 1, z: 0), perspective: 0.6
                        )
                        .opacity(isNewCard && !hasArrived ? 0 : (isFlyingAway ? 0 : 1))
                        .scaleEffect(isFlyingAway ? 0.15 : 1)
                        .offset(y: isFlyingAway ? -520 : 0)
                        .rotationEffect(.degrees(isFlyingAway ? -25 : 0))
                    Label("Tap the card to flip it", systemImage: "hand.tap.fill")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .opacity(hasArrived || !isNewCard ? 1 : 0)
                }
                Button(isNewCard ? "Add to Collection" : "Close") { addToCollection() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 360)
                    .opacity(hasArrived || !isNewCard ? 1 : 0)
                    .disabled(isNewCard && !hasArrived)
                    .accessibilityIdentifier("card.add")
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .appChrome()
        .presentationDragIndicator(isNewCard ? .hidden : .visible)
        // Yeni kart yanlışlıkla aşağı kaydırılıp kaçırılmasın; yalnızca düğmeyle eklenir
        .interactiveDismissDisabled(isNewCard)
        .task {
            guard isNewCard, !hasArrived else { return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .spring(duration: 1.1, bounce: 0.25)) {
                hasArrived = true
            }
            Haptics.play(.solved)
        }
    }

    /// Kartın arkasında genişleyip sönen ışık halkası.
    private var arrivalGlow: some View {
        let color = isGolden ? Gold.bright : theme.accent
        return Circle()
            .fill(RadialGradient(colors: [color.opacity(0.6), color.opacity(0)], center: .center, startRadius: 10, endRadius: 220))
            .scaleEffect(hasArrived ? 1.6 : 0.2)
            .opacity(hasArrived ? 0 : 1)
            .animation(.easeOut(duration: 1.6), value: hasArrived)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
