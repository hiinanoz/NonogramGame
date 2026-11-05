import XCTest
@testable import NonogramKit

/// Yumak Taksi dengelemesi: her bölüm için birkaç dizilim acemi ve akıllı bir botla oynanır;
/// akıllı bot rahatça kazanabilen dizilimler arasından acemi botun kazanma oranı hedefe en yakın
/// olan seçilir ve `YarnTaxiSeeds.swift` olarak yazılır:
///
///     YARN_BALANCE=1 swift test -c release -Xswiftc -enable-testing --filter YarnTaxiBalanceTests
final class YarnTaxiBalanceTests: XCTestCase {
    /// Acemi botun hedef kazanma oranı: ilk 15 bölüm neredeyse hep, sonra %95'ten %35'e;
    /// her mahalle biraz daha kolay başlar, her 5. bölüm nefes.
    static func target(_ number: Int) -> Double {
        if number <= 15 { return 0.99 }
        let local = (number - 1) % YarnTaxiCatalog.levelsPerDistrict
        var rate = 0.95 - 0.6 * Double(number - 16) / Double(YarnTaxiCatalog.levelCount - 16)
        rate += 0.08 * max(0, 1 - Double(local) / 10)
        if (local + 1) % 5 == 0 { rate += 0.1 }
        return min(0.99, rate)
    }

    static func beginnerRate(_ start: YarnTaxiGame, runs: Int) -> Double {
        var wins = 0
        for seed in 0..<runs {
            var random = CrushRandom(seed: UInt64(seed) &+ 99)
            var game = start
            while game.status == .playing {
                let options = game.exitableCars
                let matching = options.filter { $0.color == game.frontColor }
                let pick = (!matching.isEmpty && Double.random(in: 0..<1, using: &random) < 0.7)
                    ? matching.randomElement(using: &random) : options.randomElement(using: &random)
                guard let car = pick else { break }
                game.tap(carID: car.id)
            }
            if game.status == .won { wins += 1 }
        }
        return Double(wins) / Double(runs)
    }

    /// Akıllı bot: sırada rengi en erken gelen, önü açık araba.
    static func smartRate(_ start: YarnTaxiGame, runs: Int) -> Double {
        var wins = 0
        for seed in 0..<runs {
            var random = CrushRandom(seed: UInt64(seed) &+ 7)
            var game = start
            while game.status == .playing {
                let upcoming = Array(game.queue[game.head...])
                let ranked = game.exitableCars.map { car in
                    (car, upcoming.firstIndex(of: car.color) ?? 9999, Int.random(in: 0..<1000, using: &random))
                }
                guard let car = ranked.min(by: { ($0.1, $0.2) < ($1.1, $1.2) })?.0 else { break }
                game.tap(carID: car.id)
            }
            if game.status == .won { wins += 1 }
        }
        return Double(wins) / Double(runs)
    }

    func testBalance() throws {
        guard ProcessInfo.processInfo.environment["YARN_BALANCE"] != nil else { throw XCTSkip("YARN_BALANCE=1 ile çalıştırın") }
        var salts: [Int] = []
        var report: [String] = []
        for number in 1...YarnTaxiCatalog.levelCount {
            let level = YarnTaxiCatalog.level(number)
            let goal = Self.target(number)
            var best: (salt: Int, rate: Double, smart: Double)?
            for salt in 0..<30 {
                let game = YarnTaxiCatalog.game(for: level, salt: salt)
                guard game.lot.count == level.cars else { continue }
                let smart = Self.smartRate(game, runs: 12)
                guard smart >= 0.8 else { continue }
                let rate = Self.beginnerRate(game, runs: 50)
                if best == nil || abs(rate - goal) < abs(best!.rate - goal) { best = (salt, rate, smart) }
                if abs(rate - goal) < 0.04 { break }
            }
            let chosen = best ?? (0, -1, -1)
            salts.append(chosen.salt)
            report.append(String(format: "%3d hedef %.2f acemi %.2f akıllı %.2f", number, goal, chosen.rate, chosen.smart))
        }
        print("---- RAPOR ----\n" + report.joined(separator: "\n"))
        print("---- SALTS ----\n" + salts.map(String.init).joined(separator: ", "))
    }

    func testTargetsDecrease() {
        XCTAssertGreaterThan(Self.target(20), Self.target(290))
    }
}
