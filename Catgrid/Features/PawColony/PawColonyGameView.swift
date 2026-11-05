import NonogramKit
import SwiftUI

/// Pati Kolonisi oyun ekranı: üstte bölüm ve süre, ortada harita, bölge başında hikâye kartı.
@MainActor
struct PawColonyGameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    let levelNumber: Int
    @State private var viewModel: PawColonyGameViewModel
    @State private var isPaused = false
    @State private var isShowingStory = false
    @State private var result: PawColonyGame.Status?

    init(levelNumber: Int, saved: PawColonySavedGame? = nil) {
        self.levelNumber = levelNumber
        _viewModel = State(initialValue: PawColonyGameViewModel(level: PawColonyCatalog.level(levelNumber), resuming: saved))
    }

    private var colony: PawColonyModel { model.colony }
    private var region: PawColonyRegion { PawColonyRegion(index: viewModel.level.region) }

    var body: some View {
        VStack(spacing: 8) {
            topBar
            if viewModel.level.isBoss {
                HStack(spacing: 6) {
                    MouseFace().frame(width: 26, height: 22)
                    Text(region.boss)
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(PawColors.miceDeep))
            }
            PawColonyBoardView(viewModel: viewModel, guide: guide)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
                .accessibilityIdentifier("paw.board")
            if let tip {
                Text(tip)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
        }
        .background(background.ignoresSafeArea())
        .overlay { overlays }
        .animation(.spring(response: 0.35), value: result)
        .animation(.spring(response: 0.3), value: isPaused)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            wireEvents()
            if colony.needsStory(for: levelNumber) { isShowingStory = true }
        }
        .onDisappear { saveProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress()
                if result == nil { isPaused = true }
            }
        }
        .onChange(of: isPaused) { _, paused in viewModel.isPaused = paused || isShowingStory }
        .onChange(of: isShowingStory) { _, showing in viewModel.isPaused = showing || isPaused }
        .task {
            viewModel.isPaused = isShowingStory
            // Oyun saati: ekran kareleriyle ilerler
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                let now = clock.now
                let elapsed = last.duration(to: now)
                last = now
                viewModel.tick(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
            }
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color(hex: "#DDF0D0"), Color(hex: "#BFE0B0")], startPoint: .top, endPoint: .bottom)
            .overlay(theme.isDark ? Color.black.opacity(0.45) : Color.clear)
    }

    /// İlk bölümlerde tek cümlelik ipucu.
    private var tip: LocalizedStringResource? {
        guard result == nil else { return nil }
        switch levelNumber {
        case 1: return viewModel.game.links.isEmpty ? "Drag from your cat house to the empty house." : "Cats walk along the yarn. Win the house!"
        case 2: return "Bigger houses can open more paths (the dots under a house)."
        case 4: return "Mice! Win their houses too. Swipe across your path to cut it: the cats rush forward."
        default: return nil
        }
    }

    /// 1. bölümde, henüz yol yokken: el kedi evinden sahipsiz eve sürükler.
    private var guide: (from: Int, to: Int)? {
        guard levelNumber == 1, viewModel.game.links.isEmpty, result == nil,
              let cat = viewModel.game.nodes.first(where: { $0.owner == .cats }),
              let target = viewModel.game.nodes.first(where: { $0.owner == .neutral }) else { return nil }
        return (cat.id, target.id)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            BirdSortRoundButton(symbol: "chevron.left") { leave(to: nil, showAd: false) }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("paw.back")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("Level \(levelNumber)")
                    .font(.headline.weight(.heavy))
                Text(region.title)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.surface.opacity(0.95)))
            Spacer(minLength: 0)
            Label {
                Text(Duration.seconds(viewModel.game.time), format: .time(pattern: .minuteSecond))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "clock")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Capsule().fill(theme.surface.opacity(0.95)))
            ModePauseButton {
                guard result == nil else { return }
                Haptics.selection()
                isPaused = true
            }
            .accessibilityIdentifier("paw.pause")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var overlays: some View {
        if isShowingStory {
            PawStoryOverlay(region: region, isBoss: viewModel.level.isBoss) {
                colony.markStorySeen(region: region.index)
                withAnimation { isShowingStory = false }
            }
            .transition(.opacity)
        } else if let result {
            PawResultOverlay(level: levelNumber, won: result == .won, stars: viewModel.stars, time: viewModel.game.time,
                             hasNext: levelNumber < PawColonyCatalog.levelCount,
                             onNext: { leave(to: .colonyGame(level: levelNumber + 1)) },
                             onRetry: {
                                 colony.clearSavedGame()
                                 viewModel.restart()
                                 self.result = nil
                             },
                             onMap: { leave(to: nil) })
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else if isPaused {
            ModePauseOverlay(
                onContinue: { isPaused = false },
                onRestart: {
                    isPaused = false
                    colony.clearSavedGame()
                    viewModel.restart()
                },
                onMap: { leave(to: nil, showAd: false) }
            )
            .transition(.opacity)
        }
    }

    private func wireEvents() {
        viewModel.onLink = {
            audio.play(.tap)
            Haptics.selection()
        }
        viewModel.onCut = { audio.play(.erase) }
        viewModel.onCapture = { owner in
            if owner == .cats {
                audio.play(.meow)
                Haptics.play(.lineCompleted)
            } else {
                audio.play(.mistake)
            }
        }
        viewModel.onEnd = { status in
            result = status
            colony.clearSavedGame()
            if status == .won {
                audio.play(.fanfare)
                Haptics.play(.solved)
                colony.recordWin(level: levelNumber, stars: viewModel.stars)
                model.reportToGameCenter()
                ads.puzzleCompleted(isTutorial: levelNumber <= 3)
            } else {
                audio.play(.failed)
                Haptics.play(.mistake)
            }
        }
    }

    private func saveProgress() {
        if result != nil {
            if colony.savedGame?.level == levelNumber { colony.clearSavedGame() }
        } else if viewModel.hasProgress {
            colony.saveGame(viewModel.savedState)
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
        if showAd && result == .won {
            ads.continueAfterPuzzle(go)
        } else {
            go()
        }
    }
}

/// Kodla çizilmiş fare yüzü (fare lideri ve hikâye kartı).
struct MouseFace: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                HStack(spacing: w * 0.32) {
                    Circle().fill(PawColors.miceDeep).frame(width: w * 0.42)
                    Circle().fill(PawColors.miceDeep).frame(width: w * 0.42)
                }
                .offset(y: -w * 0.18)
                Ellipse().fill(PawColors.mice).frame(width: w * 0.8, height: w * 0.66).offset(y: w * 0.08)
                HStack(spacing: w * 0.2) {
                    Circle().fill(.black).frame(width: w * 0.09)
                    Circle().fill(.black).frame(width: w * 0.09)
                }
                .offset(y: w * 0.02)
                Circle().fill(Color(hex: "#F5B8C8")).frame(width: w * 0.12).offset(y: w * 0.18)
            }
            .frame(width: w, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

/// Bölge başında hikâye: Muffin anlatır; lider bölümlerinde fare lideri de görünür.
struct PawStoryOverlay: View {
    @Environment(\.appTheme) private var theme
    let region: PawColonyRegion
    let isBoss: Bool
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(region.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                HStack(alignment: .bottom, spacing: 16) {
                    MuffinView(pose: .point, speechID: 1)
                        .frame(width: 90, height: 130)
                    VStack(spacing: 4) {
                        MouseFace().frame(width: 70, height: 60)
                        Text(region.boss)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(PawColors.miceDeep)
                    }
                }
                Text(region.story)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onStart) {
                    Text("Let's Go!")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("paw.story.start")
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .padding(24)
        }
    }
}

/// Bölüm sonu: kazanınca yıldızlar ve süre, kaybedince tekrar dene.
struct PawResultOverlay: View {
    @Environment(\.appTheme) private var theme
    let level: Int
    let won: Bool
    let stars: Int
    let time: Double
    let hasNext: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(won ? "Level \(level) Complete!" : "The mice won this time!")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                if won {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: index == 1 ? 46 : 36, weight: .bold))
                                .foregroundStyle(index < stars ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Color.gray.opacity(0.3)))
                                .offset(y: index == 1 ? -6 : 0)
                        }
                    }
                    MuffinView(pose: .cheer, speechID: 1).frame(height: 120)
                    Text(Duration.seconds(time), format: .time(pattern: .minuteSecond))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                } else {
                    MouseFace().frame(width: 90, height: 76)
                }
                VStack(spacing: 10) {
                    if won && hasNext {
                        primary(Text("Next Level"), action: onNext).accessibilityIdentifier("paw.result.next")
                    }
                    if !won {
                        primary(Text("Try Again"), action: onRetry).accessibilityIdentifier("paw.result.retry")
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
                    .accessibilityIdentifier("paw.result.map")
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
        }
    }

    private func primary(_ title: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
