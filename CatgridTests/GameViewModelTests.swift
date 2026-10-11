import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class GameViewModelTests: XCTestCase {
    let puzzle = Puzzle(id: "bar", pattern: ["###", "...", "..."])
    let freeRules = GameRules(checksMoves: false, autoCrossCompletedLines: false)

    func position(_ row: Int, _ column: Int) -> GridPosition {
        GridPosition(row: row, column: column)
    }

    /// Yardımlı kaydırma: parmak çapraz kaysa da yalnızca ilk karenin satırı işaretlenir;
    /// hızlı kaydırmada atlanan kareler de dolar.
    func testAssistedDragStaysOnOneLine() {
        let big = Puzzle(id: "big", pattern: ["####", "....", "....", "...."])
        let viewModel = GameViewModel(puzzle: big, rules: freeRules)
        viewModel.autoCrosses = false
        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(1, 1))
        viewModel.dragMoved(to: position(1, 3))
        viewModel.dragEnded()
        for column in 0..<4 {
            XCTAssertEqual(viewModel.game.board[position(0, column)], .filled)
        }
        XCTAssertEqual(viewModel.game.board[position(1, 1)], .blank)
        XCTAssertEqual(viewModel.game.board[position(1, 3)], .blank)
    }

    /// Serbest kaydırma: parmağın geçtiği her kare işaretlenir.
    func testFreeDragMarksEveryTouchedSquare() {
        let big = Puzzle(id: "big", pattern: ["####", "....", "....", "...."])
        let viewModel = GameViewModel(puzzle: big, rules: freeRules)
        viewModel.autoCrosses = false
        viewModel.assistedDrag = false
        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(1, 1))
        viewModel.dragEnded()
        XCTAssertEqual(viewModel.game.board[position(1, 1)], .filled)
    }

    /// "Zor" mod: tamamlanan satıra otomatik X gelmez; "Tekrar Dene"den sonra da öyle kalır.
    func testHardModeSurvivesRestart() {
        let plus = Puzzle(id: "plus", pattern: [".#.", "###", ".#."])
        let viewModel = GameViewModel(puzzle: plus, rules: .classic)
        viewModel.autoCrosses = false
        viewModel.tap(position(0, 1))
        XCTAssertEqual(viewModel.game.board[position(0, 0)], .blank)

        viewModel.restart()
        viewModel.tap(position(0, 1))
        XCTAssertEqual(viewModel.game.board[position(0, 0)], .blank)

        viewModel.autoCrosses = true
        viewModel.tap(position(2, 1))
        XCTAssertEqual(viewModel.game.board[position(2, 0)], .crossed)
    }

    func testDragFillsOnlyBlankCells() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: freeRules)
        viewModel.tool = .cross
        viewModel.tap(position(0, 1))

        viewModel.tool = .fill
        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        XCTAssertEqual(viewModel.game.board.row(0), [.filled, .crossed, .filled])
    }

    func testDragStartingOnMarkErases() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: freeRules)
        viewModel.tap(position(0, 0))
        viewModel.tap(position(0, 1))

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragEnded()

        XCTAssertEqual(viewModel.game.board.row(0), [.blank, .blank, .blank])
    }

    func testReportsCompletionOnce() {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic, now: { date })
        var completions: [PuzzleCompletion] = []
        viewModel.onSolved = { completions.append($0) }

        viewModel.dragBegan(at: position(0, 0))
        viewModel.dragMoved(to: position(0, 1))
        viewModel.dragMoved(to: position(0, 2))
        viewModel.dragMoved(to: position(1, 2))
        viewModel.dragEnded()

        XCTAssertEqual(completions, [PuzzleCompletion(puzzleID: "bar", completedAt: date, elapsed: 0, mistakes: 0)])
        XCTAssertTrue(viewModel.isFinished)
    }

    func testMistakeIsExposedForFeedback() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(2, 2))
        XCTAssertEqual(viewModel.lastMistake, position(2, 2))
        XCTAssertEqual(viewModel.game.mistakes, 1)
    }

    func testTracksActiveCellWhileDragging() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.dragBegan(at: position(0, 0))
        XCTAssertEqual(viewModel.activeCell, position(0, 0))
        viewModel.dragEnded()
        XCTAssertNil(viewModel.activeCell)
    }

    func testRestartResetsLostGame() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(1, 0))
        viewModel.tap(position(1, 1))
        viewModel.tap(position(1, 2))
        XCTAssertEqual(viewModel.game.status, .lost(.outOfMistakes))

        viewModel.restart()
        XCTAssertEqual(viewModel.game.status, .playing)
        XCTAssertEqual(viewModel.game.mistakes, 0)
        XCTAssertNil(viewModel.lastMistake)
        viewModel.stop()
    }

    func testResumesFromSavedGame() {
        let first = GameViewModel(puzzle: puzzle, rules: .classic)
        first.tap(position(0, 0))
        first.tap(position(2, 2)) // hata
        let saved = first.snapshotToSave

        let resumed = GameViewModel(puzzle: puzzle, rules: .classic, savedGame: saved)
        XCTAssertEqual(resumed.game.board, first.game.board)
        XCTAssertEqual(resumed.game.mistakes, 1)
    }

    func testNothingToSaveForUntouchedOrFinishedGame() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        XCTAssertNil(viewModel.snapshotToSave)

        viewModel.tap(position(0, 0))
        XCTAssertNotNil(viewModel.snapshotToSave)

        viewModel.tap(position(0, 1))
        viewModel.tap(position(0, 2))
        XCTAssertEqual(viewModel.game.status, .won)
        XCTAssertNil(viewModel.snapshotToSave)
    }

    func testReviveOnceAfterLosing() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        XCTAssertFalse(viewModel.canRevive)
        viewModel.tap(position(1, 0))
        viewModel.tap(position(1, 1))
        viewModel.tap(position(1, 2))
        XCTAssertTrue(viewModel.canRevive)

        viewModel.revive()
        XCTAssertEqual(viewModel.game.status, .playing)
        XCTAssertEqual(viewModel.game.remainingMistakes, 1)
        XCTAssertFalse(viewModel.canRevive)
        viewModel.stop()
    }

    func testEmitsEventsForSounds() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: GameRules(autoCrossCompletedLines: false))
        var events: [GameEvent] = []
        viewModel.onEvent = { events.append($0) }

        viewModel.tap(position(0, 0))      // dolu: sütunun tek karesi, sütun tamamlanır
        viewModel.tool = .cross
        viewModel.tap(position(1, 0))      // X
        viewModel.tap(position(1, 0))      // silme
        viewModel.tap(position(0, 1))      // hata: dolu olmalıydı
        viewModel.tool = .fill
        viewModel.tap(position(0, 2))      // satır tamamlandı ve bulmaca çözüldü

        XCTAssertEqual(events, [.lineCompleted, .crossed, .erased, .mistake, .solved])
    }

    /// Duraklatınca süre durur; arka plandan dönünce (start) menü açık kalır, Devam ile sürer.
    func testPauseHoldsUntilResumed() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.tap(position(0, 0))
        viewModel.dragMoved(to: position(1, 1))
        viewModel.pause()
        XCTAssertTrue(viewModel.isPaused)
        XCTAssertNil(viewModel.activeCell)

        viewModel.start()
        XCTAssertTrue(viewModel.isPaused)

        viewModel.resume()
        XCTAssertFalse(viewModel.isPaused)
        viewModel.stop()
    }

    func testFinishedGameCannotBePausedAndRestartClearsPause() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: .classic)
        viewModel.pause()
        viewModel.restart()
        XCTAssertFalse(viewModel.isPaused)

        viewModel.tap(position(0, 0))
        viewModel.tap(position(0, 1))
        viewModel.tap(position(0, 2))
        XCTAssertEqual(viewModel.game.status, .won)
        viewModel.pause()
        XCTAssertFalse(viewModel.isPaused)
    }

    /// Dopamin modunun parıltısı için tamamlanan satır/sütun bilinir.
    func testReportsCompletedLines() {
        let viewModel = GameViewModel(puzzle: puzzle, rules: GameRules(autoCrossCompletedLines: false))
        viewModel.tap(position(0, 0))
        XCTAssertEqual(viewModel.completedLines.column, 0)
        XCTAssertNil(viewModel.completedLines.row)
        viewModel.tap(position(0, 1))
        XCTAssertEqual(viewModel.completedLines.column, 1)
        XCTAssertEqual(viewModel.completedLines.serial, 2)
    }
}
