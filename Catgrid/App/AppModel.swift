import Foundation
import NonogramKit

/// Uygulama genelindeki durum: bölüm kataloğu ve oyuncu ilerlemesi.
@MainActor
@Observable
final class AppModel {
    let catalog: LevelCatalog
    let progress: ProgressStore
    /// Günlük bulmaca havuzu (kedi dışı desenler).
    let daily: DailyPuzzles
    let badges: BadgeStore
    /// Kedi Bulmaca modu.
    let cats: CatPuzzleModel
    /// Miyav Crush modu.
    let crush: CrushModel
    /// Kuş Sıralama modu.
    let birds: BirdSortModel
    /// Kedi Kutusu modu.
    let blocks: CatBlockModel
    /// Testlerde "bugün" sabitlenebilsin diye.
    private let now: () -> Date

    init(
        catalog: LevelCatalog,
        progress: ProgressStore,
        daily: DailyPuzzles = .empty,
        badges: BadgeStore? = nil,
        cats: CatPuzzleModel? = nil,
        crush: CrushModel? = nil,
        birds: BirdSortModel? = nil,
        blocks: CatBlockModel? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        self.catalog = catalog
        self.progress = progress
        self.daily = daily
        // Varsayılan bağımsız değişken ana aktörde çalışmadığı için kayıt burada oluşturulur
        self.badges = badges ?? .inMemory()
        self.cats = cats ?? .inMemory()
        self.crush = crush ?? .inMemory()
        self.birds = birds ?? .inMemory()
        self.blocks = blocks ?? .inMemory()
        self.now = now
        // 1.0'dan gelen oyuncunun hak ettiği rozetler sessizce verilir
        self.badges.update(with: badgeProgress)
    }

    static func live() -> AppModel {
        do {
            #if DEBUG
            if DemoContent.isEnabled {
                let catalog = try CatalogLoader.load(from: .main)
                let cats = CatPuzzleModel.inMemory(pack: CatPuzzleModel.loadPack(), breeds: catalog.chapters.filter { $0.kind == .breed })
                let model = AppModel(catalog: catalog, progress: .inMemory(), daily: loadDaily(), badges: .inMemory(), cats: cats)
                DemoContent.seed(model)
                return model
            }
            #endif
            let catalog = try CatalogLoader.load(from: .main)
            let cats = CatPuzzleModel(pack: CatPuzzleModel.loadPack(), breeds: catalog.chapters.filter { $0.kind == .breed }, defaults: .standard)
            return AppModel(
                catalog: catalog, progress: ProgressStore.live(), daily: loadDaily(), badges: BadgeStore(defaults: .standard),
                cats: cats, crush: CrushModel(defaults: .standard), birds: BirdSortModel(defaults: .standard),
                blocks: CatBlockModel(defaults: .standard)
            )
        } catch {
            // Paketlenmiş içerik hatalıysa: testler (ContentValidationTests) bunu yayından önce yakalar
            fatalError("Bölüm içeriği yüklenemedi: \(error)")
        }
    }

    /// Günlük havuz yüklenemezse oyun yine açılır; yalnızca günlük kart görünmez.
    private static func loadDaily() -> DailyPuzzles {
        (try? DailyPuzzles.load(from: .main)) ?? .empty
    }

    /// Bölüm ya da günlük bulmaca.
    func puzzle(withID id: String) -> Puzzle? {
        catalog.puzzle(withID: id) ?? daily.puzzle(withID: id)
    }

    func rules(for puzzle: Puzzle) -> GameRules {
        DailyPuzzles.isDaily(puzzle.id) ? catalog.defaultRules : catalog.rules(for: puzzle)
    }

    /// En son oynanan an (çözüm ya da yarım bırakılan oyun); hatırlatmalar için.
    var lastPlayedAt: Date? {
        progress.records.values.map(\.lastPlayedAt).max()
    }

    // MARK: - Günlük bulmaca

    var today: DayKey { DayKey(now()) }

    var todaysPuzzle: Puzzle? { daily.puzzle(for: today) }

    var isTodaysPuzzleSolved: Bool {
        isDailySolved(today)
    }

    func isDailySolved(_ day: DayKey) -> Bool {
        progress.record(for: day.puzzleID)?.isCompleted ?? false
    }

    /// Günlük bulmacada geriye gidilebilecek gün sayısı.
    static let dailyHistoryDays = 10

    /// Bugün ve önceki 10 gün (en yeni başta).
    var recentDays: [DayKey] {
        let calendar = Calendar.current
        let date = now()
        return (0...Self.dailyHistoryDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: date).map { DayKey($0, calendar: calendar) }
        }
    }

    /// Geçmiş gün bulmacası oynanabilir mi (en fazla 10 gün geriye).
    func isDailyPlayable(_ day: DayKey) -> Bool {
        recentDays.contains(day)
    }

    /// Haftalık rozet için: verilen günün haftası, pazartesiden pazara.
    func week(containing day: DayKey) -> [DayKey] {
        let monday = day.dayNumber - Self.weekdayIndex(of: day)
        return (0..<7).map { Self.dayKey(dayNumber: monday + $0) }
    }

    /// Pazartesi 0 … pazar 6 (takvim ayarından bağımsız).
    static func weekdayIndex(of day: DayKey) -> Int {
        // Gün numarası 1, 1 Ocak 0001 (pazartesi) olacak biçimde sayılır; ofset ona göre bulunur
        let reference = DayKey(year: 2024, month: 1, day: 1) // pazartesi
        return ((day.dayNumber - reference.dayNumber) % 7 + 7) % 7
    }

    static func dayKey(dayNumber: Int) -> DayKey {
        let reference = DayKey(year: 2024, month: 1, day: 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date()
        let date = calendar.date(byAdding: .day, value: dayNumber - reference.dayNumber, to: base) ?? base
        return DayKey(date, calendar: calendar)
    }

    /// 7 günü de çözülmüş (pazartesi–pazar) hafta sayısı.
    static func fullWeeks(in days: Set<DayKey>) -> Int {
        let numbers = Set(days.map(\.dayNumber))
        let mondays = Set(days.map { $0.dayNumber - weekdayIndex(of: $0) })
        return mondays.filter { monday in (0..<7).allSatisfy { numbers.contains(monday + $0) } }.count
    }

    /// Kesintisiz günlük bulmaca serisi.
    var dailyStreak: Int {
        let days = progress.completedIDs.compactMap(DayKey.init(puzzleID:))
        return DailyPuzzles.streak(solvedDays: Set(days), today: today)
    }

    var progression: Progression {
        Progression(catalog: catalog, completedIDs: progress.completedIDs, tutorialSkipped: isTutorialSkipped)
    }

    // MARK: - Eğitim

    static let tutorialSkippedKey = "tutorial.skipped"

    /// Oyuncu Muffin'in Okulu'nu atladı: ilk tür hemen açılır.
    private(set) var isTutorialSkipped = UserDefaults.standard.bool(forKey: AppModel.tutorialSkippedKey)

    func skipTutorial() {
        isTutorialSkipped = true
        UserDefaults.standard.set(true, forKey: Self.tutorialSkippedKey)
    }

    /// Mod dışı bir olaydan (Kedi Bulmaca) sonra yeni kazanılan rozetler.
    @discardableResult
    func refreshBadges() -> [Badge] {
        defer { reportToGameCenter() }
        return badges.update(with: badgeProgress)
    }

    /// Game Center sıralama listelerine güncel değerler (giriş yapılmamışsa bir şey olmaz).
    func reportToGameCenter() {
        GameCenterService.shared.submit([
            .dailyStreak: dailyStreak,
            .nonogramsSolved: progress.stats.solvedCount,
            .catLevelsSolved: cats.levels.filter { cats.isSolved($0) }.count,
        ])
    }

    @discardableResult
    func record(_ completion: PuzzleCompletion) -> CompletionResult {
        let stars = puzzle(withID: completion.puzzleID).map {
            StarRating.stars(mistakes: completion.mistakes, elapsed: completion.elapsed, rows: $0.rows, columns: $0.columns)
        }
        badges.recordSolve(mistakes: completion.mistakes)
        var result = progress.recordCompletion(completion, stars: stars)
        result.newBadges = badges.update(with: badgeProgress)
        reportToGameCenter()
        return result
    }

    // MARK: - Rozetler

    var badgeProgress: BadgeProgress {
        let completed = progress.completedIDs
        let tutorial = catalog.chapters.first { $0.kind == .tutorial }
        let catalogPuzzles = catalog.chapters.flatMap { $0.puzzles + $0.premiumPuzzles }
        let solvedStars = catalogPuzzles.compactMap { stars(for: $0) }
        let dailyRecords = progress.records.values.filter { DailyPuzzles.isDaily($0.puzzleID) && $0.isCompleted }
        let dailyDays = Set(dailyRecords.compactMap { DayKey(puzzleID: $0.puzzleID) })
        let calendar = Calendar(identifier: .gregorian)
        let hasWeekend = dailyDays.contains { day in
            calendar.component(.weekday, from: day.date) == 7
                && dailyDays.contains { $0.dayNumber == day.dayNumber + 1 }
        }
        let catLevels = cats.levels
        let solvedCatLevels = catLevels.filter { cats.isSolved($0) }
        return BadgeProgress(
            isTutorialDone: tutorial.map { !$0.puzzles.isEmpty && $0.puzzles.allSatisfy { completed.contains($0.id) } } ?? false,
            collectedBreeds: collectedBreeds.count,
            totalBreeds: breeds.count,
            goldenCards: goldenBreeds.count,
            hasFourStars: solvedStars.contains(StarRating.maximum)
                || dailyRecords.contains { $0.bestStars == StarRating.maximum },
            fourStarCount: solvedStars.filter { $0 == StarRating.maximum }.count,
            perfectRun: badges.perfectRun,
            solvedCount: progress.stats.solvedCount,
            totalStars: solvedStars.reduce(0, +),
            largestSolvedSide: catalogPuzzles.filter { completed.contains($0.id) }.map { max($0.rows, $0.columns) }.max() ?? 0,
            dailyStreak: dailyStreak,
            dailySolved: dailyRecords.count,
            dailyPerfect: dailyRecords.filter { $0.fewestMistakes == 0 }.count,
            dailyFourStars: dailyRecords.filter { $0.bestStars == StarRating.maximum }.count,
            dailyCatchUps: dailyRecords.filter { record in
                guard let day = DayKey(puzzleID: record.puzzleID), let solvedAt = record.firstCompletedAt else { return false }
                return DayKey(solvedAt) != day
            }.count,
            hasDailyWeekend: hasWeekend,
            dailyFullWeeks: Self.fullWeeks(in: dailyDays),
            fastestDaily: dailyRecords.compactMap(\.bestTime).min(),
            catsFound: cats.stats.catsFound,
            catLevelsSolved: solvedCatLevels.count,
            catLevelsTotal: catLevels.count,
            catFlawless: cats.results.values.filter(\.flawless).count,
            catFlawlessRun: cats.stats.bestFlawlessRun,
            catBestCombo: cats.stats.bestCombo,
            catPerfectlyMarked: cats.stats.perfectlyMarked,
            catLargestSolved: solvedCatLevels.map(\.size).max() ?? 0,
            catTotalScore: cats.stats.totalScore,
            catFastest: cats.stats.fastestSolve
        )
    }

    // MARK: - Yıldızlar

    /// Bulmacanın en iyi yıldızı; çözülmediyse `nil`. Eski (1.0) çözümlerde en iyi süre ve en az
    /// hatadan tahmin edilir.
    func stars(for puzzle: Puzzle) -> Int? {
        guard let record = progress.record(for: puzzle.id), record.isCompleted else { return nil }
        if let stars = record.bestStars { return stars }
        return StarRating.stars(
            mistakes: record.fewestMistakes ?? 0,
            elapsed: record.bestTime ?? .infinity,
            rows: puzzle.rows,
            columns: puzzle.columns
        )
    }

    /// Tüm çözülen bulmacaların yıldız toplamı (istatistik ekranı).
    var totalStars: Int {
        catalog.chapters
            .flatMap { $0.puzzles + $0.premiumPuzzles }
            .compactMap { stars(for: $0) }
            .reduce(0, +)
    }

    // MARK: - Ekranlar için özetler

    // MARK: - Kedi koleksiyonu

    /// Oynanabilir kedi türleri. Yeni türler katalog güncellemeleriyle eklenir; toplam sayı arayüzde gösterilmez.
    var breeds: [Chapter] {
        catalog.chapters.filter { $0.kind == .breed && !$0.puzzles.isEmpty }
    }

    /// Bir tür, tüm bulmacaları çözülünce koleksiyona girer.
    func isCollected(_ chapter: Chapter) -> Bool {
        let completed = progress.completedIDs
        return !chapter.puzzles.isEmpty && chapter.puzzles.allSatisfy { completed.contains($0.id) }
    }

    var collectedBreeds: [Chapter] {
        breeds.filter { isCollected($0) }
    }

    /// Türün 9 Altın bulmacası çözülünce Altın Kart kazanılır. Abonelik bitse de kart kalır.
    func isGoldenCollected(_ chapter: Chapter) -> Bool {
        let completed = progress.completedIDs
        return chapter.card != nil && !chapter.premiumPuzzles.isEmpty
            && chapter.premiumPuzzles.allSatisfy { completed.contains($0.id) }
    }

    /// Herkese hediye Altın bulmacalar: bu tür bitince 9 Altın bulmacası abonelik olmadan açılır,
    /// oyuncu Premium'u denemiş olur.
    static let giftedGoldenBreedID = "british-shorthair"

    func isGoldenGift(_ chapter: Chapter) -> Bool {
        chapter.id == Self.giftedGoldenBreedID && !chapter.premiumPuzzles.isEmpty
    }

    /// Altın bulmacalar oynanabilir mi: Premium abonelik ya da tür bitmiş hediye tür.
    func canPlayGolden(_ chapter: Chapter, isPremium: Bool) -> Bool {
        isPremium || (isGoldenGift(chapter) && isCollected(chapter))
    }

    var goldenBreeds: [Chapter] {
        breeds.filter { isGoldenCollected($0) }
    }

    /// Koleksiyonda gösterilen kartlar: türün normal kartı ve (kazanıldıysa) hemen ardından Altın Kartı.
    var collectedCards: [CardSelection] {
        breeds.flatMap { chapter in
            (isCollected(chapter) ? [CardSelection(chapter: chapter, isGolden: false)] : [])
                + (isGoldenCollected(chapter) ? [CardSelection(chapter: chapter, isGolden: true)] : [])
        }
    }

    var hasUnmetBreeds: Bool {
        collectedBreeds.count < breeds.count
    }

    var completedCount: Int {
        let completed = progress.completedIDs
        return catalog.orderedPuzzles.filter { completed.contains($0.id) }.count
    }

    func chapter(withID id: String) -> Chapter? {
        catalog.chapters.first { $0.id == id }
    }

    /// Bölüm içindeki 1'den başlayan sıra numarası (premium bulmacalarda kendi sırası).
    func number(of puzzle: Puzzle) -> Int {
        let chapter = catalog.chapter(containing: puzzle.id)
        let list = catalog.isPremium(puzzle.id) ? chapter?.premiumPuzzles : chapter?.puzzles
        return (list?.firstIndex(of: puzzle) ?? 0) + 1
    }

    func nextPuzzle(after puzzle: Puzzle) -> Puzzle? {
        catalog.puzzle(after: puzzle.id)
    }

    /// Ana ekrandaki "Devam Et" hedefi: önce en son yarım bırakılan açık bulmaca, yoksa sıradaki.
    var resumablePuzzle: Puzzle? {
        let progression = progression
        let inProgress = catalog.orderedPuzzles
            .filter { progress.hasSavedGame(for: $0.id) && progression.isUnlocked($0.id) }
            .max { (progress.record(for: $0.id)?.lastPlayedAt ?? .distantPast) < (progress.record(for: $1.id)?.lastPlayedAt ?? .distantPast) }
        return inProgress ?? progression.nextPlayable
    }

    /// Ayarlardan ilerleme sıfırlanır.
    func resetProgress() {
        progress.resetAll()
        badges.reset()
        cats.reset()
        crush.reset()
        birds.reset()
        blocks.reset()
        isTutorialSkipped = false
        UserDefaults.standard.removeObject(forKey: Self.tutorialSkippedKey)
    }
}

/// Koleksiyonda seçilen kart: bir tür + normal mi Altın mı.
struct CardSelection: Identifiable, Hashable {
    let chapter: Chapter
    let isGolden: Bool

    var id: String { isGolden ? "\(chapter.id)#golden" : chapter.id }
}
