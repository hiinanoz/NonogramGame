import XCTest
@testable import NonogramKit

/// Miyav Crush bölüm ayarı. Bölümlerin şekli, hamlesi, renk sayısı ve hedef türleri aşağıdaki
/// şablonlarda; hedef sayıları ve yıldız eşikleri bir botla simülasyonla bulunur ve
/// `CrushLevels.swift` olarak yazılır. Yeniden üretmek için:
///
///     CRUSH_BALANCE=1 swift test -c release -Xswiftc -enable-testing --filter CrushBalanceTests
///
/// Bot oyuncu çoğunlukla ipucu hamlesini (en çok temizleyen), bazen rastgele bir hamleyi oynar;
/// hedef rengini gözetmez. Gerçek oyuncu daha iyi oynar, bu yüzden oranlar temkinlidir.
final class CrushBalanceTests: XCTestCase {
    enum Kind {
        case score
        case collect(CrushColor)
        case specials
    }

    struct Template {
        let shape: CrushShape
        let moves: Int
        let colors: Int
        let goals: [Kind]
    }

    private static func t(_ shape: CrushShape, _ moves: Int, _ colors: Int, _ goals: Kind...) -> Template {
        Template(shape: shape, moves: moves, colors: colors, goals: goals)
    }

    static let templates: [Template] = [
        // 1. macera: Yumak Bahçesi
        t(.square8, 20, 5, .score),
        t(.square8, 20, 5, .collect(.yarn)),
        t(.catHead, 20, 5, .score),
        t(.square9, 20, 5, .collect(.treat)),
        t(.diamond, 20, 5, .specials),
        t(.heart, 22, 5, .score),
        t(.square9, 20, 5, .collect(.mouse), .collect(.bowl)),
        t(.ring, 22, 5, .collect(.wand)),
        t(.plus, 22, 5, .score),
        t(.square8, 20, 5, .specials),
        t(.catHead, 22, 5, .collect(.yarn), .specials),
        t(.hourglass, 22, 5, .score),
        t(.paw, 22, 5, .collect(.treat), .collect(.mouse)),
        t(.diamond, 22, 5, .collect(.bowl)),
        t(.heart, 25, 5, .collect(.yarn), .collect(.wand), .specials),
        // 2. macera: Mama Mutfağı
        t(.square9, 20, 5, .score),
        t(.ring, 22, 5, .collect(.mouse)),
        t(.plus, 20, 5, .specials),
        t(.catHead, 22, 5, .collect(.wand), .collect(.treat)),
        t(.hourglass, 22, 5, .score),
        t(.square8, 20, 5, .collect(.bowl), .specials),
        t(.paw, 22, 5, .collect(.yarn)),
        t(.diamond, 22, 5, .score),
        t(.heart, 22, 5, .collect(.mouse), .collect(.treat)),
        t(.ring, 22, 5, .specials),
        t(.square9, 20, 5, .collect(.wand), .collect(.bowl), .collect(.yarn)),
        t(.catHead, 22, 5, .score),
        t(.plus, 22, 5, .collect(.treat), .specials),
        t(.hourglass, 22, 5, .collect(.mouse)),
        t(.paw, 25, 5, .collect(.yarn), .collect(.wand), .specials),
        // 3. macera: Fare Deliği
        t(.square9, 25, 6, .score),
        t(.square8, 22, 6, .collect(.paw)),
        t(.heart, 24, 6, .specials),
        t(.diamond, 24, 6, .collect(.yarn), .collect(.paw)),
        t(.ring, 24, 6, .score),
        t(.catHead, 24, 6, .collect(.treat), .specials),
        t(.plus, 24, 6, .collect(.mouse)),
        t(.hourglass, 24, 6, .score),
        t(.paw, 24, 6, .collect(.bowl), .collect(.wand)),
        t(.square9, 22, 6, .specials),
        t(.heart, 24, 6, .collect(.paw), .collect(.yarn), .specials),
        t(.diamond, 24, 6, .score),
        t(.ring, 24, 6, .collect(.treat), .collect(.mouse)),
        t(.catHead, 24, 6, .collect(.wand)),
        t(.square9, 26, 6, .collect(.yarn), .collect(.treat), .collect(.paw)),
        // 4. macera: Çatı Katı
        t(.plus, 22, 6, .score),
        t(.paw, 22, 6, .collect(.mouse), .specials),
        t(.hourglass, 22, 6, .collect(.bowl)),
        t(.heart, 22, 6, .specials),
        t(.square8, 20, 6, .collect(.paw), .collect(.wand)),
        t(.ring, 22, 6, .score),
        t(.diamond, 22, 6, .collect(.yarn), .specials),
        t(.catHead, 22, 6, .collect(.treat), .collect(.bowl)),
        t(.square9, 20, 6, .score),
        t(.plus, 22, 6, .collect(.mouse), .collect(.paw)),
        t(.paw, 22, 6, .specials),
        t(.hourglass, 22, 6, .collect(.wand), .collect(.yarn)),
        t(.heart, 22, 6, .score),
        t(.ring, 22, 6, .collect(.bowl), .collect(.treat), .specials),
        t(.catHead, 25, 6, .collect(.yarn), .collect(.wand), .collect(.paw), .specials),
    ]

    /// Botun kazanma oranı hedefi: ilk bölümlerde neredeyse her zaman, sona doğru üçte iki;
    /// macera sonları (15, 30 …) biraz daha zor.
    static func targetWinRate(_ number: Int) -> Double {
        if number <= 3 { return 0.99 }
        let base = 0.95 - 0.30 * Double(number - 1) / 59
        return number % CrushCatalog.levelsPerEpisode == 0 ? base - 0.08 : base
    }

    // MARK: - Bot

    struct Bot {
        var random: CrushRandom
        mutating func move(in session: CrushSession) -> CrushSwap? {
            let moves = session.engine.possibleMoves()
            if Double.random(in: 0..<1, using: &random) < 0.7, let hint = session.hint() { return hint }
            return moves.randomElement(using: &random)
        }
    }

    // MARK: - Katalog denetimleri (her zaman çalışır)

    func testCatalogMatchesTemplates() {
        let levels = CrushCatalog.standard.levels
        XCTAssertEqual(levels.count, Self.templates.count)
        XCTAssertEqual(Set(levels.map(\.id)).count, levels.count)
        for (level, template) in zip(levels, Self.templates) {
            XCTAssertEqual(level.moves, template.moves, level.id)
            XCTAssertEqual(level.colorCount, template.colors, level.id)
            XCTAssertEqual(level.shape, template.shape.lines, level.id)
            XCTAssertEqual(level.goals.count, template.goals.count, level.id)
            XCTAssertEqual(level.starScores.count, 3, level.id)
            XCTAssertEqual(level.starScores, level.starScores.sorted(), level.id)
            XCTAssertEqual(Set(level.starScores).count, 3, level.id)
            for goal in level.goals {
                XCTAssertGreaterThan(goal.target, 0, level.id)
                if case .collect(let color, _) = goal { XCTAssertTrue(level.colors.contains(color), level.id) }
                if case .score(let target) = goal { XCTAssertEqual(target, level.starScores[0], level.id) }
            }
        }
    }

    func testShapesAreRectangular() {
        for shape in CrushShape.allCases {
            XCTAssertTrue(shape.lines.allSatisfy { $0.count == shape.columns }, shape.rawValue)
        }
    }

    func testEveryLevelStartsPlayable() {
        for level in CrushCatalog.standard.levels {
            let engine = CrushEngine(level: level, seed: 7)
            XCTAssertTrue(CrushEngine.findMatches(in: engine.board).isEmpty, level.id)
            XCTAssertFalse(engine.possibleMoves().isEmpty, level.id)
            XCTAssertTrue(engine.board.playablePositions.allSatisfy { engine.board[$0] != nil }, level.id)
        }
    }

    /// İlk bölüm bot için bile kolay olmalı.
    func testFirstLevelIsEasy() {
        let level = CrushCatalog.standard.levels[0]
        var wins = 0
        for seed in 1...6 {
            var session = CrushSession(level: level, seed: UInt64(seed))
            var bot = Bot(random: CrushRandom(seed: UInt64(seed) * 31))
            while session.status == .playing, let swap = bot.move(in: session) { _ = session.play(swap) }
            if session.status == .won { wins += 1 }
        }
        XCTAssertGreaterThanOrEqual(wins, 5)
    }

    // MARK: - Ayar (yalnızca CRUSH_BALANCE=1)

    func testBalance() throws {
        guard ProcessInfo.processInfo.environment["CRUSH_BALANCE"] != nil else {
            throw XCTSkip("CRUSH_BALANCE=1 ile çalıştırın")
        }
        let runs = Int(ProcessInfo.processInfo.environment["CRUSH_RUNS"] ?? "") ?? 80
        var output: [String] = []
        var report: [String] = []
        let only = Int(ProcessInfo.processInfo.environment["CRUSH_ONLY"] ?? "")
        for (index, template) in Self.templates.enumerated() {
            let number = index + 1
            if let only, only != number { continue }
            let goal = Self.targetWinRate(number)

            // 1. tur: hedefsiz oyun, bütün hamleler; her hedefin son sayacı
            let open = CrushLevel(number: number, shape: template.shape, moves: template.moves,
                                  colors: template.colors, goals: [.score(Int.max)], stars: [1, 2, 3])
            var totals: [[Int]] = []
            for run in 0..<runs {
                let session = play(open, seed: UInt64(1000 * number + run))
                totals.append(template.goals.map { kind in
                    switch kind {
                    case .score: session.score
                    case .collect(let color): session.collected[color, default: 0]
                    case .specials: session.specialsUsed
                    }
                })
            }
            // Bütün hedeflerin birlikte tutma oranı istenen oranın altına düşmeden en zor hedefler
            // (yüzdelik adım adım yükselir; yuvarlama yüzünden oran sıçrayabilir)
            func targetsAt(_ quantile: Double) -> [Int] {
                template.goals.indices.map { g in round(percentile(totals.map { $0[g] }, quantile), kind: template.goals[g]) }
            }
            func rate(_ targets: [Int]) -> Double {
                Double(totals.filter { t in t.indices.allSatisfy { t[$0] >= targets[$0] } }.count) / Double(runs)
            }
            var targets = targetsAt(0)
            var quantile = 0.0
            while quantile < 0.95 {
                quantile += 0.005
                let candidate = targetsAt(quantile)
                if rate(candidate) < goal - 0.015 { break }
                targets = candidate
            }
            if only != nil { print("targets \(targets) rate \(rate(targets))") }
            let goals: [CrushGoal] = zip(template.goals, targets).map { kind, target in
                switch kind {
                case .score: .score(target)
                case .collect(let color): .collect(color, target)
                case .specials: .specials(target)
                }
            }

            // 2. tur: gerçek oyun (Kedi Çılgınlığı dahil); kazanılan oyunların puanı
            let scoreTarget = goals.compactMap { if case .score(let t) = $0 { t } else { nil } }.first
            let trial = CrushLevel(number: number, shape: template.shape, moves: template.moves,
                                   colors: template.colors, goals: goals, stars: [1, 2, 3])
            var scores: [Int] = []
            for run in 0..<runs {
                let session = play(trial, seed: UInt64(5000 * number + run))
                if session.status == .won { scores.append(session.score) }
            }
            let rate = Double(scores.count) / Double(runs)
            var stars = [
                scoreTarget ?? roundScore(percentile(scores, 0.05)),
                roundScore(percentile(scores, 0.55)),
                roundScore(percentile(scores, 0.88)),
            ]
            stars[1] = max(stars[1], stars[0] + 500)
            stars[2] = max(stars[2], stars[1] + 1000)

            let goalText = goals.map(Self.swift).joined(separator: ", ")
            output.append("        CrushLevel(number: \(number), shape: .\(template.shape.rawValue), moves: \(template.moves), colors: \(template.colors), goals: [\(goalText)], stars: \(stars)),")
            report.append(String(format: "%2d  hedef %.2f  bot %.2f  %@  %@", number, goal, rate, goalText, "\(stars)"))
        }
        print("---- RAPOR ----\n" + report.joined(separator: "\n"))
        print("---- SWIFT ----\n" + output.joined(separator: "\n"))
    }

    private func play(_ level: CrushLevel, seed: UInt64) -> CrushSession {
        var session = CrushSession(level: level, seed: seed)
        var bot = Bot(random: CrushRandom(seed: seed &* 7919))
        while session.status == .playing, let swap = bot.move(in: session) { _ = session.play(swap) }
        _ = session.celebrate()
        return session
    }

    private func percentile(_ values: [Int], _ q: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let position = max(0, min(Double(sorted.count - 1), q * Double(sorted.count - 1)))
        return Double(sorted[Int(position.rounded(.down))])
    }

    private func round(_ value: Double, kind: Kind) -> Int {
        switch kind {
        case .score: roundScore(value)
        case .collect: max(5, Int((value / 5).rounded(.down)) * 5)
        case .specials: max(1, Int(value))
        }
    }

    private func roundScore(_ value: Double) -> Int {
        max(500, Int((value / 500).rounded(.down)) * 500)
    }

    private static func swift(_ goal: CrushGoal) -> String {
        switch goal {
        case .score(let target): ".score(\(target))"
        case .collect(let color, let target): ".collect(.\(color), \(target))"
        case .specials(let target): ".specials(\(target))"
        }
    }
}
