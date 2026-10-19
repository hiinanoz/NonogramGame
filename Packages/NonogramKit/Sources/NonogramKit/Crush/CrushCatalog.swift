import Foundation

/// Miyav Crush bölümleri: 15'er bölümlük maceralar. Hedef sayıları ve yıldız eşikleri
/// `CrushBalanceTests` simülasyonuyla ayarlanmıştır (yeniden üretmek için oradaki açıklamaya bakın).
public struct CrushCatalog: Sendable {
    public static let levelsPerEpisode = 15

    public let levels: [CrushLevel]

    public init(levels: [CrushLevel]) {
        self.levels = levels
    }

    public static let standard = CrushCatalog(levels: CrushLevels.all)

    public var episodeCount: Int { (levels.count + Self.levelsPerEpisode - 1) / Self.levelsPerEpisode }

    public func index(of levelID: String) -> Int? { levels.firstIndex { $0.id == levelID } }

    public func level(withID id: String) -> CrushLevel? { levels.first { $0.id == id } }

    /// 1'den başlayan bölüm numarası.
    public func number(of levelID: String) -> Int? { index(of: levelID).map { $0 + 1 } }

    public func level(after levelID: String) -> CrushLevel? {
        guard let index = index(of: levelID), index + 1 < levels.count else { return nil }
        return levels[index + 1]
    }

    /// 0'dan başlayan macera numarası.
    public func episode(containing levelID: String) -> Int? {
        index(of: levelID).map { $0 / Self.levelsPerEpisode }
    }

    public func levels(in episode: Int) -> [CrushLevel] {
        let start = episode * Self.levelsPerEpisode
        guard start < levels.count else { return [] }
        return Array(levels[start..<min(levels.count, start + Self.levelsPerEpisode)])
    }
}

/// Tahta şekilleri. "." oynanabilir, " " delik.
public enum CrushShape: String, CaseIterable, Sendable {
    case square8, square9, catHead, diamond, heart, ring, plus, hourglass, paw

    public var lines: [String] {
        switch self {
        case .square8: Array(repeating: "........", count: 8)
        case .square9: Array(repeating: ".........", count: 9)
        case .catHead: [
            "..     ..",
            "...   ...",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            " ....... ",
            "  .....  ",
        ]
        case .diamond: [
            "   ...   ",
            "  .....  ",
            " ....... ",
            ".........",
            ".........",
            ".........",
            " ....... ",
            "  .....  ",
            "   ...   ",
        ]
        case .heart: [
            " ... ... ",
            ".........",
            ".........",
            ".........",
            ".........",
            " ....... ",
            "  .....  ",
            "   ...   ",
            "   ...   ",
        ]
        case .ring: [
            ".........",
            ".........",
            ".........",
            "...   ...",
            "...   ...",
            "...   ...",
            ".........",
            ".........",
            ".........",
        ]
        case .plus: [
            "  .....  ",
            "  .....  ",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "  .....  ",
            "  .....  ",
        ]
        case .hourglass: [
            ".........",
            " ....... ",
            "  .....  ",
            "   ...   ",
            "   ...   ",
            "   ...   ",
            "  .....  ",
            " ....... ",
            ".........",
        ]
        case .paw: [
            ".. ... ..",
            ".. ... ..",
            ".........",
            ".........",
            ".........",
            " ....... ",
            " ....... ",
            ".........",
            ".........",
        ]
        }
    }

    public var rows: Int { lines.count }
    public var columns: Int { lines.first?.count ?? 0 }
}

extension CrushLevel {
    /// Katalogdaki bölüm (kimlik "crush-001" biçiminde).
    public init(number: Int, shape: CrushShape, moves: Int, colors: Int, goals: [CrushGoal], stars: [Int]) {
        self.init(id: String(format: "crush-%03d", number), rows: shape.rows, columns: shape.columns,
                  shape: shape.lines, moves: moves, colorCount: colors, goals: goals, starScores: stars)
    }
}
