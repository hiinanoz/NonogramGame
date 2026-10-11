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
}
