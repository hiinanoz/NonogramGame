import Foundation

// Miyav Crush ödülleri ve ilerleme kaydı: bölüm başına en iyi puan ve yıldız, yıldız sandıkları,
// bölüm grubu (macera) ödülleri, rozetler ve güçlendirici stoku. Saf değer tipleridir; uygulama
// bunu JSON olarak saklar.

/// Güçlendiriciler (6. aşamada oyun ekranına bağlanacak).
public enum CrushBooster: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    /// Kedi Patisi: tek eşyayı patlatır
    case paw
    /// Karıştır: tahtayı yeniden dağıtır
    case shuffle
    /// +5 hamle
    case extraMoves
}

/// Sandıktan ya da maceradan çıkan ödül.
public struct CrushReward: Hashable, Codable, Sendable {
    public var boosters: [CrushBooster: Int]

    public init(boosters: [CrushBooster: Int]) {
        self.boosters = boosters.filter { $0.value > 0 }
    }

    public var isEmpty: Bool { boosters.isEmpty }
}

/// Rozetler.
public enum CrushBadge: Hashable, Codable, Sendable {
    /// İlk bölüm kazanıldı
    case firstWin
    /// Bir maceranın (75 bölüm) hepsi kazanıldı
    case episodeCleared(Int)
    /// Bir maceranın hepsi 3 yıldızla
    case episodePerfect(Int)
    /// Toplam yıldız eşiği (50, 150, 300, 600, 900)
    case starCollector(Int)
    /// Bir hamlede 5+ zincir
    case chainMaster
    /// Kedi Çılgınlığı'nda 10+ hamle ödüle döndü
    case catFrenzy

    public static let starMilestones = [50, 150, 300, 600, 900]
}

/// Bir bölüm sonucunu kaydedince oyuncuya gösterilecekler.
public struct CrushLevelOutcome: Hashable, Sendable {
    public let levelID: String
    public let stars: Int
    public let score: Int
    public let isFirstWin: Bool
    public let isNewBest: Bool
    /// Bu sonuçla eklenen yıldız (önceki en iyiye göre)
    public let starsGained: Int
    /// Açılan yıldız sandıkları
    public let chests: [CrushReward]
    /// Macera bittiyse ödülü
    public let episodeReward: CrushReward?
    public let newBadges: [CrushBadge]
    /// Bir sonraki bölüm bu sonuçla açıldıysa
    public let unlockedLevelID: String?

    /// Hepsi bir arada (envantere eklenen)
    public var totalReward: CrushReward {
        var boosters: [CrushBooster: Int] = [:]
        for reward in chests + [episodeReward].compactMap({ $0 }) {
            for (booster, count) in reward.boosters { boosters[booster, default: 0] += count }
        }
        return CrushReward(boosters: boosters)
    }
}

/// Oyuncunun Miyav Crush ilerlemesi.
public struct CrushProgress: Hashable, Codable, Sendable {
    /// Bölüm kimliği → en iyi puan
    public private(set) var bestScores: [String: Int] = [:]
    /// Bölüm kimliği → en çok yıldız (1-3)
    public private(set) var stars: [String: Int] = [:]
    public private(set) var openedChests = 0
    public private(set) var boosters: [CrushBooster: Int] = CrushProgress.startingBoosters
    public private(set) var badges: Set<CrushBadge> = []
    public private(set) var claimedEpisodes: Set<Int> = []

    /// Her bu kadar yıldızda bir sandık açılır.
    public static let starsPerChest = 15
    /// İlk açılışta hediye
    public static let startingBoosters: [CrushBooster: Int] = [.paw: 1, .shuffle: 1, .extraMoves: 1]

    public init() {}

    public var totalStars: Int { stars.values.reduce(0, +) }
    public var completedCount: Int { stars.count }

    public func stars(for levelID: String) -> Int { stars[levelID] ?? 0 }
    public func bestScore(for levelID: String) -> Int { bestScores[levelID] ?? 0 }
    public func isCompleted(_ levelID: String) -> Bool { stars[levelID] != nil }
    public func count(of booster: CrushBooster) -> Int { boosters[booster] ?? 0 }

    /// Bölümler sırayla açılır: ilk bölüm ve kazanılmış bir bölümün ardındaki bölüm.
    public func isUnlocked(_ level: CrushLevel, in catalog: CrushCatalog) -> Bool {
        guard let index = catalog.index(of: level.id) else { return false }
        return index == 0 || isCompleted(level.id) || isCompleted(catalog.levels[index - 1].id)
    }

    /// Haritadaki "Oyna" düğmesi: ilk kazanılmamış açık bölüm (hepsi bittiyse son bölüm).
    public func currentLevel(in catalog: CrushCatalog) -> CrushLevel? {
        catalog.levels.first { !isCompleted($0.id) && isUnlocked($0, in: catalog) } ?? catalog.levels.last
    }

    /// Bir sonraki sandığa kalan yıldız.
    public var starsToNextChest: Int {
        Self.starsPerChest * (openedChests + 1) - totalStars
    }

    /// Kazanılan bölümü kaydeder; ödülleri envantere ekler ve oyuncuya gösterilecekleri döndürür.
    /// Kaybedilen bölümler kaydedilmez.
    public mutating func record(levelID: String, score: Int, stars newStars: Int, bestCascade: Int = 0,
                                frenzyMoves: Int = 0, catalog: CrushCatalog) -> CrushLevelOutcome {
        let earned = max(1, min(3, newStars))
        let isFirstWin = !isCompleted(levelID)
        let previousStars = stars(for: levelID)
        let isNewBest = score > bestScore(for: levelID)
        let wasUnlocked = catalog.levels.map { isUnlocked($0, in: catalog) }

        bestScores[levelID] = max(score, bestScore(for: levelID))
        stars[levelID] = max(earned, previousStars)

        // Yıldız sandıkları
        var chests: [CrushReward] = []
        while totalStars >= Self.starsPerChest * (openedChests + 1) {
            let chest = Self.chest(number: openedChests)
            openedChests += 1
            chests.append(chest)
            add(chest)
        }

        // Macera ödülü ve rozetler
        var newBadges: [CrushBadge] = []
        func award(_ badge: CrushBadge) {
            if badges.insert(badge).inserted { newBadges.append(badge) }
        }
        award(.firstWin)
        var episodeReward: CrushReward?
        if let episode = catalog.episode(containing: levelID) {
            let ids = catalog.levels(in: episode).map(\.id)
            if ids.allSatisfy(isCompleted) {
                award(.episodeCleared(episode))
                if claimedEpisodes.insert(episode).inserted {
                    let reward = Self.episodeReward(episode)
                    episodeReward = reward
                    add(reward)
                }
            }
            if ids.allSatisfy({ self.stars(for: $0) == 3 }) { award(.episodePerfect(episode)) }
        }
        for milestone in CrushBadge.starMilestones where totalStars >= milestone {
            award(.starCollector(milestone))
        }
        if bestCascade >= 5 { award(.chainMaster) }
        if frenzyMoves >= 10 { award(.catFrenzy) }

        let unlocked = catalog.levels.enumerated().first { index, level in
            !wasUnlocked[index] && isUnlocked(level, in: catalog)
        }?.element.id

        return CrushLevelOutcome(
            levelID: levelID, stars: earned, score: score, isFirstWin: isFirstWin, isNewBest: isNewBest,
            starsGained: max(0, stars(for: levelID) - previousStars), chests: chests,
            episodeReward: episodeReward, newBadges: newBadges, unlockedLevelID: unlocked
        )
    }

    /// Güçlendirici kullanır; stokta yoksa `false`.
    public mutating func use(_ booster: CrushBooster) -> Bool {
        guard count(of: booster) > 0 else { return false }
        boosters[booster, default: 0] -= 1
        return true
    }

    /// Ödüllü reklam ya da hediye.
    public mutating func add(_ reward: CrushReward) {
        for (booster, count) in reward.boosters { boosters[booster, default: 0] += count }
    }

    /// Sandık içerikleri sırayla döner (her sandık bir öncekinden farklı): 1., 4., 7. … sandıkta
    /// fazladan +5 hamle.
    public static func chest(number: Int) -> CrushReward {
        switch number % 3 {
        case 0: CrushReward(boosters: [.paw: 1, .shuffle: 1, .extraMoves: 1])
        case 1: CrushReward(boosters: [.paw: 2, .shuffle: 1])
        default: CrushReward(boosters: [.paw: 1, .shuffle: 2, .extraMoves: 1])
        }
    }

    /// Macera bitince: her güçlendiriciden maceranın numarası + 1 kadar (en fazla 3).
    public static func episodeReward(_ episode: Int) -> CrushReward {
        let count = min(3, episode + 2)
        return CrushReward(boosters: [.paw: count, .shuffle: count, .extraMoves: count])
    }
}
