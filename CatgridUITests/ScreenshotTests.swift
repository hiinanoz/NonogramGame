import XCTest

/// App Store ekran görüntüleri. Yalnızca "Ekran görüntüleri" iş akışında çalışır
/// (`CATGRID_SCREENSHOTS=1`); normal CI'da atlanır.
///
/// Uygulama `-screenshots` ile örnek ilerlemeyle açılır, 6 ekran sırayla gezilir ve her biri
/// test sonucuna `<dil>_<sıra>_<ad>` adlı ek olarak kaydedilir.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureStoreScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CATGRID_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Yalnızca ekran görüntüsü iş akışında çalışır")
        }
        let language = environment["CATGRID_LANG"] ?? "en"
        let locale = environment["CATGRID_LOCALE"] ?? "en_US"

        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-screenshots", "-disableAds"]
        app.launch()

        // 1. Ana sayfa: üç mod, hareketli kediler, koleksiyon rafı
        let cats = app.buttons["home.mode.cats"]
        XCTAssertTrue(cats.waitForExistence(timeout: 20))
        settle(3)
        capture("01_home")

        // 2. Kedi Bulmaca serüven haritası (kalınan bölüm ortada)
        cats.tap()
        let play = app.buttons["hub.continue"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        settle(2)
        capture("02_cat_map")

        // 3. Kedi Bulmaca oyunu: kedilerin yarısı bulunmuş
        play.tap()
        let catBoard = app.descendants(matching: .any)["cat.board"]
        _ = catBoard.waitForExistence(timeout: 20)
        settle(2)
        capture("03_cat_game")
        goBack(app)
        goBack(app)

        // 4. Nonogram: yarısı çözülmüş bölüm
        let collectionMode = app.buttons["home.mode.collection"]
        XCTAssertTrue(collectionMode.waitForExistence(timeout: 20))
        collectionMode.tap()
        let start = app.buttons["hub.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        let board = app.descendants(matching: .any)["game.board"]
        if !board.waitForExistence(timeout: 20), start.exists {
            start.tap()
        }
        XCTAssertTrue(board.waitForExistence(timeout: 30))
        settle(2.5)
        capture("04_nonogram")
        goBack(app)
        goBack(app)

        // 5. Günlük bulmaca: takvim ve seri
        let daily = app.buttons["home.daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 20))
        daily.tap()
        _ = app.buttons["daily.play"].waitForExistence(timeout: 20)
        settle(2)
        capture("05_daily")
        goBack(app)

        // 6. Kart koleksiyonu
        // Geri dönüş animasyonu bitmeden dokunulursa kaçabilir: ekran açılana kadar yeniden dene
        let collection = app.buttons["home.collection"]
        XCTAssertTrue(collection.waitForExistence(timeout: 20))
        settle(1)
        let card = app.buttons["collection.card.siamese"]
        for _ in 0..<3 where !card.exists {
            if collection.exists { collection.tap() }
            _ = card.waitForExistence(timeout: 8)
        }
        XCTAssertTrue(card.exists, "Koleksiyon ekranı açılmadı")
        settle(1.5)
        capture("06_collection")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(ProcessInfo.processInfo.environment["CATGRID_LANG"] ?? "en")_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Animasyonların bitmesi için kısa bekleme.
    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5) { back.tap() }
        settle(0.6)
    }
}
