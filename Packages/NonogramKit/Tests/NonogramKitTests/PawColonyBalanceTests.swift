import XCTest
@testable import NonogramKit

/// Pati Kolonisi dengelemesi: her bölüm için farelerin zorluğu ve fazladan ev sayısı denenir;
/// acemi botun kazanma oranı hedefe en yakın, iyi botun en az hedef kadar kazandığı ayar seçilir:
///
///     PAW_BALANCE=1 swift test -c release -Xswiftc -enable-testing --filter PawColonyBalanceTests
final class PawColonyBalanceTests: XCTestCase {
    static func target(_ number: Int) -> Double {
        if number <= 10 { return 0.95 }
        let local = (number - 1) % PawColonyCatalog.levelsPerRegion
        var rate = 0.92 - 0.5 * Double(number - 11) / Double(PawColonyCatalog.levelCount - 11)
        rate += 0.08 * max(0, 1 - Double(local) / 4)
        if number % PawColonyCatalog.levelsPerRegion == 0 { rate -= 0.12 }
        return min(0.95, max(0.3, rate))
    }

    static func winRate(_ level: PawColonyLevel, skill: Double, runs: Int) -> Double {
        var wins = 0
        for seed in 0..<runs {
            var game = PawColonyCatalog.game(for: level)
            var bot = PawColonyBot(skill: skill, seed: UInt64(seed) &+ 17)
            bot.play(&game, seconds: 360)
            if game.status == .won { wins += 1 }
        }
        return Double(wins) / Double(runs)
    }

    func testBalance() throws {
        guard ProcessInfo.processInfo.environment["PAW_BALANCE"] != nil else { throw XCTSkip("PAW_BALANCE=1 ile çalıştırın") }
        var table: [String] = ["(0, 0)", "(0, 0)", "(0, 0)"]
        var report: [String] = []
        for number in 4...PawColonyCatalog.levelCount {
            let goal = Self.target(number)
            let isBoss = number % PawColonyCatalog.levelsPerRegion == 0
            var best: (extra: Int, level: Double, rate: Double, good: Double)?
            for extra in (isBoss || number > 30 ? [0, 1] : [0]) {
                for step in 1...10 {
                    let miceLevel = Double(step) / 10
                    let level = PawColonyCatalog.level(number, extraMice: extra, miceLevel: miceLevel)
                    let rate = Self.winRate(level, skill: 0.3, runs: 12)
                    let good = Self.winRate(level, skill: 0.8, runs: 6)
                    let score = abs(rate - goal) + (good + 0.1 < rate ? 0.2 : 0)
                    let bestScore = best.map { abs($0.rate - goal) + ($0.good + 0.1 < $0.rate ? 0.2 : 0) } ?? .infinity
                    if score < bestScore { best = (extra, miceLevel, rate, good) }
                    if rate < goal - 0.3 { break }
                }
            }
            let chosen = best!
            table.append("(\(chosen.extra), \(chosen.level))")
            report.append(String(format: "%3d hedef %.2f acemi %.2f iyi %.2f +%d fare zorluk %.1f", number, goal, chosen.rate, chosen.good, chosen.extra, chosen.level))
        }
        print("---- RAPOR ----\n" + report.joined(separator: "\n"))
        print("---- TABLO ----\n" + table.joined(separator: ", "))
    }
}
