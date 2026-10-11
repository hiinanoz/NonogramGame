import Foundation
import NonogramKit

/// Ses ve titreşim için arayüze bildirilen olaylar.
enum GameEvent: Equatable {
    case filled
    case crossed
    case erased
    case mistake
    case lineCompleted
    case solved
    case failed
}

/// Tamamlanan satır/sütun. `serial` her yeni tamamlamada artar (aynı satır tekrar parlasın diye).
struct CompletedLines: Equatable {
    var row: Int?
    var column: Int?
    var serial = 0
}

/// Oyun ekranının durumu. Kurallar `NonogramGame`'de; burası yalnızca arayüz akışını
/// (seçili araç, sürükleme, zamanlayıcı, bitiş bildirimi) yönetir.
@MainActor
@Observable
final class GameViewModel {
    private(set) var game: NonogramGame
    var tool: MarkTool = .fill
    /// Son hatalı kare; arayüz kısa bir kırmızı yanıp sönme ve titreşim için kullanır.
    private(set) var lastMistake: GridPosition?
    /// Parmağın altındaki kare; satırı ve sütunu vurgulanır.
    private(set) var activeCell: GridPosition?
    /// Son hamleyle tamamlanan satır ve/veya sütun (Dopamin modunda parıldar).
    private(set) var completedLines = CompletedLines()

    /// Bulmaca çözülünce çağrılır (ilerleme kaydı, reklam sayacı).
    var onSolved: ((PuzzleCompletion) -> Void)?
    /// Her anlamlı hamlede çağrılır (ses efektleri).
    var onEvent: ((GameEvent) -> Void)?

    private let rules: GameRules
    private var dragTarget: CellState?
    private var timerTask: Task<Void, Never>?
    private let now: () -> Date

    /// - Parameter savedGame: Yarım kalan oyun; varsa tahta, hatalar ve süre buradan devam eder.
    init(puzzle: Puzzle, rules: GameRules, savedGame: GameSnapshot? = nil, now: @escaping () -> Date = { Date() }) {
        self.game = savedGame.map { NonogramGame(puzzle: puzzle, rules: rules, restoring: $0) }
            ?? NonogramGame(puzzle: puzzle, rules: rules)
        self.rules = rules
        self.now = now
    }

    var puzzle: Puzzle { game.puzzle }
    var isFinished: Bool { game.status != .playing }

    /// Duraklatıldı: süre durur, tahta duraklatma menüsünün altında gizlenir.
    private(set) var isPaused = false

    /// Kaydedilecek yarım oyun. Bitmiş ya da hiç dokunulmamış oyunda `nil`:
    /// o durumda varsa eski kayıt silinmelidir.
    var snapshotToSave: GameSnapshot? {
        guard game.status == .playing else { return nil }
        let hasProgress = game.mistakes > 0 || game.board.storage.contains { $0 != .blank }
        return hasProgress ? game.snapshot : nil
    }

    // MARK: - Dokunma ve sürükleme

    func tap(_ position: GridPosition) {
        guard game.board.contains(position) else { return }
        let target: CellState = game.board[position] == .blank ? tool.cellState : .blank
        handle(game.toggle(at: position, with: tool), at: position, target: target)
    }

    /// Yardımlı kaydırma (varsayılan): sürükleme ilk karenin satırında ya da sütununda düz
    /// ilerler; parmak biraz kaysa da yalnızca o çizgi işaretlenir. Kapalıyken serbest kaydırma:
    /// parmağın geçtiği her kare (çapraz dahil) işaretlenir.
    var assistedDrag = true
    private var dragStart: GridPosition?
    private var dragAxis: HintFinder.Axis?
    private var dragLast: GridPosition?

    /// Sürüklemenin ilk karesi hedefi belirler: boş kareden başlanırsa aracın işareti
    /// konur, işaretli kareden başlanırsa geçilen aynı işaretler silinir.
    func dragBegan(at position: GridPosition) {
        guard game.board.contains(position) else { return }
        let current = game.board[position]
        dragTarget = current == .blank ? tool.cellState : (current == tool.cellState ? .blank : nil)
        dragStart = position
        dragAxis = nil
        dragLast = position
        apply(at: position)
    }

    func dragMoved(to position: GridPosition) {
        guard game.board.contains(position) else { return }
        guard assistedDrag, let start = dragStart else {
            apply(at: position)
            return
        }
        if position == start {
            // Başlangıç karesine dönünce yön yeniden seçilebilir
            dragAxis = nil
            dragLast = start
            apply(at: start)
            return
        }
        if dragAxis == nil {
            let rowDelta = abs(position.row - start.row)
            let columnDelta = abs(position.column - start.column)
            dragAxis = columnDelta >= rowDelta ? .row : .column
        }
        // Parmak çizgiden sapsa da hedef, başlangıcın satırına/sütununa izdüşürülür
        let target = dragAxis == .row
            ? GridPosition(row: start.row, column: position.column)
            : GridPosition(row: position.row, column: start.column)
        let from = dragLast ?? start
        // Hızlı kaydırmada atlanan kareler de sırayla işaretlenir
        for cell in Self.cells(from: from, to: target) where cell != from {
            apply(at: cell)
            if isFinished { break }
        }
        dragLast = target
    }

    /// Aynı satır ya da sütundaki iki kare arasındaki kareler (ikisi dahil, sırayla).
    static func cells(from: GridPosition, to: GridPosition) -> [GridPosition] {
        if from.row == to.row {
            let step = to.column >= from.column ? 1 : -1
            return stride(from: from.column, through: to.column, by: step).map { GridPosition(row: from.row, column: $0) }
        }
        if from.column == to.column {
            let step = to.row >= from.row ? 1 : -1
            return stride(from: from.row, through: to.row, by: step).map { GridPosition(row: $0, column: from.column) }
        }
        return [to]
    }

    private func apply(at position: GridPosition) {
        // Aynı karede sürüklerken gözlemcileri boşuna tetikleme
        if !isFinished, activeCell != position { activeCell = position }
        guard let target = dragTarget else { return }
        let current = game.board[position]
        // Silerken yalnızca aynı işaretleri, koyarken yalnızca boş kareleri etkile
        let applies = target == .blank ? current == tool.cellState : current == .blank
        guard applies else { return }
        handle(game.mark(target, at: position), at: position, target: target)
        if isFinished {
            dragTarget = nil
            activeCell = nil
        }
    }

    func dragEnded() {
        dragTarget = nil
        dragStart = nil
        dragAxis = nil
        dragLast = nil
        if activeCell != nil { activeCell = nil }
    }

    func undo() {
        game.undo()
    }

    // MARK: - İmleç (10x10'dan büyük tahtalar)

    /// İmlecin bulunduğu kare. Küçük karelere parmakla isabet etmek zor olduğundan büyük
    /// bulmacalarda oyuncu kareyi seçer, sonra imleç panelindeki Doldur/X ile işaretler.
    private(set) var cursor = GridPosition(row: 0, column: 0)
    /// Kilitli araç: imleç hareket ettikçe geçtiği karelere bu işaret konur.
    private(set) var cursorLock: MarkTool?
    /// Kilitliyken imleç yalnızca tek satırda ya da sütunda ilerler (ilk harekette belirlenir).
    private var cursorAxis: HintFinder.Axis?

    /// Kareye dokunma ya da imleç panelindeki taşıma: imleç oraya gider. Kilitliyse
    /// aradaki tüm kareler sırayla işaretlenir.
    func moveCursor(to target: GridPosition) {
        guard !isFinished else { return }
        var target = GridPosition(
            row: min(max(target.row, 0), puzzle.rows - 1),
            column: min(max(target.column, 0), puzzle.columns - 1)
        )
        guard target != cursor else { return }
        guard cursorLock != nil else {
            cursor = target
            return
        }
        if cursorAxis == nil {
            cursorAxis = abs(target.row - cursor.row) > abs(target.column - cursor.column) ? .column : .row
        }
        // Kilitli eksende kal
        if cursorAxis == .row {
            target = GridPosition(row: cursor.row, column: target.column)
        } else {
            target = GridPosition(row: target.row, column: cursor.column)
        }
        while cursor != target, !isFinished {
            cursor = GridPosition(
                row: cursor.row + (target.row - cursor.row).signum(),
                column: cursor.column + (target.column - cursor.column).signum()
            )
            dragMoved(to: cursor)
        }
    }

    /// İmleç panelindeki Doldur/X'e dokunma: imlecin karesini işaretler ya da siler.
    func markAtCursor(with markTool: MarkTool) {
        if cursorLock != nil { unlockCursor() }
        tool = markTool
        tap(cursor)
    }

    /// Doldur/X'e basılı tutup sağa kaydırınca: araç kilitlenir, imlecin karesi hemen işaretlenir.
    func lockCursor(with markTool: MarkTool) {
        guard !isFinished else { return }
        if cursorLock != nil { dragEnded() }
        tool = markTool
        cursorLock = markTool
        cursorAxis = nil
        dragBegan(at: cursor)
    }

    func unlockCursor() {
        cursorLock = nil
        cursorAxis = nil
        dragEnded()
    }

    /// "Kolay": tamamlanan satır/sütuna X otomatik gelir. "Zor": oyuncu X'leri kendisi koyar.
    /// "Tekrar Dene" ile yeni oyun açılınca da korunur.
    var autoCrosses = true {
        didSet { game.autoCrossesCompletedLines = autoCrosses }
    }

    /// "Kolay" modda X'ler tamamlanınca dolu karelerin kendiliğinden gelmesi (eğitimde kapatılabilir).
    var autoFills = true {
        didSet { game.autoFillsCrossedLines = autoFills }
    }

    /// Ödüllü reklam karşılığı bir kez devam hakkı (bulmaca başına).
    private(set) var hasRevived = false

    var canRevive: Bool {
        guard !hasRevived, case .lost = game.status else { return false }
        return true
    }

    /// Kaybedilen oyunu +1 pati ya da +60 saniye ile sürdürür.
    func revive() {
        guard canRevive else { return }
        hasRevived = true
        game.revive(extraMistakes: 1, extraTime: 60)
        lastMistake = nil
        start()
    }

    /// Kaybedince "Tekrar Dene": tahtayı sıfırlar.
    func restart() {
        stop()
        game = NonogramGame(puzzle: puzzle, rules: rules)
        game.autoCrossesCompletedLines = autoCrosses
        game.autoFillsCrossedLines = autoFills
        lastMistake = nil
        hasRevived = false
        activeCell = nil
        isPaused = false
        cursorLock = nil
        cursorAxis = nil
        start()
    }

    // MARK: - Zamanlayıcı

    func start() {
        guard timerTask == nil, !isFinished, !isPaused else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.isFinished else { return }
                if case .failed = self.game.advanceTime(by: 1) {
                    self.onEvent?(.failed)
                    self.stop()
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Duraklat düğmesi ya da uygulama arka plana geçince. Biten oyunda bir şey yapmaz.
    func pause() {
        guard !isFinished else { return }
        isPaused = true
        dragTarget = nil
        activeCell = nil
        stop()
    }

    func resume() {
        isPaused = false
        start()
    }

    // MARK: - Yardımcılar

    private func handle(_ outcome: NonogramGame.MoveOutcome, at position: GridPosition, target: CellState) {
        switch outcome {
        case .changed:
            if target == .filled, game.isRowSatisfied(position.row) || game.isColumnSatisfied(position.column) {
                completedLines = CompletedLines(
                    row: game.isRowSatisfied(position.row) ? position.row : nil,
                    column: game.isColumnSatisfied(position.column) ? position.column : nil,
                    serial: completedLines.serial + 1
                )
                onEvent?(.lineCompleted)
            } else {
                onEvent?(target == .filled ? .filled : (target == .crossed ? .crossed : .erased))
            }
        case .mistake:
            lastMistake = position
            onEvent?(.mistake)
        case .failed(.outOfMistakes):
            lastMistake = position
            onEvent?(.failed)
        case .failed(.outOfTime):
            onEvent?(.failed)
        case .solved:
            onEvent?(.solved)
            onSolved?(PuzzleCompletion(
                puzzleID: puzzle.id,
                completedAt: now(),
                elapsed: game.elapsed,
                mistakes: game.mistakes
            ))
        default:
            break
        }
        if isFinished { stop() }
    }
}
