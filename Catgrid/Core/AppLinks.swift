import Foundation

/// App Store'un istediği bağlantılar: gizlilik ve destek sayfaları hii.othinks.com'da.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://hii.othinks.com/catgrid/privacy")!
    static let support = URL(string: "https://hii.othinks.com/catgrid/support")!
    /// Uygulamanın tanıtım sayfası (paylaşılan sonuçlardaki bağlantı).
    static let marketing = URL(string: "https://hii.othinks.com/catgrid")!
    /// Apple'ın standart kullanım koşulları (EULA); abonelikli uygulamalarda bağlantı zorunlu.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// App Store Connect'teki uygulama kimliği (Apple ID, yalnızca rakamlar). Doldurulunca
    /// "Değerlendir" doğrudan yorum sayfasını açar; boşken iOS'un değerlendirme penceresi kullanılır.
    static let appStoreID = ""
    static var writeReview: URL? {
        appStoreID.isEmpty ? nil : URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
