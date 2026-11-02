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

    /// Bölüm şablonları: macera başına 75 bölüm. Şekil, renk, hamle ve hedef türleri sabit bir
    /// düzenle dönülür; macera içinde ve maceralar boyunca zorluk artar, arada nefes bölümleri var.
    static let levelCount = 300

    static let shapes: [CrushShape] = [.square9, .catHead, .diamond, .heart, .ring, .plus, .hourglass, .paw, .square8]

    /// Kolay başlangıç: ilk 40 bölüm küçük tahtalar ve az renkle başlar, yavaşça büyür.
    static let openingCount = 40

    static func openingTemplate(_ number: Int) -> Template {
        let palette = Array(CrushColor.allCases)
        func color(_ j: Int) -> CrushColor { palette[(number * 3 + j * 2) % 4] }
        let shape: CrushShape
        let colors: Int
        let moves: Int
        let goals: [Kind]
        switch number {
        case 1...3:
            // 5×5 → 6×6, 4 renk, bol hamle, tek ve basit hedef
            shape = number <= 2 ? .square5 : .square6
            colors = 4
            moves = 15
            goals = number == 2 ? [.collect(color(0))] : [.score]
        case 4...10:
            shape = [.square6, .smallHeart, .square7][number % 3]
            colors = number <= 7 ? 4 : 5
            moves = 16 + number % 2
            goals = [[.score], [.collect(color(0))], [.specials]][number % 3]
        case 11...25:
            shape = [.square7, .smallHeart, .square8, .square7, .heart][number % 5]
            colors = 5
            moves = 18 + [0, 2][number % 2]
            switch number % 4 {
            case 0: goals = [.score]
            case 1: goals = [.collect(color(0))]
            case 2: goals = [.specials]
            default: goals = [.collect(color(0)), .collect(color(1))]
            }
        default:
            // 26-40: mevcut şekillere geçiş
            shape = shapes[(number * 4) % shapes.count]
            colors = 5
            moves = 20 + [0, 2, 4, 2][number % 4]
            let palette5 = Array(CrushColor.allCases.prefix(5))
            func c5(_ j: Int) -> CrushColor { palette5[(number * 3 + j * 2) % 5] }
            switch number % 5 {
            case 0: goals = [.score]
            case 1: goals = [.collect(c5(0))]
            case 2: goals = [.specials]
            case 3: goals = [.collect(c5(0)), .collect(c5(1))]
            default: goals = [.collect(c5(0)), .specials]
            }
        }
        return Template(shape: shape, moves: moves, colors: colors, goals: goals)
    }

    static func template(_ number: Int) -> Template {
        if number <= openingCount { return openingTemplate(number) }
        let k = (number - 1) % CrushCatalog.levelsPerEpisode
        let episode = (number - 1) / CrushCatalog.levelsPerEpisode
        let isBoss = k % 15 == 14
        let isBreather = k % 10 == 0
        let shape: CrushShape = shapes[(number * 4 + episode) % shapes.count]
        let colors: Int
        if episode == 0 {
            colors = k < 40 || isBreather ? 5 : 6
        } else {
            colors = isBreather ? 5 : 6
        }
        let moves = isBoss ? 25 : 20 + [0, 2, 4, 2][number % 4]
        let palette = Array(CrushColor.allCases.prefix(colors))
        func color(_ j: Int) -> CrushColor { palette[(number * 3 + j * 2) % palette.count] }
        let goals: [Kind]
        if isBoss {
            goals = [.collect(color(0)), .collect(color(1)), .specials]
        } else {
            switch k % 6 {
            case 0: goals = [.score]
            case 1: goals = [.collect(color(0))]
            case 2: goals = [.specials]
            case 3: goals = [.collect(color(0)), .collect(color(1))]
            case 4: goals = [.collect(color(0)), .specials]
            default: goals = [.collect(color(0)), .collect(color(1))]
            }
        }
        return Template(shape: shape, moves: moves, colors: colors, goals: goals)
    }

    static let templates: [Template] = (1...levelCount).map(template)

    /// Botun kazanma oranı hedefi: ilk bölümlerde neredeyse her zaman, sona doğru üçte iki;
    /// macera sonları (15, 30 …) biraz daha zor.
    static func targetWinRate(_ number: Int) -> Double {
        // Kolay başlangıç: ilk 10 bölümü neredeyse herkes geçer, 40. bölüme kadar yavaşça zorlaşır
        if number <= 10 { return 0.99 }
        if number <= openingCount {
            let t = Double(number - 10) / Double(openingCount - 10)
            return 0.97 - t * (0.97 - legacyWinRate(openingCount + 1))
        }
        return legacyWinRate(number)
    }

    /// 41. bölümden sonrası (önceki ayar): %95'ten %62'ye; macera sonları biraz daha zor.
    static func legacyWinRate(_ number: Int) -> Double {
        let k = (number - 1) % CrushCatalog.levelsPerEpisode
        var rate = 0.95 - 0.33 * Double(number - 1) / Double(levelCount - 1)
        rate += 0.05 * max(0, 1 - Double(k) / 20)
        if k % 15 == 14 { rate -= 0.08 }
        if k % 10 == 0 { rate += 0.05 }
        return min(0.98, rate)
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
        let runs = Int(ProcessInfo.processInfo.environment["CRUSH_RUNS"] ?? "") ?? 100
        var output: [String] = []
        var report: [String] = []
        let only = Int(ProcessInfo.processInfo.environment["CRUSH_ONLY"] ?? "")
        let upTo = Int(ProcessInfo.processInfo.environment["CRUSH_UPTO"] ?? "") ?? Self.levelCount
        for (index, template) in Self.templates.enumerated() {
            let number = index + 1
            if let only, only != number { continue }
            if number > upTo { break }
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
            // Kolay başlangıçta hedefler küçük ve anlaşılır kalır (zincirleme patlamalar sayıları
            // şişirmesin): bölüm numarasıyla yavaşça büyüyen üst sınır
            if number <= Self.openingCount {
                targets = zip(template.goals, targets).map { kind, target in
                    switch kind {
                    case .score: min(target, 1500 + 250 * number - (1500 + 250 * number) % 500)
                    case .collect: min(target, 10 + 5 * (number / 3))
                    case .specials: min(target, 1 + number / 8)
                    }
                }
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
