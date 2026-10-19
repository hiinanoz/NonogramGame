import XCTest

/// Gerçek dokunma ve sürüklemeyle oyun ekranını dener (birim testlerin yakalayamadığı
/// SwiftUI/gesture çökmeleri için).
final class GameplayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTapAndDragOnBoardDoesNotCrash() {
        let app = XCUIApplication()
        // Reklam SDK'sı ve onay/izleme pencereleri kapalı: yalnızca oyun ekranını dener
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let mode = app.buttons["home.mode.collection"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15), "Ana ekrandaki mod kartı görünmedi")
        mode.tap()
        let start = app.buttons["hub.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "Devam düğmesi görünmedi")
        start.tap()

        let board = app.descendants(matching: .any)["game.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Tahta görünmedi")

        // Tek tek dokunuşlar. Ders çözülünce tam sayfa kutlama tahtayı örter: o andan sonra
        // dokunmak kutlamadaki düğmelere denk gelir, bu yüzden durulur.
        let next = app.buttons["result.next"]
        for (x, y) in [(0.5, 0.5), (0.3, 0.3), (0.7, 0.7), (0.5, 0.5)] where !next.exists {
            board.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        }
        // Sürükleme
        if !next.exists {
            let from = board.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            let to = board.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: to)
        }

        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
        // İlk ders (2x1) dokunuşlarla bitebilir: o zaman tahtanın yerinde sonuç kartı olur
        XCTAssertTrue(board.exists || next.waitForExistence(timeout: 5), "Tahta da sonuç kartı da yok")
    }

    /// Kullanıcı bildirimi: eğitimde yanlış hamleden hemen sonra tahtaya tekrar dokununca
    /// EXC_BAD_ACCESS. Hata kareyi kırmızı yakıp söndürürken tahtaya dokunmayı dener.
    func testTappingRightAfterMistakeDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let mode = app.buttons["home.mode.collection"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        let start = app.buttons["hub.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        var board = app.descendants(matching: .any)["game.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 10))

        // İlk ders (2x1, yatay tahta) önceki testte bitmemişse: soldaki kareye dokununca biter,
        // "Sonraki" ile 5x5 derse geçilir
        if board.frame.width > board.frame.height * 1.5 {
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
            let next = app.buttons["result.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 10), "İlk ders bitmedi")
            next.tap()
            board = app.descendants(matching: .any)["game.board"]
            XCTAssertTrue(board.waitForExistence(timeout: 10))
        }

        /// Eğitim 1 (5x5 "Mama Kutusu"): kenarlar boş, ortadaki 3x3 dolu.
        func cell(_ row: Int, _ column: Int) -> XCUICoordinate {
            board.coordinate(withNormalizedOffset: CGVector(dx: (Double(column) + 0.5) / 5, dy: (Double(row) + 0.5) / 5))
        }

        cell(0, 0).tap()        // hata: boş olmalı
        cell(1, 1).tap()        // hemen ardından doğru kare (kırmızı yanıp sönerken)
        cell(0, 4).tap()        // yine hata
        Thread.sleep(forTimeInterval: 0.35)
        cell(1, 2).tap()        // sönme animasyonu sırasında
        Thread.sleep(forTimeInterval: 1.0)
        cell(1, 3).tap()        // animasyon bittikten sonra

        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
        XCTAssertTrue(board.exists)
    }

    /// Kedi Bulmaca: ilk bölüme dokunma ve sürükleme çökmeden çalışmalı.
    func testCatPuzzleTapAndDrag() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let mode = app.buttons["home.mode.cats"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        let start = app.buttons["hub.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()

        let board = app.descendants(matching: .any)["cat.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Tahta görünmedi")
        func cell(_ row: Int, _ column: Int) -> XCUICoordinate {
            board.coordinate(withNormalizedOffset: CGVector(dx: (Double(column) + 0.5) / 5, dy: (Double(row) + 0.5) / 5))
        }
        // Eğitim bölümü: sol üst tek kareli renk; iki dokunuş = kedi
        cell(0, 0).tap()
        cell(0, 0).tap()
        cell(3, 3).tap()
        cell(4, 0).press(forDuration: 0.1, thenDragTo: cell(4, 4))
        let hint = app.buttons["cat.hint"]
        if hint.exists { hint.tap() }

        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
        XCTAssertTrue(board.exists)
    }

    /// Miyav Crush: haritadan ilk bölüme gir, hedef kartını geç, kaydırarak takas ve dokunarak
    /// seçme çökmeden çalışmalı; güçlendirici düğmeleri görünmeli.
    func testBirdSortIslandsAndMoves() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let mode = app.buttons["home.mode.birds"]
        if !mode.waitForExistence(timeout: 15) { app.swipeUp() }
        XCTAssertTrue(mode.waitForExistence(timeout: 5), "Kuş Sıralama kartı görünmedi")
        mode.tap()
        // Kilitli ada açılmaz, ilk ada bölüm yolunu açar
        let island = app.buttons["birds.island.1"]
        XCTAssertTrue(island.waitForExistence(timeout: 15), "Ada haritası görünmedi")
        island.tap()
        let first = app.buttons["birds.level.1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Bölüm yolu görünmedi")
        first.tap()
        let start = app.buttons["birds.intro.play"]
        if start.waitForExistence(timeout: 10) { start.tap() }
        let board = app.descendants(matching: .any)["birds.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 15), "Dallar görünmedi")
        // Birkaç dal dokunuşu (geçerli ya da geçersiz hamleler), geri al ve ipucu
        for pair in [(0, 1), (2, 3), (1, 4), (3, 0)] {
            let a = app.descendants(matching: .any)["birds.branch.\(pair.0)"]
            let b = app.descendants(matching: .any)["birds.branch.\(pair.1)"]
            if a.exists && b.exists {
                a.tap()
                b.tap()
                sleep(1)
            }
        }
        app.buttons["birds.undo"].tap()
        app.buttons["birds.hint"].tap()
        sleep(1)
        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
    }

    func testMeowCrushSwipeAndTap() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-disableAds"]
        app.launch()

        let mode = app.buttons["home.mode.crush"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15), "Miyav Crush kartı görünmedi")
        mode.tap()
        let play = app.buttons["crush.hub.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 15), "Oyna düğmesi görünmedi")
        // Kedi Kulesi: kilitli kata dokunmak oyunu açmaz
        let locked = app.buttons["crush.floor.2"]
        if locked.waitForExistence(timeout: 5) {
            locked.tap()
            XCTAssertFalse(app.buttons["crush.intro.play"].waitForExistence(timeout: 2), "Kilitli kat açılmamalı")
        }
        play.tap()
        let start = app.buttons["crush.intro.play"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Hedef kartı görünmedi")
        start.tap()

        let board = app.descendants(matching: .any)["crush.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Tahta görünmedi")
        func cell(_ row: Int, _ column: Int) -> XCUICoordinate {
            board.coordinate(withNormalizedOffset: CGVector(dx: (Double(column) + 0.5) / 8, dy: (Double(row) + 0.5) / 8))
        }
        // Birkaç kaydırma (geçerli ya da geçersiz) ve dokunarak takas
        for row in [2, 4, 6] {
            cell(row, 3).press(forDuration: 0.05, thenDragTo: cell(row, 4))
            sleep(2)
            cell(row, 5).press(forDuration: 0.05, thenDragTo: cell(row + 1, 5))
            sleep(2)
        }
        cell(1, 1).tap()
        cell(1, 2).tap()
        sleep(2)
        XCTAssertTrue(app.buttons["crush.booster.shuffle"].exists)
        app.buttons["crush.booster.shuffle"].tap()
        sleep(1)

        XCTAssertEqual(app.state, .runningForeground, "Uygulama çöktü")
        XCTAssertTrue(board.exists)
    }
}
