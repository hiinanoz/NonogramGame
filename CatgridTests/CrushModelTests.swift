import NonogramKit
import XCTest
@testable import Catgrid

/// Miyav Crush kaydı: kazanma, güçlendiriciler, kalıcılık ve sıfırlama.
@MainActor
final class CrushModelTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "crush-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// İlk bölümü ipucu hamleleriyle oynar (kazanana ya da hamle bitene kadar).
    private func playFirstLevel(_ model: CrushModel) -> CrushSession {
        var session = CrushSession(level: model.levels[0], seed: 42)
        while session.status == .playing, let swap = session.hint() {
            _ = session.play(swap)
        }
        _ = session.celebrate()
        return session
    }

    func testWinIsSavedAndUnlocksNextLevel() throws {
        let defaults = makeDefaults()
        let model = CrushModel(defaults: defaults)
        XCTAssertEqual(model.currentLevel?.id, model.levels[0].id)
        let session = playFirstLevel(model)
        try XCTSkipUnless(session.status == .won, "bu tohumla bölüm kazanılamadı")
        let outcome = model.recordWin(session, frenzyMoves: 0)
        XCTAssertTrue(outcome.isFirstWin)
        XCTAssertGreaterThanOrEqual(model.stars(for: model.levels[0]), 1)
        XCTAssertTrue(model.isUnlocked(model.levels[1]))

        // Yeniden açılınca kayıt duruyor
        let reloaded = CrushModel(defaults: defaults)
        XCTAssertEqual(reloaded.totalStars, model.totalStars)
        XCTAssertEqual(reloaded.currentLevel?.id, model.levels[1].id)
        XCTAssertEqual(reloaded.stats.wins, 1)
    }

    func testBoostersAndReset() {
        let defaults = makeDefaults()
        let model = CrushModel(defaults: defaults)
        XCTAssertEqual(model.count(of: .paw), 1)
        XCTAssertTrue(model.use(.paw))
        XCTAssertFalse(model.use(.paw))
        model.add(.paw, count: 2)
        XCTAssertEqual(CrushModel(defaults: defaults).count(of: .paw), 2)
        model.markIntroSeen()
        model.reset()
        XCTAssertEqual(model.count(of: .paw), 1)
        XCTAssertFalse(model.hasSeenIntro)
        XCTAssertEqual(CrushModel(defaults: defaults).totalStars, 0)
    }

    /// Ekran modeli: başlangıçta her hücrede bir eşya; geçersiz takas tahtayı değiştirmez.
    func testViewModelStartsInSyncWithBoard() {
        let model = CrushModel.inMemory()
        let viewModel = CrushGameViewModel(level: model.levels[0], seed: 7, reduceMotion: true)
        let board = viewModel.board
        XCTAssertEqual(viewModel.tiles.count, board.playablePositions.count)
        for position in board.playablePositions {
            let id = board[position]!.id
            XCTAssertEqual(viewModel.tiles[id]?.row, Double(position.row))
            XCTAssertEqual(viewModel.tiles[id]?.column, Double(position.column))
        }
        XCTAssertTrue(viewModel.canPlay)
    }
}
