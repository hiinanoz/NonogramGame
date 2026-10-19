import XCTest
@testable import NonogramKit

final class CrushEngineTests: XCTestCase {
    /// Tahtayı metinden kurar. Her hücre iki harf: renk (b r y g p o) + tür
    /// ("." normal, "H" satır yumağı, "V" sütun yumağı, "W" çıngırak kutusu); "XX" altın kedi gözü,
    /// "__" delik.
    private func board(_ rows: [String]) -> CrushBoard {
        let tokens = rows.map { $0.split(separator: " ").map(String.init) }
        let height = tokens.count, width = tokens[0].count
        var playable: [Bool] = []
        for row in tokens { for token in row { playable.append(token != "__") } }
        var board = CrushBoard(rows: height, columns: width, playable: playable)
        var id = 1
        for (r, row) in tokens.enumerated() {
            for (c, token) in row.enumerated() where token != "__" {
                let chars = Array(token)
                let color: CrushColor? = ["b": .yarn, "r": .wand, "y": .treat, "g": .bowl, "p": .mouse, "o": .paw][chars[0]]
                let special: CrushSpecial = token == "XX" ? .colorBomb
                    : ["H": .stripedRow, "V": .stripedColumn, "W": .wrapped][chars[1]] ?? .none
                board[GridPosition(row: r, column: c)] = CrushPiece(id: id, color: color, special: special)
                id += 1
            }
        }
        return board
    }

    private func p(_ row: Int, _ column: Int) -> GridPosition { GridPosition(row: row, column: column) }

    /// Her motor hamlesinden sonra geçerli olması gereken koşullar.
    private func assertSettled(_ engine: CrushEngine, file: StaticString = #filePath, line: UInt = #line) {
        let board = engine.board
        for position in board.positions {
            if board.isPlayable(position) {
                XCTAssertNotNil(board[position], "boş hücre \(position)", file: file, line: line)
            }
        }
        XCTAssertTrue(CrushEngine.findMatches(in: board).isEmpty, "çözülmemiş eşleşme kaldı", file: file, line: line)
        XCTAssertFalse(engine.possibleMoves().isEmpty, "geçerli hamle yok", file: file, line: line)
        let ids = board.cells.compactMap { $0?.id }
        XCTAssertEqual(ids.count, Set(ids).count, "aynı kimlik iki kez", file: file, line: line)
    }

    // MARK: - Eşleşme bulma

    func testThreeInARowIsPlainMatch() {
        let b = board([
            "b. b. b. r.",
            "g. y. r. y.",
            "y. r. g. g.",
        ])
        let groups = CrushEngine.findMatches(in: b)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].cells, [p(0, 0), p(0, 1), p(0, 2)])
        XCTAssertEqual(groups[0].special, .none)
        XCTAssertEqual(groups[0].color, .yarn)
    }

    func testFourInARowMakesStriped() {
        let b = board([
            "r. g. y. p.",
            "b. b. b. b.",
            "g. y. r. g.",
        ])
        let groups = CrushEngine.findMatches(in: b)
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].special.isStriped)
    }

    func testFiveInARowMakesColorBomb() {
        let b = board([
            "p. p. p. p. p.",
            "g. y. r. g. y.",
        ])
        XCTAssertEqual(CrushEngine.findMatches(in: b).first?.special, .colorBomb)
    }

    func testLShapeMakesWrapped() {
        let b = board([
            "g. r. y.",
            "g. y. r.",
            "g. g. g.",
        ])
        let groups = CrushEngine.findMatches(in: b)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].special, .wrapped)
        XCTAssertEqual(groups[0].cells.count, 5)
    }

    func testHolesBreakRuns() {
        let b = board([
            "b. b. __ b. b.",
            "g. y. r. g. y.",
        ])
        XCTAssertTrue(CrushEngine.findMatches(in: b).isEmpty)
    }

    // MARK: - Takas

    func testSwapWithoutMatchIsRejectedAndReverted() {
        let b = board([
            "b. r. y. g.",
            "g. y. r. p.",
            "y. p. g. r.",
        ])
        var engine = CrushEngine(board: b, seed: 1)
        let result = engine.apply(CrushSwap(from: p(0, 0), to: p(0, 1)))
        XCTAssertEqual(result.failureValue, .noMatch)
        XCTAssertEqual(engine.board, b)
    }

    func testNonAdjacentSwapIsRejected() {
        var engine = CrushEngine(seed: 7)
        XCTAssertEqual(engine.apply(CrushSwap(from: p(0, 0), to: p(2, 2))).failureValue, .notAdjacent)
    }

    func testMatchClearsFallsAndFills() throws {
        // (1,0)'daki mavi yukarı taşınınca üst satırda mavi üçlü olur
        let b = board([
            "r. b. b. g. y.",
            "b. y. r. p. g.",
            "g. r. y. o. p.",
            "y. g. p. r. o.",
        ])
        var engine = CrushEngine(board: b, colors: [.wand, .treat, .bowl, .mouse, .paw], seed: 3)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(1, 0), to: p(0, 0))).successValue)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.cascade, 1)
        XCTAssertEqual(Set(first.clears.map(\.position)), [p(0, 0), p(0, 1), p(0, 2)])
        XCTAssertEqual(first.falls.filter(\.isNew).count, 3, "üç yeni eşya yukarıdan gelir")
        XCTAssertGreaterThan(result.score, 0)
        // Mavi bu tahtada yeniden doğmaz (renk listesinde yok)
        XCTAssertFalse(engine.board.cells.contains { $0?.color == .yarn })
        XCTAssertNotNil(engine.board[p(0, 0)])
    }

    func testFourMatchCreatesStripedAtSwapCell() throws {
        let b = board([
            "r. b. b. g. b.",
            "b. y. r. b. g.",
            "g. r. y. o. p.",
            "y. g. p. r. o.",
        ])
        var engine = CrushEngine(board: b, colors: [.wand, .treat, .bowl, .mouse, .paw], seed: 5)
        // (1,3)'teki mavi yukarı: üst satır b b b b → 4'lü, dikey takas = sütun yumağı
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(1, 3), to: p(0, 3))).successValue)
        let creation = try XCTUnwrap(result.steps.first?.creations.first)
        XCTAssertEqual(creation.position, p(0, 3))
        XCTAssertEqual(creation.piece.special, .stripedColumn)
        XCTAssertEqual(creation.piece.color, .yarn)
    }

    func testStripedClearsWholeRowWhenMatched() throws {
        let b = board([
            "r. y. g. o. p.",
            "bH b. y. b. g.",
            "g. r. b. o. p.",
            "y. g. p. r. o.",
        ])
        var engine = CrushEngine(board: b, colors: [.wand, .treat, .bowl, .mouse, .paw], seed: 9)
        // (2,2)'deki mavi yukarı: (1,0)(1,1)(1,2) mavi üçlü; (1,0) satır yumağı → satır temizlenir
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(2, 2), to: p(1, 2))).successValue)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertTrue(first.activations.contains { $0.kind == .row && $0.position == p(1, 0) })
        let clearedRow = Set(first.clears.map(\.position).filter { $0.row == 1 })
        XCTAssertEqual(clearedRow.count, 5, "satırın tamamı temizlenir")
    }

    func testColorBombSwappedWithColorClearsThatColor() throws {
        let b = board([
            "XX r. y. r. g.",
            "y. g. r. p. r.",
            "g. r. p. y. o.",
        ])
        let redCount = b.cells.filter { $0?.color == .wand }.count
        var engine = CrushEngine(board: b, colors: [.treat, .bowl, .mouse, .paw], seed: 11)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(0, 0), to: p(0, 1))).successValue)
        let first = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(first.clears.filter { $0.piece.color == .wand }.count, redCount)
        XCTAssertFalse(engine.board.cells.contains { $0?.color == .wand })
        XCTAssertFalse(engine.board.cells.contains { $0?.special == .colorBomb })
    }

    func testDoubleColorBombClearsBoard() throws {
        let b = board([
            "XX XX y. r.",
            "y. g. r. p.",
        ])
        var engine = CrushEngine(board: b, seed: 13)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(0, 0), to: p(0, 1))).successValue)
        XCTAssertEqual(result.steps.first?.clears.count, 8)
    }

    func testWrappedExplodesTwice() throws {
        let b = board([
            "r. y. g. o. p. r.",
            "o. gW g. y. r. y.",
            "p. r. o. g. y. o.",
            "y. o. p. r. o. p.",
            "r. y. r. y. p. r.",
        ])
        var engine = CrushEngine(board: b, colors: [.wand, .treat, .mouse, .paw], seed: 17)
        // (2,3)'teki yeşil yukarı → (1,1)(1,2)(1,3) yeşil üçlü; (1,1) çıngırak kutusu
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(2, 3), to: p(1, 3))).successValue)
        let explosions = result.steps.flatMap(\.activations).filter {
            if case .explosion = $0.kind { return true } else { return false }
        }
        XCTAssertGreaterThanOrEqual(explosions.count, 2, "ilk patlama ve düştükten sonra ikincisi")
        XCTAssertFalse(engine.board.cells.contains { $0?.special == .wrappedPrimed })
    }


    /// Hızlı hamle kontrolü, bütün tahtayı tarayan yavaş kontrolle aynı sonucu vermeli.
    func testFastMoveCheckMatchesFullScan() {
        for seed in UInt64(1)...30 {
            var engine = CrushEngine(rows: 7, columns: 7, colors: [.yarn, .wand, .treat, .bowl], seed: seed)
            engine.shuffle()
            let board = engine.board
            for position in board.positions {
                for neighbor in [p(position.row, position.column + 1), p(position.row + 1, position.column)]
                where board.isPlayable(neighbor) {
                    var copy = board
                    let a = copy[position], b = copy[neighbor]
                    copy[position] = b
                    copy[neighbor] = a
                    let slow = !CrushEngine.findMatches(in: copy).isEmpty
                    XCTAssertEqual(engine.isValid(CrushSwap(from: position, to: neighbor)), slow, "tohum \(seed) \(position)")
                }
            }
        }
    }

    func testStripedPlusStripedClearsRowAndColumn() throws {
        let b = board([
            "r. y. g. o. p.",
            "o. bH rV y. g.",
            "g. r. o. p. y.",
            "y. g. p. r. o.",
        ])
        var engine = CrushEngine(board: b, colors: [.treat, .bowl, .mouse, .paw], seed: 21)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(1, 1), to: p(1, 2))).successValue)
        let cleared = Set(result.steps[0].clears.map(\.position))
        for column in 0..<5 { XCTAssertTrue(cleared.contains(p(1, column))) }
        for row in 0..<4 { XCTAssertTrue(cleared.contains(p(row, 2))) }
    }

    func testStripedPlusWrappedClearsThreeRowsAndColumns() throws {
        let b = board([
            "r. y. g. o. p. y.",
            "o. y. r. y. g. o.",
            "p. bH rW o. y. r.",
            "g. r. o. p. r. y.",
            "y. g. p. r. o. p.",
        ])
        var engine = CrushEngine(board: b, colors: [.treat, .bowl, .mouse, .paw], seed: 23)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(2, 1), to: p(2, 2))).successValue)
        let cleared = Set(result.steps[0].clears.map(\.position))
        for row in 1...3 { for column in 0..<6 { XCTAssertTrue(cleared.contains(p(row, column)), "\(row),\(column)") } }
        for column in 1...3 { for row in 0..<5 { XCTAssertTrue(cleared.contains(p(row, column))) } }
    }

    func testColorBombWithStripedTurnsColorIntoStripes() throws {
        let b = board([
            "XX gH y. g. r.",
            "y. r. g. p. y.",
            "g. y. p. r. o.",
        ])
        var engine = CrushEngine(board: b, colors: [.wand, .treat, .mouse, .paw], seed: 29)
        let result = try XCTUnwrap(engine.apply(CrushSwap(from: p(0, 0), to: p(0, 1))).successValue)
        let stripeActivations = result.steps[0].activations.filter { $0.kind == .row || $0.kind == .column }
        XCTAssertGreaterThanOrEqual(stripeActivations.count, 2, "yeşillerin hepsi yumak olup patlar")
    }

    // MARK: - Tahta üretimi, olası hamle ve karıştırma

    func testGeneratedBoardIsPlayableAndDeterministic() {
        let a = CrushEngine(seed: 42)
        let b = CrushEngine(seed: 42)
        XCTAssertEqual(a.board, b.board)
        assertSettled(a)
        XCTAssertNotNil(a.hint())
    }

    func testShapedLevelKeepsHolesEmpty() {
        let level = CrushLevel(id: "t", rows: 5, columns: 5, shape: [
            ".....",
            ". . .",
            ".....",
            ".. ..",
            ".....",
        ], moves: 20, goals: [.score(1000)], starScores: [1000, 2000, 3000])
        let engine = CrushEngine(level: level, seed: 3)
        XCTAssertNil(engine.board[p(1, 1)])
        XCTAssertNil(engine.board[p(3, 2)])
        assertSettled(engine)
    }

    func testShuffleKeepsPiecesAndLeavesAMove() {
        var engine = CrushEngine(seed: 99)
        let before = engine.board.cells.compactMap { $0?.id }.sorted()
        engine.shuffle()
        XCTAssertEqual(engine.board.cells.compactMap { $0?.id }.sorted(), before)
        assertSettled(engine)
    }

    /// Rastgele oyun: her hamleden sonra tahta dolu, eşleşmesiz ve oynanabilir kalmalı.
    func testRandomPlayKeepsBoardConsistent() throws {
        for seed in UInt64(1)...20 {
            var engine = CrushEngine(seed: seed)
            var picker = CrushRandom(seed: seed &* 7)
            for _ in 0..<60 {
                let moves = engine.possibleMoves()
                let move = try XCTUnwrap(moves.randomElement(using: &picker))
                let result = engine.apply(move)
                XCTAssertNotNil(result.successValue, "geçerli sanılan hamle reddedildi (tohum \(seed))")
                assertSettled(engine)
            }
        }
    }
}

private extension Result {
    var successValue: Success? { if case .success(let value) = self { return value } else { return nil } }
    var failureValue: Failure? { if case .failure(let error) = self { return error } else { return nil } }
}
