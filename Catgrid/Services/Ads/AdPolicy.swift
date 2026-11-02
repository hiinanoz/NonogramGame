import Foundation

/// Reklam gelir modeli (saf mantık, test edilebilir):
///
/// - Eğitim bölümlerinde hiç reklam yok.
/// - Uygulamanın kurulduğu gün hiç geçiş reklamı yok.
/// - Her gün ilk **12** bölüm reklamsız; bu sürede yalnızca isteğe bağlı ödüllü reklamlar var.
/// - Sonrasında her **4** bölümde bir geçiş reklamı; yalnızca oyuncu sonuç kartından ayrılırken
///   gösterilir, oyunun ortasında asla. İki geçiş reklamı arasında en az **4 dakika**.
/// - Ödüllü reklam yalnızca isteğe bağlı (ek can, ipucu, tahta temizleme gibi).
/// - Premium tanıtımı: günün 12. bölümünden sonra, günde en fazla bir kez.
final class AdPolicy {
    static let freeCompletionsPerDay = 12
    static let interstitialEvery = 4
    static let minimumInterval: TimeInterval = 4 * 60

    private enum Keys {
        static let completions = "ads.completionsSinceInterstitial"
        static let lastShown = "ads.lastInterstitialAt"
        static let firstSeen = "ads.firstSeenDay"
        static let today = "ads.completionsDay"
        static let completionsToday = "ads.completionsToday"
        static let lastPromoDay = "ads.lastPremiumPromoDay"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        self.defaults = defaults
        self.calendar = calendar
        // Kurulum günü (güncellemeyle gelen oyuncular için de ilk açılış günü) reklamsız
        if defaults.string(forKey: Keys.firstSeen) == nil {
            defaults.set(dayKey(now), forKey: Keys.firstSeen)
        }
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private(set) var completionsSinceInterstitial: Int {
        get { defaults.integer(forKey: Keys.completions) }
        set { defaults.set(newValue, forKey: Keys.completions) }
    }

    private(set) var lastInterstitialAt: Date? {
        get { defaults.object(forKey: Keys.lastShown) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastShown) }
    }

    /// Bugün bitirilen (eğitim dışı) bölüm sayısı.
    func completionsToday(now: Date = Date()) -> Int {
        defaults.string(forKey: Keys.today) == dayKey(now) ? defaults.integer(forKey: Keys.completionsToday) : 0
    }

    func registerCompletion(isTutorial: Bool, now: Date = Date()) {
        guard !isTutorial else { return }
        let today = completionsToday(now: now)
        defaults.set(dayKey(now), forKey: Keys.today)
        defaults.set(today + 1, forKey: Keys.completionsToday)
        // Günün reklamsız bölümleri sayaca girmez
        if today >= Self.freeCompletionsPerDay {
            completionsSinceInterstitial += 1
        }
    }

    func isInterstitialDue(now: Date = Date()) -> Bool {
        guard defaults.string(forKey: Keys.firstSeen) != dayKey(now) else { return false }
        guard completionsToday(now: now) > Self.freeCompletionsPerDay,
              completionsSinceInterstitial >= Self.interstitialEvery else { return false }
        guard let last = lastInterstitialAt else { return true }
        return now.timeIntervalSince(last) >= Self.minimumInterval
    }

    func recordInterstitialShown(now: Date = Date()) {
        completionsSinceInterstitial = 0
        lastInterstitialAt = now
    }

    /// Premium tanıtımı gösterilmeli mi: günün reklamsız bölümleri bittiyse ve bugün gösterilmediyse.
    func isPremiumPromoDue(now: Date = Date()) -> Bool {
        completionsToday(now: now) >= Self.freeCompletionsPerDay
            && defaults.string(forKey: Keys.lastPromoDay) != dayKey(now)
    }

    func recordPremiumPromoShown(now: Date = Date()) {
        defaults.set(dayKey(now), forKey: Keys.lastPromoDay)
    }
}
