import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class BirdSortModelTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "birdsort-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testWinsUnlockInOrderAndPersist() {
        let defaults = makeDefaults()
        let model = BirdSortModel(defaults: defaults)
        XCTAssertEqual(model.currentLevel, 1)
        XCTAssertFalse(model.isUnlocked(2))
        XCTAssertFalse(model.isIslandUnlocked(1))
        model.recordWin(level: 1, stars: 3, moves: 12)
        XCTAssertEqual(model.currentLevel, 2)
        XCTAssertTrue(model.isUnlocked(2))
        // Daha kötü tekrar en iyi yıldızı düşürmez
        model.recordWin(level: 1, stars: 1, moves: 40)
        XCTAssertEqual(model.stars(for: 1), 3)
        let reloaded = BirdSortModel(defaults: defaults)
        XCTAssertEqual(reloaded.currentLevel, 2)
        XCTAssertEqual(reloaded.totalStars, 3)
    }

    func testIslandUnlocksAfterSeventyFiveLevelsAndRewards() {
        let model = BirdSortModel(defaults: makeDefaults())
        let hints = model.progress.hints
        let branches = model.progress.extraBranches
        for level in 1...BirdSortCatalog.levelsPerIsland {
            model.recordWin(level: level, stars: 2, moves: 20)
        }
        XCTAssertTrue(model.isIslandUnlocked(1))
        XCTAssertEqual(model.currentIsland, 1)
        XCTAssertEqual(model.completed(inIsland: 0), BirdSortCatalog.levelsPerIsland)
        XCTAssertEqual(model.stars(inIsland: 0), BirdSortCatalog.levelsPerIsland * 2)
        // Her 10 bölümde ipucu (25'in katları hariç), her 25 bölümde ekstra dal
        XCTAssertEqual(model.progress.hints, hints + 6)
        XCTAssertEqual(model.progress.extraBranches, branches + 3)
        XCTAssertTrue(model.useHint())
        model.reset()
        XCTAssertEqual(model.currentLevel, 1)
    }

    func testViewModelPlaysALevelToTheEnd() async {
        let viewModel = BirdSortGameViewModel(level: BirdSortCatalog.level(1))
        await viewModel.load()
        XCTAssertNotNil(viewModel.session)
        XCTAssertEqual(viewModel.birds.count, viewModel.level.sets * viewModel.level.capacity)
        var won = false
        viewModel.onWin = { won = true }
        // Çözüm bir kez hesaplanır ve sırayla oynanır (her hamlede yeniden çözmek ileri geri
        // aynı hamlelere dönebilir)
        guard let board = viewModel.session?.board, let solution = BirdSortSolver.solve(board) else {
            return XCTFail("çözüm yok")
        }
        for (index, move) in solution.moves.enumerated() {
            viewModel.tap(branch: move.source)
            viewModel.tap(branch: move.target)
            var waited = 0
            while (viewModel.isAnimating || (viewModel.session?.moves ?? 0) < index + 1), waited < 100 {
                try? await Task.sleep(for: .milliseconds(50))
                waited += 1
            }
            XCTAssertEqual(viewModel.session?.moves, index + 1, "hamle \(index) oynanmadı")
        }
        XCTAssertTrue(viewModel.isWon)
        XCTAssertTrue(won)
        XCTAssertTrue(viewModel.birds.isEmpty)
        XCTAssertTrue((1...3).contains(viewModel.stars))
    }
}
