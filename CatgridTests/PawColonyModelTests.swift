import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class PawColonyModelTests: XCTestCase {
    func testWinsUnlockAndStoriesOncePerRegion() {
        let model = PawColonyModel.inMemory()
        XCTAssertEqual(model.currentLevel, 1)
        XCTAssertTrue(model.needsStory(for: 1))
        model.markStorySeen(region: 0)
        XCTAssertFalse(model.needsStory(for: 5))
        XCTAssertTrue(model.needsStory(for: 21))
        model.recordWin(level: 1, stars: 3)
        XCTAssertEqual(model.currentLevel, 2)
        XCTAssertEqual(model.totalStars, 3)
    }

    /// İlk bölüm: kedi evinden sahipsiz eve sürüklemek yolu açar, zaman ilerleyince ev kazanılır.
    func testDragToLinkAndWinFirstLevel() {
        let viewModel = PawColonyGameViewModel(level: PawColonyCatalog.level(1))
        var ended: PawColonyGame.Status?
        viewModel.onEnd = { ended = $0 }
        let cat = viewModel.game.nodes.first { $0.owner == .cats }!
        let house = viewModel.game.nodes.first { $0.owner == .neutral }!
        viewModel.dragBegan(at: cat.position)
        viewModel.dragMoved(to: house.position)
        viewModel.dragEnded(at: house.position)
        XCTAssertEqual(viewModel.game.links.count, 1)
        for _ in 0..<1200 where ended == nil { viewModel.tick(0.1) }
        XCTAssertEqual(ended, .won)
        XCTAssertGreaterThanOrEqual(viewModel.stars, 1)
    }

    func testSavedGameRoundTrip() {
        let model = PawColonyModel.inMemory()
        let viewModel = PawColonyGameViewModel(level: PawColonyCatalog.level(6))
        for _ in 0..<30 { viewModel.tick(0.1) }
        model.saveGame(viewModel.savedState)
        XCTAssertEqual(model.savedGame(for: 6)?.game, viewModel.game)
    }
}
