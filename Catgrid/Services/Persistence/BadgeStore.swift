import Foundation

/// Rozetlerin ait olduğu oyun modu (her modun kendi "Rozetlerim" ekranı var).
enum BadgeMode: String, CaseIterable, Identifiable, Hashable {
    case collection
    case daily
    case cats

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .collection: "Cat Card Collection"
        case .daily: "Daily Puzzle"
        case .cats: "Cat Puzzle"
        }
    }
}

/// Oyuncunun kazanabileceği rozetler. Ham değerler kayıtta saklanır; değiştirilmemeli.
enum Badge: String, CaseIterable, Identifiable, Codable {
    // MARK: Kedi Kart Koleksiyonu
    case graduate
    case tenSolved
    case firstCard
    case fiveBreeds
    case tenBreeds
    case fifteenBreeds
    case twentyBreeds
    case allBreeds
    case firstGolden
    case threeGolden
    case tenGolden
    case fourStars
    case tenFourStars
    case perfectFive
    case perfectTen
    case perfectTwentyFive
    case fiftySolved
    case hundredSolved
    case twoHundredSolved
    case starHunter
    case fiveHundredStars
    case bigBoard

    // MARK: Günlük Bulmaca
    case dailyFirst
    case dailyStreak3
    case dailyWeek
    case dailyStreak14
    case dailyStreak30
    case dailyStreak60
    case dailyStreak100
    case daily10
    case daily25
    case daily50
    case daily100
    case daily200
    case daily365
    case dailyPerfect
    case dailyPerfect10
    case dailyFourStars
    case dailyFourStars10
    case dailyCatchUp
    case dailyCatchUp10
    case dailyWeekend
    case dailyFast
    case dailyFullWeek

    // MARK: Kedi Bulmaca
    case catFirst
    case catGraduate
    case catSolved10
    case catSolved25
    case catSolved50
    case catSolved100
    case catSolved200
    case catSolvedAll
    case catsFound100
    case catsFound500
    case catsFound1000
    case catsFound2500
    case catFlawless
    case catFlawless10
    case catFlawless50
    case catRun5
    case catRun15
    case catCombo4
    case catCombo7
    case catSharpEye
    case catGrid10
    case catGrid15
    case catScore
    case catFast

    var id: String { rawValue }

    var mode: BadgeMode {
        switch self {
        case .graduate, .tenSolved, .firstCard, .fiveBreeds, .tenBreeds, .fifteenBreeds, .twentyBreeds, .allBreeds,
             .firstGolden, .threeGolden, .tenGolden, .fourStars, .tenFourStars, .perfectFive, .perfectTen,
             .perfectTwentyFive, .fiftySolved, .hundredSolved, .twoHundredSolved, .starHunter, .fiveHundredStars, .bigBoard:
            .collection
        case .dailyFirst, .dailyStreak3, .dailyWeek, .dailyStreak14, .dailyStreak30, .dailyStreak60, .dailyStreak100,
             .daily10, .daily25, .daily50, .daily100, .daily200, .daily365, .dailyPerfect, .dailyPerfect10,
             .dailyFourStars, .dailyFourStars10, .dailyCatchUp, .dailyCatchUp10, .dailyWeekend, .dailyFast, .dailyFullWeek:
            .daily
        default:
            .cats
        }
    }

    static func all(in mode: BadgeMode) -> [Badge] {
        allCases.filter { $0.mode == mode }
    }

    var icon: String {
        switch self {
        case .graduate: "graduationcap.fill"
        case .tenSolved: "flame"
        case .firstCard: "rectangle.portrait.fill"
        case .fiveBreeds: "cat.fill"
        case .tenBreeds: "pawprint.fill"
        case .fifteenBreeds: "books.vertical"
        case .twentyBreeds: "building.columns.fill"
        case .allBreeds: "books.vertical.fill"
        case .firstGolden: "crown.fill"
        case .threeGolden: "crown"
        case .tenGolden: "sparkles.rectangle.stack.fill"
        case .fourStars: "star.fill"
        case .tenFourStars: "star.square.on.square.fill"
        case .perfectFive: "sparkles"
        case .perfectTen: "hand.thumbsup.fill"
        case .perfectTwentyFive: "shield.lefthalf.filled"
        case .fiftySolved: "square.grid.3x3.fill"
        case .hundredSolved: "checkmark.seal.fill"
        case .twoHundredSolved: "trophy.fill"
        case .starHunter: "star.circle.fill"
        case .fiveHundredStars: "moon.stars.fill"
        case .bigBoard: "rectangle.split.3x3.fill"
        case .dailyFirst: "calendar"
        case .dailyStreak3: "flame"
        case .dailyWeek: "flame.fill"
        case .dailyStreak14: "flame.circle"
        case .dailyStreak30: "flame.circle.fill"
        case .dailyStreak60: "bolt.fill"
        case .dailyStreak100: "bolt.circle.fill"
        case .daily10: "10.circle.fill"
        case .daily25: "calendar.circle"
        case .daily50: "calendar.circle.fill"
        case .daily100: "rosette"
        case .daily200: "calendar.badge.checkmark"
        case .daily365: "globe.europe.africa.fill"
        case .dailyPerfect: "sun.max.fill"
        case .dailyPerfect10: "sun.horizon.fill"
        case .dailyFourStars: "star.fill"
        case .dailyFourStars10: "star.leadinghalf.filled"
        case .dailyCatchUp: "clock.arrow.circlepath"
        case .dailyCatchUp10: "arrow.uturn.backward.circle.fill"
        case .dailyWeekend: "sofa.fill"
        case .dailyFast: "hare.fill"
        case .dailyFullWeek: "gift.fill"
        case .catFirst: "cat.fill"
        case .catGraduate: "graduationcap.fill"
        case .catSolved10: "square.grid.2x2.fill"
        case .catSolved25: "square.grid.3x3.fill"
        case .catSolved50: "square.grid.4x3.fill"
        case .catSolved100: "checkmark.seal.fill"
        case .catSolved200: "trophy.fill"
        case .catSolvedAll: "crown.fill"
        case .catsFound100: "pawprint"
        case .catsFound500: "pawprint.fill"
        case .catsFound1000: "pawprint.circle"
        case .catsFound2500: "pawprint.circle.fill"
        case .catFlawless: "sparkles"
        case .catFlawless10: "sparkle"
        case .catFlawless50: "wand.and.stars"
        case .catRun5: "flame.fill"
        case .catRun15: "bolt.heart.fill"
        case .catCombo4: "bolt.fill"
        case .catCombo7: "bolt.circle.fill"
        case .catSharpEye: "eye.fill"
        case .catGrid10: "rectangle.split.3x3"
        case .catGrid15: "rectangle.split.3x3.fill"
        case .catScore: "star.circle.fill"
        case .catFast: "hare.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .graduate: "Graduate"
        case .tenSolved: "Warming Up"
        case .firstCard: "First Card"
        case .fiveBreeds: "Cat Collector"
        case .tenBreeds: "Cat Expert"
        case .fifteenBreeds: "Cat Scholar"
        case .twentyBreeds: "Cat Professor"
        case .allBreeds: "Cat Encyclopedia"
        case .firstGolden: "Golden Touch"
        case .threeGolden: "Golden Paws"
        case .tenGolden: "Treasure Hunter"
        case .fourStars: "Purrfect Score"
        case .tenFourStars: "Purrfectionist"
        case .perfectFive: "Flawless Five"
        case .perfectTen: "Steady Paws"
        case .perfectTwentyFive: "Untouchable"
        case .fiftySolved: "Puzzle Fan"
        case .hundredSolved: "Puzzle Master"
        case .twoHundredSolved: "Puzzle Legend"
        case .starHunter: "Star Hunter"
        case .fiveHundredStars: "Star Collector"
        case .bigBoard: "Big Thinker"
        case .dailyFirst: "Daily Debut"
        case .dailyStreak3: "Three in a Row"
        case .dailyWeek: "Daily Habit"
        case .dailyStreak14: "Two Weeks Strong"
        case .dailyStreak30: "Monthly Regular"
        case .dailyStreak60: "Unbreakable"
        case .dailyStreak100: "Century Streak"
        case .daily10: "Daily Ten"
        case .daily25: "Daily Regular"
        case .daily50: "Daily Fan"
        case .daily100: "Daily Hundred"
        case .daily200: "Daily Devotee"
        case .daily365: "A Year of Puzzles"
        case .dailyPerfect: "Flawless Day"
        case .dailyPerfect10: "Steady Hands"
        case .dailyFourStars: "Daily Star"
        case .dailyFourStars10: "Star of the Day"
        case .dailyCatchUp: "Time Traveler"
        case .dailyCatchUp10: "Catching Up"
        case .dailyWeekend: "Weekend Warrior"
        case .dailyFast: "Speedy Daily"
        case .dailyFullWeek: "Weekly Badge"
        case .catFirst: "First Whiskers"
        case .catGraduate: "Cat Puzzle Graduate"
        case .catSolved10: "Cat Spotter"
        case .catSolved25: "Cat Seeker"
        case .catSolved50: "Cat Tracker"
        case .catSolved100: "Cat Detective"
        case .catSolved200: "Cat Whisperer"
        case .catSolvedAll: "Queen of Cats"
        case .catsFound100: "Hundred Whiskers"
        case .catsFound500: "Cat Crowd"
        case .catsFound1000: "Thousand Cats"
        case .catsFound2500: "Cat Kingdom"
        case .catFlawless: "Clean Sweep"
        case .catFlawless10: "Sharp Mind"
        case .catFlawless50: "Logic Wizard"
        case .catRun5: "Hot Streak"
        case .catRun15: "On Fire"
        case .catCombo4: "Combo Cat"
        case .catCombo7: "Unstoppable"
        case .catSharpEye: "Sharp Eye"
        case .catGrid10: "Grid Master"
        case .catGrid15: "Giant Grid"
        case .catScore: "High Scorer"
        case .catFast: "Quick Paws"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .graduate: "Finish Muffin's School."
        case .tenSolved: "Solve 10 puzzles."
        case .firstCard: "Collect your first cat card."
        case .fiveBreeds: "Collect 5 cat breeds."
        case .tenBreeds: "Collect 10 cat breeds."
        case .fifteenBreeds: "Collect 15 cat breeds."
        case .twentyBreeds: "Collect 20 cat breeds."
        case .allBreeds: "Collect every cat breed."
        case .firstGolden: "Win your first Golden Card."
        case .threeGolden: "Win 3 Golden Cards."
        case .tenGolden: "Win 10 Golden Cards."
        case .fourStars: "Get 4 stars on a puzzle."
        case .tenFourStars: "Get 4 stars on 10 puzzles."
        case .perfectFive: "Solve 5 puzzles in a row without a mistake."
        case .perfectTen: "Solve 10 puzzles in a row without a mistake."
        case .perfectTwentyFive: "Solve 25 puzzles in a row without a mistake."
        case .fiftySolved: "Solve 50 puzzles."
        case .hundredSolved: "Solve 100 puzzles."
        case .twoHundredSolved: "Solve 200 puzzles."
        case .starHunter: "Collect 100 stars."
        case .fiveHundredStars: "Collect 500 stars."
        case .bigBoard: "Solve a puzzle 15 squares wide or bigger."
        case .dailyFirst: "Solve your first Daily Puzzle."
        case .dailyStreak3: "Solve the Daily Puzzle 3 days in a row."
        case .dailyWeek: "Solve the Daily Puzzle 7 days in a row."
        case .dailyStreak14: "Solve the Daily Puzzle 14 days in a row."
        case .dailyStreak30: "Solve the Daily Puzzle 30 days in a row."
        case .dailyStreak60: "Solve the Daily Puzzle 60 days in a row."
        case .dailyStreak100: "Solve the Daily Puzzle 100 days in a row."
        case .daily10: "Solve 10 Daily Puzzles."
        case .daily25: "Solve 25 Daily Puzzles."
        case .daily50: "Solve 50 Daily Puzzles."
        case .daily100: "Solve 100 Daily Puzzles."
        case .daily200: "Solve 200 Daily Puzzles."
        case .daily365: "Solve 365 Daily Puzzles."
        case .dailyPerfect: "Solve a Daily Puzzle without a mistake."
        case .dailyPerfect10: "Solve 10 Daily Puzzles without a mistake."
        case .dailyFourStars: "Get 4 stars on a Daily Puzzle."
        case .dailyFourStars10: "Get 4 stars on 10 Daily Puzzles."
        case .dailyCatchUp: "Solve a Daily Puzzle from a past day."
        case .dailyCatchUp10: "Solve 10 Daily Puzzles from past days."
        case .dailyWeekend: "Solve both the Saturday and Sunday puzzles of a weekend."
        case .dailyFast: "Solve a Daily Puzzle in under 3 minutes."
        case .dailyFullWeek: "Solve all 7 daily puzzles of a week, Monday to Sunday."
        case .catFirst: "Find your first cat."
        case .catGraduate: "Finish the first Cat Puzzle level."
        case .catSolved10: "Solve 10 Cat Puzzle levels."
        case .catSolved25: "Solve 25 Cat Puzzle levels."
        case .catSolved50: "Solve 50 Cat Puzzle levels."
        case .catSolved100: "Solve 100 Cat Puzzle levels."
        case .catSolved200: "Solve 200 Cat Puzzle levels."
        case .catSolvedAll: "Solve every Cat Puzzle level."
        case .catsFound100: "Find 100 cats."
        case .catsFound500: "Find 500 cats."
        case .catsFound1000: "Find 1,000 cats."
        case .catsFound2500: "Find 2,500 cats."
        case .catFlawless: "Solve a level with no mistakes and no hints."
        case .catFlawless10: "Solve 10 levels with no mistakes and no hints."
        case .catFlawless50: "Solve 50 levels with no mistakes and no hints."
        case .catRun5: "Solve 5 levels in a row with no mistakes and no hints."
        case .catRun15: "Solve 15 levels in a row with no mistakes and no hints."
        case .catCombo4: "Find 4 cats in a quick combo."
        case .catCombo7: "Find 7 cats in a quick combo."
        case .catSharpEye: "Find 25 cats after crossing out the rest of their color."
        case .catGrid10: "Solve a 10×10 level."
        case .catGrid15: "Solve a 15×15 level."
        case .catScore: "Score 100,000 points in total."
        case .catFast: "Solve a level in under a minute."
        }
    }

    func isEarned(_ progress: BadgeProgress) -> Bool {
        switch self {
        case .graduate: progress.isTutorialDone
        case .tenSolved: progress.solvedCount >= 10
        case .firstCard: progress.collectedBreeds >= 1
        case .fiveBreeds: progress.collectedBreeds >= 5
        case .tenBreeds: progress.collectedBreeds >= 10
        case .fifteenBreeds: progress.collectedBreeds >= 15
        case .twentyBreeds: progress.collectedBreeds >= 20
        case .allBreeds: progress.totalBreeds > 0 && progress.collectedBreeds >= progress.totalBreeds
        case .firstGolden: progress.goldenCards >= 1
        case .threeGolden: progress.goldenCards >= 3
        case .tenGolden: progress.goldenCards >= 10
        case .fourStars: progress.hasFourStars
        case .tenFourStars: progress.fourStarCount >= 10
        case .perfectFive: progress.perfectRun >= 5
        case .perfectTen: progress.perfectRun >= 10
        case .perfectTwentyFive: progress.perfectRun >= 25
        case .fiftySolved: progress.solvedCount >= 50
        case .hundredSolved: progress.solvedCount >= 100
        case .twoHundredSolved: progress.solvedCount >= 200
        case .starHunter: progress.totalStars >= 100
        case .fiveHundredStars: progress.totalStars >= 500
        case .bigBoard: progress.largestSolvedSide >= 15
        case .dailyFirst: progress.dailySolved >= 1
        case .dailyStreak3: progress.dailyStreak >= 3
        case .dailyWeek: progress.dailyStreak >= 7
        case .dailyStreak14: progress.dailyStreak >= 14
        case .dailyStreak30: progress.dailyStreak >= 30
        case .dailyStreak60: progress.dailyStreak >= 60
        case .dailyStreak100: progress.dailyStreak >= 100
        case .daily10: progress.dailySolved >= 10
        case .daily25: progress.dailySolved >= 25
        case .daily50: progress.dailySolved >= 50
        case .daily100: progress.dailySolved >= 100
        case .daily200: progress.dailySolved >= 200
        case .daily365: progress.dailySolved >= 365
        case .dailyPerfect: progress.dailyPerfect >= 1
        case .dailyPerfect10: progress.dailyPerfect >= 10
        case .dailyFourStars: progress.dailyFourStars >= 1
        case .dailyFourStars10: progress.dailyFourStars >= 10
        case .dailyCatchUp: progress.dailyCatchUps >= 1
        case .dailyCatchUp10: progress.dailyCatchUps >= 10
        case .dailyWeekend: progress.hasDailyWeekend
        case .dailyFast: progress.fastestDaily.map { $0 < 180 } ?? false
        case .dailyFullWeek: progress.dailyFullWeeks >= 1
        case .catFirst: progress.catsFound >= 1
        case .catGraduate: progress.catLevelsSolved >= 1
        case .catSolved10: progress.catLevelsSolved >= 10
        case .catSolved25: progress.catLevelsSolved >= 25
        case .catSolved50: progress.catLevelsSolved >= 50
        case .catSolved100: progress.catLevelsSolved >= 100
        case .catSolved200: progress.catLevelsSolved >= 200
        case .catSolvedAll: progress.catLevelsTotal > 0 && progress.catLevelsSolved >= progress.catLevelsTotal
        case .catsFound100: progress.catsFound >= 100
        case .catsFound500: progress.catsFound >= 500
        case .catsFound1000: progress.catsFound >= 1000
        case .catsFound2500: progress.catsFound >= 2500
        case .catFlawless: progress.catFlawless >= 1
        case .catFlawless10: progress.catFlawless >= 10
        case .catFlawless50: progress.catFlawless >= 50
        case .catRun5: progress.catFlawlessRun >= 5
        case .catRun15: progress.catFlawlessRun >= 15
        case .catCombo4: progress.catBestCombo >= 4
        case .catCombo7: progress.catBestCombo >= 7
        case .catSharpEye: progress.catPerfectlyMarked >= 25
        case .catGrid10: progress.catLargestSolved >= 10
        case .catGrid15: progress.catLargestSolved >= 15
        case .catScore: progress.catTotalScore >= 100_000
        case .catFast: progress.catFastest.map { $0 < 60 } ?? false
        }
    }
}

/// Rozet kurallarının baktığı ilerleme özeti.
struct BadgeProgress: Equatable {
    // Kedi Kart Koleksiyonu
    var isTutorialDone = false
    var collectedBreeds = 0
    var totalBreeds = 0
    var goldenCards = 0
    var hasFourStars = false
    var fourStarCount = 0
    var perfectRun = 0
    var solvedCount = 0
    var totalStars = 0
    var largestSolvedSide = 0
    // Günlük
    var dailyStreak = 0
    var dailySolved = 0
    var dailyPerfect = 0
    var dailyFourStars = 0
    var dailyCatchUps = 0
    var hasDailyWeekend = false
    /// Pazartesiden pazara 7 günü de çözülmüş haftalar.
    var dailyFullWeeks = 0
    var fastestDaily: TimeInterval?
    // Kedi Bulmaca
    var catsFound = 0
    var catLevelsSolved = 0
    var catLevelsTotal = 0
    var catFlawless = 0
    var catFlawlessRun = 0
    var catBestCombo = 0
    var catPerfectlyMarked = 0
    var catLargestSolved = 0
    var catTotalScore = 0
    var catFastest: TimeInterval?
}

/// Kazanılan rozetler (kazanma tarihiyle) ve art arda hatasız çözüm sayısı. Rozetler bir kez
/// kazanılınca kalır; yalnızca "İlerlemeyi Sıfırla" siler.
@MainActor
@Observable
final class BadgeStore {
    static let earnedKey = "badges.earned"
    static let perfectRunKey = "badges.perfectRun"

    private let defaults: UserDefaults
    private(set) var earned: [Badge: Date]
    private(set) var perfectRun: Int

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.earnedKey) as? [String: Double] ?? [:]
        earned = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            Badge(rawValue: key).map { ($0, Date(timeIntervalSince1970: value)) }
        })
        perfectRun = defaults.integer(forKey: Self.perfectRunKey)
    }

    /// Testler ve ekran görüntüsü modu için kalıcı olmayan kayıt.
    static func inMemory() -> BadgeStore {
        let name = "badges-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return BadgeStore(defaults: defaults)
    }

    func isEarned(_ badge: Badge) -> Bool {
        earned[badge] != nil
    }

    /// Her çözümde: hatasızsa seri uzar, hatalıysa sıfırlanır.
    func recordSolve(mistakes: Int) {
        perfectRun = mistakes == 0 ? perfectRun + 1 : 0
        defaults.set(perfectRun, forKey: Self.perfectRunKey)
    }

    /// Yeni kazanılan rozetleri kaydeder ve döner (sıralı).
    @discardableResult
    func update(with progress: BadgeProgress, now: Date = Date()) -> [Badge] {
        let new = Badge.allCases.filter { !isEarned($0) && $0.isEarned(progress) }
        guard !new.isEmpty else { return [] }
        for badge in new { earned[badge] = now }
        save()
        return new
    }

    func reset() {
        earned = [:]
        perfectRun = 0
        defaults.removeObject(forKey: Self.earnedKey)
        defaults.removeObject(forKey: Self.perfectRunKey)
    }

    private func save() {
        defaults.set(Dictionary(uniqueKeysWithValues: earned.map { ($0.key.rawValue, $0.value.timeIntervalSince1970) }),
                     forKey: Self.earnedKey)
    }
}
