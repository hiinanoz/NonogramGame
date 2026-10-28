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

        // 1. Ana sayfa: beş mod, hareketli kediler, koleksiyon rafı
        let cats = app.buttons["home.mode.cats"]
        XCTAssertTrue(cats.waitForExistence(timeout: 20))
        settle(3)
        capture("01_home")

        // 2. Miyav Crush: Kedi Kulesi'ndeki sıradaki bölüm
        tapHomeMode(app, "home.mode.crush")
        let crushPlay = app.buttons["crush.hub.play"]
        XCTAssertTrue(crushPlay.waitForExistence(timeout: 20))
        settle(1.5)
        crushPlay.tap()
        // Bölüm hedef kartı kapanır, taşlar yerine oturur
        let crushStart = app.buttons["crush.intro.play"]
        if crushStart.waitForExistence(timeout: 20) { crushStart.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["crush.board"].waitForExistence(timeout: 20))
        settle(3)
        XCTAssertEqual(app.state, .runningForeground, "Miyav Crush açılırken uygulama kapandı")
        capture("02_crush")
        goHome(app)

        // 3. Miyav Sort: sıradaki bölümün dalları
        tapHomeMode(app, "home.mode.birds")
        let birdsPlay = app.buttons["birds.hub.play"]
        XCTAssertTrue(birdsPlay.waitForExistence(timeout: 20))
        settle(1.5)
        birdsPlay.tap()
        _ = app.descendants(matching: .any)["birds.board"].waitForExistence(timeout: 30)
        settle(3)
        capture("03_sort")
        goHome(app)

        // 4. Kedi Kutusu: yarısı dolu, devam eden oyun
        tapHomeMode(app, "home.mode.block")
        let blockContinue = app.buttons["block.continue"]
        XCTAssertTrue(blockContinue.waitForExistence(timeout: 20))
        settle(1)
        blockContinue.tap()
        _ = app.descendants(matching: .any)["block.board"].waitForExistence(timeout: 20)
        settle(2)
        capture("04_block")
        goHome(app)

        // 5. Kedi Bulmaca serüven haritası (kalınan bölüm ortada)
        tapHomeMode(app, "home.mode.cats")
        let play = app.buttons["hub.continue"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        settle(2)
        capture("05_cat_map")

        // 6. Kedi Bulmaca oyunu: kedilerin yarısı bulunmuş
        play.tap()
        let catBoard = app.descendants(matching: .any)["cat.board"]
        _ = catBoard.waitForExistence(timeout: 20)
        settle(2)
        capture("06_cat_game")
        goBack(app)
        goBack(app)

        // 7. Nonogram: yarısı çözülmüş bölüm
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
        capture("07_nonogram")
        goBack(app)
        goBack(app)

        // 8. Günlük bulmaca: takvim ve seri
        let daily = app.buttons["home.daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 20))
        daily.tap()
        _ = app.buttons["daily.play"].waitForExistence(timeout: 20)
        settle(2)
        capture("08_daily")
        goBack(app)

        // 9. Kart koleksiyonu
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
        capture("09_collection")
    }

    /// Ana sayfadaki mod kartına dokunur (gerekirse kartı görünür yapmak için kaydırır).
    private func tapHomeMode(_ app: XCUIApplication, _ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 20), "\(identifier) yok")
        for _ in 0..<3 where !button.isHittable {
            app.swipeUp()
            settle(0.6)
        }
        button.tap()
    }

    /// Ana sayfaya dönmenin en sağlam yolu: uygulamayı yeniden açmak. Örnek ilerleme her açılışta
    /// aynı şekilde yeniden kurulur (bellekte), açılış animasyonu `-screenshots` ile atlanır.
    private func goHome(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.mode.cats"].waitForExistence(timeout: 30))
        settle(1.5)
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
