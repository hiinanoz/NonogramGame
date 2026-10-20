import NonogramKit
import SwiftUI

/// Kuş Sıralama oyun ekranı: üstte bölüm, ortada dallar, altta kedi ve yardımcılar
/// (geri al, ekstra dal, ipucu). Yardımcılar bitince Premium'da ücretsiz, değilse ödüllü reklamla.
@MainActor
struct BirdSortGameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    let levelNumber: Int
    @State private var isPaused = false
    @State private var viewModel: BirdSortGameViewModel
    @State private var isShowingIntro = false
    @State private var reward: BirdSortReward?
    @State private var isShowingPaywall = false
    @State private var adOffer: BirdSortBooster?

    enum BirdSortBooster: Identifiable {
        case hint
        case branch
        var id: Self { self }
    }

    init(levelNumber: Int, saved: BirdSortSession? = nil) {
        self.levelNumber = levelNumber
        _viewModel = State(initialValue: BirdSortGameViewModel(level: BirdSortCatalog.level(levelNumber), resuming: saved))
    }

    private var birds: BirdSortModel { model.birds }
    private var island: BirdSortIsland { BirdSortIsland(index: viewModel.level.island) }

    var body: some View {
        GeometryReader { screen in
            screenContent(dockHeight: max(118, screen.size.height * 0.15))
        }
        .background {
            // Zemin biraz soluk: dallar ve kuşlar öne çıksın
            Image("birdsort-sea")
                .resizable()
                .scaledToFill()
                .saturation(0.8)
                .overlay(theme.isDark ? Color.black.opacity(0.42) : Color.white.opacity(0.32))
                .ignoresSafeArea()
        }
    }

    /// Üst çubuk, dallar ve alttaki menü alanı (ekranın yaklaşık %15'i; kedi ve yardımcılar).
    private func screenContent(dockHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                if viewModel.session == nil {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                } else {
                    BirdSortBoardView(viewModel: viewModel, branchImage: island.branchImage, branchSurface: island.branchSurface)
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("birds.board")
                }
            }
            .frame(maxHeight: .infinity)
            dock(height: dockHeight)
        }
        .overlay {
            if isPaused && !viewModel.isWon {
                ModePauseOverlay(
                    onContinue: { isPaused = false },
                    onRestart: {
                        isPaused = false
                        birds.clearSavedGame()
                        viewModel.restart()
                    },
                    onMap: { leave(to: nil, showAd: false) }
                )
                .transition(.opacity)
            } else if viewModel.isWon {
                BirdSortWinOverlay(level: levelNumber, stars: viewModel.stars, moves: viewModel.moves, reward: reward,
                                   hasNext: levelNumber < BirdSortCatalog.levelCount,
                                   onNext: { leave(to: .birdGame(level: levelNumber + 1)) },
                                   onMap: { leave(to: nil) })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else if isShowingIntro {
                BirdSortIntroOverlay(capacity: viewModel.capacity) {
                    birds.markIntroSeen()
                    withAnimation { isShowingIntro = false }
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isStuck && !viewModel.isWon {
                Text("No moves left. Undo or add a branch.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.surface).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
                    .padding(.top, 60)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isWon)
        .animation(.easeInOut, value: viewModel.isStuck)
        .animation(.spring(response: 0.3), value: isPaused)
        .onDisappear { saveProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress()
                if viewModel.session != nil && !viewModel.isWon { isPaused = true }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPaywall) { PremiumPaywall() }
        .alert(adOfferTitle, isPresented: isOfferingAd) {
            Button("Watch Video") {
                if let offer = adOffer { watchAd(for: offer) }
            }
            Button("Go Premium") { isShowingPaywall = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Watch a short ad to get one more, or go Premium for unlimited helpers.")
        }
        .task {
            wireEvents()
            await viewModel.load()
            if !birds.hasSeenIntro && levelNumber <= 2 {
                withAnimation { isShowingIntro = true }
            }
        }
    }

    // MARK: - Üst çubuk

    private var topBar: some View {
        HStack(spacing: 10) {
            BirdSortRoundButton(symbol: "chevron.left") { leave(to: nil, showAd: false) }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("birds.game.back")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("Level \(levelNumber)")
                    .font(.headline.weight(.heavy))
                Text(island.title)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.92)))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                Text(verbatim: "\(viewModel.moves)")
                    .font(.subheadline.weight(.heavy).monospacedDigit())
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Capsule().fill(.white.opacity(0.92)))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Moves"))
            .accessibilityValue(Text(verbatim: "\(viewModel.moves)"))
            ModePauseButton {
                guard viewModel.session != nil, !viewModel.isWon else { return }
                Haptics.selection()
                isPaused = true
            }
            .accessibilityIdentifier("birds.game.pause")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Alt bölüm: kedi ve yardımcılar

    private func dock(height: CGFloat) -> some View {
        // Kedi görsellerinin kenarları boş: düğmeler kedinin boş sağ kenarına biraz biner
        HStack(alignment: .bottom, spacing: -height * 0.22) {
            // Kedi solda ve büyük: menü alanının üstüne taşar
            BirdSortCatView(mood: viewModel.catMood)
                .frame(width: height * 1.7, height: height * 1.13, alignment: .bottom)
                .padding(.leading, -height * 0.2)
            HStack(alignment: .bottom, spacing: 0) {
                boosterButton(symbol: "arrow.uturn.backward", title: Text("Undo"), badge: nil, enabled: viewModel.canUndo) {
                    audio.play(.tap)
                    viewModel.undo()
                }
                .accessibilityIdentifier("birds.undo")
                boosterButton(symbol: "plus.rectangle.on.rectangle", title: Text("Branch"),
                              badge: store.isPremium ? nil : birds.progress.extraBranches,
                              enabled: viewModel.canAddBranch) {
                    addBranch()
                }
                .accessibilityIdentifier("birds.branch.add")
                boosterButton(symbol: "lightbulb.fill", title: Text("Hint"),
                              badge: store.isPremium ? nil : birds.progress.hints,
                              enabled: viewModel.session != nil && !viewModel.isWon) {
                    showHint()
                }
                .accessibilityIdentifier("birds.hint")
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .frame(height: height, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .background(
            // Menü alanı: dallar bunun üstünden başlar
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#FFF6E6").opacity(0.96), Color(hex: "#F6E2C2").opacity(0.98)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func boosterButton(symbol: String, title: Text, badge: Int?, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(enabled ? Color(hex: "#7A4B25") : Color(hex: "#7A4B25").opacity(0.35))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.95)))
                    .overlay(Circle().strokeBorder(Color(hex: "#F3C784"), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .overlay(alignment: .topTrailing) {
                        if let badge {
                            Group {
                                if badge > 0 {
                                    Text(verbatim: "\(badge)")
                                } else {
                                    Image(systemName: "play.rectangle.fill")
                                }
                            }
                            .font(.caption2.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(Color(hex: "#F07A3C")))
                            .offset(x: 6, y: -4)
                        }
                    }
                title
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(hex: "#7A4B25"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }

    // MARK: - Olaylar

    private func wireEvents() {
        viewModel.onFlap = { audio.play(.wingFlap) }
        viewModel.onBirdsAway = {
            audio.play(.birdsAway)
            Haptics.play(.lineCompleted)
        }
        viewModel.onMistake = {
            audio.play(.mistake)
            Haptics.play(.mistake)
        }
        viewModel.onSelect = { Haptics.selection() }
        viewModel.onWin = {
            audio.play(.fanfare)
            Haptics.play(.solved)
            birds.clearSavedGame()
            let outcome = birds.recordWin(level: levelNumber, stars: viewModel.stars, moves: viewModel.moves)
            reward = outcome.reward
            ads.puzzleCompleted(isTutorial: levelNumber <= 2)
        }
    }

    private func addBranch() {
        guard viewModel.canAddBranch else { return }
        if store.isPremium {
            if viewModel.addBranch() { audio.play(.card) }
        } else if birds.progress.extraBranches > 0 {
            if viewModel.addBranch() {
                _ = birds.useExtraBranch()
                audio.play(.card)
            }
        } else {
            adOffer = .branch
        }
    }

    private func showHint() {
        if store.isPremium || birds.progress.hints > 0 {
            Task {
                if await viewModel.showHint() {
                    if !store.isPremium { _ = birds.useHint() }
                    audio.play(.catHint)
                }
            }
        } else {
            adOffer = .hint
        }
    }

    private func watchAd(for booster: BirdSortBooster) {
        Task {
            guard await ads.watchRewardedAd() else { return }
            switch booster {
            case .hint:
                if await viewModel.showHint() { audio.play(.catHint) }
            case .branch:
                if viewModel.addBranch() { audio.play(.card) }
            }
        }
    }

    private var isOfferingAd: Binding<Bool> {
        Binding(get: { adOffer != nil }, set: { if !$0 { adOffer = nil } })
    }

    private var adOfferTitle: Text {
        switch adOffer {
        case .hint: return Text("No Hints Left")
        case .branch: return Text("No Extra Branches Left")
        case nil: return Text(verbatim: "")
        }
    }

    /// Çıkarken: hamle yapılmış bölüm kaydedilir; bitmiş bölümün kaydı silinir.
    private func saveProgress() {
        guard let session = viewModel.session else { return }
        if viewModel.isWon {
            if birds.savedGame?.level.number == levelNumber { birds.clearSavedGame() }
        } else if viewModel.hasProgress {
            birds.saveGame(session)
        }
    }

    private func leave(to route: Route?, showAd: Bool = true) {
        let go = {
            if let route {
                router.replaceTop(with: route)
            } else {
                router.pop()
            }
        }
        if showAd && viewModel.isWon {
            ads.continueAfterPuzzle(go)
        } else {
            go()
        }
    }
}
