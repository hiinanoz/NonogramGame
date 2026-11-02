import NonogramKit
import XCTest
@testable import Catgrid

/// Eğitim senaryoları gerçek ders bulmacalarında oynanınca hatasız çözüme götürmeli.
final class TutorialScriptTests: XCTestCase {
    private var tutorial: Chapter!

    override func setUpWithError() throws {
        let catalog = try CatalogLoader.load(from: .main)
        tutorial = try XCTUnwrap(catalog.chapters.first { $0.kind == .tutorial })
    }

    private func puzzle(_ lesson: TutorialLesson) throws -> Puzzle {
        try XCTUnwrap(tutorial.puzzles.first { $0.lesson == lesson })
    }

    /// Patinin gösterdiği her hamleyi sırayla yapar (Kolay mod).
    func testScriptedLessonsSolveWithoutMistakes() throws {
        for lesson in [TutorialLesson.firstSquare, .tapToFill, .emptyLines] {
            let puzzle = try puzzle(lesson)
            let script = try XCTUnwrap(TutorialScript.script(for: lesson, puzzle: puzzle), "\(lesson)")
            var game = NonogramGame(puzzle: puzzle, rules: .classic)
            var guard_ = 0
            while let step = script.currentStep(on: game.board), game.status == .playing, guard_ < 100 {
                guard_ += 1
                game.autoFillsCrossedLines = script.autoFills(on: game.board)
                // Ders, son adıma gelmeden bitmemeli
                XCTAssertTrue(script.steps.firstIndex { !$0.isDone(on: game.board) } != nil, "\(lesson)")
                let cell = try XCTUnwrap(step.cells.first { game.board[$0] == .blank })
                game.mark(step.tool.cellState, at: cell)
            }
            XCTAssertEqual(game.status, .won, "\(lesson)")
            XCTAssertEqual(game.mistakes, 0, "\(lesson)")
        }
    }

    /// 4. ders: önce 0 satırlar, sonra tam dolu satır, sonra "2 1" satırları; adımlar
    /// otomatik doldurmayla atlanmamalı.
    func testEmptyLinesLessonWalksThroughEveryPhase() throws {
        let puzzle = try puzzle(.emptyLines)
        let script = try XCTUnwrap(TutorialScript.script(for: .emptyLines, puzzle: puzzle))
        XCTAssertFalse(script.autoFills)
        var game = NonogramGame(puzzle: puzzle, rules: .classic)
        game.autoFillsCrossedLines = script.autoFills
        var visited = 0
        for step in script.steps {
            XCTAssertFalse(step.isDone(on: game.board), "adım kendiliğinden bitmemeli")
            for cell in step.cells where game.board[cell] == .blank {
                game.mark(step.tool.cellState, at: cell)
            }
            visited += 1
        }
        XCTAssertEqual(visited, script.steps.count)
        XCTAssertEqual(game.status, .won)
    }

    /// Kullanıcı bildirimi: 2. ders, sağ sütun gösterilmeden alt satır bitince tamamlanıyordu.
    func testTapToFillLessonWaitsForTheLastLine() throws {
        let puzzle = try puzzle(.tapToFill)
        let script = try XCTUnwrap(TutorialScript.script(for: .tapToFill, puzzle: puzzle))
        var game = NonogramGame(puzzle: puzzle, rules: .classic)
        for (index, step) in script.steps.enumerated() {
            for cell in step.cells where game.board[cell] == .blank {
                game.autoFillsCrossedLines = script.autoFills(on: game.board)
                game.mark(step.tool.cellState, at: cell)
            }
            if index < script.steps.count - 1 {
                XCTAssertEqual(game.status, .playing, "adım \(index + 1) sonrası bitmemeli")
            }
        }
        XCTAssertEqual(game.status, .won)
    }

    func testOnlyEarlyLessonsLockEasyMode() {
        XCTAssertTrue(TutorialLesson.tapToFill.locksEasyMode)
        XCTAssertTrue(TutorialLesson.mistakesAndLives.locksEasyMode)
        XCTAssertFalse(TutorialLesson.difficulty.locksEasyMode)
        XCTAssertFalse(TutorialLesson.graduation.locksEasyMode)
    }
}
