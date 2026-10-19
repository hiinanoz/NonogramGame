import Foundation

/// Miyav Crush canları: en fazla 5; bölüm başlarken 1 can harcanır, kazanınca geri verilir
/// (yalnızca kaybedilen ya da yarıda bırakılan bölüm can götürür). Eksik canlar 30 dakikada bir
/// dolar. Zamana bağlı hesaplar dışarıdan verilen `now` ile yapılır (test edilebilir).
public struct CrushLives: Hashable, Codable, Sendable {
    public static let maximum = 5
    public static let refillInterval: TimeInterval = 30 * 60

    private var stored: Int
    /// Bir sonraki canın sayılmaya başladığı an (canlar doluyken `nil`).
    private var refillStart: Date?

    public init(count: Int = CrushLives.maximum, refillStart: Date? = nil) {
        stored = min(max(count, 0), Self.maximum)
        self.refillStart = stored < Self.maximum ? refillStart : nil
    }

    /// Şu anki can sayısı (dolan canlar dahil).
    public func count(at now: Date) -> Int {
        var copy = self
        copy.settle(at: now)
        return copy.stored
    }

    public func isFull(at now: Date) -> Bool { count(at: now) >= Self.maximum }

    /// Bir sonraki cana kalan süre; canlar doluysa `nil`.
    public func timeToNextLife(at now: Date) -> TimeInterval? {
        var copy = self
        copy.settle(at: now)
        guard copy.stored < Self.maximum, let start = copy.refillStart else { return nil }
        return max(0, start.addingTimeInterval(Self.refillInterval).timeIntervalSince(now))
    }

    /// Dolan canları sayıya ekler.
    public mutating func settle(at now: Date) {
        guard stored < Self.maximum else {
            refillStart = nil
            return
        }
        guard let start = refillStart else {
            refillStart = now
            return
        }
        let elapsed = now.timeIntervalSince(start)
        guard elapsed > 0 else {
            // Saat geri alındıysa sayaç yeniden başlar
            if elapsed < 0 { refillStart = now }
            return
        }
        let gained = Int(elapsed / Self.refillInterval)
        guard gained > 0 else { return }
        stored = min(Self.maximum, stored + gained)
        refillStart = stored < Self.maximum ? start.addingTimeInterval(Double(gained) * Self.refillInterval) : nil
    }

    /// Bölüm başlarken bir can harcar; can yoksa `false`.
    public mutating func use(at now: Date) -> Bool {
        settle(at: now)
        guard stored > 0 else { return false }
        if stored == Self.maximum { refillStart = now }
        stored -= 1
        return true
    }

    /// Can ekler (kazanınca geri verme, ödüllü reklam); en fazla 5.
    public mutating func add(_ count: Int = 1, at now: Date) {
        settle(at: now)
        stored = min(Self.maximum, stored + max(count, 0))
        if stored >= Self.maximum { refillStart = nil }
    }
}
