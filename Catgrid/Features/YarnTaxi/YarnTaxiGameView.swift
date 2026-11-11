import NonogramKit
import SwiftUI

/// Yumak Taksi oyun ekranı: üstte yumak sırası ve durak, ortada otopark, altta kedi ve yardımcılar
/// (geri al, ek yer, ipucu). Yardımcılar bitince Premium'da sınırsız, değilse ödüllü reklamla.
@MainActor
struct YarnTaxiGameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    // Araba yolu ve yumak atlayışı için parçaların ekrandaki yerleri
    @State private var queueFrame: CGRect = .zero
    @State private var stationFrame: CGRect = .zero
    @State private var lotFrame: CGRect = .zero
    private static let space = "taxi"
    let levelNumber: Int
    @State private var viewModel: YarnTaxiGameViewModel
    @State private var isPaused = false
    @State private var reward: YarnTaxiReward?
    @State private var isShowingPaywall = false
    @State private var adOffer: Booster?

    enum Booster: Identifiable {
        case hint
        case slot
        var id: Self { self }
    }

    init(levelNumber: Int, saved: YarnTaxiSavedGame? = nil) {
        self.levelNumber = levelNumber
        _viewModel = State(initialValue: YarnTaxiGameViewModel(level: YarnTaxiCatalog.level(levelNumber), resuming: saved))
    }

    private var taxi: YarnTaxiModel { model.taxi }
    private var district: YarnTaxiDistrict { YarnTaxiDistrict(index: viewModel.level.district) }

    var body: some View {
        GeometryReader { screen in
            content(dockHeight: max(118, screen.size.height * 0.15))
        }
        .background(background.ignoresSafeArea())
        .overlay { overlays }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isWon)
        .animation(.easeInOut, value: viewModel.isStuck)
        .animation(.spring(response: 0.3), value: isPaused)
        .onDisappear { saveProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress()
                if !viewModel.isWon { isPaused = true }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPaywall) { PremiumPaywall() }
        .alert(adOfferTitle, isPresented: isOfferingAd) {
            Button("Watch Video") {
                if let adOffer { watchAd(for: adOffer) }
            }
            Button("Go Premium") { isShowingPaywall = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Watch a short ad to get one more, or go Premium for unlimited helpers.")
        }
        .onAppear { wireEvents() }
    }

    private var background: some View {
        LinearGradient(colors: ModeStyle.taxi.backgroundColors(theme), startPoint: .top, endPoint: .bottom)
    }

    private func content(dockHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            topBar
            // Sıra ve durak: yol şeridinin üstünde
            VStack(spacing: 6) {
                YarnQueueView(game: viewModel.game)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { queueFrame = $0 }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#7A5A8C").opacity(0.85)))
                YarnStationView(game: viewModel.game, travelingCar: viewModel.traveling?.car.id,
                                flyingSlot: viewModel.flyingYarn?.slot, bouncingSlot: viewModel.bouncingSlot,
                                bounceID: viewModel.bounceID, confetti: viewModel.confetti)
                    .frame(height: 74)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { stationFrame = $0 }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "#4A4F5C"))
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color(hex: "#F6D365")).frame(height: 3).padding(.horizontal, 10)
                            }
                    )
                    .accessibilityIdentifier("taxi.station")
            }
            .padding(.horizontal, 12)
            if level1Tip {
                Text("Tap the glowing car: it drives to the station and the yarn of its color hops in!")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
            }
            YarnLotView(game: viewModel.game, hintCar: viewModel.hintCar, guideCar: viewModel.guideCar,
                        shakingCar: viewModel.shakingCar, shakeID: viewModel.shakeID,
                        blockerCar: viewModel.blockerCar) { car in
                viewModel.tap(car)
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.shakeID)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { lotFrame = $0 }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("taxi.lot")
            dock(height: dockHeight)
        }
        .overlay(alignment: .topLeading) { motionLayer }
        .coordinateSpace(.named(Self.space))
    }

    // MARK: - Hareket katmanı (yoldaki araba, atlayan yumak)

    private var grid: CGRect {
        let inner = YarnLotView.gridRect(in: lotFrame.size, rows: viewModel.game.rows, columns: viewModel.game.columns)
        return inner.offsetBy(dx: lotFrame.minX, dy: lotFrame.minY)
    }

    private func slotCenter(_ slot: Int) -> CGPoint {
        let count = CGFloat(max(viewModel.game.station.count, 1))
        return CGPoint(x: stationFrame.minX + (CGFloat(slot) + 0.5) * stationFrame.width / count, y: stationFrame.midY)
    }

    /// Arabanın yolu: baktığı yöne doğru otoparktan çıkar, kenardaki yoldan durağın altındaki
    /// şeride gelir ve yerine girer.
    private func route(for car: YarnCar, to slot: Int) -> [CGPoint] {
        let grid = grid
        let cell = grid.width / CGFloat(viewModel.game.columns)
        let columns = car.direction.isHorizontal ? CGFloat(car.length) : 1
        let rows = car.direction.isHorizontal ? 1 : CGFloat(car.length)
        let start = CGPoint(x: grid.minX + (CGFloat(car.column) + columns / 2) * cell,
                            y: grid.minY + (CGFloat(car.row) + rows / 2) * cell)
        let target = slotCenter(slot)
        let reach = cell * CGFloat(car.length) / 2 + 4
        let laneY = (stationFrame.maxY + grid.minY) / 2 + 4
        let leftX = max(grid.minX - cell * 0.45, 14)
        let rightX = min(grid.maxX + cell * 0.45, lotFrame.maxX + 6)
        var points = [start]
        switch car.direction {
        case .up:
            break
        case .left:
            points.append(CGPoint(x: min(leftX, grid.minX - reach * 0.4), y: start.y))
            points.append(CGPoint(x: points.last!.x, y: laneY))
        case .right:
            points.append(CGPoint(x: max(rightX, grid.maxX + reach * 0.4), y: start.y))
            points.append(CGPoint(x: points.last!.x, y: laneY))
        case .down:
            let bottom = grid.maxY + reach * 0.5
            let sideX = start.x < grid.midX ? leftX : rightX
            points.append(CGPoint(x: start.x, y: bottom))
            points.append(CGPoint(x: sideX, y: bottom))
            points.append(CGPoint(x: sideX, y: laneY))
        }
        if car.direction == .up { points.append(CGPoint(x: start.x, y: laneY)) }
        points.append(CGPoint(x: target.x, y: laneY))
        points.append(target)
        return points
    }

    @ViewBuilder
    private var motionLayer: some View {
        if !lotFrame.isEmpty, !stationFrame.isEmpty {
            ZStack(alignment: .topLeading) {
                Color.clear
                if let travel = viewModel.traveling {
                    let cell = grid.width / CGFloat(viewModel.game.columns)
                    let stationCell = YarnStationView.carCell(in: stationFrame.size, slots: viewModel.game.station.count)
                    YarnTravelingCar(car: travel.car, points: route(for: travel.car, to: travel.slot), cell: cell,
                                     endScale: stationCell / max(cell, 1), duration: YarnTaxiGameViewModel.travelTime)
                        .id(travel.car.id)
                }
                if let yarn = viewModel.flyingYarn {
                    YarnHoppingBall(from: CGPoint(x: queueFrame.minX + YarnQueueView.headSize / 2, y: queueFrame.midY),
                                    to: slotCenter(yarn.slot), color: yarn.color, duration: YarnTaxiGameViewModel.hopTime)
                        .id(yarn.index)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var level1Tip: Bool { levelNumber == 1 && viewModel.game.moves == 0 }

    @ViewBuilder
    private var overlays: some View {
        if isPaused && !viewModel.isWon {
            ModePauseOverlay(
                onContinue: { isPaused = false },
                onRestart: {
                    isPaused = false
                    taxi.clearSavedGame()
                    viewModel.restart()
                },
                onMap: { leave(to: nil, showAd: false) }
            )
            .transition(.opacity)
        } else if viewModel.isWon {
            YarnTaxiWinOverlay(level: levelNumber, stars: viewModel.stars, reward: reward,
                               hasNext: levelNumber < YarnTaxiCatalog.levelCount,
                               onNext: { leave(to: .taxiGame(level: levelNumber + 1)) },
                               onMap: { leave(to: nil) })
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else if viewModel.isStuck {
            YarnTaxiStuckOverlay(
                canUndo: viewModel.canUndo,
                slotBadge: store.isPremium ? nil : taxi.progress.extraSlots,
                onUndo: { viewModel.undo() },
                onSlot: addSlot,
                onRestart: {
                    taxi.clearSavedGame()
                    viewModel.restart()
                }
            )
            .transition(.opacity)
        }
    }

    // MARK: - Üst çubuk

    private var topBar: some View {
        HStack(spacing: 10) {
            BirdSortRoundButton(symbol: "chevron.left") { leave(to: nil, showAd: false) }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("taxi.back")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text("Level \(levelNumber)")
                    .font(.headline.weight(.heavy))
                Text(district.title)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.surface.opacity(0.95)))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            Spacer(minLength: 0)
            ModePauseButton {
                guard !viewModel.isWon else { return }
                Haptics.selection()
                isPaused = true
            }
            .accessibilityIdentifier("taxi.pause")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Alt bölüm: kedi ve yardımcılar

    private func dock(height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: -height * 0.22) {
            BirdSortCatView(mood: viewModel.mood)
                .frame(width: height * 1.7, height: height * 1.13, alignment: .bottom)
                .padding(.leading, -height * 0.2)
            HStack(alignment: .bottom, spacing: 0) {
                boosterButton(symbol: "arrow.uturn.backward", title: Text("Undo"), badge: nil, enabled: viewModel.canUndo) {
                    audio.play(.tap)
                    viewModel.undo()
                }
                .accessibilityIdentifier("taxi.undo")
                boosterButton(symbol: "parkingsign.square.fill", title: Text("+1 Place"),
                              badge: store.isPremium ? nil : taxi.progress.extraSlots, enabled: !viewModel.isWon) {
                    addSlot()
                }
                .accessibilityIdentifier("taxi.slot")
                boosterButton(symbol: "lightbulb.fill", title: Text("Hint"),
                              badge: store.isPremium ? nil : taxi.progress.hints, enabled: !viewModel.isWon) {
                    showHint()
                }
                .accessibilityIdentifier("taxi.hint")
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .frame(height: height, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .background(
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
        viewModel.onMove = { audio.play(.tap) }
        viewModel.onBoard = { _ in audio.play(.fill) }
        viewModel.onDepart = {
            audio.play(.combo)
            Haptics.play(.lineCompleted)
        }
        viewModel.onBlocked = {
            audio.play(.mistake)
            Haptics.play(.mistake)
        }
        viewModel.onStuck = { Haptics.play(.mistake) }
        viewModel.onWin = {
            audio.play(.fanfare)
            Haptics.play(.solved)
            taxi.clearSavedGame()
            reward = taxi.recordWin(level: levelNumber, stars: viewModel.stars)
            model.reportToGameCenter()
            ads.puzzleCompleted(isTutorial: levelNumber <= 2)
        }
    }

    private func addSlot() {
        guard !viewModel.isWon else { return }
        if store.isPremium {
            viewModel.addSlot()
            audio.play(.card)
        } else if taxi.useExtraSlot() {
            viewModel.addSlot()
            audio.play(.card)
        } else {
            adOffer = .slot
        }
    }

    private func showHint() {
        if store.isPremium {
            Task { if await viewModel.showHint() { audio.play(.catHint) } }
        } else if taxi.progress.hints > 0 {
            Task {
                if await viewModel.showHint() {
                    _ = taxi.useHint()
                    audio.play(.catHint)
                }
            }
        } else {
            adOffer = .hint
        }
    }

    private func watchAd(for booster: Booster) {
        Task {
            guard await ads.watchRewardedAd() else { return }
            switch booster {
            case .hint:
                if await viewModel.showHint() { audio.play(.catHint) }
            case .slot:
                viewModel.addSlot()
                audio.play(.card)
            }
        }
    }

    private var isOfferingAd: Binding<Bool> {
        Binding(get: { adOffer != nil }, set: { if !$0 { adOffer = nil } })
    }

    private var adOfferTitle: Text {
        switch adOffer {
        case .hint: Text("No Hints Left")
        case .slot: Text("No Extra Places Left")
        case nil: Text(verbatim: "")
        }
    }

    /// Çıkarken: hamle yapılmış bölüm kaydedilir; bitmiş bölümün kaydı silinir.
    private func saveProgress() {
        if viewModel.isWon {
            if taxi.savedGame?.level == levelNumber { taxi.clearSavedGame() }
        } else if viewModel.hasProgress {
            taxi.saveGame(viewModel.savedState)
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

/// Bölüm bitti kartı.
struct YarnTaxiWinOverlay: View {
    @Environment(\.appTheme) private var theme
    let level: Int
    let stars: Int
    let reward: YarnTaxiReward?
    let hasNext: Bool
    let onNext: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Level \(level) Complete!")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: index == 1 ? 46 : 36, weight: .bold))
                            .foregroundStyle(index < stars ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(Color.gray.opacity(0.3)))
                            .offset(y: index == 1 ? -6 : 0)
                    }
                }
                Image("sortcat-cheer-4")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                if let reward {
                    HStack(spacing: 6) {
                        Image(systemName: reward == .hint ? "lightbulb.fill" : "parkingsign.square.fill")
                        Text(reward == .hint ? "+1 Hint" : "+1 Extra Place")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "#C25A1E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#FFE7C7")))
                }
                VStack(spacing: 10) {
                    if hasNext {
                        Button(action: onNext) {
                            Text("Next Level")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("taxi.result.next")
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
                    .accessibilityIdentifier("taxi.result.map")
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
        }
    }
}

/// Durak doldu: geri al, ek yer ya da baştan.
struct YarnTaxiStuckOverlay: View {
    @Environment(\.appTheme) private var theme
    let canUndo: Bool
    let slotBadge: Int?
    let onUndo: () -> Void
    let onSlot: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Image("sortcat-idle-4")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)
                Text("The station is full!")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(theme.textPrimary)
                button(Text("+1 Place"), symbol: "parkingsign.square.fill", prominent: true, action: onSlot)
                    .overlay(alignment: .topTrailing) {
                        if let slotBadge, slotBadge == 0 {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Circle().fill(Color(hex: "#F07A3C")))
                                .offset(x: 4, y: -6)
                        }
                    }
                    .accessibilityIdentifier("taxi.stuck.slot")
                if canUndo {
                    button(Text("Undo"), symbol: "arrow.uturn.backward", prominent: false, action: onUndo)
                        .accessibilityIdentifier("taxi.stuck.undo")
                }
                button(Text("Restart"), symbol: "arrow.counterclockwise", prominent: false, action: onRestart)
                    .accessibilityIdentifier("taxi.stuck.restart")
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(theme.surface))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
        }
    }

    private func button(_ title: Text, symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { title } icon: { Image(systemName: symbol) }
                .font(.headline.weight(prominent ? .heavy : .semibold))
                .foregroundStyle(prominent ? .white : theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(prominent
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(theme.surfaceMuted)))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
