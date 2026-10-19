import Foundation

// Miyav Crush: 3'lü eşleştirme (match-3) modunun veri modelleri.
// Motor (CrushEngine) ve arayüz bu tiplerle konuşur; hepsi değer tipidir, UI'ya bağlı değildir.

/// Tahtadaki eşyaların rengi. Her renk tek bir kedi eşyasıdır.
public enum CrushColor: Int, CaseIterable, Codable, Sendable {
    /// Mavi yün yumağı
    case yarn
    /// Kırmızı tüylü kedi oltası
    case wand
    /// Sarı balık şekilli ödül maması
    case treat
    /// Yeşil mama / su kabı
    case bowl
    /// Mor peluş fare
    case mouse
    /// Turuncu pati izi (tırmalama tahtası)
    case paw
}

/// Özel eşyalar (Candy Crush karşılıkları).
public enum CrushSpecial: Int, Codable, Sendable {
    case none
    /// Çizgili Işıltılı Yumak: bütün satırı temizler (4'lü eşleşme)
    case stripedRow
    /// Çizgili Işıltılı Yumak: bütün sütunu temizler (4'lü eşleşme)
    case stripedColumn
    /// Çıngırak Kutusu: 3x3 patlar, düştükten sonra bir kez daha (T/L şeklinde 5'li)
    case wrapped
    /// Çıngırak Kutusu ilk patlamasını yaptı; düştükten sonra ikinci kez patlayacak
    case wrappedPrimed
    /// Altın Kedi Gözü: takas edildiği renkteki her şeyi temizler (düz 5'li). Rengi yoktur.
    case colorBomb

    public var isStriped: Bool { self == .stripedRow || self == .stripedColumn }
    public var isWrapped: Bool { self == .wrapped || self == .wrappedPrimed }
}

/// Tahtadaki tek bir eşya. `id` animasyonlarda aynı eşyayı ekranda takip etmek içindir.
public struct CrushPiece: Hashable, Codable, Sendable {
    public let id: Int
    /// Renk bombasında `nil`.
    public var color: CrushColor?
    public var special: CrushSpecial

    public init(id: Int, color: CrushColor?, special: CrushSpecial = .none) {
        self.id = id
        self.color = special == .colorBomb ? nil : color
        self.special = special
    }

    public var isSpecial: Bool { special != .none }
}

/// Tahta: satır × sütun hücre. `playable == false` olan hücreler şekilli bölümler içindir
/// (delik); oraya eşya konmaz, eşyalar üstünden geçerek düşer.
public struct CrushBoard: Hashable, Codable, Sendable {
    public let rows: Int
    public let columns: Int
    public private(set) var playable: [Bool]
    public internal(set) var cells: [CrushPiece?]

    public init(rows: Int, columns: Int, playable: [Bool]? = nil) {
        self.rows = rows
        self.columns = columns
        self.playable = playable ?? Array(repeating: true, count: rows * columns)
        self.cells = Array(repeating: nil, count: rows * columns)
    }

    @inline(__always)
    public func index(_ position: GridPosition) -> Int { position.row * columns + position.column }

    public func contains(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < rows && position.column >= 0 && position.column < columns
    }

    public func isPlayable(_ position: GridPosition) -> Bool {
        contains(position) && playable[index(position)]
    }

    public subscript(position: GridPosition) -> CrushPiece? {
        get { contains(position) ? cells[index(position)] : nil }
        set { if isPlayable(position) { cells[index(position)] = newValue } }
    }

    public var positions: [GridPosition] {
        (0..<rows).flatMap { row in (0..<columns).map { GridPosition(row: row, column: $0) } }
    }

    public var playablePositions: [GridPosition] { positions.filter(isPlayable) }

    /// Yatay ve dikey komşular (çapraz yok).
    public func areAdjacent(_ a: GridPosition, _ b: GridPosition) -> Bool {
        abs(a.row - b.row) + abs(a.column - b.column) == 1
    }
}

/// Oyuncunun hamlesi: iki komşu hücrenin takası.
public struct CrushSwap: Hashable, Codable, Sendable {
    public let from: GridPosition
    public let to: GridPosition

    public init(from: GridPosition, to: GridPosition) {
        self.from = from
        self.to = to
    }

    public var isHorizontal: Bool { from.row == to.row }
}

/// Bir hücrenin neden temizlendiği (efekt seçimi için).
public enum CrushClearReason: Hashable, Sendable {
    /// Normal 3/4/5'li eşleşme
    case match
    /// Çizgili yumak satır/sütun ipliği
    case stripe(GridPosition)
    /// Çıngırak kutusu patlaması
    case explosion(GridPosition)
    /// Altın kedi gözü lazeri
    case colorBomb(GridPosition)
}

/// Patlayan tek eşya.
public struct CrushClear: Hashable, Sendable {
    public let position: GridPosition
    public let piece: CrushPiece
    public let reason: CrushClearReason
}

/// Eşleşmeden doğan yeni özel eşya.
public struct CrushCreation: Hashable, Sendable {
    public let position: GridPosition
    public let piece: CrushPiece
}

/// Etkinleşen özel eşya (UI'da iplik, patlama ya da lazer efekti çizilir).
public struct CrushActivation: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case row
        case column
        case explosion(radius: Int)
        case colorBomb(CrushColor?)
        case board
    }

    public let position: GridPosition
    public let kind: Kind
}

/// Yerçekimiyle düşen ya da yukarıdan gelen eşya.
public struct CrushFall: Hashable, Sendable {
    public let piece: CrushPiece
    /// Yeni gelen eşyalarda tahtanın üstündeki sanal satır (negatif).
    public let fromRow: Int
    public let to: GridPosition
    public let isNew: Bool
}

/// Bir zincir adımı: önce temizlenir (efektler), özel eşyalar doğar, sonra düşme/dolma.
/// UI adımları sırayla oynatır.
public struct CrushStep: Sendable {
    /// 1'den başlar; 2 ve üstü zincirleme (kombo) adımlarıdır.
    public let cascade: Int
    public internal(set) var clears: [CrushClear] = []
    public internal(set) var activations: [CrushActivation] = []
    public internal(set) var creations: [CrushCreation] = []
    public internal(set) var falls: [CrushFall] = []
    public internal(set) var score = 0
}

/// Bir hamlenin bütün sonucu.
public struct CrushMoveResult: Sendable {
    public let swap: CrushSwap
    public let steps: [CrushStep]
    /// Hamleden sonra geçerli hamle kalmadığı için tahta karıştırıldıysa yeni dizilim.
    public let shuffled: Bool

    public var score: Int { steps.reduce(0) { $0 + $1.score } }
    public var cascades: Int { steps.map(\.cascade).max() ?? 0 }
    public var clearedCount: Int { steps.reduce(0) { $0 + $1.clears.count } }
}

/// Hamlenin geçersiz olma nedeni (UI eşyaları geri kaydırır).
public enum CrushMoveError: Error, Equatable, Sendable {
    case notAdjacent
    case notPlayable
    case noMatch
    /// Bölüm bitti (hamle kalmadı ya da kazanıldı)
    case levelOver
}

// MARK: - Bölüm ve hedefler

/// Bölüm hedefi (yıldız ve bitiş koşulu).
public enum CrushGoal: Hashable, Codable, Sendable {
    /// Belirli bir puana ulaş
    case score(Int)
    /// Belirli renkten şu kadar eşya topla
    case collect(CrushColor, Int)
    /// Belirli sayıda özel eşya patlat
    case specials(Int)

    public var target: Int {
        switch self {
        case .score(let target), .collect(_, let target), .specials(let target): target
        }
    }
}

/// Bir Miyav Crush bölümü.
public struct CrushLevel: Hashable, Codable, Sendable {
    public let id: String
    public let rows: Int
    public let columns: Int
    /// Satır satır; "." oynanabilir, " " delik. Boşsa tahta tamamen oynanabilir.
    public let shape: [String]
    public let moves: Int
    /// Kullanılan renk sayısı (4-6); az renk = kolay
    public let colorCount: Int
    public let goals: [CrushGoal]
    /// 1, 2 ve 3 yıldız için puan eşikleri
    public let starScores: [Int]

    public init(id: String, rows: Int = 9, columns: Int = 9, shape: [String] = [], moves: Int,
                colorCount: Int = 6, goals: [CrushGoal], starScores: [Int]) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.shape = shape
        self.moves = moves
        self.colorCount = colorCount
        self.goals = goals
        self.starScores = starScores
    }

    public var playableMask: [Bool] {
        guard shape.count == rows else { return Array(repeating: true, count: rows * columns) }
        return shape.flatMap { line in
            (0..<columns).map { column in
                let characters = Array(line)
                return column < characters.count ? characters[column] != " " : false
            }
        }
    }

    public var colors: [CrushColor] { Array(CrushColor.allCases.prefix(max(3, min(colorCount, CrushColor.allCases.count)))) }
}

// MARK: - Rastgelelik

/// Tekrarlanabilir rastgele sayı üreteci (SplitMix64): aynı tohumla aynı tahta, testler için.
public struct CrushRandom: RandomNumberGenerator, Codable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
