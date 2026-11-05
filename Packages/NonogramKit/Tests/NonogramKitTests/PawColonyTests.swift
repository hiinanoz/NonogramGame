import XCTest
@testable import NonogramKit

/// Oyuncuyu taklit eden bot (testlerde ve dengelemede): saniyede bir, boş yolu olan her evden
/// alabileceği en yakın evi hedefler; zayıflayan saldırıyı keser. `skill` 0-1: karar sıklığı ve
/// hedef seçme özeni.
struct PawColonyBot {
    var skill: Double
    var random: CrushRandom
    private var clock = 0.0

    init(skill: Double, seed: UInt64) {
        self.skill = skill
        random = CrushRandom(seed: seed)
    }

    mutating func play(_ game: inout PawColonyGame, seconds: Double) {
        var elapsed = 0.0
        while elapsed < seconds, game.status == .playing {
            game.advance(0.5)
            elapsed += 0.5
            clock += 0.5
            guard clock >= 2.0 - skill * 1.2 else { continue }
            clock = 0
            think(&game)
        }
    }

    private mutating func think(_ game: inout PawColonyGame) {
        for source in game.nodes where source.owner == .cats {
            let out = game.outgoing(from: source.id)
            if source.count < 3, let link = out.first(where: { game.node($0.to)?.owner != .cats }) {
                game.cut(linkID: link.id, at: 0.9)
                continue
            }
            guard out.count < source.maxLinks else { continue }
            let options = game.nodes.filter { target in
                target.id != source.id && !out.contains { $0.to == target.id }
            }.map { target -> (PawNode, Double) in
                let cost = source.position.distance(to: target.position) * PawColonyGame.costPerLength
                var score: Double
                switch target.owner {
                case .neutral: score = source.count - cost - 3 - target.count * skill * 0.5
                case .mice: score = source.count - cost - target.count * (0.9 - skill * 0.4) + (source.count > 60 ? 30 : 0)
                case .cats: score = target.count < 8 && source.count > 25 ? 5 : -100
                }
                score += Double.random(in: -8...8, using: &random) * (1 - skill)
                return (target, score)
            }
            if let best = options.max(by: { $0.1 < $1.1 }), best.1 > 0 {
                game.link(from: source.id, to: best.0.id)
            }
        }
    }
}

final class PawColonyTests: XCTestCase {
    func testLinkCostsCatsThenCapturesNeutral() {
        let cat = PawNode(id: 1, position: PawPoint(x: 0.5, y: 0.9), owner: .cats, count: 40)
        let house = PawNode(id: 2, position: PawPoint(x: 0.5, y: 0.5), owner: .neutral, count: 5)
        var game = PawColonyGame(nodes: [cat, house], miceLevel: 0)
        XCTAssertTrue(game.link(from: 1, to: 2))
        XCTAssertFalse(game.link(from: 1, to: 2), "aynı hedefe ikinci yol yok")
        game.advance(0.5)
        XCTAssertLessThan(game.node(1)!.count, 40, "uzayan yol kedi harcar")
        game.advance(10)
        XCTAssertEqual(game.node(2)?.owner, .cats)
        XCTAssertEqual(game.status, .won)
    }

    func testCuttingSendsTheRestToTheTarget() {
        let cat = PawNode(id: 1, position: PawPoint(x: 0.5, y: 0.9), owner: .cats, count: 60)
        let house = PawNode(id: 2, position: PawPoint(x: 0.5, y: 0.1), owner: .neutral, count: 50)
        var game = PawColonyGame(nodes: [cat, house], miceLevel: 0)
        game.link(from: 1, to: 2)
        game.advance(2.4)
        XCTAssertEqual(game.links.first?.state, .connected)
        let before = game.node(2)!.count
        game.cut(linkID: game.links[0].id, at: 0.0)
        XCTAssertLessThan(game.node(2)!.count, before - 15, "kesilen yol hedefe saldırır")
        game.advance(5)
        XCTAssertTrue(game.links.isEmpty)
    }

    func testMaxLinksGrowWithCount() {
        XCTAssertEqual(PawNode(id: 1, position: PawPoint(x: 0, y: 0), owner: .cats, count: 10).maxLinks, 1)
        XCTAssertEqual(PawNode(id: 1, position: PawPoint(x: 0, y: 0), owner: .cats, count: 20).maxLinks, 2)
        XCTAssertEqual(PawNode(id: 1, position: PawPoint(x: 0, y: 0), owner: .cats, count: 45).maxLinks, 3)
    }

    func testOpposingLinksClashInTheMiddle() {
        let cat = PawNode(id: 1, position: PawPoint(x: 0.5, y: 0.9), owner: .cats, count: 50)
        let mouse = PawNode(id: 2, position: PawPoint(x: 0.5, y: 0.1), owner: .mice, count: 50)
        var game = PawColonyGame(nodes: [cat, mouse], miceLevel: 0)
        game.link(from: 1, to: 2)
        game.link(from: 2, to: 1, owner: .mice)
        game.advance(4)
        XCTAssertTrue(game.links.allSatisfy { abs($0.reach - $0.length / 2) < 0.01 })
        XCTAssertEqual(game.node(1)?.owner, .cats)
        XCTAssertEqual(game.node(2)?.owner, .mice)
    }

    func testLevelsAreWellFormedAndDeterministic() throws {
        for number in 1...PawColonyCatalog.levelCount {
            let level = PawColonyCatalog.level(number)
            let game = PawColonyCatalog.game(for: level)
            XCTAssertEqual(game.nodes.count, level.cats + level.mice + level.neutrals)
            XCTAssertEqual(PawColonyCatalog.game(for: level), game)
            XCTAssertTrue(game.nodes.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
        }
        XCTAssertEqual(PawColonyCatalog.level(1).mice, 0)
        XCTAssertGreaterThan(PawColonyCatalog.level(4).mice, 0)
        let data = try JSONEncoder().encode(PawColonyCatalog.game(for: PawColonyCatalog.level(30)))
        XCTAssertEqual(try JSONDecoder().decode(PawColonyGame.self, from: data), PawColonyCatalog.game(for: PawColonyCatalog.level(30)))
    }

    func testFirstLevelsAreWonByAnyPlayer() {
        for number in 1...5 {
            var game = PawColonyCatalog.game(for: PawColonyCatalog.level(number))
            var bot = PawColonyBot(skill: 0.3, seed: UInt64(number))
            bot.play(&game, seconds: 300)
            XCTAssertEqual(game.status, .won, "\(number)")
        }
    }
}
