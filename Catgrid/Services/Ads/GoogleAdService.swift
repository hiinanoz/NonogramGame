#if canImport(GoogleMobileAds)
import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Google Mobile Ads 11.5 (Xcode 15.2 ile çalışan son sürüm) ile geçiş ve ödüllü reklamlar.
@MainActor
@Observable
final class GoogleAdService: NSObject, AdService {
    private(set) var isRewardedReady = false
    private(set) var isPrivacyOptionsRequired = false

    private let configuration: AdConfiguration
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var isStarted = false
    private var dismissContinuation: CheckedContinuation<Void, Never>?
    /// Teşhis için son durumlar (reklam yüklenemezse AdMob'un hata mesajı).
    private var interstitialStatus = "not requested"
    private var rewardedStatus = "not requested"
    private var startStatus = "waiting"
    /// Art arda başarısız yüklemelerde bekleme (30 sn, 60 sn, ... en çok 5 dk).
    private var interstitialFailures = 0
    private var rewardedFailures = 0

    init(configuration: AdConfiguration = .current) {
        self.configuration = configuration
    }

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        // Onay formu ve izleme (ATT) sorusu yalnızca uygulama öndeyken ve pencere hazırken
        // gösterilebilir; aksi halde iOS soruyu sessizce atlar
        while UIApplication.shared.applicationState != .active || UIApplication.shared.topViewController == nil {
            try? await Task.sleep(for: .milliseconds(300))
        }
        await requestConsent()
        await requestTrackingAuthorization()
        guard UMPConsentInformation.sharedInstance.canRequestAds else {
            startStatus = "consent does not allow ads yet"
            return
        }
        // Her yaşa uygun, sakin bir kedi oyunu: yalnızca genel izleyici reklamları
        GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = .general
        await withCheckedContinuation { continuation in
            GADMobileAds.sharedInstance().start { _ in continuation.resume() }
        }
        startStatus = "SDK started"
        loadInterstitial()
        loadRewarded()
    }

    // MARK: - Onay ve izleme izni

    private func requestConsent() async {
        let parameters = UMPRequestParameters()
        let consent = UMPConsentInformation.sharedInstance
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            consent.requestConsentInfoUpdate(with: parameters) { _ in continuation.resume() }
        }
        if let root = UIApplication.shared.topViewController {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in continuation.resume() }
            }
        }
        isPrivacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
    }

    private func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { continuation.resume(returning: $0) }
        }
    }

    func presentPrivacyOptions() async {
        guard let root = UIApplication.shared.topViewController else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentForm.presentPrivacyOptionsForm(from: root) { _ in continuation.resume() }
        }
    }

    // MARK: - Yükleme

    private func loadInterstitial() {
        interstitialStatus = "loading"
        GADInterstitialAd.load(withAdUnitID: configuration.interstitialUnitID, request: GADRequest()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.interstitial = ad
                ad?.fullScreenContentDelegate = self
                if ad != nil {
                    self.interstitialFailures = 0
                    self.interstitialStatus = "ready"
                } else {
                    self.interstitialFailures += 1
                    self.interstitialStatus = "failed: \(error?.localizedDescription ?? "unknown")"
                    self.retry(after: self.interstitialFailures) { $0.loadInterstitial() }
                }
            }
        }
    }

    private func loadRewarded() {
        rewardedStatus = "loading"
        GADRewardedAd.load(withAdUnitID: configuration.rewardedUnitID, request: GADRequest()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.rewarded = ad
                ad?.fullScreenContentDelegate = self
                self.isRewardedReady = ad != nil
                if ad != nil {
                    self.rewardedFailures = 0
                    self.rewardedStatus = "ready"
                } else {
                    self.rewardedFailures += 1
                    self.rewardedStatus = "failed: \(error?.localizedDescription ?? "unknown")"
                    self.retry(after: self.rewardedFailures) { $0.loadRewarded() }
                }
            }
        }
    }

    /// Reklam bulunamazsa (yeni hesaplarda sık) bir süre sonra yeniden dener.
    private func retry(after failures: Int, _ load: @escaping @MainActor (GoogleAdService) -> Void) {
        let delay = min(30.0 * pow(2, Double(failures - 1)), 300)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }
            load(self)
        }
    }

    // MARK: - Gösterme

    func showInterstitial() async -> Bool {
        guard let ad = interstitial, let root = UIApplication.shared.topViewController else {
            if isStarted, interstitial == nil { loadInterstitial() }
            return false
        }
        interstitial = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissContinuation = continuation
            ad.present(fromRootViewController: root)
        }
        loadInterstitial()
        return true
    }

    func showRewarded() async -> Bool {
        guard let ad = rewarded, let root = UIApplication.shared.topViewController else { return false }
        rewarded = nil
        isRewardedReady = false
        var earned = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dismissContinuation = continuation
            ad.present(fromRootViewController: root) { earned = true }
        }
        loadRewarded()
        return earned
    }

    fileprivate func finishPresentation() {
        dismissContinuation?.resume()
        dismissContinuation = nil
    }
}

extension GoogleAdService: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in self.finishPresentation() }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finishPresentation() }
    }
}
#endif

import UIKit

extension UIApplication {
    /// Reklam ve onay formlarının sunulacağı en üstteki ekran.
    var topViewController: UIViewController? {
        let window = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
