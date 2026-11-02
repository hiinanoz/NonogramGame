import XCTest
@testable import NonogramKit

final class CatBlockTests: XCTestCase {
    func testNewGameHasThreePiecesAndEmptyBoard() {
        let game = CatBlockGame(seed: 1)
        XCTAssertEqual(game.tray.compactMap { $0 }.count, 3)
        XCTAssertTrue(game.cells.allSatisfy { $0 == nil })
        XCTAssertFalse(game.isOver)
    }

    func testShapesAreWellFormed() {
        for shape in CatBlockShape.all {
            XCTAssertFalse(shape.cells.isEmpty)
            XCTAssertEqual(Set(shape.cells).count, shape.cells.count)
            XCTAssertTrue(shape.cells.contains { $0.row == 0 })
            XCTAssertTrue(shape.cells.contains { $0.column == 0 })
            XCTAssertLessThanOrEqual(shape.rows, 5)
            XCTAssertLessThanOrEqual(shape.columns, 5)
        }
    }

    /// Rastgele ama kurallı oyun: her yerleştirme geçerli, puan artar, oyun bir gün biter.
    func testRandomPlayKeepsRules() {
        for seed in 1...20 as ClosedRange<UInt64> {
            var game = CatBlockGame(seed: seed)
            var steps = 0
            while !game.isOver, steps < 2000 {
                guard let (index, row, column) = firstMove(in: game) else { break }
                let before = game.score
                let placement = game.place(trayIndex: index, row: row, column: column)
                XCTAssertNotNil(placement)
                XCTAssertGreaterThan(game.score, before)
                // Dolu satır ya da sütun kalmaz
                for r in 0..<CatBlockGame.size {
                    XCTAssertFalse((0..<CatBlockGame.size).allSatisfy { game[r, $0] != nil })
                }
                steps += 1
            }
            XCTAssertGreaterThan(steps, 3)
        }
    }

    /// Acemi oyuncu (satır tamamlayan hamleyi görür, yoksa ilk bulduğu yere koyar) başlangıçta
    /// büyük çoğunlukla 300 puanı geçmeli: oyunun başında küçük ve yardımcı parçalar gelir.
    func testBeginnerPassesEarlyScores() {
        var scores: [Int] = []
        for seed in 1...20 as ClosedRange<UInt64> {
            var game = CatBlockGame(seed: seed)
            var steps = 0
            while !game.isOver, game.score < 300, steps < 3000, let (index, row, column) = beginnerMove(in: game) {
                game.place(trayIndex: index, row: row, column: column)
                steps += 1
            }
            scores.append(game.score)
        }
        let passed = scores.filter { $0 >= 300 }.count
        XCTAssertGreaterThanOrEqual(passed, 17, "300 puanı geçen oyun: \(passed)/20 · \(scores.sorted())")
    }

    func testDifficultyFollowsScore() {
        var game = CatBlockGame(seed: 1)
        XCTAssertEqual(game.ease, 1)
        XCTAssertEqual(game.challenge, 0)
        // Puan arttıkça kolaylık azalır
        var steps = 0
        while !game.isOver, game.score < 2000, steps < 5000, let (index, row, column) = firstMove(in: game) {
            game.place(trayIndex: index, row: row, column: column)
            steps += 1
        }
        if game.score >= 2000 { XCTAssertEqual(game.ease, 0) }
    }

    func testLineClearScoringAndCombo() throws {
        var game = CatBlockGame(seed: 3)
        // Tahtayı elle hazırlamak için ilk satırı 1'lik ve 2'lik parçalarla doldurmak yerine
        // kodlayıp çözmek: bir satırı neredeyse dolu bir oyun
        var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as! [String: Any]
        var cells = Array(repeating: NSNull() as Any, count: 64)
        for c in 0..<7 { cells[c] = 2 }
        data["cells"] = cells
        let single: [String: Any] = ["id": 99, "color": 1, "shape": ["cells": [["row": 0, "column": 0]], "weight": 1]]
        data["tray"] = [single, NSNull(), NSNull()]
        game = try JSONDecoder().decode(CatBlockGame.self, from: JSONSerialization.data(withJSONObject: data))
        let placement = try XCTUnwrap(game.place(trayIndex: 0, row: 0, column: 7))
        XCTAssertEqual(placement.rows, [0])
        XCTAssertEqual(placement.lineCount, 1)
        XCTAssertEqual(placement.combo, 1)
        XCTAssertTrue(placement.boardCleared)
        XCTAssertEqual(placement.points, 1 + 10 + 300)
        XCTAssertEqual(game.score, 311)
        XCTAssertEqual(game.tray.compactMap { $0 }.count, 3, "tepsi boşalınca yeni üç parça")
    }

    func testBoardClearOncePerGameAndRoundTrip() throws {
        var game = CatBlockGame(seed: 5)
        if let (i, r, c) = firstMove(in: game) { game.place(trayIndex: i, row: r, column: c) }
        XCTAssertFalse(game.clearBoard().isEmpty)
        XCTAssertTrue(game.cells.allSatisfy { $0 == nil })
        XCTAssertTrue(game.clearBoard().isEmpty, "bir oyunda bir kez")
        let restored = try JSONDecoder().decode(CatBlockGame.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored.score, game.score)
        XCTAssertTrue(restored.usedBoardClear)
        XCTAssertEqual(restored.tray, game.tray)
    }

    /// Önce satır/sütun temizleyen bir hamle arar, yoksa ilk sığan yer.
    private func beginnerMove(in game: CatBlockGame) -> (Int, Int, Int)? {
        for (index, piece) in game.tray.enumerated() {
            guard let piece else { continue }
            for r in 0..<CatBlockGame.size {
                for c in 0..<CatBlockGame.size where game.canPlace(piece, row: r, column: c) {
                    var trial = game
                    if (trial.place(trayIndex: index, row: r, column: c)?.lineCount ?? 0) > 0 { return (index, r, c) }
                }
            }
        }
        return firstMove(in: game)
    }

    private func firstMove(in game: CatBlockGame) -> (Int, Int, Int)? {
        for (index, piece) in game.tray.enumerated() {
            guard let piece else { continue }
            for r in 0..<CatBlockGame.size {
                for c in 0..<CatBlockGame.size where game.canPlace(piece, row: r, column: c) {
                    return (index, r, c)
                }
            }
        }
        return nil
    }
}
