import NonogramKit
import XCTest
@testable import Catgrid

/// Uygulamaya paketlenen gerçek bulmaca içeriğini doğrular.
/// Aynı kontroller Xcode'suz ortamda `Tools/validate_puzzles.py` ile de çalışır.
final class ContentValidationTests: XCTestCase {
    private var catalog: LevelCatalog!

    override func setUpWithError() throws {
        catalog = try CatalogLoader.load(from: .main)
    }

    func testStartsWithTutorialFollowedByBreeds() {
        XCTAssertEqual(catalog.chapters.first?.kind, .tutorial)
        XCTAssertEqual(catalog.chapters.first?.puzzles.count, 12)
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        XCTAssertGreaterThanOrEqual(breeds.count, 15)
        for breed in breeds {
            XCTAssertEqual(breed.puzzles.count, 16, "\(breed.id) 16 ücretsiz bulmaca içermeli")
            XCTAssertNotNil(breed.subtitle, "\(breed.id) tür bilgisi eksik")
        }
    }

    /// Her türde abonelere özel 9 Altın bulmaca: üçer tane 8x8, 10x10, 12x12; biri pati.
    func testEveryBreedHasNineGoldenPuzzles() {
        for breed in catalog.chapters.filter({ $0.kind == .breed }) {
            let premium = breed.premiumPuzzles
            XCTAssertEqual(premium.count, 9, "\(breed.id) 9 premium bulmaca içermeli")
            XCTAssertTrue(premium.allSatisfy { $0.rows == $0.columns }, "\(breed.id) premium bulmacalar kare olmalı")
            XCTAssertEqual(premium.map(\.rows).sorted(), [8, 8, 8, 10, 10, 10, 12, 12, 12], breed.id)
            XCTAssertTrue(premium.contains { $0.title.translations["en"] == "Golden Paw" }, "\(breed.id) pati yok")
            for puzzle in premium {
                XCTAssertTrue(catalog.isPremium(puzzle.id))
                XCTAssertTrue(PuzzleSolver.isLogicallySolvable(puzzle), "\(puzzle.id) mantıkla çözülemiyor")
                XCTAssertNotNil(puzzle.title.translations["tr"], "\(puzzle.id) başlığı Türkçe değil")
            }
        }
    }

    /// Her türde 16 ücretsiz bölüm: 5 kolay, 7 orta, 3 zor, 1 çok zor (en büyük 12x12).
    func testBreedsGetHarderWithinTheChapter() {
        func side(_ puzzle: Puzzle) -> Int { max(puzzle.rows, puzzle.columns) }
        for breed in catalog.chapters.filter({ $0.kind == .breed }) {
            let puzzles = breed.puzzles
            XCTAssertTrue(puzzles[0..<5].allSatisfy { side($0) <= 7 }, "\(breed.id) kolay bölümler 7'den büyük")
            XCTAssertTrue(puzzles[5..<12].allSatisfy { (6...9).contains(side($0)) }, "\(breed.id) orta bölümler 6-9 dışında")
            XCTAssertTrue(puzzles[12..<15].allSatisfy { (8...10).contains(side($0)) }, "\(breed.id) zor bölümler 8-10 dışında")
            XCTAssertTrue((10...12).contains(side(puzzles[15])), "\(breed.id) son bölüm 10-12 dışında")
        }
        XCTAssertEqual(catalog.orderedPuzzles.map(side).max(), 12)
    }

    /// Günlük havuz: en az bir yıl, genişlik en fazla 10, yükseklik en fazla 20, tahminsiz çözülebilir.
    func testDailyPoolIsSolvableAndWithinSize() throws {
        let daily = try DailyPuzzles.load(from: .main)
        XCTAssertGreaterThanOrEqual(daily.pool.count, 365)
        for puzzle in daily.pool {
            XCTAssertLessThanOrEqual(puzzle.columns, 10, puzzle.id)
            XCTAssertLessThanOrEqual(puzzle.rows, 20, puzzle.id)
            XCTAssertNotNil(puzzle.title.translations["tr"], "\(puzzle.id) başlığı Türkçe değil")
            XCTAssertTrue(PuzzleSolver.isLogicallySolvable(puzzle), "\(puzzle.id) mantıkla çözülemiyor")
        }
    }

    func testEveryBreedHasPortraitAndCard() {
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        for breed in breeds {
            XCTAssertNotNil(breed.portrait, "\(breed.id) portresi yok")
            XCTAssertNotNil(breed.card, "\(breed.id) kartı yok")
            if let card = breed.card {
                XCTAssertNotNil(card.fact.translations["tr"], "\(breed.id) kart bilgisi Türkçe değil")
                XCTAssertNotNil(card.about?.translations["en"], "\(breed.id) kartının arka yüzü yok")
                XCTAssertNotNil(card.about?.translations["tr"], "\(breed.id) kartının arka yüzü Türkçe değil")
                XCTAssertNotNil(card.goldenFact, "\(breed.id) Altın Kart bilgisi yok")
                XCTAssertNotEqual(card.goldenFact?.translations["en"], card.fact.translations["en"], "\(breed.id) Altın Kart bilgisi normal kartla aynı")
                for value in [card.stats.energy, card.stats.affection, card.stats.playfulness, card.stats.grooming] {
                    XCTAssertTrue((1...5).contains(value), "\(breed.id) puanı 1-5 dışında")
                }
            }
        }
        XCTAssertEqual(breeds.compactMap(\.card?.number), Array(1...breeds.count), "Kart numaraları sıralı olmalı")
    }

    func testEveryPuzzleHasUniqueLogicalSolution() {
        for puzzle in catalog.orderedPuzzles {
            XCTAssertTrue(PuzzleSolver.isLogicallySolvable(puzzle), "\(puzzle.id) tahmin gerektiriyor")
        }
    }

    static let languages = ["en", "tr", "ja", "de", "fr", "es", "pt-BR", "ko"]

    /// Bulmaca, tür ve kart metinleri uygulamanın desteklediği her dilde olmalı.
    func testEveryContentTextIsTranslated() {
        let premium = catalog.chapters.flatMap(\.premiumPuzzles)
        for language in Self.languages {
            for puzzle in catalog.orderedPuzzles + premium {
                XCTAssertNotNil(puzzle.title.translations[language], "\(puzzle.id) [\(language)] başlık eksik")
            }
            for chapter in catalog.chapters {
                XCTAssertNotNil(chapter.title.translations[language], "\(chapter.id) [\(language)] ad eksik")
                guard let card = chapter.card else { continue }
                for text in [card.origin, card.coat, card.fact, card.about, card.goldenFact].compactMap({ $0 }) {
                    XCTAssertNotNil(text.translations[language], "\(chapter.id) kartı [\(language)] eksik")
                }
            }
        }
    }

    /// Uygulamanın dil listesi (CFBundleLocalizations) çevirilerle aynı olmalı.
    func testBundleDeclaresEveryLanguage() throws {
        let declared = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String])
        XCTAssertEqual(Set(declared), Set(Self.languages))
    }

    /// Yavru Okulu 6 ders: ilk kare, sıfır ve çarpı, boş/dolu satır, birden çok blok,
    /// satır-sütun birlikte, canlar ve zorluk (sırayla).
    func testTutorialHasSixShortLessons() throws {
        let tutorial = try XCTUnwrap(catalog.chapters.first { $0.kind == .tutorial })
        XCTAssertEqual(tutorial.puzzles.compactMap(\.lesson),
                       [.firstSquare, .tapToFill, .emptyLines, .multipleBlocks, .crossReference, .difficulty])
        // Son derste canlar devreye girer
        XCTAssertEqual(tutorial.puzzles.last?.rulesOverride?.mistakeLimit, 3)
    }
}
