import Foundation

/// Reklam ağından bağımsız arayüz. Testler ve önizlemeler `NoAdService` kullanır.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    /// GDPR bölgelerinde Ayarlar'da "Gizlilik Seçenekleri" gösterilmeli.
    var isPrivacyOptionsRequired: Bool { get }
    /// Onay (UMP), izleme izni (ATT) ve SDK başlatma; ardından reklamları önceden yükler.
    func start() async
    /// Gösterildiyse ve kapatıldıysa `true`.
    func showInterstitial() async -> Bool
    /// Oyuncu ödülü kazandıysa `true`.
    func showRewarded() async -> Bool
    func presentPrivacyOptions() async
    /// Ayarlar'daki gizli teşhis satırı (sürüm yazısına uzun basınca): reklamlar neden gelmiyor?
}

@MainActor
final class NoAdService: AdService {
    var isRewardedReady: Bool
    let isPrivacyOptionsRequired = false
    private(set) var interstitialsShown = 0

    init(isRewardedReady: Bool = false) {
        self.isRewardedReady = isRewardedReady
    }

    func start() async {}

    func showInterstitial() async -> Bool {
        interstitialsShown += 1
        return true
    }

    func showRewarded() async -> Bool { isRewardedReady }
    func presentPrivacyOptions() async {}
}

/// Reklam kimlikleri. AdMob hesabı onaylanınca `production` değerlerini doldur;
/// boş kaldıkça (ve her zaman Debug derlemede) Google'ın test reklamları kullanılır.
/// Uygulama kimliği ayrıca project.yml → GADApplicationIdentifier içinde güncellenmeli.
struct AdConfiguration {
    let interstitialUnitID: String
    let rewardedUnitID: String

    static let test = AdConfiguration(
        interstitialUnitID: "ca-app-pub-3940256099942544/4411468910",
        rewardedUnitID: "ca-app-pub-3940256099942544/1712485313"
    )

    static let production = AdConfiguration(
        interstitialUnitID: "ca-app-pub-7892998113103360/1228464879",  // Bölüm geçişi
        rewardedUnitID: "ca-app-pub-7892998113103360/4077989496"       // Ödül: +1 pati / +60 sn
    )

    static var current: AdConfiguration {
        #if DEBUG
        return .test
        #else
        return production.interstitialUnitID.isEmpty ? .test : production
        #endif
    }
}
