import Foundation

/// Bir bölümün ayarları.
public struct PawColonyLevel: Hashable, Codable, Sendable {
    public let number: Int
    /// Sahipsiz ev sayısı.
    public let neutrals: Int
    /// Fare evi sayısı (0: rakipsiz öğrenme bölümü).
    public let mice: Int
    /// Kedi evi sayısı.
    public let cats: Int
    /// Farelerin hızı ve saldırganlığı (0-1).
    public let miceLevel: Double
    /// Bölge (0'dan başlar).
    public var region: Int { (number - 1) / PawColonyCatalog.levelsPerRegion }
    /// Bölgenin son bölümü: fare lideri.
    public var isBoss: Bool { number % PawColonyCatalog.levelsPerRegion == 0 }
    /// 3 yıldız için süre (saniye).
    public var parTime: Double { 30 + Double(neutrals) * 8 + Double(mice) * 25 }
}

/// 5 bölge × 20 bölüm. İlk bölümler rakipsiz (yol çizmeyi öğretir); fareler 4. bölümde gelir.
public enum PawColonyCatalog {
    public static let regionCount = 5
    public static let levelsPerRegion = 20
    public static var levelCount: Int { regionCount * levelsPerRegion }

    /// Dengelemenin denediği ayar (fazladan fare evi, fare zorluğu).
    static func level(_ number: Int, extraMice: Int, miceLevel: Double) -> PawColonyLevel {
        let base = level(number)
        return PawColonyLevel(number: number, neutrals: base.neutrals, mice: base.cats + extraMice, cats: base.cats, miceLevel: miceLevel)
    }

    public static func level(_ number: Int) -> PawColonyLevel {
        let number = min(max(number, 1), levelCount)
        let progress = Double(number - 1) / Double(levelCount - 1)
        let local = (number - 1) % levelsPerRegion
        switch number {
        case 1: return PawColonyLevel(number: 1, neutrals: 1, mice: 0, cats: 1, miceLevel: 0)
        case 2: return PawColonyLevel(number: 2, neutrals: 2, mice: 0, cats: 1, miceLevel: 0)
        case 3: return PawColonyLevel(number: 3, neutrals: 4, mice: 0, cats: 1, miceLevel: 0)
        default:
            let isBoss = number % levelsPerRegion == 0
            // İki taraf eşit ev sayısıyla başlar; dengeleme bazı bölümlerde farelere bir ev ekler
            let cats = 1 + Int(progress * 2.5)
            let neutrals = min(8, 2 + Int(progress * 5) + local % 3)
            let tuning = PawColonyTuning.table
            if number <= tuning.count {
                let (extra, level) = tuning[number - 1]
                return PawColonyLevel(number: number, neutrals: neutrals, mice: cats + extra, cats: cats, miceLevel: level)
            }
            var level = 0.12 + 0.55 * progress + 0.15 * Double(local) / Double(levelsPerRegion)
            if isBoss { level += 0.12 }
            return PawColonyLevel(number: number, neutrals: neutrals, mice: cats + (isBoss ? 1 : 0), cats: cats, miceLevel: min(0.95, level))
        }
    }

    /// Bölümün başlangıç haritası: evler birbirinden uzak, kediler altta, fareler üstte;
    /// sahipsiz evler arada. Aynı numara hep aynı harita.
    public static func game(for level: PawColonyLevel, salt: Int = 0) -> PawColonyGame {
        var random = CrushRandom(seed: UInt64(level.number) &* 0x9E37_79B9_7F4A_7C15 &+ 0xC0105 &+ UInt64(salt) &* 0xD1B5_4A32_D192_ED03)
        var nodes: [PawNode] = []
        var positions: [PawPoint] = []
        func place(yRange: ClosedRange<Double>) -> PawPoint {
            var best = PawPoint(x: 0.5, y: (yRange.lowerBound + yRange.upperBound) / 2)
            var bestGap = -1.0
            // En uzak boş yer (birkaç deneme içinden)
            for _ in 0..<40 {
                let point = PawPoint(x: Double.random(in: 0.12...0.88, using: &random), y: Double.random(in: yRange, using: &random))
                let gap = positions.map { $0.distance(to: point) }.min() ?? 1
                if gap > bestGap {
                    best = point
                    bestGap = gap
                }
            }
            positions.append(best)
            return best
        }
        for _ in 0..<level.cats {
            nodes.append(PawNode(id: nodes.count + 1, position: place(yRange: 0.82...0.92), owner: .cats, count: 20))
        }
        for _ in 0..<level.mice {
            let start = 10 + level.miceLevel * 14 + (level.isBoss ? 6 : 0)
            nodes.append(PawNode(id: nodes.count + 1, position: place(yRange: 0.08...0.2), owner: .mice, count: start.rounded()))
        }
        for _ in 0..<level.neutrals {
            let count = Double(Int.random(in: 4...10, using: &random)) + Double(level.number / 12)
            nodes.append(PawNode(id: nodes.count + 1, position: place(yRange: 0.28...0.72), owner: .neutral, count: count))
        }
        return PawColonyGame(nodes: nodes, miceLevel: level.miceLevel, seed: UInt64(level.number) &* 31 &+ UInt64(salt))
    }
}
