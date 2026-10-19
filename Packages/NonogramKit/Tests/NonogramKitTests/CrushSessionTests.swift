import XCTest
@testable import NonogramKit

final class CrushSessionTests: XCTestCase {
    private func level(_ goals: [CrushGoal], moves: Int = 20, colors: Int = 5, stars: [Int] = [100, 2_000, 5_000]) -> CrushLevel {
        CrushLevel(id: "test", rows: 8, columns: 8, moves: moves, colorCount: colors, goals: goals, starScores: stars)
    }

    /// Hamle bitene ya da bölüm bitene kadar ipucu hamlesini oynar.
    private func playOut(_ session: inout CrushSession, limit: Int = 200) {
        var count = 0
        while session.status == .playing, count < limit, let swap = session.hint() {
            _ = session.play(swap)
            count += 1
        }
    }

    private func error(_ result: Result<CrushSession.Turn, CrushMoveError>) -> CrushMoveError? {
        if case .failure(let error) = result { return error }
        return nil
    }

    // MARK: - Hamleler

    func testInvalidSwapCostsNoMove() {
        var session = CrushSession(level: level([.score(1_000)]), seed: 3)
        let invalid = session.board.playablePositions.lazy.flatMap { p in
            [GridPosition(row: p.row, column: p.column + 1), GridPosition(row: p.row + 1, column: p.column)]
                .map { CrushSwap(from: p, to: $0) }
        }.first { session.board.isPlayable($0.to) && !session.isValid($0) }!
        XCTAssertEqual(error(session.play(invalid)), .noMatch)
        XCTAssertEqual(session.movesLeft, 20)
        XCTAssertEqual(error(session.play(CrushSwap(from: GridPosition(row: 0, column: 0), to: GridPosition(row: 2, column: 0)))),
                       .notAdjacent)
        XCTAssertEqual(session.movesLeft, 20)
    }

    func testValidSwapCountsMoveScoreAndCollected() throws {
        var session = CrushSession(level: level([.score(100_000)]), seed: 5)
        let turn = try session.play(XCTUnwrap(session.hint())).get()
        XCTAssertEqual(session.movesLeft, 19)
        XCTAssertEqual(session.movesUsed, 1)
        XCTAssertEqual(session.score, turn.move.score)
        XCTAssertGreaterThan(session.score, 0)
        let cleared = turn.move.steps.flatMap(\.clears).filter { $0.piece.color != nil }.count
        XCTAssertEqual(turn.collected.values.reduce(0, +), cleared)
        XCTAssertEqual(session.collected, turn.collected)
    }

    // MARK: - Bitiş

    func testCollectLevelEndsAsSoonAsGoalsComplete() {
        var session = CrushSession(level: level([.collect(.yarn, 3)], moves: 30, colors: 3), seed: 9)
        playOut(&session)
        XCTAssertEqual(session.status, .won)
        XCTAssertGreaterThan(session.movesLeft, 0)
        XCTAssertTrue(session.goals[0].isComplete)
        XCTAssertEqual(error(session.play(CrushSwap(from: GridPosition(row: 0, column: 0), to: GridPosition(row: 0, column: 1)))),
                       .levelOver)
    }

    func testScoreLevelPlaysAllMoves() {
        var session = CrushSession(level: level([.score(100)], moves: 6), seed: 11)
        XCTAssertTrue(session.isScoreLevel)
        _ = session.play(session.hint()!)
        XCTAssertEqual(session.status, .playing, "puan hedefe ulaşsa da hamleler bitene kadar sürer")
        playOut(&session)
        XCTAssertEqual(session.movesLeft, 0)
        XCTAssertEqual(session.status, .won)
    }

    func testLosingAndExtraMoves() {
        var session = CrushSession(level: level([.collect(.yarn, 10_000)], moves: 3), seed: 13)
        playOut(&session)
        XCTAssertEqual(session.status, .lost)
        XCTAssertEqual(session.stars, 0)
        session.addMoves(5)
        XCTAssertEqual(session.status, .playing)
        XCTAssertEqual(session.movesLeft, 5)
    }

    func testCelebrationTurnsMovesIntoPoints() throws {
        var session = CrushSession(level: level([.collect(.yarn, 3)], moves: 30), seed: 17)
        playOut(&session)
        XCTAssertEqual(session.status, .won)
        let movesLeft = session.movesLeft
        let before = session.score
        let finale = try XCTUnwrap(session.celebrate())
        XCTAssertEqual(finale.movesConverted, movesLeft)
        XCTAssertEqual(finale.steps.first?.creations.count, movesLeft)
        XCTAssertTrue(finale.steps.first!.creations.allSatisfy { $0.piece.special.isStriped })
        XCTAssertGreaterThanOrEqual(finale.score, movesLeft * CrushEngine.Points.bonusPerMove)
        XCTAssertEqual(session.score, before + finale.score)
        XCTAssertEqual(session.movesLeft, 0)
        XCTAssertNil(session.celebrate(), "bir kez")
        // Sonunda tahta dolu, özel eşya ve eşleşme kalmamış
        let board = session.board
        XCTAssertTrue(board.playablePositions.allSatisfy { board[$0] != nil })
        XCTAssertTrue(board.playablePositions.allSatisfy { board[$0]?.isSpecial == false })
        XCTAssertTrue(CrushEngine.findMatches(in: board).isEmpty)
    }

    func testCelebrationFinishesOnEveryShape() {
        for (index, level) in CrushCatalog.standard.levels.enumerated() where index % 4 == 0 {
            var engine = CrushEngine(level: level, seed: UInt64(index))
            let steps = engine.celebrate(movesLeft: 15)
            XCTAssertLessThan(steps.count, CrushEngine.maxCascades, level.id)
            XCTAssertTrue(engine.board.playablePositions.allSatisfy { engine.board[$0]?.isSpecial == false }, level.id)
        }
    }

    func testCelebrationWithoutMovesOrSpecialsDoesNothing() {
        var engine = CrushEngine(rows: 8, columns: 8, seed: 21)
        XCTAssertTrue(engine.celebrate(movesLeft: 0).isEmpty)
    }

    // MARK: - Güçlendiriciler

    func testPawSmashesOnePieceWithoutUsingAMove() throws {
        var session = CrushSession(level: level([.score(100_000)]), seed: 23)
        let target = GridPosition(row: 4, column: 4)
        let piece = try XCTUnwrap(session.board[target])
        let turn = try XCTUnwrap(session.usePaw(at: target))
        XCTAssertEqual(session.movesLeft, 20)
        XCTAssertTrue(turn.move.steps[0].clears.contains { $0.piece.id == piece.id })
        XCTAssertGreaterThan(session.score, 0)
        XCTAssertTrue(session.board.playablePositions.allSatisfy { session.board[$0] != nil })
        XCTAssertTrue(CrushEngine.findMatches(in: session.board).isEmpty)
    }

    func testPawOnRattleBoxExplodesTwiceAndRemovesIt() throws {
        var session = CrushSession(level: level([.score(100_000)]), seed: 29)
        // Kutuyu doğrudan koymak için motoru tahtayla kur
        var board = session.board
        let center = GridPosition(row: 4, column: 4)
        board[center] = CrushPiece(id: 9_999, color: .yarn, special: .wrapped)
        var engine = CrushEngine(board: board, colors: CrushColor.allCases, seed: 1)
        let result = try XCTUnwrap(engine.smash(center))
        let explosions = result.steps.flatMap(\.activations).filter { $0.kind == .explosion(radius: 1) }
        XCTAssertEqual(explosions.count, 2)
        XCTAssertFalse(engine.board.playablePositions.contains { engine.board[$0]?.id == 9_999 })
        XCTAssertNil(session.usePaw(at: GridPosition(row: -1, column: 0)))
    }

    func testShuffleKeepsPiecesAndMoves() {
        var session = CrushSession(level: level([.score(100_000)]), seed: 31)
        let before = session.board.cells.compactMap { $0?.id }.sorted()
        session.shuffle()
        XCTAssertEqual(session.board.cells.compactMap { $0?.id }.sorted(), before)
        XCTAssertEqual(session.movesLeft, 20)
        XCTAssertFalse(session.engine.possibleMoves().isEmpty)
    }

    // MARK: - Yıldızlar

    func testStars() {
        XCTAssertEqual(CrushSession.stars(score: 50, thresholds: [100, 200, 300]), 1, "kazanılan bölüm en az 1 yıldız")
        XCTAssertEqual(CrushSession.stars(score: 200, thresholds: [100, 200, 300]), 2)
        XCTAssertEqual(CrushSession.stars(score: 999, thresholds: [100, 200, 300]), 3)
    }

    func testGoalProgress() {
        let progress = CrushSession.GoalProgress(goal: .collect(.yarn, 20), current: 5)
        XCTAssertEqual(progress.remaining, 15)
        XCTAssertEqual(progress.fraction, 0.25)
        XCTAssertFalse(progress.isComplete)
        XCTAssertTrue(CrushSession.GoalProgress(goal: .specials(2), current: 3).isComplete)
    }

    // MARK: - İlerleme ve ödüller

    private let catalog = CrushCatalog.standard

    func testUnlockingInOrder() {
        var progress = CrushProgress()
        let levels = catalog.levels
        XCTAssertTrue(progress.isUnlocked(levels[0], in: catalog))
        XCTAssertFalse(progress.isUnlocked(levels[1], in: catalog))
        XCTAssertEqual(progress.currentLevel(in: catalog)?.id, levels[0].id)
        let outcome = progress.record(levelID: levels[0].id, score: 5_000, stars: 2, catalog: catalog)
        XCTAssertTrue(outcome.isFirstWin)
        XCTAssertEqual(outcome.unlockedLevelID, levels[1].id)
        XCTAssertEqual(outcome.newBadges, [.firstWin])
        XCTAssertTrue(progress.isUnlocked(levels[1], in: catalog))
        XCTAssertEqual(progress.currentLevel(in: catalog)?.id, levels[1].id)
    }

    func testReplayKeepsBestAndCountsOnlyNewStars() {
        var progress = CrushProgress()
        let id = catalog.levels[0].id
        _ = progress.record(levelID: id, score: 9_000, stars: 2, catalog: catalog)
        let worse = progress.record(levelID: id, score: 4_000, stars: 1, catalog: catalog)
        XCTAssertFalse(worse.isFirstWin)
        XCTAssertFalse(worse.isNewBest)
        XCTAssertEqual(worse.starsGained, 0)
        XCTAssertNil(worse.unlockedLevelID)
        XCTAssertEqual(progress.stars(for: id), 2)
        XCTAssertEqual(progress.bestScore(for: id), 9_000)
        let better = progress.record(levelID: id, score: 20_000, stars: 3, catalog: catalog)
        XCTAssertTrue(better.isNewBest)
        XCTAssertEqual(better.starsGained, 1)
        XCTAssertEqual(progress.totalStars, 3)
    }

    func testStarChestsAndEpisodeReward() {
        var progress = CrushProgress()
        var chests: [CrushReward] = []
        var episodeReward: CrushReward?
        for level in catalog.levels(in: 0) {
            let outcome = progress.record(levelID: level.id, score: 1, stars: 3, catalog: catalog)
            chests += outcome.chests
            if let reward = outcome.episodeReward { episodeReward = reward }
        }
        // 45 yıldız → 3 sandık (12, 24, 36)
        XCTAssertEqual(progress.totalStars, 45)
        XCTAssertEqual(chests, [CrushProgress.chest(number: 0), CrushProgress.chest(number: 1), CrushProgress.chest(number: 2)])
        XCTAssertEqual(progress.starsToNextChest, 3)
        XCTAssertEqual(episodeReward, CrushProgress.episodeReward(0))
        XCTAssertTrue(progress.badges.contains(.episodeCleared(0)))
        XCTAssertTrue(progress.badges.contains(.episodePerfect(0)))
        // Envanter: başlangıç + sandıklar + macera ödülü
        let expectedPaws = 1 + chests.map { $0.boosters[.paw] ?? 0 }.reduce(0, +) + (episodeReward?.boosters[.paw] ?? 0)
        XCTAssertEqual(progress.count(of: .paw), expectedPaws)
        // Macera ödülü yalnızca bir kez
        let again = progress.record(levelID: catalog.levels[14].id, score: 1, stars: 3, catalog: catalog)
        XCTAssertNil(again.episodeReward)
        XCTAssertTrue(again.chests.isEmpty)
    }

    func testBadgesForChainsAndFrenzy() {
        var progress = CrushProgress()
        let outcome = progress.record(levelID: catalog.levels[0].id, score: 1, stars: 1, bestCascade: 6,
                                      frenzyMoves: 12, catalog: catalog)
        XCTAssertEqual(Set(outcome.newBadges), [.firstWin, .chainMaster, .catFrenzy])
    }

    func testBoosters() {
        var progress = CrushProgress()
        XCTAssertEqual(progress.count(of: .shuffle), 1)
        XCTAssertTrue(progress.use(.shuffle))
        XCTAssertFalse(progress.use(.shuffle))
        progress.add(CrushReward(boosters: [.shuffle: 2, .paw: 0]))
        XCTAssertEqual(progress.count(of: .shuffle), 2)
    }

    func testProgressRoundTripsThroughJSON() throws {
        var progress = CrushProgress()
        _ = progress.record(levelID: catalog.levels[0].id, score: 12_345, stars: 3, bestCascade: 5, catalog: catalog)
        _ = progress.use(.paw)
        let data = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(CrushProgress.self, from: data), progress)
    }

    /// Kataloğun bütün bölümleri, art arda kazanılınca hepsi sırayla açılır; son macera ödülü verilir.
    func testWholeCatalogCanBeCompleted() {
        var progress = CrushProgress()
        for level in catalog.levels {
            XCTAssertTrue(progress.isUnlocked(level, in: catalog), level.id)
            _ = progress.record(levelID: level.id, score: 1, stars: 1, catalog: catalog)
        }
        XCTAssertEqual(progress.claimedEpisodes, Set(0..<catalog.episodeCount))
        XCTAssertEqual(catalog.episodeCount, 4)
        XCTAssertTrue(progress.badges.contains(.starCollector(50)))
    }
}
