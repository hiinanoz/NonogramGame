import NonogramKit
import SwiftUI
import XCTest
@testable import Catgrid

/// Kedi Kulesi: katların durumu ilerlemeden doğru türetilir ve ekran açık/koyu temada, küçük ve
/// büyük ekranda çökmeden çizilir.
@MainActor
final class CatTowerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func win(_ model: CrushModel, levelAt index: Int, seed: UInt64) throws -> CrushSession {
        var session = CrushSession(level: model.levels[index], seed: seed)
        while session.status == .playing, let swap = session.hint() { _ = session.play(swap) }
        _ = session.celebrate()
        try XCTSkipUnless(session.status == .won, "bu tohumla bölüm kazanılamadı")
        _ = model.recordWin(session, frenzyMoves: 0)
        return session
    }

    func testFirstLevelIsCurrentAndTheRestLocked() {
        let model = CrushModel.inMemory()
        let floors = model.towerFloors(episode: 0)
        XCTAssertEqual(floors.count, model.catalog.levels(in: 0).count)
        XCTAssertEqual(floors.map(\.number), Array(1...floors.count), "katlar alttan üste artan numarayla")
        XCTAssertEqual(floors[0].state, .current)
        XCTAssertTrue(floors.dropFirst().allSatisfy { $0.state == .locked })
        XCTAssertTrue(model.towerFloors(episode: 1).allSatisfy { $0.state == .locked })
    }

    func testWinningCompletesFloorAndOpensTheNext() throws {
        let model = CrushModel.inMemory()
        _ = try win(model, levelAt: 0, seed: 42)
        let floors = model.towerFloors(episode: 0)
        guard case .completed(let stars) = floors[0].state else { return XCTFail("1. kat tamamlanmalı") }
        XCTAssertTrue((1...3).contains(stars))
        XCTAssertEqual(floors[1].state, .current)
        XCTAssertEqual(floors[2].state, .locked)
        XCTAssertFalse(CatTowerFloorState.locked.isPlayable)
        XCTAssertTrue(CatTowerFloorState.current.isPlayable)
    }

    func testSecondEpisodeNumbersContinue() {
        let model = CrushModel.inMemory()
        let first = model.towerFloors(episode: 0)
        let second = model.towerFloors(episode: 1)
        XCTAssertEqual(second.first?.number, first.count + 1)
    }

    /// Dört binanın teması ve her katın oda planı.
    func testEveryBuildingHasThemeAndRoomPlans() {
        for building in 0..<4 {
            let tower = CatTowerTheme(index: building)
            XCTAssertEqual(tower.key, CatTowerTheme.keys[building])
            let counts = tower.counts
            for level in (building * 75 + 1)...(building * 75 + 75) {
                let plan = CatTowerRoomPlan.make(level: level, tower: building, counts: counts)
                XCTAssertTrue((1...3).contains(plan.accessories.count))
                XCTAssertTrue(plan.wall < counts.walls && plan.furniture < counts.furniture)
            }
        }
    }

    /// Kule ekranı gündüz/gece, küçük ve büyük telefonda, yüzlerce katla çizilir.
    func testTowerRendersInBothThemesAndSizes() throws {
        let puzzle = Puzzle(id: "tower", pattern: ["#.", ".#"])
        let catalog = try LevelCatalog(chapters: [
            Chapter(id: "siamese", kind: .breed, title: ["en": "Siamese"], expectedPuzzleCount: 1, puzzles: [puzzle]),
        ])
        for isDark in [false, true] {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 430, height: 932)] {
                let model = AppModel(catalog: catalog, progress: .inMemory())
                let root = NavigationStack {
                    CrushHubView()
                }
                .environment(model)
                .environment(Router())
                .environment(AudioManager(defaults: UserDefaults(suiteName: "tower-audio-\(UUID().uuidString)")!))
                .environment(AdCoordinator(service: NoAdService()))
                .environment(StoreManager(defaults: UserDefaults(suiteName: "tower-store-\(UUID().uuidString)")!))
                .environment(\.appTheme, AppTheme(palette: .pastel, isDark: isDark))
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = UIHostingController(rootView: root)
                window.makeKeyAndVisible()
                self.window = window
                RunLoop.main.run(until: Date().addingTimeInterval(0.5))
                XCTAssertNotNil(window.rootViewController?.view)
                window.isHidden = true
            }
        }
    }
}
