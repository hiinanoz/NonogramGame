import Foundation
import NonogramKit

/// Miyav Crush istatistikleri (istatistik satırları ve Game Center için).
struct CrushStats: Codable, Equatable {
    var gamesPlayed = 0
    var wins = 0
    var losses = 0
    var totalScore = 0
    var bestCascade = 0
    var specialsUsed = 0
    var boostersUsed = 0
}

/// Miyav Crush modu: bölüm kataloğu, ilerleme (yıldızlar, güçlendiriciler, rozetler) ve
/// istatistikler. Kayıtlar UserDefaults'ta JSON olarak (küçük ve tek cihazlık veri).
@MainActor
@Observable
final class CrushModel {
    enum Keys {
        static let progress = "crush.progress"
        static let stats = "crush.stats"
        static let introSeen = "crush.introSeen"
    }

    let catalog: CrushCatalog
    private let defaults: UserDefaults

    private(set) var progress: CrushProgress
    private(set) var stats: CrushStats
    /// İlk bölümdeki "nasıl oynanır" kartı gösterildi mi.
    private(set) var hasSeenIntro: Bool

    init(catalog: CrushCatalog = .standard, defaults: UserDefaults) {
        self.catalog = catalog
        self.defaults = defaults
        progress = Self.decode(CrushProgress.self, defaults.data(forKey: Keys.progress)) ?? CrushProgress()
        stats = Self.decode(CrushStats.self, defaults.data(forKey: Keys.stats)) ?? CrushStats()
        hasSeenIntro = defaults.bool(forKey: Keys.introSeen)
    }

    static func inMemory(catalog: CrushCatalog = .standard) -> CrushModel {
        let name = "crush-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return CrushModel(catalog: catalog, defaults: defaults)
    }

    var levels: [CrushLevel] { catalog.levels }

    func level(withID id: String) -> CrushLevel? { catalog.level(withID: id) }

    func number(of level: CrushLevel) -> Int { catalog.number(of: level.id) ?? 1 }

    func level(after level: CrushLevel) -> CrushLevel? { catalog.level(after: level.id) }

    func episode(of level: CrushLevel) -> Int { catalog.episode(containing: level.id) ?? 0 }

    func isUnlocked(_ level: CrushLevel) -> Bool { progress.isUnlocked(level, in: catalog) }

    func stars(for level: CrushLevel) -> Int { progress.stars(for: level.id) }

    var currentLevel: CrushLevel? { progress.currentLevel(in: catalog) }

    var completedCount: Int { progress.completedCount }

    var totalStars: Int { progress.totalStars }

    var maxStars: Int { levels.count * 3 }

    func count(of booster: CrushBooster) -> Int { progress.count(of: booster) }

    // MARK: - Kayıt

    /// Kazanılan bölüm: yıldız, ödüller ve rozetler.
    func recordWin(_ session: CrushSession, frenzyMoves: Int) -> CrushLevelOutcome {
        let outcome = progress.record(
            levelID: session.level.id, score: session.score, stars: session.stars,
            bestCascade: session.bestCascade, frenzyMoves: frenzyMoves, catalog: catalog
        )
        stats.gamesPlayed += 1
        stats.wins += 1
        recordStats(session)
        save()
        return outcome
    }

    func recordLoss(_ session: CrushSession) {
        stats.gamesPlayed += 1
        stats.losses += 1
        recordStats(session)
        save()
    }

    private func recordStats(_ session: CrushSession) {
        stats.totalScore += session.score
        stats.bestCascade = max(stats.bestCascade, session.bestCascade)
        stats.specialsUsed += session.specialsUsed
    }

    /// Güçlendirici harcar; stokta yoksa `false`.
    func use(_ booster: CrushBooster) -> Bool {
        guard progress.use(booster) else { return false }
        stats.boostersUsed += 1
        save()
        return true
    }

    /// Ödüllü reklam ya da hediye.
    func add(_ booster: CrushBooster, count: Int = 1) {
        progress.add(CrushReward(boosters: [booster: count]))
        save()
    }

    func markIntroSeen() {
        hasSeenIntro = true
        defaults.set(true, forKey: Keys.introSeen)
    }

    func reset() {
        progress = CrushProgress()
        stats = CrushStats()
        hasSeenIntro = false
        for key in [Keys.progress, Keys.stats, Keys.introSeen] {
            defaults.removeObject(forKey: key)
        }
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Keys.progress)
        defaults.set(try? JSONEncoder().encode(stats), forKey: Keys.stats)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
