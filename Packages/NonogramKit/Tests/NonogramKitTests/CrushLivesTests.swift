import XCTest
@testable import NonogramKit

final class CrushLivesTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private func minutes(_ m: Double) -> Date { start.addingTimeInterval(m * 60) }

    func testStartsFullAndUsesOne() {
        var lives = CrushLives()
        XCTAssertEqual(lives.count(at: start), 5)
        XCTAssertNil(lives.timeToNextLife(at: start))
        XCTAssertTrue(lives.use(at: start))
        XCTAssertEqual(lives.count(at: start), 4)
        XCTAssertEqual(lives.timeToNextLife(at: start), 30 * 60)
    }

    func testRefillsOneEveryThirtyMinutes() {
        var lives = CrushLives()
        for _ in 0..<5 { XCTAssertTrue(lives.use(at: start)) }
        XCTAssertFalse(lives.use(at: minutes(1)))
        XCTAssertEqual(lives.count(at: minutes(29)), 0)
        XCTAssertEqual(lives.count(at: minutes(30)), 1)
        XCTAssertEqual(lives.count(at: minutes(75)), 2)
        XCTAssertEqual(lives.timeToNextLife(at: minutes(75)), 15 * 60)
        XCTAssertEqual(lives.count(at: minutes(500)), 5)
        XCTAssertNil(lives.timeToNextLife(at: minutes(500)))
    }

    func testUsingWhileRefillingKeepsTheClock() {
        var lives = CrushLives()
        XCTAssertTrue(lives.use(at: start))
        XCTAssertTrue(lives.use(at: minutes(10)))
        // İlk can 30. dakikada döner (sayaç ilk harcamadan başladı)
        XCTAssertEqual(lives.count(at: minutes(30)), 4)
        XCTAssertEqual(lives.count(at: minutes(60)), 5)
    }

    func testRefundAndAdsCapAtFive() {
        var lives = CrushLives()
        XCTAssertTrue(lives.use(at: start))
        lives.add(at: minutes(1))
        XCTAssertEqual(lives.count(at: minutes(1)), 5)
        XCTAssertNil(lives.timeToNextLife(at: minutes(1)))
        lives.add(3, at: minutes(2))
        XCTAssertEqual(lives.count(at: minutes(2)), 5)
    }

    func testClockGoingBackwardDoesNotGrantLives() {
        var lives = CrushLives()
        XCTAssertTrue(lives.use(at: start))
        XCTAssertEqual(lives.count(at: minutes(-120)), 4)
    }

    func testRoundTripsThroughJSON() throws {
        var lives = CrushLives()
        _ = lives.use(at: start)
        let data = try JSONEncoder().encode(lives)
        XCTAssertEqual(try JSONDecoder().decode(CrushLives.self, from: data), lives)
    }
}
