import NonogramKit
import SwiftUI

/// Patinin tahtada gösterdiği hareket: `from == to` ise tek dokunuş, değilse kaydırma.
struct PointerPath: Equatable {
    var from: GridPosition
    var to: GridPosition

    var isTap: Bool { from == to }
}

/// Eğitimde Muffin'in gösterdiği tek hamle: önce doğru araç seçilir, sonra pati
/// satırı/sütunu kaydırarak ya da kareye dokunarak gösterir.
struct TutorialStep {
    enum Gesture: Equatable {
        /// Pati satır/sütun boyunca baştan sona kayar.
        case swipe
        /// Pati sıradaki boş kareye dokunur.
        case tap
    }

    let tool: MarkTool
    let gesture: Gesture
    /// Adım, bu karelerin hiçbiri boş kalmayınca biter (otomatik X/doldurma da sayılır).
    let cells: [GridPosition]
    let highlight: HintFinder.Hint?
    /// Bu adımdan itibaren Muffin'in söylediği (yoksa dersin ana metni).
    var message: LocalizedStringResource?

    func isDone(on board: Matrix<CellState>) -> Bool {
        cells.allSatisfy { board[$0] != .blank }
    }

    /// Patinin gösterdiği hareket; dokunmada sıradaki boş kare.
    func pointer(on board: Matrix<CellState>) -> PointerPath? {
        switch gesture {
        case .swipe:
            guard let first = cells.first, let last = cells.last else { return nil }
            return PointerPath(from: first, to: last)
        case .tap:
            return cells.first { board[$0] == .blank }.map { PointerPath(from: $0, to: $0) }
        }
    }

    static func swipeRow(_ row: Int, columns: Int, tool: MarkTool, message: LocalizedStringResource? = nil) -> TutorialStep {
        TutorialStep(
            tool: tool,
            gesture: .swipe,
            cells: (0..<columns).map { GridPosition(row: row, column: $0) },
            highlight: HintFinder.Hint(axis: .row, index: row, newCells: 0),
            message: message
        )
    }

    static func swipeColumn(_ column: Int, rows: Int, tool: MarkTool, message: LocalizedStringResource? = nil) -> TutorialStep {
        TutorialStep(
            tool: tool,
            gesture: .swipe,
            cells: (0..<rows).map { GridPosition(row: $0, column: column) },
            highlight: HintFinder.Hint(axis: .column, index: column, newCells: 0),
            message: message
        )
    }

    /// Satırın çözümde dolu olan karelerine tek tek dokunma.
    static func tapFilled(inRow row: Int, of puzzle: Puzzle, message: LocalizedStringResource? = nil) -> TutorialStep {
        TutorialStep(
            tool: .fill,
            gesture: .tap,
            cells: (0..<puzzle.columns).map { GridPosition(row: row, column: $0) }.filter { puzzle.solution[$0] },
            highlight: HintFinder.Hint(axis: .row, index: row, newCells: 0),
            message: message
        )
    }
}

/// İlk derslerin adım adım senaryosu. Sonraki derslerde pati ve vurgu yok: oyuncu kendisi çözer.
struct TutorialScript {
    let steps: [TutorialStep]
    /// "Kolay" modda X'ler tamamlanınca kalan karelerin kendiliğinden dolması. Bazı derslerde
    /// kapalı ki oyuncu gösterilen kareleri kendisi doldursun.
    var autoFills = true

    /// Otomatik doldurma yalnızca son adımda: ders, gösterilen bütün adımlar bitmeden
    /// kendiliğinden tamamlanmasın.
    func autoFills(on board: Matrix<CellState>) -> Bool {
        guard autoFills else { return false }
        guard let index = steps.firstIndex(where: { !$0.isDone(on: board) }) else { return true }
        return index == steps.count - 1
    }

    /// Sıradaki (bitmemiş) adım; ders bitince `nil`.
    func currentStep(on board: Matrix<CellState>) -> TutorialStep? {
        steps.first { !$0.isDone(on: board) }
    }

    /// Muffin'in o an söylediği: geçilen ya da sıradaki adımların en sonuncusunun metni.
    func message(on board: Matrix<CellState>) -> LocalizedStringResource? {
        let index = steps.firstIndex { !$0.isDone(on: board) } ?? steps.count - 1
        guard index >= 0 else { return nil }
        return steps[...index].last { $0.message != nil }?.message
    }

    static func script(for lesson: TutorialLesson, puzzle: Puzzle) -> TutorialScript? {
        let rows = puzzle.rows
        let columns = puzzle.columns
        switch lesson {
        case .firstSquare:
            // "a." — tek kareye dokun
            return TutorialScript(steps: [
                TutorialStep(
                    tool: .fill,
                    gesture: .tap,
                    cells: [GridPosition(row: 0, column: 0)],
                    highlight: HintFinder.Hint(axis: .row, index: 0, newCells: 0)
                ),
            ])
        case .tapToFill:
            // Kutu: kenarlardaki 0 satır/sütunlar X'lenir, içi "Kolay" modda kendiliğinden dolar
            return TutorialScript(steps: [
                TutorialStep.swipeRow(0, columns: columns, tool: .cross),
                TutorialStep.swipeColumn(0, rows: rows, tool: .cross),
                TutorialStep.swipeRow(rows - 1, columns: columns, tool: .cross),
                TutorialStep.swipeColumn(columns - 1, rows: rows, tool: .cross),
            ])
        case .fullLines:
            // Pencere: önce tam dolu satırlar, sonra tam dolu sütunlar
            let fullRows = (0..<rows).filter { puzzle.rowClues[$0] == [columns] }
            let fullColumns = (0..<columns).filter { puzzle.columnClues[$0] == [rows] }
            let rowSteps = fullRows.map { TutorialStep.swipeRow($0, columns: columns, tool: .fill) }
            let columnSteps = fullColumns.map { TutorialStep.swipeColumn($0, rows: rows, tool: .fill) }
            return TutorialScript(steps: rowSteps + columnSteps)
        case .emptyLines:
            // Balık: 0 satırlar X, tam dolu satır, sonra "2 1" satırları
            let emptyRows = (0..<rows).filter { puzzle.rowClues[$0].isEmpty }
            let fullRows = (0..<rows).filter { puzzle.rowClues[$0] == [columns] }
            let otherRows = (0..<rows).filter { !emptyRows.contains($0) && !fullRows.contains($0) }
            let fullMessage: LocalizedStringResource = "5 means the whole row is full. Pick Fill and swipe!"
            let blocksMessage: LocalizedStringResource = "2 1 means: 2 squares together, a gap, then 1. Tap where I point."
            var steps = emptyRows.map { TutorialStep.swipeRow($0, columns: columns, tool: .cross) }
            for (index, row) in fullRows.enumerated() {
                steps.append(TutorialStep.swipeRow(row, columns: columns, tool: .fill, message: index == 0 ? fullMessage : nil))
            }
            for (index, row) in otherRows.enumerated() {
                steps.append(TutorialStep.tapFilled(inRow: row, of: puzzle, message: index == 0 ? blocksMessage : nil))
            }
            return TutorialScript(steps: steps, autoFills: false)
        default:
            return nil
        }
    }
}

extension TutorialLesson {
    /// Senaryosuz derslerde sıradaki çözülebilir satır/sütun parlasın mı?
    var highlightsNextLine: Bool {
        switch self {
        case .multipleBlocks, .overlap, .edges, .crossReference: true
        default: false
        }
    }

    /// Zorluk dersine kadar zorluk değiştirilemez, eğitim "Kolay" modda oynanır.
    var locksEasyMode: Bool {
        let all = TutorialLesson.allCases
        guard let index = all.firstIndex(of: self), let difficulty = all.firstIndex(of: .difficulty) else { return false }
        return index < difficulty
    }
}

/// Eğitim patisi: dokunmada yerinde zıplar, kaydırmada satır boyunca tekrar tekrar kayar.
/// Tahtanın üstünde hep durur (dokunmayı engellemez), yalnızca görünürlüğü değişir.
struct GuidePaw: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var path: PointerPath?
    let cell: CGFloat

    private static let cycle: TimeInterval = 1.9

    var body: some View {
        let isAnimating = path.map { !$0.isTap } == true && !reduceMotion
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            let phase = isAnimating ? Self.phase(at: timeline.date) : (progress: 0.0, fade: 1.0)
            let point = location(progress: phase.progress)
            PawPointer(bobs: path?.isTap ?? true)
                .opacity(phase.fade)
                .offset(x: point.x, y: point.y)
        }
        .opacity(path == nil ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func location(progress: Double) -> CGPoint {
        let from = path?.from ?? GridPosition(row: 0, column: 0)
        let to = path?.to ?? from
        let column = Double(from.column) + Double(to.column - from.column) * progress
        let row = Double(from.row) + Double(to.row - from.row) * progress
        return CGPoint(x: column * cell + cell * 0.45, y: row * cell + cell * 0.5)
    }

    /// Bir tur: başta kısa bekleme, yumuşak kayma, sonda bekleyip kaybolma.
    private static func phase(at date: Date) -> (progress: Double, fade: Double) {
        let time = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        switch time {
        case ..<0.3:
            return (0, min(time / 0.2, 1))
        case ..<1.4:
            let t = (time - 0.3) / 1.1
            return (t * t * (3 - 2 * t), 1)
        default:
            return (1, max(1 - (time - 1.4) / 0.4, 0))
        }
    }
}
