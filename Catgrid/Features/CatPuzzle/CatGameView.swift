import NonogramKit
import SwiftUI

/// Rotadan gelen bölüm kimliğiyle Kedi Bulmaca ekranı.
@MainActor
struct CatGameScreen: View {
    @Environment(AppModel.self) private var model
    let levelID: String

    var body: some View {
        if let level = model.cats.level(withID: levelID) {
            CatGameView(level: level, saved: model.cats.savedGame(for: level))
                .id(levelID)
        } else {
            ContentUnavailableView("Level not found", systemImage: "questionmark.square.dashed")
        }
    }
}

@MainActor
struct CatGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: CatGameViewModel
    @State private var result: CatResult?
    @State private var isConfirmingRestart = false
    @State private var adOffer: CatHelper?
    @State private var noHintNote = false
    @AppStorage(SettingsKeys.catHardMode) private var isHardMode = false
    @State private var difficultyNote: Bool?

    init(level: CatLevel, saved: CatSnapshot? = nil) {
        _viewModel = State(initialValue: CatGameViewModel(level: level, saved: saved))
    }

    private var game: CatGame { viewModel.game }
    private var cats: CatPuzzleModel { model.cats }
    private var number: Int { cats.number(of: viewModel.level) }
    private var isTutorial: Bool { number == 1 }

    var body: some View {
        content
            .themedScreen()
            .screenTitle(Text("Level \(number)"), subtitle: sizeText)
            .toolbar { toolbarMenu }
            .confirmationDialog("Start over?", isPresented: $isConfirmingRestart, titleVisibility: .visible) {
                Button("Start Over", role: .destructive) {
                    withAnimation(.snappy) { viewModel.restart() }
                }
            }
            .alert(adOfferTitle, isPresented: isOfferingAd, presenting: adOffer) { helper in
                Button("Watch Video") { watchAd(for: helper) }
                Button("Not Now", role: .cancel) {}
            } message: { _ in
                adOfferMessage
            }
        .onAppear(perform: setUp)
        .onDisappear {
            viewModel.stop()
            persist()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.resume()
                cats.refillIfNeeded(isPremium: store.isPremium, today: model.today)
            } else {
                viewModel.pause()
                persist()
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            if isTutorial, game.status == .playing {
                CatTutorialBanner(step: tutorialStep)
                    .transition(.opacity)
            }
            scoreHeader
            CatStrip(level: viewModel.level, found: game.foundRegions, cats: cats)
            RulesStrip(violated: violatedRule)
            board
            bottomBar
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay { endOverlay }
        .animation(.spring(duration: 0.4), value: result != nil)
        .animation(.spring(duration: 0.4), value: game.status)
    }

    @ViewBuilder
    private var endOverlay: some View {
        if let result {
            CatResultOverlay(
                result: result,
                next: cats.level(after: viewModel.level),
                onNext: { next in leave(to: .catGame(levelID: next.id)) },
                onLevels: { leave(to: nil) }
            )
            .transition(.opacity)
        } else if game.status == .lost {
            CatFailedOverlay(
                canRevive: store.isPremium || ads.isRewardedReady,
                isPremium: store.isPremium,
                onRevive: revive,
                onRetry: retry
            )
            .transition(.opacity)
        }
    }

    private var sizeText: Text {
        let size = viewModel.level.size
        return Text("\(size)×\(size)")
    }

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isConfirmingRestart = true
                } label: {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(theme.textPrimary)
            }
            .accessibilityLabel(Text("More"))
        }
    }

    private var isOfferingAd: Binding<Bool> {
        Binding(get: { adOffer != nil }, set: { if !$0 { adOffer = nil } })
    }

    private var adOfferTitle: Text {
        adOffer == .find ? Text("No Cat Finders Left") : Text("No Hints Left")
    }

    private var adOfferMessage: Text {
        if store.isPremium {
            return Text("Watch a short video for one more. Premium refills to 6 every day at midnight.")
        }
        return Text("Watch a short video for one more. With Premium you get 6 every day.")
    }

    private func retry() {
        audio.play(.tap)
        withAnimation(.snappy) { viewModel.restart() }
    }

    // MARK: - Parçalar

    private var scoreHeader: some View {
        HStack(alignment: .center) {
            Image(systemName: "star.fill")
                .font(.headline)
                .foregroundStyle(Gold.mid)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Gold.light.opacity(theme.isDark ? 0.2 : 0.8)))
            VStack(alignment: .leading, spacing: 0) {
                Text("Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                Text(viewModel.score, format: .number)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText(value: Double(viewModel.score)))
                    .animation(.snappy, value: viewModel.score)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<game.lives, id: \.self) { index in
                    let isAlive = index < game.remainingLives
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(isAlive ? theme.accent : theme.textSecondary.opacity(0.25))
                        .scaleEffect(isAlive ? 1 : 0.85)
                }
            }
            .font(.title3)
            .animation(.spring, value: game.remainingLives)
            .accessibilityElement()
            .accessibilityLabel(Text("\(game.remainingLives) paws left"))
            // Kolay/Zor (Nonogram'daki gibi); ilk bölümde (eğitim) gösterilmez, X'leri oyuncu koyar
            if !isTutorial {
                DifficultyToggle(isHard: $isHardMode)
                    .padding(.leading, 6)
                    .accessibilityIdentifier("cat.difficulty")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(ModeStyle.cats.background(theme)))
        .overlay(alignment: .bottom) {
            if let hard = difficultyNote {
                Text(hard ? LocalizedStringKey("Hard: you place every X yourself.") : LocalizedStringKey("Easy: X's go around every cat you find."))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.surface).shadow(color: .black.opacity(0.1), radius: 6, y: 2))
                    .offset(y: 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(1)
        .onChange(of: isHardMode) { _, hard in
            guard !isTutorial else { return }
            viewModel.setAutoCrosses(!hard)
            Haptics.selection()
            withAnimation(.snappy) { difficultyNote = hard }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if difficultyNote == hard { withAnimation(.easeOut) { difficultyNote = nil } }
            }
        }
    }

    private var board: some View {
        CatBoardView(
            game: game,
            cats: cats,
            activeCell: viewModel.activeCell,
            wrongCell: viewModel.lastWrong,
            hint: viewModel.pendingHint,
            pointer: isTutorial && game.status == .playing ? tutorialStep.pointer : nil,
            effects: viewModel.effects,
            banner: viewModel.banner,
            animations: viewModel.animations,
            conflict: viewModel.lastConflict,
            onBegan: { viewModel.touchBegan(at: $0) },
            onMoved: { viewModel.touchMoved(to: $0) },
            onEnded: { viewModel.touchEnded() }
        )
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .top) {
            if let hint = viewModel.pendingHint {
                // Kart tahtanın hemen üstünde (kedi şeridinin üzerine biner), tahtayı örtmez
                CatHintCard(hint: hint)
                    .alignmentGuide(.top) { $0[.bottom] + 6 }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.snappy(duration: 0.2), value: viewModel.pendingHint)
    }

    private var bottomBar: some View {
        HStack(spacing: 22) {
                CatEraserButton(isOn: viewModel.isErasing) {
                    audio.play(.tap)
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) { viewModel.toggleEraser() }
                }
                .accessibilityIdentifier("cat.eraser")
                CatHelperButton(
                    systemImage: "cat.fill",
                    title: "Find a Cat",
                    count: cats.findCharges,
                    tint: theme.accent,
                    isGuided: isTutorial && tutorialStep == .finder,
                    action: findCat
                )
                .accessibilityIdentifier("cat.find")
                CatHelperButton(
                    systemImage: "questionmark",
                    title: "Hint",
                    count: cats.markCharges,
                    tint: Color(red: 0.55, green: 0.42, blue: 0.82),
                    isGuided: isTutorial && tutorialStep == .useHint,
                    action: showHint
                )
                .accessibilityIdentifier("cat.hint")
            }
            .disabled(game.status != .playing)
            .overlay(alignment: .top) {
                if noHintNote {
                    Text("No sure step right now. Try placing X's first.")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .offset(y: -24)
                        .transition(.opacity)
                }
            }
    }

    // MARK: - Eylemler

    private func setUp() {
        cats.refillIfNeeded(isPremium: store.isPremium, today: model.today)
        // Eğitimde X'leri oyuncu koyar (kurallar öğrenilsin)
        viewModel.setAutoCrosses(!isHardMode && !isTutorial)
        viewModel.onEvent = { event in
            switch event {
            case .crossed: audio.play(.catX)
            case .cleared: audio.play(.erase)
            case .found(let combo):
                audio.play(.catFound)
                cats.recordCatFound()
                if combo >= 2 {
                    Task {
                        try? await Task.sleep(for: .seconds(0.25))
                        audio.play(.catCombo)
                    }
                }
                Haptics.play(.lineCompleted)
            case .wrong:
                audio.play(.catWrong)
                cats.recordMistake()
                Haptics.play(.mistake)
            case .solved:
                audio.play(.catWin)
                Haptics.play(.solved)
            case .failed:
                audio.play(.failed)
                cats.recordMistake()
                Haptics.play(.failed)
            }
        }
        viewModel.onSolved = { completion in
            let isFirst = cats.record(completion)
            ads.puzzleCompleted(isTutorial: isTutorial)
            let newBadges = model.refreshBadges()
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                result = CatResult(completion: completion, isFirstSolve: isFirst, newBadges: newBadges)
            }
        }
        viewModel.start()
    }

    private func persist() {
        cats.save(viewModel.snapshotToSave, for: viewModel.level)
    }

    private func findCat() {
        // Eğitim bölümünde ipuçları hak harcamaz
        guard isTutorial || cats.useFindCharge() else {
            adOffer = .find
            return
        }
        audio.play(.catHint)
        viewModel.revealCat()
    }

    /// "?" ipucu: bir hak harcanır ve ipucu kendiliğinden uygulanır (mantık adımı yoksa hak gitmez).
    private func showHint() {
        guard viewModel.pendingHint == nil else { return }
        guard isTutorial || cats.markCharges > 0 else {
            adOffer = .mark
            return
        }
        if viewModel.useHint() {
            if !isTutorial { _ = cats.useMarkCharge() }
            audio.play(.catHint)
        } else {
            withAnimation { noHintNote = true }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { noHintNote = false }
            }
        }
    }

    private func watchAd(for helper: CatHelper) {
        Task {
            guard await ads.watchRewardedAd() else { return }
            switch helper {
            case .find:
                cats.addFindCharge()
                findCat()
            case .mark:
                cats.addMarkCharge()
                showHint()
            }
        }
    }

    private func revive() {
        if store.isPremium {
            viewModel.revive()
            return
        }
        Task {
            if await ads.watchRewardedAd() { viewModel.revive() }
        }
    }

    private func leave(to route: Route?) {
        persist()
        ads.continueAfterPuzzle {
            if let route {
                router.replaceTop(with: route)
            } else {
                router.pop()
            }
        }
    }

    // MARK: - Eğitim (1. bölüm)

    private var tutorialStep: CatTutorialStep {
        let level = viewModel.level
        switch game.foundCount {
        case 0:
            return .first(level.catPosition(ofRegion: level.region(at: GridPosition(row: 0, column: 0))))
        case 1:
            // Önce "?" ile ilk kedinin etki alanı X'lenir, sonra ikinci kedi
            let first = level.catPosition(ofRegion: level.region(at: GridPosition(row: 0, column: 0)))
            let index = first.row * level.size + first.column
            let hasBlanks = CatRules.attacked(by: index, in: level).contains { game.marks[$0] == .blank }
            return hasBlanks ? .useHint : .second(GridPosition(row: 1, column: level.solution[1]))
        case 2:
            return .finder
        default:
            return .freePlay
        }
    }

    /// Yanlış kedinin bozduğu kural (kural şeridinde kırmızı yanar).
    private var violatedRule: RulesStrip.Rule? {
        guard let conflict = viewModel.lastConflict else { return nil }
        switch conflict {
        case .color: return .color
        case .line: return .line
        case .touching: return .touching
        }
    }
}

/// İpucu türü (reklam teklifinde hangi hak eksik).
enum CatHelper: Identifiable {
    case find
    case mark

    var id: Self { self }
}

/// Bölüm sonu özeti.
struct CatResult: Equatable {
    let completion: CatPuzzleModel.Completion
    let isFirstSolve: Bool
    let newBadges: [Badge]

    static func == (lhs: CatResult, rhs: CatResult) -> Bool {
        lhs.completion.level.id == rhs.completion.level.id && lhs.completion.score == rhs.completion.score
    }
}

// MARK: - Alt düğmeler

@MainActor
struct CatHelperButton: View {
    @Environment(\.appTheme) private var theme
    let systemImage: String
    let title: LocalizedStringKey
    let count: Int
    let tint: Color
    /// Eğitimde: düğme parlar, pati onu gösterir.
    var isGuided = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
                        )
                        .shadow(color: tint.opacity(theme.isDark ? 0 : 0.2), radius: 6, y: 3)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(tint)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(theme.accent, lineWidth: 3)
                                .padding(-5)
                                .opacity(isGuided ? 1 : 0)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            PawPointer()
                                .offset(x: 18, y: 26)
                                .opacity(isGuided ? 1 : 0)
                        }
                    Group {
                        if count > 0 {
                            Text(verbatim: "\(count)")
                                .font(.caption.bold().monospacedDigit())
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Circle().fill(theme.mistake))
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption2.bold())
                                .frame(width: 24, height: 22)
                                .background(Capsule().fill(Color(red: 0.2, green: 0.65, blue: 0.35)))
                        }
                    }
                    .foregroundStyle(.white)
                    .offset(x: 4, y: -4)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(count) left"))
    }
}

// MARK: - Kurallar şeridi

@MainActor
struct RulesStrip: View {
    enum Rule {
        case color
        case line
        case touching
    }

    @Environment(\.appTheme) private var theme
    /// Yanlış kedinin bozduğu kural kırmızı yanar.
    var violated: Rule?

    var body: some View {
        HStack(spacing: 8) {
            rule(.color, "paintpalette.fill", "1 cat per color")
            rule(.line, "square.grid.3x3.fill", "1 per row & column")
            rule(.touching, "hand.raised.fill", "Cats can't touch")
        }
        .animation(.easeOut(duration: 0.25), value: violated)
    }

    private func rule(_ kind: Rule, _ icon: String, _ text: LocalizedStringKey) -> some View {
        let isViolated = violated == kind
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(isViolated ? .white : theme.accent)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isViolated ? .white : theme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(isViolated ? theme.mistake : theme.surface))
        .scaleEffect(isViolated ? 1.06 : 1)
    }
}

// MARK: - Bulunacak kediler şeridi

/// Her renge düşen kedi: bulunmadıysa o renkte soluk silüet, bulununca türün portresi.
@MainActor
struct CatStrip: View {
    @Environment(\.appTheme) private var theme
    let level: CatLevel
    let found: Set<Int>
    let cats: CatPuzzleModel

    var body: some View {
        GeometryReader { proxy in
            let count = CGFloat(level.size)
            let size = min(38, (proxy.size.width - (count - 1) * 4) / count)
            HStack(spacing: 4) {
                ForEach(0..<level.size, id: \.self) { region in
                    CatToken(
                        breedID: level.breeds[region],
                        portrait: cats.breed(level.breeds[region])?.portrait,
                        color: CatPalette.color(region),
                        isFound: found.contains(region)
                    )
                    .frame(width: size, height: size)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 38)
        .accessibilityElement()
        .accessibilityLabel(Text("\(found.count) of \(level.size) cats found"))
    }
}

@MainActor
struct CatToken: View {
    let breedID: String
    let portrait: Matrix<RGBColor?>?
    let color: Color
    let isFound: Bool

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(isFound ? 0.95 : 0.25))
            if let photo = BreedPhoto.portrait(breedID) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(2)
                    // Bulunmadıysa: rengin tonunda soluk
                    .grayscale(isFound ? 0 : 1)
                    .colorMultiply(isFound ? .white : color)
                    .opacity(isFound ? 1 : 0.5)
            } else if let portrait {
                ArtworkThumbnail(artwork: portrait, outlined: false)
                    .padding(3)
                    // Bulunmadıysa: rengin tonunda soluk silüet
                    .grayscale(isFound ? 0 : 1)
                    .colorMultiply(isFound ? .white : color)
                    .opacity(isFound ? 1 : 0.55)
            }
        }
        .scaleEffect(isFound ? 1 : 0.9)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isFound)
    }
}

/// Sihirli silgi: açıkken X'lere dokunmak ya da üzerlerinden sürüklemek onları siler.
/// Kedilere ve boş karelere dokunmaz; boş bir kareye dokununca kendiliğinden kapanır.
@MainActor
struct CatEraserButton: View {
    @Environment(\.appTheme) private var theme
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        let tint = Color(hex: "#E58BB0")
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isOn ? tint : theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(tint.opacity(isOn ? 0 : 0.35), lineWidth: 1.5)
                    )
                    .shadow(color: tint.opacity(theme.isDark ? 0 : (isOn ? 0.45 : 0.2)), radius: isOn ? 10 : 6, y: 3)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(isOn ? .white : tint)
                            .rotationEffect(.degrees(isOn ? -12 : 0))
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isOn ? Gold.bright : tint.opacity(0.7))
                            .offset(x: 4, y: -4)
                    }
                    .scaleEffect(isOn ? 1.06 : 1)
                Text("Magic Eraser")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOn ? tint : theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Magic Eraser"))
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
