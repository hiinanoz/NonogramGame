import NonogramKit
import SwiftUI

/// Kedi Kutusu oyun ekranı: üstte en yüksek puan ve puan, ortada 8×8 tahta, altta üç parça.
/// Parça sürüklenip tahtaya bırakılır; parmağın biraz üstünde görünür, yerleşeceği yer soluk
/// gösterilir ve tamamlanacak satır/sütunlar parlar.
@MainActor
struct CatBlockGameScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var game: CatBlockGame
    /// Oyuna başlarken kayıtlı en yüksek puan ("Yeni rekor" bir kez gösterilir).
    @State private var startingBest: Int
    @State private var isPaused = false
    @State private var isOver = false
    @State private var isNewBest = false
    @State private var shownNewBestBanner = false
    @State private var isDiscarded = false

    // Sürükleme
    @State private var dragIndex: Int?
    @State private var dragLocation: CGPoint = .zero
    @State private var boardFrame: CGRect = .zero

    // Efektler
    @State private var bursts: [CatBlockBurst] = []
    @State private var popup: CatBlockPopup?
    @State private var shake = 0

    private static let space = "catblock"

    init(saved: CatBlockGame?, best: Int) {
        _game = State(initialValue: saved ?? CatBlockGame(seed: UInt64.random(in: 1...UInt64.max)))
        _startingBest = State(initialValue: best)
    }

    private var blocks: CatBlockModel { model.blocks }

    var body: some View {
        GeometryReader { proxy in
            let boardSide: CGFloat = min(proxy.size.width - 32, proxy.size.height * 0.56)
            let cell: CGFloat = boardSide / CGFloat(CatBlockGame.size)
            VStack(spacing: 0) {
                topBar
                scoreHeader
                    .padding(.top, 6)
                Spacer(minLength: 8)
                board(cell: cell)
                    .frame(width: boardSide, height: boardSide)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { boardFrame = $0 }
                    .modifier(CatBlockShake(amount: CGFloat(shake)))
                Spacer(minLength: 8)
                tray(cell: cell)
                    .frame(height: cell * 3.4)
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) { draggedPiece(cell: cell) }
        }
        .coordinateSpace(.named(Self.space))
        .background(background.ignoresSafeArea())
        .overlay { overlays }
        .animation(.spring(response: 0.35), value: isOver)
        .animation(.spring(response: 0.3), value: isPaused)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { saveProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress()
                if !isOver { isPaused = true }
            }
        }
        .onAppear {
            if game.isOver { finish() }
        }
    }

    private var background: some View {
        LinearGradient(colors: ModeStyle.block.backgroundColors(theme), startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Üst kısım

    private var topBar: some View {
        HStack(spacing: 10) {
            BirdSortRoundButton(symbol: "chevron.left") { leave() }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("block.back")
            HStack(spacing: 5) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Gold.mid)
                Text(verbatim: "\(max(blocks.bestScore, game.score))")
                    .font(.headline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(theme.surface.opacity(0.95)))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Best Score"))
            Spacer()
            ModePauseButton {
                guard !isOver else { return }
                Haptics.selection()
                isPaused = true
            }
            .accessibilityIdentifier("block.pause")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var scoreHeader: some View {
        ZStack {
            Text(verbatim: "\(game.score)")
                .font(.system(size: 46, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(ModeStyle.block.ink(theme))
                .contentTransition(.numericText(value: Double(game.score)))
                .animation(.snappy, value: game.score)
                .accessibilityLabel(Text("Score"))
                .accessibilityValue(Text(verbatim: "\(game.score)"))
            if let popup {
                CatBlockPopupView(popup: popup)
                    .id(popup.id)
                    .offset(y: 46)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 64)
    }

    // MARK: - Tahta

    private func board(cell: CGFloat) -> some View {
        let preview = previewPlacement(cell: cell)
        let highlight = preview.map { linesToClear(piece: $0.piece, row: $0.row, column: $0.column) } ?? []
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.isDark ? Color(hex: "#221C33") : Color(hex: "#3B3360").opacity(0.92))
                .padding(-6)
            ForEach(0..<CatBlockGame.size, id: \.self) { row in
                ForEach(0..<CatBlockGame.size, id: \.self) { column in
                    cellView(row: row, column: column, cell: cell, preview: preview, highlight: highlight)
                        .offset(x: CGFloat(column) * cell, y: CGFloat(row) * cell)
                }
            }
            ForEach(bursts) { burst in
                CatBlockBurstView(burst: burst, cell: cell, reduceMotion: reduceMotion)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Board"))
        .accessibilityIdentifier("block.board")
    }

    @ViewBuilder
    private func cellView(row: Int, column: Int, cell: CGFloat,
                          preview: (piece: CatBlockPiece, row: Int, column: Int)?, highlight: Set<Int>) -> some View {
        let inset: CGFloat = cell * 0.04
        if let color = game[row, column] {
            // Tamamlanacak çizgideki bloklar parçanın rengine bürünüp parlar
            let lit = highlight.contains(row * CatBlockGame.size + column)
            CatBlockTile(color: lit ? (preview?.piece.color ?? color) : color, size: cell - inset * 2)
                .brightness(lit ? 0.12 : 0)
                .padding(inset)
        } else if let preview, preview.piece.shape.cells.contains(where: {
            preview.row + $0.row == row && preview.column + $0.column == column
        }) {
            CatBlockTile(color: preview.piece.color, size: cell - inset * 2, isGhost: true)
                .padding(inset)
        } else {
            RoundedRectangle(cornerRadius: cell * 0.16, style: .continuous)
                .fill(Color.white.opacity(theme.isDark ? 0.05 : 0.08))
                .frame(width: cell - inset * 2, height: cell - inset * 2)
                .padding(inset)
        }
    }

    // MARK: - Parçalar

    private func tray(cell: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<CatBlockGame.trayCount, id: \.self) { index in
                ZStack {
                    if let piece = game.tray[index], dragIndex != index {
                        let fits = game.canPlaceAnywhere(piece)
                        CatBlockPieceView(piece: piece, cell: cell * 0.56)
                            .opacity(fits ? 1 : 0.35)
                            .saturation(fits ? 1 : 0.3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(dragGesture(index))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Piece \(index + 1)"))
                .accessibilityIdentifier("block.piece.\(index)")
            }
        }
        .padding(.horizontal, 12)
    }

    private func dragGesture(_ index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard !isOver, !isPaused, game.tray.indices.contains(index), game.tray[index] != nil else { return }
                if dragIndex == nil {
                    dragIndex = index
                    Haptics.selection()
                }
                dragLocation = value.location
            }
            .onEnded { _ in
                guard let index = dragIndex else { return }
                let cell = boardFrame.width / CGFloat(CatBlockGame.size)
                if let target = previewPlacement(cell: cell) {
                    place(index: index, row: target.row, column: target.column)
                } else {
                    audio.play(.tap)
                }
                withAnimation(.spring(response: 0.3)) { dragIndex = nil }
            }
    }

    /// Sürüklenen parça: parmağın biraz üstünde, tahtadaki boyutunda.
    @ViewBuilder
    private func draggedPiece(cell: CGFloat) -> some View {
        if let index = dragIndex, let piece = game.tray[index] {
            let origin = pieceOrigin(piece, cell: cell)
            CatBlockPieceView(piece: piece, cell: cell)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                .offset(x: origin.x, y: origin.y)
                .allowsHitTesting(false)
        }
    }

    /// Parçanın sol üst köşesi: ortası parmakta, parmağın üstüne kaldırılmış.
    private func pieceOrigin(_ piece: CatBlockPiece, cell: CGFloat) -> CGPoint {
        let width = CGFloat(piece.shape.columns) * cell
        let height = CGFloat(piece.shape.rows) * cell
        return CGPoint(x: dragLocation.x - width / 2, y: dragLocation.y - height - cell * 1.1)
    }

    /// Sürüklenen parçanın bırakılırsa oturacağı yer (geçerliyse).
    private func previewPlacement(cell: CGFloat) -> (piece: CatBlockPiece, row: Int, column: Int)? {
        guard let index = dragIndex, let piece = game.tray[index], boardFrame.width > 0 else { return nil }
        let cell = boardFrame.width / CGFloat(CatBlockGame.size)
        let origin = pieceOrigin(piece, cell: cell)
        let column = Int(((origin.x - boardFrame.minX) / cell).rounded())
        let row = Int(((origin.y - boardFrame.minY) / cell).rounded())
        guard game.canPlace(piece, row: row, column: column) else { return nil }
        return (piece, row, column)
    }

    /// Parça bırakılırsa temizlenecek hücreler (parlatılır).
    private func linesToClear(piece: CatBlockPiece, row: Int, column: Int) -> Set<Int> {
        let size = CatBlockGame.size
        var filled = Set((0..<(size * size)).filter { game.cells[$0] != nil })
        for cell in piece.shape.cells { filled.insert((row + cell.row) * size + column + cell.column) }
        var result = Set<Int>()
        for r in 0..<size where (0..<size).allSatisfy({ filled.contains(r * size + $0) }) {
            for c in 0..<size { result.insert(r * size + c) }
        }
        for c in 0..<size where (0..<size).allSatisfy({ filled.contains($0 * size + c) }) {
            for r in 0..<size { result.insert(r * size + c) }
        }
        return result
    }

    // MARK: - Oyun

    private func place(index: Int, row: Int, column: Int) {
        var next = game
        guard let placement = next.place(trayIndex: index, row: row, column: column) else { return }
        withAnimation(.spring(response: 0.25)) { game = next }
        if placement.lineCount > 0 {
            audio.play(placement.combo >= 2 || placement.lineCount >= 2 ? .combo : .line)
            Haptics.play(.lineCompleted)
            let burst = CatBlockBurst(cells: placement.clearedCells)
            bursts.append(burst)
            Task {
                try? await Task.sleep(for: .seconds(0.7))
                bursts.removeAll { $0.id == burst.id }
            }
            showPopup(CatBlockPopup(points: placement.points, combo: placement.combo, lines: placement.lineCount,
                                    boardCleared: placement.boardCleared))
        } else {
            audio.play(.fill)
            Haptics.selection()
        }
        if !shownNewBestBanner, startingBest > 0, game.score > startingBest {
            shownNewBestBanner = true
            isNewBest = true
            audio.play(.fanfare)
            showPopup(CatBlockPopup(points: 0, combo: 0, lines: 0, boardCleared: false, isNewBest: true))
        }
        if game.isOver {
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                finish()
            }
        }
    }

    private func showPopup(_ value: CatBlockPopup) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { popup = value }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            if popup?.id == value.id { withAnimation(.easeOut(duration: 0.3)) { popup = nil } }
        }
    }

    private func finish() {
        guard !isOver else { return }
        audio.play(.failed)
        Haptics.play(.failed)
        withAnimation(.default) { shake += 1 }
        isNewBest = game.score > startingBest && game.score > 0
        blocks.report(score: game.score)
        model.reportToGameCenter()
        isOver = true
    }

    /// Oyun bitti: tahtayı bir kez silip devam (Premium'da ücretsiz, değilse reklamla).
    private func clearBoardAndContinue() {
        if store.isPremium {
            continueAfterClear()
        } else {
            Task {
                if await ads.watchRewardedAd() { continueAfterClear() }
            }
        }
    }

    private func continueAfterClear() {
        var next = game
        let cleared = next.clearBoard()
        guard !cleared.isEmpty else { return }
        audio.play(.card)
        let burst = CatBlockBurst(cells: cleared)
        bursts.append(burst)
        withAnimation(.spring(response: 0.35)) {
            game = next
            isOver = false
        }
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    private func newGame() {
        blocks.recordFinishedGame(score: game.score)
        isDiscarded = true
        ads.puzzleCompleted(isTutorial: false)
        ads.continueAfterPuzzle {
            router.replaceTop(with: .blockGame(UUID().uuidString))
        }
    }

    private func leave() {
        if isOver {
            blocks.recordFinishedGame(score: game.score)
            isDiscarded = true
            ads.puzzleCompleted(isTutorial: false)
            ads.continueAfterPuzzle { router.pop() }
        } else {
            router.pop()
        }
    }

    /// Çıkarken: süren oyun kaydedilir, biten oyun kayda geçer.
    private func saveProgress() {
        guard !isDiscarded else { return }
        if isOver || game.isOver {
            blocks.recordFinishedGame(score: game.score)
            isDiscarded = true
        } else if game.piecesPlaced > 0 {
            blocks.report(score: game.score)
            blocks.saveGame(game)
        }
    }

    // MARK: - Kartlar

    @ViewBuilder
    private var overlays: some View {
        if isPaused && !isOver {
            ModePauseOverlay(
                onContinue: { isPaused = false },
                onRestart: {
                    isPaused = false
                    isDiscarded = true
                    blocks.report(score: game.score)
                    blocks.clearSavedGame()
                    router.replaceTop(with: .blockGame(UUID().uuidString))
                },
                onMap: { router.pop() },
                leaveTitle: "Home",
                leaveIcon: "house.fill"
            )
            .transition(.opacity)
        } else if isOver {
            CatBlockGameOverOverlay(
                score: game.score,
                best: max(blocks.bestScore, game.score),
                isNewBest: isNewBest,
                canClearBoard: !game.usedBoardClear,
                isPremium: store.isPremium,
                canWatchAd: ads.isRewardedReady,
                onClearBoard: clearBoardAndContinue,
                onPlayAgain: newGame,
                onHome: leave
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

/// Tepsideki ya da sürüklenen parça.
struct CatBlockPieceView: View {
    let piece: CatBlockPiece
    let cell: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(piece.shape.cells.enumerated()), id: \.offset) { _, square in
                CatBlockTile(color: piece.color, size: cell * 0.94)
                    .offset(x: CGFloat(square.column) * cell + cell * 0.03, y: CGFloat(square.row) * cell + cell * 0.03)
            }
        }
        .frame(width: CGFloat(piece.shape.columns) * cell, height: CGFloat(piece.shape.rows) * cell, alignment: .topLeading)
    }
}

/// Temizlenen blokların parlayıp dağılması.
struct CatBlockBurst: Identifiable {
    let id = UUID()
    let cells: [CatBlockCell]
    let start = Date()
}

struct CatBlockBurstView: View {
    let burst: CatBlockBurst
    let cell: CGFloat
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = min(1, context.date.timeIntervalSince(burst.start) / 0.6)
            ZStack(alignment: .topLeading) {
                ForEach(burst.cells, id: \.self) { square in
                    CatBlockTile(color: square.color, size: cell * 0.92)
                        .brightness(0.25 * (1 - t))
                        .scaleEffect(reduceMotion ? 1 : 1 + t * 0.35)
                        .opacity(1 - t)
                        .offset(x: CGFloat(square.column) * cell + cell * 0.04, y: CGFloat(square.row) * cell + cell * 0.04)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Puan ve kombo yazısı.
struct CatBlockPopup: Equatable {
    let id = UUID()
    let points: Int
    let combo: Int
    let lines: Int
    let boardCleared: Bool
    var isNewBest = false
}

struct CatBlockPopupView: View {
    let popup: CatBlockPopup

    var body: some View {
        VStack(spacing: 0) {
            if popup.isNewBest {
                Label("New Best!", systemImage: "crown.fill")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Gold.foil)
            } else {
                if popup.boardCleared {
                    Text("Clean Sweep!")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: "#EC6A8F"))
                } else if popup.combo >= 2 {
                    Text("Combo \(popup.combo)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: "#9A7BE0"))
                }
                Text(verbatim: "+\(popup.points)")
                    .font(.headline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color(hex: "#F09A4A"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.92)).shadow(color: .black.opacity(0.15), radius: 6, y: 3))
        .allowsHitTesting(false)
    }
}

/// Oyun bitti kartı: puan, en yüksek puan, bir kez tahtayı silip devam, yeniden oyna.
struct CatBlockGameOverOverlay: View {
    @Environment(\.appTheme) private var theme
    let score: Int
    let best: Int
    let isNewBest: Bool
    let canClearBoard: Bool
    let isPremium: Bool
    let canWatchAd: Bool
    let onClearBoard: () -> Void
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                if isNewBest {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Gold.foil)
                    Text("New Best!")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("No Room Left")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(theme.textPrimary)
                }
                Text(verbatim: "\(score)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(ModeStyle.block.ink(theme))
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").foregroundStyle(Gold.mid)
                    Text("Best Score")
                    Text(verbatim: "\(best)")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                VStack(spacing: 10) {
                    if canClearBoard {
                        Button(action: onClearBoard) {
                            Label(isPremium ? LocalizedStringKey("Clear the Board") : LocalizedStringKey("Clear the Board (Video)"),
                                  systemImage: isPremium ? "sparkles" : "play.rectangle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isPremium && !canWatchAd)
                        .accessibilityIdentifier("block.clearBoard")
                        Text("Once per game: the board empties and you keep your score.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.textSecondary)
                    }
                    if canClearBoard {
                        Button(action: onPlayAgain) {
                            Label("Play Again", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("block.playAgain")
                    } else {
                        Button(action: onPlayAgain) {
                            Label("Play Again", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("block.playAgain")
                    }
                    Button(action: onHome) {
                        Label("Home", systemImage: "house.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("block.home")
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 380)
            .card()
            .padding(.horizontal, 24)
        }
    }
}

/// Oyun bitince tahta hafifçe sallanır.
struct CatBlockShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}
