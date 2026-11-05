import XCTest
@testable import NonogramKit

final class YarnTaxiTests: XCTestCase {
    /// İki araba: biri diğerinin önünü kapatıyor. Önü kapalı araba çıkamaz; açılınca durağa gelir,
    /// kendi rengindeki yumaklar biner, dolunca ayrılır.
    func testBlockingBoardingAndDeparture() {
        // A (renk 0) aşağı bakıyor, B (renk 1) altında yatay duruyor ve A'nın yolunu kesiyor
        let a = YarnCar(id: 1, color: 0, row: 0, column: 1, length: 2, direction: .down)
        let b = YarnCar(id: 2, color: 1, row: 2, column: 0, length: 2, direction: .left)
        var game = YarnTaxiGame(rows: 4, columns: 4, cars: [a, b], queue: [1, 1, 1, 1, 0, 0, 0, 0], slots: 3)
        XCTAssertEqual(game.tap(carID: 1), .blocked)
        XCTAssertEqual(game.tap(carID: 2), .moved(boarded: 4, departed: [2]))
        XCTAssertEqual(game.freeSlots, 3)
        XCTAssertEqual(game.tap(carID: 1), .moved(boarded: 4, departed: [1]))
        XCTAssertEqual(game.status, .won)
    }

    /// Durak dolar ve sıranın önü binemezse oyun takılır; ek yer güçlendiricisi kurtarır.
    func testStuckWhenStationFullAndExtraSlot() {
        let cars = [
            YarnCar(id: 1, color: 0, row: 0, column: 0, length: 2, direction: .up),
            YarnCar(id: 2, color: 1, row: 0, column: 1, length: 2, direction: .up),
        ]
        var game = YarnTaxiGame(rows: 3, columns: 2, cars: cars, queue: [1, 1, 1, 1, 0, 0, 0, 0], slots: 1)
        XCTAssertEqual(game.tap(carID: 1), .moved(boarded: 0, departed: []))
        XCTAssertEqual(game.status, .stuck)
        game.addSlot()
        XCTAssertEqual(game.status, .playing)
        XCTAssertEqual(game.tap(carID: 2), .moved(boarded: 8, departed: [2, 1]))
        XCTAssertEqual(game.status, .won)
    }

    func testEveryLevelIsSolvableAndGrowsHarder() {
        var previousCars = 0
        for number in [1, 2, 3, 5, 10, 20, 40, 75, 120, 200, 300] {
            let level = YarnTaxiCatalog.level(number)
            let game = YarnTaxiCatalog.game(for: level)
            XCTAssertEqual(game.lot.count, level.cars, "\(number): araba yerleşmedi")
            XCTAssertEqual(game.queue.count, game.lot.map(\.seats).reduce(0, +), "\(number)")
            XCTAssertNotNil(YarnTaxiSolver.solve(game, nodeLimit: 200_000), "\(number) çözülemedi")
            XCTAssertGreaterThanOrEqual(level.cars, previousCars - 2, "\(number)")
            previousCars = level.cars
        }
        XCTAssertEqual(YarnTaxiCatalog.level(1).colors, 2)
        XCTAssertEqual(YarnTaxiCatalog.level(1).cars, 3)
    }

    /// Bütün bölümler: arabalar sığar, sıra koltuklarla aynı, aynı numara hep aynı bölüm.
    func testAllLevelsAreWellFormedAndDeterministic() {
        for number in 1...YarnTaxiCatalog.levelCount {
            let level = YarnTaxiCatalog.level(number)
            let game = YarnTaxiCatalog.game(for: level)
            XCTAssertEqual(game.lot.count, level.cars, "\(number)")
            let cells = game.lot.flatMap(\.cells)
            XCTAssertEqual(Set(cells).count, cells.count, "\(number): üst üste araba")
            XCTAssertTrue(cells.allSatisfy { (0..<level.rows).contains($0.row) && (0..<level.columns).contains($0.column) })
            XCTAssertEqual(game.queue.count, game.lot.map(\.seats).reduce(0, +), "\(number)")
            XCTAssertEqual(YarnTaxiCatalog.game(for: level), game, "\(number)")
        }
    }

    func testHintLeadsToWin() {
        var game = YarnTaxiCatalog.game(for: YarnTaxiCatalog.level(30))
        var steps = 0
        while game.status == .playing, steps < 200, let car = YarnTaxiSolver.hint(game) {
            game.tap(carID: car)
            steps += 1
        }
        XCTAssertEqual(game.status, .won)
    }

    func testCodableRoundTrip() throws {
        var game = YarnTaxiCatalog.game(for: YarnTaxiCatalog.level(12))
        if let car = YarnTaxiSolver.hint(game) { game.tap(carID: car) }
        let data = try JSONEncoder().encode(game)
        XCTAssertEqual(try JSONDecoder().decode(YarnTaxiGame.self, from: data), game)
    }
}
