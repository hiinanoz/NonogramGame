import Foundation

/// Ekranların reklamla tek temas noktası: politikayı uygular, reklam ağını saklar.
@MainActor
@Observable
final class AdCoordinator {
    private let service: any AdService
    private let policy: AdPolicy
    private let now: () -> Date

    init(service: any AdService, policy: AdPolicy = AdPolicy(), now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.policy = policy
        self.now = now
    }

    static func live() -> AdCoordinator {
        #if DEBUG
        // Arayüz testleri reklam/onay pencereleri olmadan çalışabilsin (yalnızca Debug derleme)
        if ProcessInfo.processInfo.arguments.contains("-disableAds") {
            let coordinator = AdCoordinator(service: NoAdService())
            coordinator.showsPremiumPromo = false
            return coordinator
        }
        #endif
        #if canImport(GoogleMobileAds)
        return AdCoordinator(service: GoogleAdService())
        #else
        return AdCoordinator(service: NoAdService())
        #endif
    }

    /// Premium aboneyse bölümler arası reklam (ve Premium tanıtımı) gösterilmez.
    var interstitialsDisabled = false

    /// Günün reklamsız bölümleri bitince açılan Premium tanıtım ekranı (RootView sunar).
    var isPremiumPromoPresented = false
    var showsPremiumPromo = true

    var isRewardedReady: Bool { service.isRewardedReady }
    var isPrivacyOptionsRequired: Bool { service.isPrivacyOptionsRequired }

    func start() async {
        await service.start()
    }

    func puzzleCompleted(isTutorial: Bool) {
        policy.registerCompletion(isTutorial: isTutorial, now: now())
    }

    /// Sonuç kartından ayrılırken çağrılır: sırası geldiyse önce geçiş reklamı, sonra `action`.
    /// Günün reklamsız bölümleri bitince günde bir kez Premium tanıtımı açılır.
    func continueAfterPuzzle(_ action: @escaping () -> Void) {
        guard !interstitialsDisabled else {
            action()
            return
        }
        guard policy.isInterstitialDue(now: now()) else {
            action()
            presentPremiumPromoIfDue()
            return
        }
        Task {
            if await service.showInterstitial() {
                policy.recordInterstitialShown(now: now())
            }
            action()
            presentPremiumPromoIfDue()
        }
    }

    private func presentPremiumPromoIfDue() {
        guard showsPremiumPromo, policy.isPremiumPromoDue(now: now()) else { return }
        policy.recordPremiumPromoShown(now: now())
        // Sonraki ekrana geçiş bitince açılır (geçişin ortasında sayfa açılmasın)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isPremiumPromoPresented = true
        }
    }

    /// Ödüllü reklam: oyuncu sonuna kadar izlediyse `true`.
    func watchRewardedAd() async -> Bool {
        await service.showRewarded()
    }

    func presentPrivacyOptions() async {
        await service.presentPrivacyOptions()
    }

}
