import Foundation
import NonogramKit

/// Pati Kolonisi ilerlemesi: bölüm başına en iyi yıldız ve okunan hikâye kartları.
struct PawColonyProgress: Codable, Equatable {
    var stars: [Int: Int] = [:]
    /// Hikâyesi gösterilmiş bölgeler.
    var storiesSeen: Set<Int> = []
    var gamesWon = 0
}

struct PawColonySavedGame: Codable, Equatable {
    let level: Int
    let game: PawColonyGame
}

@MainActor
@Observable
final class PawColonyModel {
    enum Keys {
        static let progress = "pawcolony.progress"
        static let savedGame = "pawcolony.savedGame"
        static let rulesSeen = "pawcolony.rulesSeen"
    }

    private let defaults: UserDefaults
    private(set) var progress: PawColonyProgress
    private(set) var savedGame: PawColonySavedGame?
    var selectedRegion: Int?
    /// Görsel kural kartı gösterildi mi (1. bölümde bir kez; "?" ile her zaman açılır).
    private(set) var hasSeenRules: Bool

    init(defaults: UserDefaults) {
        self.defaults = defaults
        progress = defaults.data(forKey: Keys.progress).flatMap { try? JSONDecoder().decode(PawColonyProgress.self, from: $0) }
            ?? PawColonyProgress()
        savedGame = defaults.data(forKey: Keys.savedGame).flatMap { try? JSONDecoder().decode(PawColonySavedGame.self, from: $0) }
        hasSeenRules = defaults.bool(forKey: Keys.rulesSeen)
    }

    func markRulesSeen() {
        hasSeenRules = true
        defaults.set(true, forKey: Keys.rulesSeen)
    }

    static func inMemory() -> PawColonyModel {
        let name = "pawcolony-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return PawColonyModel(defaults: defaults)
    }

    var levelCount: Int { PawColonyCatalog.levelCount }

    var currentLevel: Int {
        var number = 1
        while number <= levelCount, progress.stars[number] != nil { number += 1 }
        return min(number, levelCount)
    }

    var completedCount: Int { progress.stars.count }
    var totalStars: Int { progress.stars.values.reduce(0, +) }
    var currentRegion: Int { (currentLevel - 1) / PawColonyCatalog.levelsPerRegion }

    func stars(for number: Int) -> Int { progress.stars[number] ?? 0 }
    func isUnlocked(_ number: Int) -> Bool { number <= currentLevel }

    func regionRange(_ region: Int) -> ClosedRange<Int> {
        let first = region * PawColonyCatalog.levelsPerRegion + 1
        return first...(first + PawColonyCatalog.levelsPerRegion - 1)
    }

    func isRegionUnlocked(_ region: Int) -> Bool { isUnlocked(regionRange(region).lowerBound) }

    /// Bölgenin hikâyesi henüz gösterilmediyse (bölgenin ilk bölümü açılırken).
    func needsStory(for level: Int) -> Bool {
        let region = (level - 1) / PawColonyCatalog.levelsPerRegion
        return !progress.storiesSeen.contains(region)
    }

    func markStorySeen(region: Int) {
        progress.storiesSeen.insert(region)
        save()
    }

    func recordWin(level: Int, stars: Int) {
        progress.stars[level] = max(progress.stars[level] ?? 0, min(max(stars, 1), 3))
        progress.gamesWon += 1
        save()
    }

    func savedGame(for level: Int) -> PawColonySavedGame? {
        guard let savedGame, savedGame.level == level, savedGame.game.status == .playing else { return nil }
        return savedGame
    }

    func saveGame(_ game: PawColonySavedGame) {
        savedGame = game
        defaults.set(try? JSONEncoder().encode(game), forKey: Keys.savedGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Keys.savedGame)
    }

    func reset() {
        progress = PawColonyProgress()
        selectedRegion = nil
        clearSavedGame()
        hasSeenRules = false
        defaults.removeObject(forKey: Keys.progress)
        defaults.removeObject(forKey: Keys.rulesSeen)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Keys.progress)
    }
}

/// Bölgeler ve hikâyeleri: Muffin'in mahallesini fareler ele geçirmiş; kediler evleri yün
/// yollarıyla birbirine bağlayıp mahalleyi geri alır. Fare liderleri yenilince dostlaşır.
struct PawColonyRegion: Identifiable, Hashable {
    let index: Int
    var id: Int { index }

    static let all: [PawColonyRegion] = (0..<PawColonyCatalog.regionCount).map(PawColonyRegion.init)

    var title: LocalizedStringResource {
        switch index {
        case 0: "Muffin's Garden"
        case 1: "Cheese Alley"
        case 2: "Rooftop Town"
        case 3: "Old Mill"
        default: "Mouse Castle"
        }
    }

    /// Bölge başında Muffin'in anlattığı kısa hikâye.
    var story: LocalizedStringResource {
        switch index {
        case 0: "Oh no! While we napped, the mice moved into our houses. Let's link the houses with yarn paths and bring the cats home!"
        case 1: "Captain Squeak guards Cheese Alley. Big houses can open more paths. Grow first, then strike!"
        case 2: "The mice ran up to the rooftops. Swipe across a path to cut it: the cats on it rush forward."
        case 3: "Miller Mouse hides in the Old Mill with his whole family. Help your weak houses before they fall!"
        default: "King Whiskerless waits in Mouse Castle. Win this and the mice become our friends again!"
        }
    }

    /// Fare liderinin adı (bölgenin son bölümü).
    var boss: LocalizedStringResource {
        switch index {
        case 0: "Little Nibbles"
        case 1: "Captain Squeak"
        case 2: "Roof Rascal"
        case 3: "Miller Mouse"
        default: "King Whiskerless"
        }
    }
}
