import NonogramKit
import SwiftUI

/// Tamamlanan satır/sütunun parıltısı (Dopamin modu).
struct LineGlow: Equatable {
    static let duration: TimeInterval = 0.6
    var row: Int?
    var column: Int?
    var start: Date
}

/// İpuçları + tahta. Kareler tek bir `Canvas` ile çizilir; 20x20'de 400 ayrı View yerine
/// tek çizim, sürüklemede akıcı kalır.
@MainActor
struct BoardView: View {
    @Environment(\.appTheme) private var theme

    let game: NonogramGame
    var activeCell: GridPosition?
    /// Kısa süreliğine kırmızı yanıp sönen hatalı kare.
    var flashingCell: GridPosition?
    /// Kedinin "şuna bak" dediği satır ya da sütun.
    var hint: HintFinder.Hint?
    /// Eğitimde patinin gösterdiği dokunuş ya da kaydırma.
    var pointer: PointerPath?
    /// Dopamin modu: az önce tamamlanan satır/sütunun kısa parıltısı.
    var lineGlow: LineGlow?
    /// Büyük tahtalarda imleç ve paneli (`nil`: doğrudan dokunarak oynanır).
    var cursor: BoardCursorControls?
    let onDragBegan: (GridPosition) -> Void
    let onDragMoved: (GridPosition) -> Void
    let onDragEnded: () -> Void

    /// Büyük tahtalarda yakınlaştırma durumu (her bulmaca için yeni).
    @State private var zoom = BoardZoom()

    private var puzzle: Puzzle { game.puzzle }
    /// Yakınlaştırma şimdilik kapalı: büyük tahta da ekrana tamamen sığar
    /// (oyuncu denemesinden sonra yeniden açılabilir: `max(rows, columns) > 10`).
    private var isZoomable: Bool { false }
    private var isSolved: Bool { game.status == .won }

    var body: some View {
        GeometryReader { proxy in
            let rowClueSlots = max(puzzle.rowClues.map(\.count).max() ?? 1, 1)
            let columnClueSlots = max(puzzle.columnClues.map(\.count).max() ?? 1, 1)
            let cell = max(floor(min(
                proxy.size.width / CGFloat(puzzle.columns + rowClueSlots),
                proxy.size.height / CGFloat(puzzle.rows + columnClueSlots)
            )), 1)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    Color.clear.frame(width: cell * CGFloat(rowClueSlots), height: cell * CGFloat(columnClueSlots))
                    if isZoomable {
                        // Yakınlaşınca sütun ipuçları yerinde kalır, tahtayla birlikte yatay kayar
                        PannedStrip(zoom: zoom, axis: .horizontal, fitCell: cell) { screenCell in
                            columnClues(width: screenCell, height: cell)
                        }
                        .frame(width: cell * CGFloat(puzzle.columns), height: cell * CGFloat(columnClueSlots), alignment: .bottomLeading)
                        .clipped()
                    } else {
                        columnClues(width: cell, height: cell)
                    }
                }
                HStack(alignment: .top, spacing: 0) {
                    if isZoomable {
                        PannedStrip(zoom: zoom, axis: .vertical, fitCell: cell) { screenCell in
                            rowClues(width: cell, height: screenCell, slots: rowClueSlots)
                        }
                        .frame(width: cell * CGFloat(rowClueSlots), height: cell * CGFloat(puzzle.rows), alignment: .topLeading)
                        .clipped()
                        // Tek parmak boyar; iki parmak yakınlaştırır ve kaydırır
                        ZoomableBoard(zoom: zoom, fitSize: CGSize(width: cell * CGFloat(puzzle.columns), height: cell * CGFloat(puzzle.rows))) {
                            canvas(cell: cell * BoardZoom.maxScale)
                        }
                        .frame(width: cell * CGFloat(puzzle.columns), height: cell * CGFloat(puzzle.rows))
                        .overlay(alignment: .topTrailing) {
                            ZoomResetButton(zoom: zoom)
                                .padding(6)
                        }
                    } else {
                        rowClues(width: cell, height: cell, slots: rowClueSlots)
                        canvas(cell: cell)
                            // İmleç paneli tahtanın üstünde, tahtanın dokunma alanının dışında bir katman
                            .overlay(alignment: .topLeading) {
                                if let cursor, cursor.showsPad, !isSolved, game.status == .playing {
                                    CursorPad(controls: cursor, cell: cell, rows: puzzle.rows, columns: puzzle.columns)
                                }
                            }
                    }
                }
            }
            .opacity(isSolved ? 0 : 1)
            // Çözülünce tahta kaybolur; renkli resim sonuç kartıyla birlikte gelir (GameView)
            .animation(.spring(duration: 0.7), value: isSolved)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Tahta

    private func canvas(cell: CGFloat) -> BoardCanvas {
        BoardCanvas(
            game: game,
            cell: cell,
            theme: theme,
            activeCell: activeCell,
            flashingCell: flashingCell,
            hint: hint,
            pointer: pointer,
            lineGlow: lineGlow,
            cursorCell: cursor?.position,
            onDragBegan: onDragBegan,
            onDragMoved: onDragMoved,
            onDragEnded: onDragEnded
        )
    }

    // MARK: - İpuçları

    private func columnClues(width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<puzzle.columns, id: \.self) { column in
                VStack(spacing: 0) {
                    ForEach(clueTexts(puzzle.columnClues[column]), id: \.self) { text in
                        clueLabel(text, width: width, height: height)
                    }
                }
                .frame(width: width)
                .background(clueBackground(isActive: activeCell?.column == column, isHinted: isHinted(.column, column)))
                .foregroundStyle(clueColor(isSatisfied: game.isColumnSatisfied(column)))
            }
        }
    }

    private func rowClues(width: CGFloat, height: CGFloat, slots: Int) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<puzzle.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(clueTexts(puzzle.rowClues[row]), id: \.self) { text in
                        clueLabel(text, width: width, height: height)
                    }
                }
                .frame(width: width * CGFloat(slots), height: height, alignment: .trailing)
                .background(clueBackground(isActive: activeCell?.row == row, isHinted: isHinted(.row, row)))
                .foregroundStyle(clueColor(isSatisfied: game.isRowSatisfied(row)))
            }
        }
    }

    private func clueColor(isSatisfied: Bool) -> Color {
        isSatisfied ? theme.textSecondary.opacity(0.45) : theme.textPrimary
    }

    private func clueBackground(isActive: Bool, isHinted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isHinted ? theme.accent.opacity(0.3) : (isActive ? theme.highlight : .clear))
    }

    private func isHinted(_ axis: HintFinder.Axis, _ index: Int) -> Bool {
        hint?.axis == axis && hint?.index == index
    }

    /// Aynı sayı tekrar edebildiği için konumla birlikte benzersiz kimlik üretilir.
    private func clueTexts(_ clue: [Int]) -> [String] {
        let numbers = clue.isEmpty ? [0] : clue
        return numbers.enumerated().map { "\($0.offset):\($0.element)" }
    }

    private func clueLabel(_ text: String, width: CGFloat, height: CGFloat) -> some View {
        Text(verbatim: String(text.split(separator: ":").last ?? ""))
            .font(.system(size: min(min(width, height) * 0.6, 22), weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .frame(width: width, height: height)
    }
}

/// Tahtanın kareleri: tek `Canvas` ve tek parmakla boyama. Büyük tahtalarda
/// yakınlaştırılabilir kaydırma görünümünün içinde, büyük ölçekte çizilir.
@MainActor
struct BoardCanvas: View {
    let game: NonogramGame
    let cell: CGFloat
    let theme: AppTheme
    var activeCell: GridPosition?
    var flashingCell: GridPosition?
    var hint: HintFinder.Hint?
    var pointer: PointerPath?
    var lineGlow: LineGlow?
    var cursorCell: GridPosition?
    let onDragBegan: (GridPosition) -> Void
    let onDragMoved: (GridPosition) -> Void
    let onDragEnded: () -> Void

    @State private var isDragging = false
    @GestureState private var isTouching = false

    var body: some View {
        board(cell: cell)
            .onChange(of: isTouching) { _, touching in
                guard !touching, isDragging else { return }
                isDragging = false
                onDragEnded()
            }
    }

    private func board(cell: CGFloat) -> some View {
        let board = game.board
        let theme = theme
        let activeCell = activeCell
        let flashingCell = flashingCell
        let hint = hint
        let lineGlow = lineGlow
        let cursorCell = cursorCell

        // Parıltı yalnızca varken zaman çizelgesi işler; yoksa duraklar
        return TimelineView(.animation(paused: lineGlow == nil)) { timeline in
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.surface))

            if let active = activeCell {
                let rowRect = CGRect(x: 0, y: CGFloat(active.row) * cell, width: size.width, height: cell)
                let columnRect = CGRect(x: CGFloat(active.column) * cell, y: 0, width: cell, height: size.height)
                context.fill(Path(rowRect), with: .color(theme.highlight))
                context.fill(Path(columnRect), with: .color(theme.highlight))
            }

            for position in board.positions {
                let rect = CGRect(
                    x: CGFloat(position.column) * cell,
                    y: CGFloat(position.row) * cell,
                    width: cell,
                    height: cell
                )
                switch board[position] {
                case .filled:
                    let inset = rect.insetBy(dx: cell * 0.06, dy: cell * 0.06)
                    context.fill(Path(roundedRect: inset, cornerRadius: cell * 0.16), with: .color(theme.cellFilled))
                case .crossed:
                    var cross = Path()
                    let inset = rect.insetBy(dx: cell * 0.3, dy: cell * 0.3)
                    cross.move(to: inset.origin)
                    cross.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
                    cross.move(to: CGPoint(x: inset.maxX, y: inset.minY))
                    cross.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
                    context.stroke(
                        cross,
                        with: .color(theme.cellCross),
                        style: StrokeStyle(lineWidth: max(cell * 0.07, 1.2), lineCap: .round)
                    )
                case .blank:
                    break
                }
            }
            // Hatalı kare de Canvas içinde çizilir (ayrı görünüm eklenmez)
            if let flashing = flashingCell {
                let rect = CGRect(
                    x: CGFloat(flashing.column) * cell,
                    y: CGFloat(flashing.row) * cell,
                    width: cell,
                    height: cell
                )
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.16), with: .color(theme.mistake.opacity(0.55)))
            }
            BoardCanvas.drawGridLines(in: context, size: size, cell: cell, rows: board.rows, columns: board.columns, theme: theme)
            // İpucu çizgisi en üstte, kalın bir çerçeveyle
            if let hint {
                let rect = hint.axis == .row
                    ? CGRect(x: 0, y: CGFloat(hint.index) * cell, width: size.width, height: cell)
                    : CGRect(x: CGFloat(hint.index) * cell, y: 0, width: cell, height: size.height)
                let frame = Path(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: cell * 0.2)
                context.fill(frame, with: .color(theme.accent.opacity(0.12)))
                context.stroke(frame, with: .color(theme.accent), lineWidth: 3)
            }
            // İmleç: kalın, belirgin çerçeve
            if let cursorCell {
                let rect = CGRect(
                    x: CGFloat(cursorCell.column) * cell,
                    y: CGFloat(cursorCell.row) * cell,
                    width: cell,
                    height: cell
                ).insetBy(dx: 1, dy: 1)
                let frame = Path(roundedRect: rect, cornerRadius: cell * 0.18)
                context.fill(frame, with: .color(theme.accent.opacity(0.18)))
                context.stroke(frame, with: .color(theme.textPrimary), lineWidth: max(cell * 0.12, 2.5))
            }
            if let glow = lineGlow {
                let age = timeline.date.timeIntervalSince(glow.start)
                if age >= 0, age < LineGlow.duration {
                    let fade = 1 - age / LineGlow.duration
                    var rects: [CGRect] = []
                    if let row = glow.row { rects.append(CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)) }
                    if let column = glow.column { rects.append(CGRect(x: CGFloat(column) * cell, y: 0, width: cell, height: size.height)) }
                    for rect in rects {
                        // Satır boyunca soldan sağa (sütunda yukarıdan aşağı) kayan ışık
                        let sweep = age / LineGlow.duration
                        let path = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: cell * 0.2)
                        context.fill(path, with: .color(Gold.bright.opacity(0.35 * fade)))
                        context.stroke(path, with: .color(Gold.mid.opacity(fade)), lineWidth: 3)
                        let spot = rect.width > rect.height
                            ? CGPoint(x: rect.minX + rect.width * sweep, y: rect.midY)
                            : CGPoint(x: rect.midX, y: rect.minY + rect.height * sweep)
                        let radius = cell * 0.45
                        context.fill(Path(ellipseIn: CGRect(x: spot.x - radius, y: spot.y - radius, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(0.7 * fade)))
                    }
                }
            }
        }
        }
        .frame(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // Pati hep hiyerarşide durur (yalnızca görünürlüğü değişir); dokunmayı engellemez
        .overlay(alignment: .topLeading) {
            GuidePaw(path: pointer, cell: cell)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(cell: cell))
        .accessibilityElement()
        .accessibilityLabel(Text("Puzzle board"))
        .accessibilityIdentifier("game.board")
        .accessibilityValue(Text(game.progress, format: .percent.precision(.fractionLength(0))))
    }

    /// Her 5 karede bir kalın çizgi: büyük tahtalarda saymayı kolaylaştırır.
    static func drawGridLines(
        in context: GraphicsContext,
        size: CGSize,
        cell: CGFloat,
        rows: Int,
        columns: Int,
        theme: AppTheme
    ) {
        func stroke(from start: CGPoint, to end: CGPoint, major: Bool) {
            var line = Path()
            line.move(to: start)
            line.addLine(to: end)
            context.stroke(line, with: .color(major ? theme.gridLineMajor : theme.gridLine), lineWidth: major ? 1.25 : 0.6)
        }
        // Önce ince, sonra kalın çizgiler: kesişimlerde kalın olan üstte kalsın
        for major in [false, true] {
            for index in 0...columns where (index % 5 == 0 || index == columns) == major {
                let x = CGFloat(index) * cell
                stroke(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: size.height), major: major)
            }
            for index in 0...rows where (index % 5 == 0 || index == rows) == major {
                let y = CGFloat(index) * cell
                stroke(from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y), major: major)
            }
        }
    }

    /// Dokunma da sıfır mesafeli sürükleme olarak işlenir, böylece tek bir yol kalır.
    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            // İki parmakla yakınlaştırma başlayınca sürükleme iptal olur (onEnded gelmez);
            // GestureState sıfırlanınca sürükleme yine de bitirilir
            .updating($isTouching) { _, state, _ in state = true }
            .onChanged { value in
                guard value.location.x >= 0, value.location.y >= 0 else { return }
                let position = GridPosition(row: Int(value.location.y / cell), column: Int(value.location.x / cell))
                if isDragging {
                    onDragMoved(position)
                } else {
                    isDragging = true
                    onDragBegan(position)
                }
            }
            .onEnded { _ in
                isDragging = false
                onDragEnded()
            }
    }

}
