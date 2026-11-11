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
    @State private var isShowingRules = false
    @State private var ticker = PawTicker()
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
            if colony.needsStory(for: levelNumber) {
                isShowingStory = true
            } else if !colony.hasSeenRules {
                isShowingRules = true
            }
        }
        .onDisappear { saveProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress()
                if result == nil { isPaused = true }
            }
        }
        .onChange(of: isPaused) { _, _ in updatePause() }
        .onChange(of: isShowingStory) { _, _ in updatePause() }
        .onChange(of: isShowingRules) { _, _ in updatePause() }
        .onAppear {
            updatePause()
            // Oyun saati ekran yenilemesine bağlı
            ticker.start { dt in viewModel.tick(dt) }
        }
        .onDisappear { ticker.stop() }
    }

    private func updatePause() {
        viewModel.isPaused = isPaused || isShowingStory || isShowingRules
    }

    private var background: some View {
        LinearGradient(colors: [Color(hex: "#DDF0D0"), Color(hex: "#BFE0B0")], startPoint: .top, endPoint: .bottom)
            .overlay(theme.isDark ? Color.black.opacity(0.45) : Color.clear)
    }

    /// İlk bölümlerde tek cümlelik ipucu: her bölüm tek bir şey öğretir (yol aç, destek gönder, kes).
    private var tip: LocalizedStringResource? {
        guard result == nil else { return nil }
        switch levelNumber {
        case 1: return viewModel.game.links.isEmpty ? "Drag from your cat house to the empty house." : "Cats walk along the yarn. Win the house!"
        case 2: return viewModel.didReinforce
            ? "Bigger houses can open more paths (the dots under a house)."
            : "Win a house, then drag from your big house to the small one to send help."
        case 3: return viewModel.didCut ? "Well done! Cutting sends the cats on the path straight ahead." : "Swipe across your path to cut it: the cats rush forward."
        case 4: return "Mice! Win their houses too. A mouse house wiggles before it attacks."
        default: return nil
        }
    }

    /// Öğretici eli: 1. bölümde ilk yol, 2. bölümde destek, 3. bölümde kesme (oyuncu yapana kadar).
    private var guide: PawGuide? {
        guard result == nil, !isShowingStory, !isShowingRules else { return nil }
        let game = viewModel.game
        let cats = game.nodes.filter { $0.owner == .cats }
        switch levelNumber {
        case 1:
            guard game.links.isEmpty, let cat = cats.first, let target = game.nodes.first(where: { $0.owner == .neutral }) else { return nil }
            return .drag(from: cat.id, to: target.id)
        case 2:
            guard !viewModel.didReinforce else { return nil }
            if cats.count >= 2, let big = cats.max(by: { $0.count < $1.count }), let small = cats.min(by: { $0.count < $1.count }),
               game.canLink(from: big.id, to: small.id) {
                return .drag(from: big.id, to: small.id)
            }
            if game.links.isEmpty, let cat = cats.first,
               let target = game.nodes.filter({ $0.owner == .neutral }).min(by: { $0.position.distance(to: cat.position) < $1.position.distance(to: cat.position) }) {
                return .drag(from: cat.id, to: target.id)
            }
            return nil
        case 3:
            guard !viewModel.didCut else { return nil }
            if let link = game.links.first(where: { $0.owner == .cats && $0.state == .connected }) { return .cut(link: link.id) }
            if game.links.isEmpty, let cat = cats.first,
               let target = game.nodes.filter({ $0.owner == .neutral }).max(by: { $0.count < $1.count }) {
                return .drag(from: cat.id, to: target.id)
            }
            return nil
        default:
            return nil
        }
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
            Button {
                Haptics.selection()
                viewModel.speedMultiplier = viewModel.speedMultiplier == 1 ? 2 : 1
            } label: {
                Text(verbatim: viewModel.speedMultiplier == 1 ? "1×" : "2×")
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(viewModel.speedMultiplier == 1 ? theme.textPrimary : .white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(viewModel.speedMultiplier == 1 ? theme.surface.opacity(0.95) : PawColors.cats))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Text("Game speed"))
            .accessibilityValue(Text(verbatim: viewModel.speedMultiplier == 1 ? "1×" : "2×"))
            .accessibilityIdentifier("paw.speed")
            BirdSortRoundButton(symbol: "questionmark") {
                guard result == nil else { return }
                withAnimation { isShowingRules = true }
            }
            .accessibilityLabel(Text("How to Play"))
            .accessibilityIdentifier("paw.rules")
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
                withAnimation {
                    isShowingStory = false
                    if !colony.hasSeenRules { isShowingRules = true }
                }
            }
            .transition(.opacity)
        } else if isShowingRules {
            PawRulesOverlay {
                colony.markRulesSeen()
                withAnimation { isShowingRules = false }
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
        viewModel.onCut = {
            audio.play(.erase)
            Haptics.play(.mistake)
        }
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

/// Görsel kural kartı: üç küçük canlı sahne, her birinin altında tek kısa satır.
struct PawRulesOverlay: View {
    @Environment(\.appTheme) private var theme
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("How to Play")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                PawRuleScene(kind: .drag)
                PawRuleScene(kind: .flow)
                PawRuleScene(kind: .cut)
                Button(action: onClose) {
                    Text("Got it!")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("paw.rules.close")
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .padding(20)
        }
    }
}

/// Kural sahnesi: solda kedi evi, sağda hedef ev.
/// - drag: el soldan sağa sürükler, yol uzar.
/// - flow: yolda patiler akar, hedefin sayısı azalır, ev turuncuya döner.
/// - cut: yolun ortasından el aşağı kaydırır, yol kesilir, kalan patiler hedefe koşar.
struct PawRuleScene: View {
    enum Kind { case drag, flow, cut }
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: Kind

    var body: some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 1.5 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3)
                scene(t: t)
            }
            .frame(height: 74)
            Text(caption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#E8F6DF").opacity(theme.isDark ? 0.15 : 1)))
        .accessibilityElement(children: .combine)
    }

    private var caption: LocalizedStringResource {
        switch kind {
        case .drag: "Drag from your house to another house: a yarn path grows."
        case .flow: "Cats flow along the path. When the number drops below zero, the house is yours!"
        case .cut: "Swipe across your path to cut it: the cats on it rush ahead."
        }
    }

    private func scene(t: Double) -> some View {
        GeometryReader { proxy in
            let left = CGPoint(x: 40, y: proxy.size.height / 2)
            let right = CGPoint(x: proxy.size.width - 40, y: proxy.size.height / 2)
            let progress: Double = switch kind {
            case .drag: min(max((t - 0.3) / 1.6, 0), 1)
            case .flow, .cut: 1
            }
            let targetCount: Int = switch kind {
            case .drag: 8
            case .flow: max(-3, 8 - Int(max(t - 0.4, 0) * 5))
            case .cut: t > 1.4 ? max(-2, 8 - Int((t - 1.4) * 12)) : 8
            }
            let cutDone = kind == .cut && t > 1.2
            ZStack {
                // Yol
                Path { path in
                    path.move(to: left)
                    path.addLine(to: CGPoint(x: left.x + (right.x - left.x) * progress, y: left.y))
                }
                .stroke(PawColors.cats, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: cutDone ? [4, 6] : []))
                .opacity(cutDone ? 0.35 : 1)
                if kind != .drag {
                    // Akan patiler
                    ForEach(0..<3, id: \.self) { i in
                        let phase = ((t * 0.6) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .position(x: left.x + (right.x - left.x) * phase, y: left.y)
                            .opacity(cutDone && kind == .cut ? 0 : 1)
                    }
                }
                PawHouseView(node: PawNode(id: 1, position: PawPoint(x: 0, y: 0), owner: .cats, count: 20), links: progress >= 1 ? 1 : 0)
                    .scaleEffect(0.62)
                    .position(left)
                PawHouseView(node: PawNode(id: 2, position: PawPoint(x: 0, y: 0), owner: targetCount < 0 ? .cats : .neutral,
                                           count: Double(abs(targetCount))), links: 0)
                    .scaleEffect(0.62)
                    .position(right)
                // El
                switch kind {
                case .drag:
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)
                        .position(x: left.x + (right.x - left.x) * progress + 10, y: left.y + 18)
                case .cut:
                    let y = proxy.size.height * min(max((t - 0.6) / 0.8, 0), 1)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)
                        .position(x: (left.x + right.x) / 2 + 10, y: y + 10)
                case .flow:
                    EmptyView()
                }
            }
        }
    }
}

/// Ekran yenilemesiyle eşzamanlı oyun saati (CADisplayLink).
@MainActor
final class PawTicker {
    private var link: CADisplayLink?
    private var proxy: Proxy?

    func start(_ onTick: @escaping @MainActor (Double) -> Void) {
        stop()
        let proxy = Proxy(onTick)
        let link = CADisplayLink(target: proxy, selector: #selector(Proxy.step(_:)))
        link.add(to: .main, forMode: .common)
        self.proxy = proxy
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        proxy = nil
    }

    private final class Proxy: NSObject {
        let onTick: @MainActor (Double) -> Void
        private var last: CFTimeInterval?

        init(_ onTick: @escaping @MainActor (Double) -> Void) { self.onTick = onTick }

        @MainActor @objc func step(_ link: CADisplayLink) {
            defer { last = link.timestamp }
            guard let last else { return }
            onTick(link.timestamp - last)
        }
    }
}
