import XCTest
@testable import NonogramKit

final class CatTowerRoomsTests: XCTestCase {
    private let counts = CatTowerRoomPlan.Counts(walls: 3, windows: 3, floors: 3, furniture: 3, accessories: 5, cats: 5)

    func testSameFloorAlwaysLooksTheSame() {
        for level in [1, 7, 150, 300] {
            XCTAssertEqual(CatTowerRoomPlan.make(level: level, tower: level / 76, counts: counts),
                           CatTowerRoomPlan.make(level: level, tower: level / 76, counts: counts))
        }
    }

    func testEveryRoomHasFurnitureCatAndOneToThreeDistinctAccessories() {
        for level in 1...300 {
            let plan = CatTowerRoomPlan.make(level: level, tower: (level - 1) / 75, counts: counts)
            XCTAssertTrue((0..<3).contains(plan.wall))
            XCTAssertTrue((0..<3).contains(plan.window))
            XCTAssertTrue((0..<3).contains(plan.furniture))
            XCTAssertTrue((0..<5).contains(plan.cat))
            XCTAssertTrue((1...3).contains(plan.accessories.count), "\(level)")
            XCTAssertEqual(Set(plan.accessories.values).count, plan.accessories.count, "aksesuarlar farklı")
            XCTAssertTrue(plan.accessories.values.allSatisfy { (0..<5).contains($0) })
        }
    }

    func testNeighboursDifferMostOfTheTime() {
        var same = 0
        for level in 2...300 {
            let tower = (level - 1) / 75
            let a = CatTowerRoomPlan.make(level: level - 1, tower: tower, counts: counts)
            let b = CatTowerRoomPlan.make(level: level, tower: tower, counts: counts)
            if a.wall == b.wall && a.furniture == b.furniture && a.cat == b.cat { same += 1 }
        }
        XCTAssertLessThan(same, 5)
    }

    func testSpecialAndMilestoneFloors() {
        XCTAssertEqual(CatTowerRoomPlan.kind(of: 4), .normal)
        XCTAssertEqual(CatTowerRoomPlan.kind(of: 5), .special)
        XCTAssertEqual(CatTowerRoomPlan.kind(of: 15), .milestone)
        XCTAssertEqual(CatTowerRoomPlan.kind(of: 30), .milestone)
        XCTAssertEqual(CatTowerRoomPlan.make(level: 15, tower: 0, counts: counts).accessories.count, 3)
        XCTAssertGreaterThanOrEqual(CatTowerRoomPlan.make(level: 10, tower: 0, counts: counts).accessories.count, 2)
    }

    func testSmallAssetSetsStillWork() {
        let tiny = CatTowerRoomPlan.Counts(walls: 1, windows: 1, floors: 1, furniture: 1, accessories: 1, cats: 1)
        let plan = CatTowerRoomPlan.make(level: 15, tower: 0, counts: tiny)
        XCTAssertEqual(plan.accessories.count, 1)
        XCTAssertEqual(plan.wall, 0)
    }
}
