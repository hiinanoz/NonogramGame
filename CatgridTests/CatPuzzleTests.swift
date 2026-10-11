import NonogramKit
import XCTest
@testable import Catgrid

/// Kedi Bulmaca içeriği ve modeli.
@MainActor
final class CatPuzzleTests: XCTestCase {
    private var pack: CatLevelPack!

    override func setUpWithError() throws {
        pack = try CatLevelPack.load(from: .main)
    }

    func testPackHasEnoughLevelsFromFiveToFifteen() throws {
        XCTAssertGreaterThanOrEqual(pack.levels.count, 300)
        XCTAssertEqual(pack.levels.first?.size, 5)
        XCTAssertEqual(pack.levels.last?.size, 15)
        XCTAssertEqual(Set(pack.levels.map(\.id)).count, pack.levels.count, "kimlikler benzersiz olmalı")
        // Boyutlar küçükten büyüğe
        XCTAssertEqual(pack.levels.map(\.size), pack.levels.map(\.size).sorted())
    }

    /// Her bölümde farklı türler ve geçerli bir çözüm (satır, sütun, renk başına bir; dokunmuyorlar).
    func testEveryLevelIsConsistent() throws {
        let catalog = try CatalogLoader.load(from: .main)
        let breedIDs = Set(catalog.chapters.filter { $0.kind == .breed }.map(\.id))
        for level in pack.levels {
            XCTAssertEqual(Set(level.breeds).count, level.size, "\(level.id) türler farklı olmalı")
            XCTAssertTrue(Set(level.breeds).isSubset(of: breedIDs), "\(level.id) bilinmeyen tür")
            XCTAssertEqual(Set(level.solution).count, level.size, "\(level.id) sütunlar")
            let regions = (0..<level.size).map { level.region(at: GridPosition(row: $0, column: level.solution[$0])) }
            XCTAssertEqual(Set(regions).count, level.size, "\(level.id) renkler")
            for row in 1..<level.size {
                XCTAssertGreaterThan(abs(level.solution[row] - level.solution[row - 1]), 1, "\(level.id) kediler değiyor")
            }
        }
    }

    /// İpuçlarıyla (tahmin yapmadan) hatasız çözülebilmeli. Tümü üreticide denenir; burada
    /// her boyuttan örnekler (Debug derlemede hepsi uzun sürer).
    func testLevelsSolveWithHintsAlone() {
        let sample = pack.levels.enumerated().filter { index, _ in index < 30 || index % 12 == 0 }.map(\.element)
        for level in sample {
            var game = CatGame(level: level)
            var steps = 0
            while game.status == .playing, let hint = game.hint(), steps < 500 {
                game.apply(hint)
                steps += 1
            }
            XCTAssertEqual(game.status, .won, "\(level.id) ipuçlarıyla çözülemedi")
            XCTAssertEqual(game.mistakes, 0, "\(level.id)")
        }
    }

    func testProgressUnlocksBySizeAndRecordsStats() throws {
        let cats = CatPuzzleModel.inMemory(pack: pack)
        let first = pack.levels[0]
        let second = pack.levels[1]
        let fives = pack.levels.filter { $0.size == 5 }
        let firstSix = try XCTUnwrap(pack.levels.first { $0.size == 6 })
        // Aynı boyuttaki bölümler istenen sırada oynanır; sonraki boyut 10 çözümle açılır
        XCTAssertTrue(cats.isUnlocked(first))
        XCTAssertTrue(cats.isUnlocked(second))
        XCTAssertFalse(cats.isUnlocked(firstSix))
        XCTAssertEqual(cats.resumableLevel?.id, first.id)

        let isFirst = cats.record(.init(level: first, score: 2000, mistakes: 0, usedHints: false, elapsed: 40, bestCombo: 3, perfectlyMarked: 1))
        XCTAssertTrue(isFirst)
        XCTAssertEqual(cats.nextLevel?.id, second.id)
        for level in fives[2..<CatPuzzleModel.unlockThreshold] {
            cats.record(.init(level: level, score: 100, mistakes: 0, usedHints: false, elapsed: 30, bestCombo: 1, perfectlyMarked: 0))
        }
        XCTAssertFalse(cats.isUnlocked(firstSix), "9 bölüm yetmez")
        XCTAssertEqual(cats.stats.flawlessRun, 9)
        XCTAssertEqual(cats.results[first.id]?.flawless, true)

        cats.record(.init(level: second, score: 500, mistakes: 1, usedHints: true, elapsed: 90, bestCombo: 1, perfectlyMarked: 0))
        XCTAssertTrue(cats.isUnlocked(firstSix), "10. çözümle 6x6 açılır")
        XCTAssertEqual(cats.stats.flawlessRun, 0)
        XCTAssertEqual(cats.stats.bestFlawlessRun, 9)
    }

    /// Herkese 6 hak; bitince reklamla +1; Premium'da her gün 6'ya tamamlanır.
    func testHelperChargesAndPremiumRefill() {
        let cats = CatPuzzleModel.inMemory(pack: pack)
        XCTAssertEqual(cats.findCharges, CatPuzzleModel.maxCharges)
        for _ in 0..<CatPuzzleModel.maxCharges { XCTAssertTrue(cats.useFindCharge()) }
        XCTAssertFalse(cats.useFindCharge())
        cats.addFindCharge()
        XCTAssertEqual(cats.findCharges, 1)

        let today = DayKey(year: 2026, month: 10, day: 10)
        cats.refillIfNeeded(isPremium: false, today: today)
        XCTAssertEqual(cats.findCharges, 1, "Premium değilse dolmaz")
        cats.refillIfNeeded(isPremium: true, today: today)
        XCTAssertEqual(cats.findCharges, CatPuzzleModel.maxCharges)
        XCTAssertTrue(cats.useFindCharge())
        cats.refillIfNeeded(isPremium: true, today: today)
        XCTAssertEqual(cats.findCharges, CatPuzzleModel.maxCharges - 1, "aynı gün ikinci kez dolmaz")
        cats.refillIfNeeded(isPremium: true, today: DayKey(year: 2026, month: 10, day: 11))
        XCTAssertEqual(cats.findCharges, CatPuzzleModel.maxCharges)
    }

    func testEveryModeHasAtLeastTwentyBadges() {
        for mode in BadgeMode.allCases {
            XCTAssertGreaterThanOrEqual(Badge.all(in: mode).count, 20, "\(mode)")
        }
    }

    /// Sihirli silgi: X'i siler, kediye dokunmaz; boş kareye dokununca kapanır.
    @MainActor
    func testMagicEraserClearsCrossesOnly() throws {
        let level = try XCTUnwrap(pack.levels.first)
        let viewModel = CatGameViewModel(level: level)
        let blank = GridPosition(row: 0, column: level.solution[0] == 0 ? 1 : 0)
        viewModel.touchBegan(at: blank)
        viewModel.touchEnded()
        XCTAssertEqual(viewModel.game[blank], .cross)

        viewModel.toggleEraser()
        XCTAssertTrue(viewModel.isErasing)
        viewModel.touchBegan(at: blank)
        viewModel.touchEnded()
        XCTAssertEqual(viewModel.game[blank], .blank)
        XCTAssertTrue(viewModel.isErasing)

        // Boş kareye dokunmak silgiyi kapatır ve kareyi işaretlemez
        viewModel.touchBegan(at: blank)
        viewModel.touchEnded()
        XCTAssertFalse(viewModel.isErasing)
        XCTAssertEqual(viewModel.game[blank], .blank)
    }
}
