import XCTest
@testable import Catgrid

final class AdPolicyTests: XCTestCase {
    /// Kurulumdan iki gün sonra öğlen (kurulum günü kuralı devre dışı).
    let day = Date(timeIntervalSinceReferenceDate: 86_400 * 2 + 43_200)
    let installDay = Date(timeIntervalSinceReferenceDate: 43_200)

    func makePolicy(installedAt: Date? = nil) -> AdPolicy {
        AdPolicy(defaults: UserDefaults(suiteName: "AdPolicyTests-\(UUID().uuidString)")!,
                 calendar: utc, now: installedAt ?? installDay)
    }

    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func complete(_ policy: AdPolicy, _ count: Int, at date: Date) {
        for _ in 0..<count { policy.registerCompletion(isTutorial: false, now: date) }
    }

    func testTutorialNeverCountsTowardAds() {
        let policy = makePolicy()
        for _ in 0..<30 { policy.registerCompletion(isTutorial: true, now: day) }
        XCTAssertFalse(policy.isInterstitialDue(now: day))
    }

    func testNoInterstitialOnInstallDay() {
        let policy = makePolicy()
        complete(policy, 40, at: installDay)
        XCTAssertFalse(policy.isInterstitialDue(now: installDay))
    }

    func testFirstTwelveLevelsOfTheDayAreFreeThenEveryFour() {
        let policy = makePolicy()
        complete(policy, AdPolicy.freeCompletionsPerDay, at: day)
        XCTAssertFalse(policy.isInterstitialDue(now: day), "Günün ilk 12 bölümü reklamsız")
        complete(policy, 3, at: day)
        XCTAssertFalse(policy.isInterstitialDue(now: day))
        complete(policy, 1, at: day)
        XCTAssertTrue(policy.isInterstitialDue(now: day), "Sonra her 4 bölümde bir")

        policy.recordInterstitialShown(now: day)
        complete(policy, 4, at: day)
        XCTAssertFalse(policy.isInterstitialDue(now: day.addingTimeInterval(60)), "En az 4 dakika ara")
        XCTAssertTrue(policy.isInterstitialDue(now: day.addingTimeInterval(AdPolicy.minimumInterval)))
    }

    func testFreeLevelsResetEachDay() {
        let policy = makePolicy()
        complete(policy, 20, at: day)
        let nextDay = day.addingTimeInterval(86_400)
        XCTAssertEqual(policy.completionsToday(now: nextDay), 0)
        complete(policy, 5, at: nextDay)
        XCTAssertFalse(policy.isInterstitialDue(now: nextDay))
    }

    func testPremiumPromoOncePerDayAfterFreeLevels() {
        let policy = makePolicy()
        complete(policy, 11, at: day)
        XCTAssertFalse(policy.isPremiumPromoDue(now: day))
        complete(policy, 1, at: day)
        XCTAssertTrue(policy.isPremiumPromoDue(now: day))
        policy.recordPremiumPromoShown(now: day)
        complete(policy, 10, at: day)
        XCTAssertFalse(policy.isPremiumPromoDue(now: day), "Günde en fazla bir kez")
    }
}

@MainActor
final class AdCoordinatorTests: XCTestCase {
    func testShowsInterstitialOnlyWhenDueThenContinues() async {
        let service = NoAdService()
        var clock = Date(timeIntervalSinceReferenceDate: 0)
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "AdCoordinatorTests-\(UUID().uuidString)")!, now: clock)
        clock.addTimeInterval(86_400 * 3)
        let coordinator = AdCoordinator(service: service, policy: policy, now: { clock })
        coordinator.showsPremiumPromo = false

        var navigations = 0
        for _ in 0..<(AdPolicy.freeCompletionsPerDay + AdPolicy.interstitialEvery - 1) {
            coordinator.puzzleCompleted(isTutorial: false)
        }
        coordinator.continueAfterPuzzle { navigations += 1 }
        XCTAssertEqual(navigations, 1)
        XCTAssertEqual(service.interstitialsShown, 0)

        coordinator.puzzleCompleted(isTutorial: false)
        let shown = expectation(description: "reklam sonrası devam")
        coordinator.continueAfterPuzzle {
            navigations += 1
            shown.fulfill()
        }
        await fulfillment(of: [shown], timeout: 2)
        XCTAssertEqual(navigations, 2)
        XCTAssertEqual(service.interstitialsShown, 1)
    }

    func testPremiumPromoOpensAfterTheDaysFreeLevels() async {
        let service = NoAdService()
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "Promo-\(UUID().uuidString)")!)
        let coordinator = AdCoordinator(service: service, policy: policy)

        for _ in 0..<AdPolicy.freeCompletionsPerDay { coordinator.puzzleCompleted(isTutorial: false) }
        coordinator.continueAfterPuzzle {}
        try? await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(service.interstitialsShown, 0)
        XCTAssertTrue(coordinator.isPremiumPromoPresented)
    }
}

@MainActor
final class RemoveAdsTests: XCTestCase {
    func testPurchasedRemoveAdsSkipsInterstitials() async {
        let service = NoAdService()
        let policy = AdPolicy(defaults: UserDefaults(suiteName: "RemoveAds-\(UUID().uuidString)")!)
        let coordinator = AdCoordinator(service: service, policy: policy)
        coordinator.interstitialsDisabled = true

        for _ in 0..<4 { coordinator.puzzleCompleted(isTutorial: false) }
        var navigated = false
        coordinator.continueAfterPuzzle { navigated = true }

        XCTAssertTrue(navigated, "Reklam olmadan hemen devam edilmeli")
        XCTAssertEqual(service.interstitialsShown, 0)
    }

    @MainActor
    func testCachedSubscriptionStateIsRestoredOnLaunch() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Store-\(UUID().uuidString)"))
        XCTAssertFalse(StoreManager(defaults: defaults).isPremium)
        defaults.set(true, forKey: StoreManager.cacheKey)
        XCTAssertTrue(StoreManager(defaults: defaults).isPremium)
    }

    func testSubscriptionProductsAreConfiguredLocally() throws {
        // Simülatörde satın alma denemesi için .storekit dosyasında iki abonelik olmalı
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Catgrid/Resources/Catgrid.storekit")
        let text = try String(contentsOf: url)
        for id in StoreManager.productIDs {
            XCTAssertTrue(text.contains(id), "\(id) .storekit dosyasında yok")
        }
    }
}

@MainActor
final class AudioManagerTests: XCTestCase {
    func testPersistsSoundSettings() {
        let defaults = UserDefaults(suiteName: "AudioManagerTests-\(UUID().uuidString)")!
        let audio = AudioManager(defaults: defaults)
        XCTAssertTrue(audio.musicEnabled)
        XCTAssertTrue(audio.effectsEnabled)

        audio.musicEnabled = false
        audio.effectsVolume = 0.25

        let reloaded = AudioManager(defaults: defaults)
        XCTAssertFalse(reloaded.musicEnabled)
        XCTAssertEqual(reloaded.effectsVolume, 0.25)
    }

    func testBundlesEverySoundFile() {
        for effect in SoundEffect.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"), effect.rawValue)
        }
        // Her oyun modunun listesindeki tüm parçalar pakette olmalı
        for mode in PlayMode.allCases {
            for track in mode.playlist.tracks {
                XCTAssertNotNil(Bundle.main.url(forResource: track.name, withExtension: track.fileExtension), track.name)
            }
        }
    }
}
