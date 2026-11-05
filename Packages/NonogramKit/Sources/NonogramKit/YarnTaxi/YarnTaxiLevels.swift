import Foundation

/// Bir bölümün ayarları.
public struct YarnTaxiLevel: Hashable, Codable, Sendable {
    public let number: Int
    public let rows: Int
    public let columns: Int
    public let colors: Int
    public let cars: Int
    /// Kullanılabilen araba uzunlukları (2 küçük, 3 orta, 4 otobüs).
    public let lengths: [Int]
    /// Durak yeri sayısı.
    public let slots: Int
    /// Sırada aynı anda karışık gelen araba sayısı (1: yumaklar araba araba gelir, kolay).
    public let interleave: Int
    /// Durak baskısı (0-1): yüksekse sıra en son çıkan arabaların yumaklarını öne alır, önceki
    /// arabalar durakta bekler; yanlış araba çıkarmak daha çabuk tıkar.
    public var pressure: Double = 0

    /// Mahalle (0'dan başlar).
    public var district: Int { (number - 1) / YarnTaxiCatalog.levelsPerDistrict }
}

/// 4 mahalle × 75 bölüm. Kolay başlar: 1. bölüm 2 renk, 3 küçük araba; zorluk adım adım artar.
public enum YarnTaxiCatalog {
    public static let districtCount = 4
    public static let levelsPerDistrict = 75
    public static var levelCount: Int { districtCount * levelsPerDistrict }

    public static func level(_ number: Int) -> YarnTaxiLevel {
        let number = min(max(number, 1), levelCount)
        let progress = Double(number - 1) / Double(levelCount - 1)
        let local = (number - 1) % levelsPerDistrict
        // Her 5. bölüm nefes: biraz daha az araba
        let breather = (local + 1) % 5 == 0
        switch number {
        case 1:
            return YarnTaxiLevel(number: 1, rows: 4, columns: 4, colors: 2, cars: 3, lengths: [2], slots: 5, interleave: 1)
        case 2:
            return YarnTaxiLevel(number: 2, rows: 4, columns: 4, colors: 2, cars: 4, lengths: [2], slots: 5, interleave: 1)
        case 3...10:
            return YarnTaxiLevel(number: number, rows: 5, columns: 5, colors: 3, cars: 4 + number / 3,
                                 lengths: [2], slots: 5, interleave: number < 7 ? 1 : 2)
        default:
            let rows = min(9, 6 + Int(progress * 4))
            let columns = min(7, 5 + Int(progress * 3))
            let colors = min(8, 3 + Int(progress * 6) + (number > 40 ? 1 : 0))
            var cars = min(rows * columns / 3, 7 + Int(progress * 20))
            if breather { cars = max(5, cars - 2) }
            let lengths = number < 25 ? [2, 2, 3] : (number < 60 ? [2, 3] : [2, 3, 3, 4])
            let interleave = 2 + (progress > 0.3 ? 1 : 0) + (progress > 0.82 ? 1 : 0)
            // Mahalle içinde de artar; her mahalle biraz daha kolay başlar
            let pressure = min(0.7, 0.1 + 0.45 * progress + 0.15 * Double(local) / Double(levelsPerDistrict))
            return YarnTaxiLevel(number: number, rows: rows, columns: columns, colors: colors, cars: cars,
                                 lengths: lengths, slots: 5, interleave: interleave,
                                 pressure: breather ? pressure * 0.5 : pressure)
        }
    }

    /// Bölümün başlangıç oyunu. Her zaman çözülebilir: arabalar bir çıkış sırasıyla otoparktan
    /// alınabilecek biçimde yerleştirilir ve yumak sırası bu sıraya göre, aynı anda en fazla
    /// `interleave` (< durak yeri) araba karışık gelecek şekilde dizilir.
    public static func game(for level: YarnTaxiLevel) -> YarnTaxiGame {
        let salts = YarnTaxiSeeds.salts
        let salt = level.number <= salts.count ? salts[level.number - 1] : 0
        return game(for: level, salt: salt)
    }

    /// `salt`: aynı ayarlarla farklı bir dizilim (dengeleme hedef zorluğa en yakınını seçer,
    /// bkz. `YarnTaxiBalanceTests`).
    static func game(for level: YarnTaxiLevel, salt: Int) -> YarnTaxiGame {
        var random = CrushRandom(seed: UInt64(level.number) &* 0x9E37_79B9_7F4A_7C15 &+ 0x5A17 &+ UInt64(salt) &* 0xD1B5_4A32_D192_ED03)
        // Sıkışık otoparkta istenen sayıda araba her denemede sığmayabilir: birkaç kez yeniden dizilir
        var cars = placeCars(level, random: &random)
        for _ in 0..<40 where cars.count < level.cars {
            cars = placeCars(level, random: &random)
        }
        let order = exitOrder(cars, rows: level.rows, columns: level.columns, random: &random)
        let queue = makeQueue(order: order, interleave: min(level.interleave, level.slots - 1),
                              pressure: level.pressure, random: &random)
        return YarnTaxiGame(rows: level.rows, columns: level.columns, cars: cars, queue: queue, slots: level.slots)
    }

    static func placeCars(_ level: YarnTaxiLevel, random: inout CrushRandom) -> [YarnCar] {
        var cars: [YarnCar] = []
        var attempts = 0
        // Renkler sırayla dağıtılır: her renkten en az bir araba
        var colors = (0..<level.cars).map { $0 % level.colors }
        colors.shuffle(using: &random)
        while cars.count < level.cars, attempts < 4000 {
            attempts += 1
            let length = level.lengths.randomElement(using: &random) ?? 2
            let direction = YarnDirection.allCases.randomElement(using: &random) ?? .up
            let maxRow = direction.isHorizontal ? level.rows - 1 : level.rows - length
            let maxColumn = direction.isHorizontal ? level.columns - length : level.columns - 1
            guard maxRow >= 0, maxColumn >= 0 else { continue }
            let car = YarnCar(id: cars.count + 1, color: colors[cars.count], row: Int.random(in: 0...maxRow, using: &random),
                              column: Int.random(in: 0...maxColumn, using: &random), length: length, direction: direction)
            let occupied = Set(cars.flatMap(\.cells))
            guard car.cells.allSatisfy({ !occupied.contains($0) }) else { continue }
            // Hepsi bir sırayla çıkabilmeli (çıkmak hiçbir zaman başkasını kilitlemez: açgözlü sıra yeter)
            guard isClearable(cars + [car], rows: level.rows, columns: level.columns) else { continue }
            cars.append(car)
        }
        return cars
    }

    static func isClearable(_ cars: [YarnCar], rows: Int, columns: Int) -> Bool {
        var game = YarnTaxiGame(rows: rows, columns: columns, cars: cars, queue: [], slots: 0)
        while !game.lot.isEmpty {
            guard let next = game.exitableCars.first else { return false }
            game.removeFromLot(next.id)
        }
        return true
    }

    static func exitOrder(_ cars: [YarnCar], rows: Int, columns: Int, random: inout CrushRandom) -> [YarnCar] {
        var game = YarnTaxiGame(rows: rows, columns: columns, cars: cars, queue: [], slots: 0)
        var order: [YarnCar] = []
        while let next = game.exitableCars.randomElement(using: &random) {
            order.append(next)
            game.removeFromLot(next.id)
        }
        return order
    }

    /// Yumak sırası: çıkış sırasındaki arabalar sırayla "açılır"; aynı anda en fazla `interleave`
    /// açık araba olur ve sıradaki yumak açık arabalardan rastgele birinin rengindendir.
    static func makeQueue(order: [YarnCar], interleave: Int, pressure: Double = 0, random: inout CrushRandom) -> [Int] {
        var queue: [Int] = []
        var open: [(color: Int, left: Int)] = []
        var next = 0
        while next < order.count || !open.isEmpty {
            while open.count < max(1, interleave), next < order.count {
                open.append((order[next].color, order[next].seats))
                next += 1
            }
            // Baskı yüksekse en son açılan arabanın yumakları öne geçer (öncekiler durakta bekler);
            // değilse ilk açılan araba biraz öncelikli, sıra çok dağınık olmaz
            let roll = Double.random(in: 0..<1, using: &random)
            let pick = roll < pressure ? open.count - 1
                : (roll < pressure + (1 - pressure) * 0.5 ? 0 : Int.random(in: 0..<open.count, using: &random))
            queue.append(open[pick].color)
            open[pick].left -= 1
            if open[pick].left == 0 { open.remove(at: pick) }
        }
        return queue
    }
}

extension YarnTaxiGame {
    /// Bölüm üretimi ve çözücü için: arabayı durağa götürmeden otoparktan kaldırır.
    mutating func removeFromLot(_ id: Int) {
        lotRemove(id)
    }
}
