import Foundation

/// Kedi Kulesi katının oda planı: hangi duvar, pencere, zemin, ana mobilya, aksesuarlar ve kedi.
/// Bölüm numarası ve bina numarasından türetilen sabit tohumla seçilir: her açılışta aynı kat
/// aynı görünür, komşu katlarda aynı birleşim tekrar etmez. Görseller katman katman çizilir
/// (arka duvar → pencere → zemin → mobilya → aksesuar → kedi), bölüm numarası/yıldız/kilit ayrı.
public struct CatTowerRoomPlan: Hashable, Sendable {
    /// Katın türü: her 5 katta özel oda, her 15 katta dönüm noktası.
    public enum Kind: Hashable, Sendable {
        case normal
        case special
        case milestone
    }

    /// Her katmandaki seçenek sayısı (binanın görsel setine göre).
    public struct Counts: Hashable, Sendable {
        public var walls: Int
        public var windows: Int
        public var floors: Int
        public var furniture: Int
        public var accessories: Int
        public var cats: Int

        public init(walls: Int, windows: Int, floors: Int, furniture: Int, accessories: Int, cats: Int) {
            self.walls = max(1, walls)
            self.windows = max(1, windows)
            self.floors = max(1, floors)
            self.furniture = max(1, furniture)
            self.accessories = max(1, accessories)
            self.cats = max(1, cats)
        }
    }

    /// Aksesuar yuvaları (çakışmasın diye sabit yerler). Ana mobilyanın durduğu zemin yuvası boş kalır.
    public enum Slot: Int, CaseIterable, Hashable, Sendable {
        /// Sol zemin
        case left
        /// Sağ zemin
        case right
        /// Duvardaki raf / asılı
        case wall
        /// Orta zemin (mobilya yandayken)
        case middle
    }

    /// Ana mobilyanın zemindeki yeri.
    public enum Spot: Int, CaseIterable, Hashable, Sendable {
        case left
        case middle
        case right

        /// Bu yerdeki mobilyanın kapattığı aksesuar yuvası.
        var slot: Slot {
            switch self {
            case .left: return .left
            case .middle: return .middle
            case .right: return .right
            }
        }
    }

    public let level: Int
    public let tower: Int
    public let kind: Kind
    public let wall: Int
    public let window: Int
    public let floor: Int
    public let furniture: Int
    /// Mobilyanın solda, ortada ya da sağda durması.
    public let furnitureSpot: Spot
    /// 1–3 aksesuar, her biri ayrı yuvada ve birbirinden farklı.
    public let accessories: [Slot: Int]
    public let cat: Int
    public let isCatFlipped: Bool
    /// Bu kattaki kedi çoğunlukla uyur.
    public let isCatSleepy: Bool

    public static func kind(of level: Int) -> Kind {
        if level % 15 == 0 { return .milestone }
        if level % 5 == 0 { return .special }
        return .normal
    }

    /// `level`: bütün oyun boyunca 1'den başlayan bölüm numarası. `tower`: 0'dan başlayan bina.
    public static func make(level: Int, tower: Int, counts: Counts) -> CatTowerRoomPlan {
        let base = raw(level: level, tower: tower, counts: counts, salt: 0)
        guard level > 1 else { return base }
        // Komşu kat aynı duvar + mobilya + kediyle gelirse farklı bir tohum denenir
        let previous = raw(level: level - 1, tower: tower, counts: counts, salt: 0)
        var plan = base
        var salt: UInt64 = 1
        while plan.looksLike(previous), salt < 8 {
            plan = raw(level: level, tower: tower, counts: counts, salt: salt)
            salt += 1
        }
        return plan
    }

    /// Görünüşü belirleyen ana katmanlar aynı mı.
    func looksLike(_ other: CatTowerRoomPlan) -> Bool {
        (wall == other.wall && furniture == other.furniture) || (cat == other.cat && furniture == other.furniture)
    }

    private static func raw(level: Int, tower: Int, counts: Counts, salt: UInt64) -> CatTowerRoomPlan {
        var random = CrushRandom(seed: UInt64(truncatingIfNeeded: level) &* 0x9E37_79B9 &+ UInt64(truncatingIfNeeded: tower) &* 0x85EB_CA6B &+ salt &* 0xC2B2_AE35)
        func pick(_ count: Int) -> Int { Int(random.next() % UInt64(count)) }
        let wall = wallIndex(level: level, tower: tower, count: counts.walls)
        _ = pick(counts.walls)
        let window = pick(counts.windows)
        let floor = pick(counts.floors)
        let furniture = pick(counts.furniture)
        let cat = pick(counts.cats)
        let flipped = random.next() % 2 == 1
        let spot = Spot.allCases[pick(Spot.allCases.count)]
        let sleepy = pick(4) == 0
        // 1–3 aksesuar; özel katlarda en az 2, dönüm noktasında 3
        let kind = kind(of: level)
        let minimum = kind == .milestone ? 3 : (kind == .special ? 2 : 1)
        let wanted = min(Slot.allCases.count, max(minimum, 1 + pick(3)), counts.accessories)
        var slots = Slot.allCases.filter { $0 != spot.slot }
        var used = Set<Int>()
        var accessories: [Slot: Int] = [:]
        while accessories.count < wanted, !slots.isEmpty {
            let slot = slots.remove(at: pick(slots.count))
            var item = pick(counts.accessories)
            var tries = 0
            while used.contains(item), tries < counts.accessories {
                item = (item + 1) % counts.accessories
                tries += 1
            }
            used.insert(item)
            accessories[slot] = item
        }
        return CatTowerRoomPlan(level: level, tower: tower, kind: kind, wall: wall, window: window, floor: floor,
                                furniture: furniture, furnitureSpot: spot, accessories: accessories, cat: cat,
                                isCatFlipped: flipped, isCatSleepy: sleepy)
    }

    /// Duvar sırası: binanın duvarları karışık bir sıraya dizilir ve katlar bu sırada `step` adımla
    /// ilerler. Adım, ardışık iki ve üç katın aynı duvara düşmeyeceği şekilde seçilir; böylece bir
    /// katın altındaki ve üstündeki ikişer katın duvarı ondan farklıdır (en az 3 duvar varsa).
    static func wallIndex(level: Int, tower: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        var order = Array(0..<count)
        var random = CrushRandom(seed: UInt64(truncatingIfNeeded: tower + 1) &* 0xD6E8_FEB8_6659_FD93)
        for i in stride(from: count - 1, to: 0, by: -1) {
            order.swapAt(i, Int(random.next() % UInt64(i + 1)))
        }
        let step = (1..<count).first { k in
            gcd(k, count) == 1 && (count < 3 || (2 * k) % count != 0) && (count < 4 || k > 1)
        } ?? 1
        return order[(level * step) % count]
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
