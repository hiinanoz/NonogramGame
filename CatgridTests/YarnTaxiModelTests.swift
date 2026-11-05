import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class YarnTaxiModelTests: XCTestCase {
    func testWinUnlocksNextLevelAndRewards() {
        let model = YarnTaxiModel.inMemory()
        XCTAssertEqual(model.currentLevel, 1)
        XCTAssertFalse(model.isUnlocked(2))
        model.recordWin(level: 1, stars: 3)
        XCTAssertEqual(model.currentLevel, 2)
        XCTAssertEqual(model.totalStars, 3)
        XCTAssertEqual(model.recordWin(level: 10, stars: 2), .hint)
        XCTAssertEqual(model.recordWin(level: 25, stars: 1), .extraSlot)
    }

    func testSavedGameRoundTrip() async {
        let model = YarnTaxiModel.inMemory()
        let viewModel = YarnTaxiGameViewModel(level: YarnTaxiCatalog.level(5))
        if let car = YarnTaxiSolver.hint(viewModel.game), let target = viewModel.game.lot.first(where: { $0.id == car }) {
            viewModel.tap(target)
        }
        while viewModel.isAnimating { try? await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(viewModel.hasProgress)
        model.saveGame(viewModel.savedState)
        XCTAssertEqual(model.savedGame(for: 5)?.game, viewModel.game)
        XCTAssertNil(model.savedGame(for: 6))
    }

    /// Görünüm modeliyle ipuçlarını izleyerek bölüm kazanılır (her dokunuşta araba durağa gider,
    /// yumaklar tek tek biner); ipucu yıldızı düşürür.
    func testPlayingThroughWithHints() async {
        let viewModel = YarnTaxiGameViewModel(level: YarnTaxiCatalog.level(1))
        var won = false
        viewModel.onWin = { won = true }
        var steps = 0
        while !viewModel.isWon, steps < 50, let id = YarnTaxiSolver.hint(viewModel.game),
              let car = viewModel.game.lot.first(where: { $0.id == id }) {
            viewModel.tap(car)
            XCTAssertTrue(viewModel.isAnimating)
            while viewModel.isAnimating { try? await Task.sleep(for: .milliseconds(50)) }
            steps += 1
        }
        XCTAssertTrue(won)
        XCTAssertEqual(viewModel.stars, 3)
        viewModel.restart()
        XCTAssertTrue(viewModel.showHint())
        XCTAssertEqual(viewModel.stars, 2)
    }
}
