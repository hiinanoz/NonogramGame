import Foundation
import NonogramKit
import SwiftUI

/// Kuş Sıralama ilerlemesi: bölüm başına en iyi yıldız ve güçlendiriciler. Bölümler sırayla açılır.
/// Kayıtlar UserDefaults'ta JSON olarak.
struct BirdSortProgress: Codable, Equatable {
    /// Bölüm numarası → en iyi yıldız (1–3).
    var stars: [Int: Int] = [:]
    var hints = 3
    var extraBranches = 2
    var gamesWon = 0
    var movesTotal = 0
}

@MainActor
@Observable
final class BirdSortModel {
    enum Keys {
        static let progress = "birdsort.progress"
        static let introSeen = "birdsort.introSeen"
        static let savedGame = "birdsort.savedGame"
    }

    private let defaults: UserDefaults
    private(set) var progress: BirdSortProgress
    private(set) var hasSeenIntro: Bool
    /// Ada haritasında en son açılan ada (geri dönünce aynı ada).
    var selectedIsland: Int?
    /// Yarıda bırakılan bölüm: geri dönünce kaldığı yerden sürer.
    private(set) var savedGame: BirdSortSession?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        progress = (defaults.data(forKey: Keys.progress)).flatMap { try? JSONDecoder().decode(BirdSortProgress.self, from: $0) }
            ?? BirdSortProgress()
        hasSeenIntro = defaults.bool(forKey: Keys.introSeen)
        savedGame = defaults.data(forKey: Keys.savedGame).flatMap { try? JSONDecoder().decode(BirdSortSession.self, from: $0) }
    }

    func savedSession(for level: Int) -> BirdSortSession? {
        guard let savedGame, savedGame.level.number == level, !savedGame.isWon else { return nil }
        return savedGame
    }

    func saveGame(_ session: BirdSortSession) {
        savedGame = session
        defaults.set(try? JSONEncoder().encode(session), forKey: Keys.savedGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Keys.savedGame)
    }

    static func inMemory() -> BirdSortModel {
        let name = "birdsort-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return BirdSortModel(defaults: defaults)
    }

    var levelCount: Int { BirdSortCatalog.levelCount }

    /// Sıradaki (ilk çözülmemiş) bölüm; hepsi bittiyse sonuncusu.
    var currentLevel: Int {
        var number = 1
        while number <= levelCount, progress.stars[number] != nil { number += 1 }
        return min(number, levelCount)
    }

    var completedCount: Int { progress.stars.count }
    var totalStars: Int { progress.stars.values.reduce(0, +) }

    func stars(for number: Int) -> Int { progress.stars[number] ?? 0 }

    func isUnlocked(_ number: Int) -> Bool { number <= currentLevel }

    /// Ada açık mı: ilk bölümü açıksa.
    func isIslandUnlocked(_ island: Int) -> Bool { isUnlocked(island * BirdSortCatalog.levelsPerIsland + 1) }

    func stars(inIsland island: Int) -> Int {
        let range = islandRange(island)
        return progress.stars.filter { range.contains($0.key) }.values.reduce(0, +)
    }

    func completed(inIsland island: Int) -> Int {
        let range = islandRange(island)
        return progress.stars.keys.filter { range.contains($0) }.count
    }

    func islandRange(_ island: Int) -> ClosedRange<Int> {
        let first = island * BirdSortCatalog.levelsPerIsland + 1
        return first...(first + BirdSortCatalog.levelsPerIsland - 1)
    }

    var currentIsland: Int { (currentLevel - 1) / BirdSortCatalog.levelsPerIsland }

    /// Kazanılan bölüm: en iyi yıldız saklanır. Her 10 bölümde bir ipucu, her 25 bölümde ekstra dal.
    @discardableResult
    func recordWin(level: Int, stars: Int, moves: Int) -> (isFirstWin: Bool, reward: BirdSortReward?) {
        let isFirst = progress.stars[level] == nil
        progress.stars[level] = max(progress.stars[level] ?? 0, min(max(stars, 1), 3))
        progress.gamesWon += 1
        progress.movesTotal += moves
        var reward: BirdSortReward?
        if isFirst {
            if level % 25 == 0 {
                progress.extraBranches += 1
                reward = .extraBranch
            } else if level % 10 == 0 {
                progress.hints += 1
                reward = .hint
            }
        }
        save()
        return (isFirst, reward)
    }

    func useHint() -> Bool {
        guard progress.hints > 0 else { return false }
        progress.hints -= 1
        save()
        return true
    }

    func useExtraBranch() -> Bool {
        guard progress.extraBranches > 0 else { return false }
        progress.extraBranches -= 1
        save()
        return true
    }

    func markIntroSeen() {
        hasSeenIntro = true
        defaults.set(true, forKey: Keys.introSeen)
    }

    func reset() {
        progress = BirdSortProgress()
        hasSeenIntro = false
        selectedIsland = nil
        savedGame = nil
        defaults.removeObject(forKey: Keys.savedGame)
        defaults.removeObject(forKey: Keys.progress)
        defaults.removeObject(forKey: Keys.introSeen)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Keys.progress)
    }
}

enum BirdSortReward: Equatable {
    case hint
    case extraBranch
}

/// Adaların adı, rengi ve görselleri.
struct BirdSortIsland: Identifiable, Hashable {
    let index: Int
    var id: Int { index }

    static let all: [BirdSortIsland] = (0..<BirdSortCatalog.islandCount).map(BirdSortIsland.init)

    var title: LocalizedStringResource {
        switch index {
        case 0: return "Blossom Cove"
        case 1: return "Whispering Woods"
        case 2: return "Palm Oasis"
        case 3: return "Maple Falls"
        case 4: return "Frosty Pines"
        default: return "Moonlight Isle"
        }
    }

    /// Ada haritasındaki çizim ve konum (haritanın oranı olarak).
    var islandImage: String { "birdsort-island-\(index + 1)" }
    var pathImage: String { "birdsort-path-\(index + 1)" }

    var mapPosition: CGPoint {
        let points: [CGPoint] = [
            CGPoint(x: 0.25, y: 0.255), CGPoint(x: 0.75, y: 0.265), CGPoint(x: 0.25, y: 0.445),
            CGPoint(x: 0.74, y: 0.47), CGPoint(x: 0.24, y: 0.665), CGPoint(x: 0.73, y: 0.71),
        ]
        return points[index]
    }

    /// Bu adanın dal görseli.
    var branchImage: String {
        ["branch-2", "branch-1", "branch-5", "branch-3", "branch-4", "branch-11"][index]
    }

    /// Dal görselinde tahtanın üst yüzeyi (görselin boyuna oranı), gövdeden uca 10 noktada
    /// (görselin %10'undan %95'ine). Kuşların ayakları bu çizgiye basar.
    var branchSurface: [CGFloat] {
        [
            [0.36, 0.44, 0.50, 0.57, 0.62, 0.62, 0.60, 0.54, 0.46, 0.42],
            [0.38, 0.44, 0.49, 0.53, 0.57, 0.58, 0.55, 0.49, 0.44, 0.42],
            [0.24, 0.27, 0.30, 0.35, 0.42, 0.43, 0.38, 0.33, 0.30, 0.30],
            [0.30, 0.32, 0.36, 0.42, 0.50, 0.52, 0.50, 0.45, 0.42, 0.42],
            [0.38, 0.46, 0.50, 0.56, 0.62, 0.64, 0.58, 0.52, 0.46, 0.44],
            [0.36, 0.36, 0.36, 0.38, 0.42, 0.45, 0.40, 0.35, 0.33, 0.32],
        ][index]
    }

    /// Yol görselindeki bölüm noktaları (yukarıdan aşağı, görselin oranı olarak). Görsel alt alta
    /// eklenir; her görselde 10 bölüm.
    var pathNodes: [CGPoint] {
        let nodes: [[(Double, Double)]] = [
            [(0.45, 0.05), (0.62, 0.14), (0.76, 0.22), (0.6, 0.32), (0.36, 0.38), (0.55, 0.45), (0.76, 0.53), (0.74, 0.63), (0.55, 0.72), (0.74, 0.86)],
            [(0.62, 0.06), (0.74, 0.16), (0.55, 0.26), (0.28, 0.3), (0.3, 0.4), (0.55, 0.44), (0.78, 0.52), (0.78, 0.6), (0.62, 0.8), (0.74, 0.88)],
            [(0.25, 0.07), (0.6, 0.15), (0.72, 0.25), (0.42, 0.32), (0.25, 0.42), (0.52, 0.5), (0.8, 0.56), (0.8, 0.65), (0.55, 0.72), (0.3, 0.8)],
            [(0.3, 0.06), (0.3, 0.2), (0.45, 0.31), (0.68, 0.37), (0.82, 0.46), (0.85, 0.55), (0.58, 0.61), (0.42, 0.8), (0.28, 0.88), (0.32, 0.96)],
            [(0.2, 0.06), (0.4, 0.18), (0.62, 0.25), (0.22, 0.34), (0.45, 0.46), (0.78, 0.5), (0.8, 0.6), (0.48, 0.7), (0.32, 0.8), (0.6, 0.92)],
            [(0.3, 0.06), (0.32, 0.17), (0.55, 0.24), (0.78, 0.32), (0.75, 0.44), (0.45, 0.51), (0.2, 0.57), (0.38, 0.68), (0.7, 0.77), (0.85, 0.88)],
        ]
        return nodes[index].map { CGPoint(x: $0.0, y: $0.1) }
    }

    var tint: Color {
        [Color(hex: "#F08FB0"), Color(hex: "#5FAF6B"), Color(hex: "#E7A64A"), Color(hex: "#E9763A"),
         Color(hex: "#6FA8D6"), Color(hex: "#8E6BD8")][index]
    }
}
