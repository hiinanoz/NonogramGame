import NonogramKit
import SwiftUI

/// Rotadan gelen bölüm kimliğiyle Miyav Crush ekranı.
@MainActor
struct CrushGameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let levelID: String

    var body: some View {
        if let level = model.crush.level(withID: levelID) {
            CrushGameView(level: level, reduceMotion: reduceMotion)
                .id(levelID)
        } else {
            ContentUnavailableView("Level not found", systemImage: "questionmark.square.dashed")
        }
    }
}

/// Bölüm sonu özeti (kazanınca).
struct CrushResult: Equatable {
    let levelID: String
    let score: Int
    let stars: Int
    let outcome: CrushLevelOutcome
}

@MainActor
struct CrushGameView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme

    @State private var viewModel: CrushGameViewModel
    @State private var isShowingIntro = true
    @State private var result: CrushResult?
    @State private var isLost = false
    @State private var pawMode = false
    @State private var adOffer: CrushBooster?
    @State private var isConfirmingRestart = false
    @State private var confetti: Date?
    /// Bu bölümde bir kez bedava +5 hamle (Premium); sonrası güçlendirici ya da reklam.
    @State private var usedPremiumRevive = false

    init(level: CrushLevel, reduceMotion: Bool = false) {
        _viewModel = State(initialValue: CrushGameViewModel(level: level, reduceMotion: reduceMotion))
    }

    private var crush: CrushModel { model.crush }
    private var level: CrushLevel { viewModel.level }
    private var number: Int { crush.number(of: level) }
    private var session: CrushSession { viewModel.session }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { ConfettiView(start: confetti).ignoresSafeArea() }
            .overlay { overlays }
            .background { CrushBackdrop().ignoresSafeArea() }
            .themedScreen()
            .screenTitle(Text("Level \(number)"), subtitle: Text(CrushEpisode(index: crush.episode(of: level)).title))
            .toolbar { toolbarMenu }
            .confirmationDialog("Start over?", isPresented: $isConfirmingRestart, titleVisibility: .visible) {
                Button("Start Over", role: .destructive) { restart() }
            }
            .alert(adOfferTitle, isPresented: isOfferingAd, presenting: adOffer) { booster in
                Button("Watch Video") { watchAd(for: booster) }
                Button("Not Now", role: .cancel) {}
            } message: { _ in
                Text("Watch a short video to get one for free.")
            }
            .onAppear(perform: setUp)
            .onDisappear { viewModel.stop() }
    }

    private var content: some View {
        VStack(spacing: 12) {
            CrushHUD(session: session, displayedScore: viewModel.displayedScore)
            ZStack {
                CrushBoardView(viewModel: viewModel, pawMode: pawMode) { position in
                    usePaw(at: position)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.55))
                )
                .overlay(alignment: .top) {
                    if pawMode {
                        Label("Tap an item to pop it", systemImage: "pawprint.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(CrushBooster.paw.tint))
                            .offset(y: -14)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                CheerView(cheer: viewModel.cheer, id: viewModel.cheerID)
                    .allowsHitTesting(false)
            }
            .frame(maxHeight: .infinity)
            boosterBar
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.35), value: pawMode)
    }

    private var overlays: some View {
        overlayContent
            .animation(.spring(duration: 0.4), value: result != nil)
            .animation(.spring(duration: 0.4), value: isLost)
            .animation(.spring(duration: 0.4), value: isShowingIntro)
    }

    @ViewBuilder
    private var overlayContent: some View {
        if isShowingIntro {
            CrushIntroOverlay(level: level, number: number, showsHowTo: !crush.hasSeenIntro) {
                crush.markIntroSeen()
                isShowingIntro = false
                viewModel.start()
            }
            .transition(.opacity)
        } else if let result {
            CrushResultOverlay(
                result: result,
                level: level,
                number: number,
                next: crush.level(after: level),
                onNext: { next in leave(to: .crushGame(levelID: next.id)) },
                onReplay: { leave(to: .crushGame(levelID: level.id)) },
                onMap: { leave(to: nil) }
            )
            .transition(.opacity)
        } else if isLost {
            CrushFailedOverlay(
                session: session,
                extraMoves: crush.count(of: .extraMoves),
                canWatchAd: ads.isRewardedReady,
                isPremiumFree: store.isPremium && !usedPremiumRevive,
                onContinue: continueWithMoves,
                onRetry: restart,
                onMap: { leave(to: nil) }
            )
            .transition(.opacity)
        }
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

    private var boosterBar: some View {
        HStack(spacing: 18) {
            CrushBoosterButton(booster: .paw, count: crush.count(of: .paw), isOn: pawMode) {
                guard viewModel.canPlay else { return }
                if pawMode {
                    pawMode = false
                } else if crush.count(of: .paw) > 0 {
                    Haptics.selection()
                    viewModel.clearSelection()
                    pawMode = true
                } else {
                    adOffer = .paw
                }
            }
            .accessibilityIdentifier("crush.booster.paw")
            CrushBoosterButton(booster: .shuffle, count: crush.count(of: .shuffle), isOn: false) {
                guard viewModel.canPlay else { return }
                pawMode = false
                if crush.use(.shuffle) {
                    audio.play(.card)
                    viewModel.shuffle()
                } else {
                    adOffer = .shuffle
                }
            }
            .accessibilityIdentifier("crush.booster.shuffle")
            CrushBoosterButton(booster: .extraMoves, count: crush.count(of: .extraMoves), isOn: false) {
                guard viewModel.canPlay else { return }
                pawMode = false
                if crush.use(.extraMoves) {
                    audio.play(.card)
                    viewModel.addMoves(5)
                } else {
                    adOffer = .extraMoves
                }
            }
            .accessibilityIdentifier("crush.booster.moves")
        }
        .disabled(session.status != .playing || isShowingIntro)
    }

    // MARK: - Eylemler

    private func setUp() {
        viewModel.onEvent = { event in
            switch event {
            case .swap: audio.play(.tap)
            case .invalid:
                audio.play(.catWrong)
                Haptics.play(.mistake)
            case .cleared(let cascade):
                audio.play(cascade >= 2 ? .combo : .catFound)
                Haptics.play(.lineCompleted)
            case .special:
                audio.play(.catCombo)
                Haptics.play(.lineCompleted)
            case .created:
                audio.play(.catHint)
            case .cheer(let cheer):
                audio.play(cheer == .pawPower || cheer == .frenzy ? .meow2 : .meow)
            case .won:
                audio.play(.catWin)
                Haptics.play(.solved)
            case .lost:
                audio.play(.failed)
                Haptics.play(.failed)
            case .finale:
                audio.play(.fanfare)
            case .boosted:
                Haptics.play(.lineCompleted)
            }
        }
        viewModel.onEnd = { session in
            switch session.status {
            case .won:
                let outcome = crush.recordWin(session, frenzyMoves: viewModel.frenzyMoves)
                ads.puzzleCompleted(isTutorial: number == 1)
                model.reportToGameCenter()
                confetti = Date()
                result = CrushResult(levelID: session.level.id, score: session.score, stars: session.stars, outcome: outcome)
            case .lost:
                isLost = true
            case .playing:
                break
            }
        }
    }

    private func usePaw(at position: GridPosition) {
        guard pawMode, crush.count(of: .paw) > 0 else { return }
        if viewModel.smash(position) {
            _ = crush.use(.paw)
            audio.play(.catX)
            pawMode = false
        }
    }

    /// Hamle bitti: +5 hamleyle devam (güçlendirici, Premium ya da reklam).
    private func continueWithMoves() {
        if store.isPremium && !usedPremiumRevive {
            usedPremiumRevive = true
            revive()
        } else if crush.use(.extraMoves) {
            revive()
        } else {
            Task {
                if await ads.watchRewardedAd() { revive() }
            }
        }
    }

    private func revive() {
        isLost = false
        viewModel.addMoves(5)
        audio.play(.card)
    }

    private func restart() {
        if session.status == .lost { crush.recordLoss(session) }
        router.replaceTop(with: .crushGame(levelID: level.id))
    }

    private func leave(to route: Route?) {
        if session.status == .lost { crush.recordLoss(session) }
        ads.continueAfterPuzzle {
            if let route {
                router.replaceTop(with: route)
            } else {
                router.pop()
            }
        }
    }

    private var isOfferingAd: Binding<Bool> {
        Binding(get: { adOffer != nil }, set: { if !$0 { adOffer = nil } })
    }

    private var adOfferTitle: Text {
        Text("No \(Text(adOffer?.title ?? "")) Left")
    }

    private func watchAd(for booster: CrushBooster) {
        Task {
            guard await ads.watchRewardedAd() else { return }
            crush.add(booster)
            audio.play(.card)
        }
    }
}

// MARK: - Üst çubuk

/// Hamle sayısı, hedefler ve yıldızlı puan çubuğu.
@MainActor
struct CrushHUD: View {
    @Environment(\.appTheme) private var theme
    let session: CrushSession
    let displayedScore: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(verbatim: "\(session.movesLeft)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(session.movesLeft <= 3 ? theme.mistake : ModeStyle.crush.ink(theme))
                    .contentTransition(.numericText(value: Double(session.movesLeft)))
                    .animation(.snappy, value: session.movesLeft)
                Text("Moves")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(width: 64, height: 64)
            .background(Circle().fill(theme.surface))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("crush.moves")

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Array(session.goals.enumerated()), id: \.offset) { _, goal in
                        CrushGoalChip(goal: goal)
                    }
                }
                CrushScoreBar(score: displayedScore, thresholds: session.level.starScores)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(ModeStyle.crush.background(theme)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(theme.isDark ? 0.06 : 0.7), lineWidth: 1)
        )
    }
}

/// Tek hedef: eşya simgesi ve kalan sayı (tamamlanınca onay işareti).
@MainActor
struct CrushGoalChip: View {
    @Environment(\.appTheme) private var theme
    let goal: CrushSession.GoalProgress
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 4) {
            CrushGoalIcon(goal: goal.goal)
                .frame(width: size, height: size)
            Group {
                if goal.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                } else if case .score = goal.goal {
                    Text(goal.target, format: .number)
                } else {
                    Text(verbatim: "\(goal.remaining)")
                }
            }
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(theme.textPrimary)
            .contentTransition(.numericText())
            .animation(.snappy, value: goal.remaining)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(theme.surface.opacity(0.9)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goal.goal.sentence)
        .accessibilityValue(goal.isComplete ? Text("Done") : Text("\(goal.remaining) left"))
    }
}

/// Hedefin simgesi: toplanacak eşya, özel eşya ya da puan yıldızı.
struct CrushGoalIcon: View {
    let goal: CrushGoal

    var body: some View {
        switch goal {
        case .collect(let color, _):
            CrushPieceView(piece: CrushPiece(id: 0, color: color))
        case .specials:
            CrushPieceView(piece: CrushPiece(id: 0, color: .yarn, special: .stripedRow))
        case .score:
            Image(systemName: "star.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Gold.mid)
        }
    }
}

extension CrushGoal {
    /// Hedefin cümlesi ("25 Yün Yumağı topla").
    var sentence: Text {
        switch self {
        case .score(let target):
            Text("Score \(target) points")
        case .collect(let color, let target):
            Text("Collect \(target) \(Text(color.title))")
        case .specials(let target):
            Text("Pop \(target) special items")
        }
    }
}

/// Puan çubuğu ve üstünde üç yıldız eşiği.
@MainActor
struct CrushScoreBar: View {
    @Environment(\.appTheme) private var theme
    let score: Int
    let thresholds: [Int]

    var body: some View {
        let top = Double(max(thresholds.last ?? 1, 1))
        HStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surface)
                    Capsule()
                        .fill(LinearGradient(colors: [ModeStyle.crush.tint(theme).opacity(0.7), ModeStyle.crush.tint(theme)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, width * CGFloat(min(1, Double(score) / top))))
                        .animation(.snappy, value: score)
                    ForEach(Array(thresholds.enumerated()), id: \.offset) { _, threshold in
                        let reached = score >= threshold
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(reached ? Gold.bright : theme.textSecondary.opacity(0.4))
                            .shadow(color: .black.opacity(reached ? 0.25 : 0), radius: 1, y: 1)
                            .scaleEffect(reached ? 1.2 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: reached)
                            .position(x: min(width - 8, width * CGFloat(Double(threshold) / top)), y: 6)
                    }
                }
            }
            .frame(height: 12)
            Text(score, format: .number)
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText(value: Double(score)))
                .frame(minWidth: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Score"))
        .accessibilityValue(Text(score, format: .number))
    }
}

// MARK: - Güçlendiriciler

extension CrushBooster {
    var title: LocalizedStringResource {
        switch self {
        case .paw: "Cat Paw"
        case .shuffle: "Shuffle"
        case .extraMoves: "+5 Moves"
        }
    }

    var icon: String {
        switch self {
        case .paw: "pawprint.fill"
        case .shuffle: "shuffle"
        case .extraMoves: "plus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .paw: Color(hex: "#F06A8A")
        case .shuffle: Color(hex: "#5A9BE6")
        case .extraMoves: Color(hex: "#3DAE7A")
        }
    }
}

@MainActor
struct CrushBoosterButton: View {
    @Environment(\.appTheme) private var theme
    let booster: CrushBooster
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isOn ? booster.tint : theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(booster.tint.opacity(isOn ? 0 : 0.4), lineWidth: 1.5)
                        )
                        .shadow(color: booster.tint.opacity(theme.isDark ? 0 : 0.25), radius: 6, y: 3)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Image(systemName: booster.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(isOn ? .white : booster.tint)
                        }
                        .scaleEffect(isOn ? 1.08 : 1)
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
                    .offset(x: 5, y: -5)
                }
                Text(booster.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(booster.title))
        .accessibilityValue(Text("\(count) left"))
    }
}

// MARK: - Zincir yazısı ve zemin

/// "Miyav!", "Harika!", "Pati Gücü!" yazısı: zıplayarak gelir, kaybolur.
struct CheerView: View {
    let cheer: CrushCheer?
    let id: Int

    var body: some View {
        ZStack {
            if let cheer {
                Text(cheer.text)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#FFE27A"), Color(hex: "#FF8A3D")], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: "#7A2E00").opacity(0.55), radius: 0, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                    .rotationEffect(.degrees(-6))
                    .id(id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .opacity.combined(with: .scale(scale: 1.3))))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: id)
    }
}

/// Oyun ekranının zemini: modun pastel renginde yumuşak geçiş ve silik patiler.
struct CrushBackdrop: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: ModeStyle.crush.backgroundColors(theme), startPoint: .top, endPoint: .bottom)
            if Illustration.exists("crush-background") {
                IllustrationView(name: "crush-background", contentMode: .fill)
                    .opacity(0.9)
            } else {
                Canvas { context, size in
                    let step: CGFloat = 70
                    var row = 0
                    var y: CGFloat = 20
                    while y < size.height {
                        var x: CGFloat = row.isMultiple(of: 2) ? 20 : 55
                        while x < size.width {
                            var paw = context
                            paw.translateBy(x: x, y: y)
                            paw.rotate(by: .degrees(row.isMultiple(of: 2) ? -15 : 15))
                            paw.opacity = theme.isDark ? 0.05 : 0.08
                            paw.fill(Path(ellipseIn: CGRect(x: -7, y: -2, width: 14, height: 11)), with: .color(.white))
                            for (dx, dy) in [(-8.0, -8.0), (-3.0, -12.0), (3.0, -12.0), (8.0, -8.0)] {
                                paw.fill(Path(ellipseIn: CGRect(x: dx - 2.5, y: dy - 2.5, width: 5, height: 5)), with: .color(.white))
                            }
                            x += step
                        }
                        y += step * 0.8
                        row += 1
                    }
                }
            }
        }
    }
}
