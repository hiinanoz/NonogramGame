import Foundation
import NonogramKit

/// Yumak Taksi ilerlemesi: bölüm başına en iyi yıldız ve yardımcılar. Bölümler sırayla açılır.
struct YarnTaxiProgress: Codable, Equatable {
    /// Bölüm numarası → en iyi yıldız (1–3).
    var stars: [Int: Int] = [:]
    var hints = 3
    var extraSlots = 2
    var gamesWon = 0
}

/// Yarıda bırakılan bölüm: geri dönünce kaldığı yerden sürer.
struct YarnTaxiSavedGame: Codable, Equatable {
    let level: Int
    let game: YarnTaxiGame
    let boostersUsed: Int
}

@MainActor
@Observable
final class YarnTaxiModel {
    enum Keys {
        static let progress = "yarntaxi.progress"
        static let introSeen = "yarntaxi.introSeen"
        static let savedGame = "yarntaxi.savedGame"
    }

    private let defaults: UserDefaults
    private(set) var progress: YarnTaxiProgress
    private(set) var hasSeenIntro: Bool
    private(set) var savedGame: YarnTaxiSavedGame?
    /// Haritada en son bakılan mahalle.
    var selectedDistrict: Int?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        progress = defaults.data(forKey: Keys.progress).flatMap { try? JSONDecoder().decode(YarnTaxiProgress.self, from: $0) }
            ?? YarnTaxiProgress()
        hasSeenIntro = defaults.bool(forKey: Keys.introSeen)
        savedGame = defaults.data(forKey: Keys.savedGame).flatMap { try? JSONDecoder().decode(YarnTaxiSavedGame.self, from: $0) }
    }

    static func inMemory() -> YarnTaxiModel {
        let name = "yarntaxi-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return YarnTaxiModel(defaults: defaults)
    }

    var levelCount: Int { YarnTaxiCatalog.levelCount }

    /// Sıradaki (ilk çözülmemiş) bölüm; hepsi bittiyse sonuncusu.
    var currentLevel: Int {
        var number = 1
        while number <= levelCount, progress.stars[number] != nil { number += 1 }
        return min(number, levelCount)
    }

    var completedCount: Int { progress.stars.count }
    var totalStars: Int { progress.stars.values.reduce(0, +) }
    var currentDistrict: Int { (currentLevel - 1) / YarnTaxiCatalog.levelsPerDistrict }

    func stars(for number: Int) -> Int { progress.stars[number] ?? 0 }
    func isUnlocked(_ number: Int) -> Bool { number <= currentLevel }

    func districtRange(_ district: Int) -> ClosedRange<Int> {
        let first = district * YarnTaxiCatalog.levelsPerDistrict + 1
        return first...(first + YarnTaxiCatalog.levelsPerDistrict - 1)
    }

    func stars(inDistrict district: Int) -> Int {
        let range = districtRange(district)
        return progress.stars.filter { range.contains($0.key) }.values.reduce(0, +)
    }

    func isDistrictUnlocked(_ district: Int) -> Bool { isUnlocked(districtRange(district).lowerBound) }

    /// Kazanılan bölüm. Her 10 bölümde bir ipucu, her 25 bölümde ek durak yeri.
    @discardableResult
    func recordWin(level: Int, stars: Int) -> YarnTaxiReward? {
        let isFirst = progress.stars[level] == nil
        progress.stars[level] = max(progress.stars[level] ?? 0, min(max(stars, 1), 3))
        progress.gamesWon += 1
        var reward: YarnTaxiReward?
        if isFirst {
            if level % 25 == 0 {
                progress.extraSlots += 1
                reward = .extraSlot
            } else if level % 10 == 0 {
                progress.hints += 1
                reward = .hint
            }
        }
        save()
        return reward
    }

    func useHint() -> Bool {
        guard progress.hints > 0 else { return false }
        progress.hints -= 1
        save()
        return true
    }

    func useExtraSlot() -> Bool {
        guard progress.extraSlots > 0 else { return false }
        progress.extraSlots -= 1
        save()
        return true
    }

    func markIntroSeen() {
        hasSeenIntro = true
        defaults.set(true, forKey: Keys.introSeen)
    }

    func savedGame(for level: Int) -> YarnTaxiSavedGame? {
        guard let savedGame, savedGame.level == level, savedGame.game.status == .playing else { return nil }
        return savedGame
    }

    func saveGame(_ game: YarnTaxiSavedGame) {
        savedGame = game
        defaults.set(try? JSONEncoder().encode(game), forKey: Keys.savedGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Keys.savedGame)
    }

    func reset() {
        progress = YarnTaxiProgress()
        hasSeenIntro = false
        selectedDistrict = nil
        clearSavedGame()
        defaults.removeObject(forKey: Keys.progress)
        defaults.removeObject(forKey: Keys.introSeen)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Keys.progress)
    }
}

enum YarnTaxiReward: Equatable {
    case hint
    case extraSlot
}

/// Mahalleler: ad ve renk.
struct YarnTaxiDistrict: Identifiable, Hashable {
    let index: Int
    var id: Int { index }

    static let all: [YarnTaxiDistrict] = (0..<YarnTaxiCatalog.districtCount).map(YarnTaxiDistrict.init)

    var title: LocalizedStringResource {
        switch index {
        case 0: "Yarn Lane"
        case 1: "Whisker Market"
        case 2: "Purr Harbor"
        default: "Moonlight Hills"
        }
    }
}
