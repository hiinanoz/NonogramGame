import XCTest
@testable import NonogramKit

final class BirdSortTests: XCTestCase {
    func testMoveRulesAndClearing() {
        var board = BirdSortBoard(branches: [[0, 1, 1], [1], [], [2]], capacity: 4)
        XCTAssertEqual(board.movableCount(from: 0, to: 1), 2, "uçtaki iki kuş birlikte uçar")
        XCTAssertEqual(board.movableCount(from: 0, to: 3), 0, "farklı türün üstüne konamaz")
        XCTAssertEqual(board.movableCount(from: 0, to: 2), 2, "boş dala konabilir")
        let move = board.move(from: 0, to: 1)
        XCTAssertEqual(move?.count, 2)
        XCTAssertEqual(move?.clearedTarget, false)
        XCTAssertEqual(board.branches[1], [1, 1, 1])
        board = BirdSortBoard(branches: [[1, 1], [1, 1]], capacity: 4)
        XCTAssertEqual(board.move(from: 0, to: 1)?.clearedTarget, true, "dolan dal uçup gider")
        XCTAssertTrue(board.isCleared)
    }

    func testOnlyWhatFitsMoves() {
        var board = BirdSortBoard(branches: [[2, 0, 0, 0], [0, 0, 0]], capacity: 4)
        XCTAssertEqual(board.move(from: 0, to: 1)?.count, 1)
        XCTAssertEqual(board.branches[0], [2, 0, 0])
        XCTAssertTrue(board.branches[1].isEmpty, "dolan dal boşalır")
    }

    func testDifficultyRamp() {
        let first = BirdSortCatalog.level(1)
        XCTAssertEqual(first.capacity, 4)
        XCTAssertEqual(first.branchCount, 7)
        XCTAssertEqual(first.speciesCount, 10)
        let last = BirdSortCatalog.level(BirdSortCatalog.levelCount)
        XCTAssertEqual(last.capacity, 6)
        XCTAssertEqual(last.branchesPerSide, 9)
        XCTAssertEqual(BirdSortCatalog.level(75).branchesPerSide, 5, "ilk adanın sonunda iki yanda 5 dal")
        var previousIsland = 0
        var maxSoFar = 0
        for number in 1...BirdSortCatalog.levelCount {
            let level = BirdSortCatalog.level(number)
            if level.island != previousIsland { previousIsland = level.island }
            XCTAssertGreaterThanOrEqual(level.branchCount, maxSoFar - 1, "dal sayısı azalmaz (nefes bölümleri hariç)")
            maxSoFar = max(maxSoFar, level.branchCount)
        }
        XCTAssertEqual(last.speciesCount, 15)
        for number in 1...BirdSortCatalog.levelCount {
            let level = BirdSortCatalog.level(number)
            XCTAssertTrue((4...6).contains(level.capacity))
            XCTAssertTrue((4...9).contains(level.branchesPerSide))
            XCTAssertEqual(level.sets, level.branchCount - 2)
            XCTAssertEqual(level.speciesCount, 10 + level.island)
        }
    }

    func testEveryLevelIsSolvableAndStable() {
        var slowest = 0.0
        var fallbacks = 0
        // Hepsi (450) yalnızca BIRD_SORT_ALL=1 ile; normalde her adadan örnekler (debug derlemede hızlı)
        let all = ProcessInfo.processInfo.environment["BIRD_SORT_ALL"] != nil
        let numbers = all ? Array(1...BirdSortCatalog.levelCount)
            : (0..<BirdSortCatalog.islandCount).flatMap { island in [1, 2, 38, 39, 75].map { island * 75 + $0 } }
        for number in numbers {
            let level = BirdSortCatalog.level(number)
            let start = Date()
            let puzzle = BirdSortCatalog.puzzle(for: level)
            slowest = max(slowest, Date().timeIntervalSince(start))
            let board = puzzle.board
            XCTAssertEqual(board.branches.count, level.branchCount)
            XCTAssertEqual(board.birdCount, level.sets * level.capacity, "\(number)")
            XCTAssertTrue(board.branches.allSatisfy { $0.count <= level.capacity })
            XCTAssertEqual(board.branches.filter(\.isEmpty).count, 1, "\(number): tek boş dal")
            XCTAssertTrue(board.branches.flatMap { $0 }.allSatisfy { (0..<level.speciesCount).contains($0) })
            if board.branches.allSatisfy({ Set($0).count <= 1 }) { fallbacks += 1 }
            XCTAssertNotNil(BirdSortSolver.solve(board), "\(number) çözülebilir")
            if number % 75 == 1 {
                XCTAssertEqual(BirdSortCatalog.puzzle(for: level).board, board, "aynı bölüm aynı tahta")
            }
        }
        XCTAssertEqual(fallbacks, 0)
        print("BirdSort slowest generation: \(slowest)s")
    }

    func testSessionUndoAddBranchAndStars() {
        let level = BirdSortCatalog.level(1)
        var session = BirdSortSession(level: level)
        let before = session.board
        guard let solution = BirdSortSolver.solve(session.board) else { return XCTFail() }
        let first = solution.moves[0]
        XCTAssertNotNil(session.play(from: first.source, to: first.target))
        XCTAssertTrue(session.undo())
        XCTAssertEqual(session.board, before)
        XCTAssertTrue(session.addBranch())
        XCTAssertFalse(session.addBranch(), "tek ekstra dal")
        XCTAssertEqual(session.board.branches.count, level.branchCount + 1)
        while !session.isWon {
            guard let hint = session.hint() else { return XCTFail("ipucu bulunamadı") }
            session.play(from: hint.source, to: hint.target)
        }
        XCTAssertTrue((1...3).contains(session.stars))
    }
}

final class SavedSessionTests: XCTestCase {
    func testBirdSortSessionRoundTrips() throws {
        var session = BirdSortSession(level: BirdSortCatalog.level(5))
        _ = session.hint()
        if let move = BirdSortSolver.solve(session.board)?.moves.first {
            session.play(from: move.source, to: move.target)
        }
        let data = try JSONEncoder().encode(session)
        let restored = try JSONDecoder().decode(BirdSortSession.self, from: data)
        XCTAssertEqual(restored.board, session.board)
        XCTAssertEqual(restored.moves, session.moves)
        XCTAssertEqual(restored.par, session.par)
        XCTAssertEqual(restored.level, session.level)
        XCTAssertTrue(restored.canUndo)
    }

    func testCrushSessionRoundTripsAndPlaysOn() throws {
        let level = CrushCatalog.standard.levels[0]
        var session = CrushSession(level: level, seed: 7)
        if let swap = session.hint() { _ = session.play(swap) }
        let data = try JSONEncoder().encode(session)
        var restored = try JSONDecoder().decode(CrushSession.self, from: data)
        XCTAssertEqual(restored.board, session.board)
        XCTAssertEqual(restored.movesLeft, session.movesLeft)
        XCTAssertEqual(restored.score, session.score)
        // Kayıttan dönen oyun aynı rastgele sırayla sürer
        if let swap = session.hint() {
            let a = session.play(swap)
            let b = restored.play(swap)
            XCTAssertEqual(session.board, restored.board)
            XCTAssertEqual(session.score, restored.score)
            _ = (a, b)
        }
    }
}
