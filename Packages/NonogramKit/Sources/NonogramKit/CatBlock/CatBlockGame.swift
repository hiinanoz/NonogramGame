import Foundation

/// Kedi Kutusu (blok yerleştirme): 8×8 tahta, altta üç parça. Parça tahtaya sürüklenir; dolan
/// satır ve sütunlar temizlenir. Üç parça da yerleşince yeni üç parça gelir. Hiçbir parça
/// sığmayınca oyun biter. Amaç en yüksek puan.
///
/// Puan: yerleşen her kare 1 puan. Temizlenen her satır/sütun 10 puan × aynı anda temizlenen
/// çizgi sayısı (2 çizgi 40, 3 çizgi 90…), kombo çarpanıyla. Arka arkaya temizleme kombo yapar;
/// üç yerleştirme boyunca hiç temizleme olmazsa kombo sıfırlanır. Tahta tamamen boşalırsa +300.
public struct CatBlockGame: Codable, Sendable {
    public static let size = 8
    public static let trayCount = 3
    /// Kombo, temizlemesiz bu kadar yerleştirmeden sonra biter.
    public static let comboGrace = 3

    /// Satır satır hücreler; dolu hücrede rengin numarası.
    public private(set) var cells: [Int?]
    /// Alttaki parçalar (yerleşen parçanın yeri boş kalır).
    public private(set) var tray: [CatBlockPiece?]
    public private(set) var score = 0
    public private(set) var combo = 0
    public private(set) var placementsSinceClear = 0
    public private(set) var linesCleared = 0
    public private(set) var piecesPlaced = 0
    public private(set) var bestCombo = 0
    /// Bu oyunda tahta silme hakkı kullanıldı mı (oyun başına bir kez).
    public private(set) var usedBoardClear = false
    private var random: CrushRandom
    private var nextPieceID = 1

    public init(seed: UInt64) {
        cells = Array(repeating: nil, count: Self.size * Self.size)
        tray = []
        random = CrushRandom(seed: seed)
        refillTray()
    }

    public subscript(row: Int, column: Int) -> Int? {
        cells[row * Self.size + column]
    }

    public var isOver: Bool {
        !tray.contains { piece in piece.map { canPlaceAnywhere($0) } ?? false }
    }

    // MARK: - Yerleştirme

    public func canPlace(_ piece: CatBlockPiece, row: Int, column: Int) -> Bool {
        for cell in piece.shape.cells {
            let r = row + cell.row
            let c = column + cell.column
            guard (0..<Self.size).contains(r), (0..<Self.size).contains(c), self[r, c] == nil else { return false }
        }
        return true
    }

    public func canPlaceAnywhere(_ piece: CatBlockPiece) -> Bool {
        for row in 0..<Self.size {
            for column in 0..<Self.size where canPlace(piece, row: row, column: column) {
                return true
            }
        }
        return false
    }

    /// Bir yerleştirmenin sonucu (arayüz efektleri için).
    public struct Placement: Sendable, Equatable {
        public let rows: [Int]
        public let columns: [Int]
        /// Temizlenen hücreler ve renkleri (patlama efekti).
        public let clearedCells: [CatBlockCell]
        public let points: Int
        public let combo: Int
        public let boardCleared: Bool
        public var lineCount: Int { rows.count + columns.count }
    }

    @discardableResult
    public mutating func place(trayIndex: Int, row: Int, column: Int) -> Placement? {
        guard tray.indices.contains(trayIndex), let piece = tray[trayIndex],
              canPlace(piece, row: row, column: column) else { return nil }
        for cell in piece.shape.cells {
            cells[(row + cell.row) * Self.size + column + cell.column] = piece.color
        }
        tray[trayIndex] = nil
        piecesPlaced += 1
        var points = piece.shape.cells.count

        let fullRows = (0..<Self.size).filter { r in (0..<Self.size).allSatisfy { self[r, $0] != nil } }
        let fullColumns = (0..<Self.size).filter { c in (0..<Self.size).allSatisfy { self[$0, c] != nil } }
        var cleared: [CatBlockCell] = []
        var seen = Set<Int>()
        for r in fullRows {
            for c in 0..<Self.size where seen.insert(r * Self.size + c).inserted {
                cleared.append(CatBlockCell(row: r, column: c, color: self[r, c] ?? 0))
            }
        }
        for c in fullColumns {
            for r in 0..<Self.size where seen.insert(r * Self.size + c).inserted {
                cleared.append(CatBlockCell(row: r, column: c, color: self[r, c] ?? 0))
            }
        }
        for index in seen { cells[index] = nil }

        let lines = fullRows.count + fullColumns.count
        var boardCleared = false
        if lines > 0 {
            combo += 1
            placementsSinceClear = 0
            linesCleared += lines
            points += 10 * lines * lines * combo
            if cells.allSatisfy({ $0 == nil }) {
                boardCleared = true
                points += 300
            }
            bestCombo = max(bestCombo, combo)
        } else {
            placementsSinceClear += 1
            if placementsSinceClear >= Self.comboGrace { combo = 0 }
        }
        score += points
        if tray.allSatisfy({ $0 == nil }) { refillTray() }
        return Placement(rows: fullRows, columns: fullColumns, clearedCells: cleared, points: points,
                         combo: lines > 0 ? combo : 0, boardCleared: boardCleared)
    }

    /// Tahta silme hakkı (oyun başına bir kez, reklam ya da Premium): bütün bloklar kalkar, puan
    /// korunur, sıkışan parçalar yeniden oynanabilir.
    @discardableResult
    public mutating func clearBoard() -> [CatBlockCell] {
        guard !usedBoardClear else { return [] }
        usedBoardClear = true
        var cleared: [CatBlockCell] = []
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                if let color = self[r, c] { cleared.append(CatBlockCell(row: r, column: c, color: color)) }
            }
        }
        cells = Array(repeating: nil, count: Self.size * Self.size)
        combo = 0
        placementsSinceClear = 0
        return cleared
    }

    // MARK: - Yeni parçalar

    /// Üç yeni parça. Tahta doldukça küçük parçalar biraz daha sık gelir; üçünden en az biri
    /// (mümkünse) tahtaya sığar, böylece oyun şansa bağlı çok erken bitmez.
    private mutating func refillTray() {
        var pieces: [CatBlockPiece] = []
        let filled = Double(cells.compactMap { $0 }.count) / Double(cells.count)
        for _ in 0..<Self.trayCount {
            pieces.append(makePiece(filled: filled))
        }
        if !pieces.contains(where: canPlaceAnywhere) {
            // Sığan bir parça bulunur (küçükten büyüğe)
            let fitting = CatBlockShape.all.sorted { $0.cells.count < $1.cells.count }.first { shape in
                canPlaceAnywhere(CatBlockPiece(id: 0, shape: shape, color: 0))
            }
            if let fitting {
                pieces[Int(random.next() % UInt64(Self.trayCount))] = CatBlockPiece(
                    id: takeID(), shape: fitting, color: Int(random.next() % UInt64(CatBlockPiece.colorCount)))
            }
        }
        tray = pieces
    }

    private mutating func makePiece(filled: Double) -> CatBlockPiece {
        let shapes = CatBlockShape.all
        // Ağırlık: büyük parçalar tahta doldukça seyrekleşir
        let weights: [Double] = shapes.map { shape in
            let size = Double(shape.cells.count)
            return shape.weight * (size >= 5 ? max(0.25, 1 - filled * 1.2) : 1)
        }
        let total = weights.reduce(0, +)
        var pick = Double(random.next() % 1_000_000) / 1_000_000 * total
        var chosen = shapes[0]
        for (shape, weight) in zip(shapes, weights) {
            pick -= weight
            if pick <= 0 {
                chosen = shape
                break
            }
        }
        return CatBlockPiece(id: takeID(), shape: chosen, color: Int(random.next() % UInt64(CatBlockPiece.colorCount)))
    }

    private mutating func takeID() -> Int {
        defer { nextPieceID += 1 }
        return nextPieceID
    }
}

public struct CatBlockCell: Hashable, Codable, Sendable {
    public let row: Int
    public let column: Int
    public let color: Int
}

public struct CatBlockPiece: Hashable, Codable, Sendable, Identifiable {
    public static let colorCount = 7
    public let id: Int
    public let shape: CatBlockShape
    public let color: Int
}

/// Parça şekli: (satır, sütun) kareleri, sol üst köşe (0, 0).
public struct CatBlockShape: Hashable, Codable, Sendable {
    public struct Cell: Hashable, Codable, Sendable {
        public let row: Int
        public let column: Int
    }

    public let cells: [Cell]
    /// Gelme sıklığı (göreli).
    public let weight: Double

    public var rows: Int { (cells.map(\.row).max() ?? 0) + 1 }
    public var columns: Int { (cells.map(\.column).max() ?? 0) + 1 }

    init(_ rows: [String], weight: Double = 1) {
        var cells: [Cell] = []
        for (r, line) in rows.enumerated() {
            for (c, char) in line.enumerated() where char == "#" {
                cells.append(Cell(row: r, column: c))
            }
        }
        self.cells = cells
        self.weight = weight
    }

    public static let all: [CatBlockShape] = [
        CatBlockShape(["#"], weight: 0.6),
        CatBlockShape(["##"]), CatBlockShape(["#", "#"]),
        CatBlockShape(["###"]), CatBlockShape(["#", "#", "#"]),
        CatBlockShape(["####"], weight: 0.8), CatBlockShape(["#", "#", "#", "#"], weight: 0.8),
        CatBlockShape(["#####"], weight: 0.5), CatBlockShape(["#", "#", "#", "#", "#"], weight: 0.5),
        CatBlockShape(["##", "##"], weight: 1.2),
        CatBlockShape(["###", "###", "###"], weight: 0.45),
        CatBlockShape(["##", "#."]), CatBlockShape(["##", ".#"]), CatBlockShape(["#.", "##"]), CatBlockShape([".#", "##"]),
        CatBlockShape(["###", "#..", "#.."], weight: 0.35), CatBlockShape(["###", "..#", "..#"], weight: 0.35),
        CatBlockShape(["#..", "#..", "###"], weight: 0.35), CatBlockShape(["..#", "..#", "###"], weight: 0.35),
        CatBlockShape(["###", ".#."], weight: 0.8), CatBlockShape([".#.", "###"], weight: 0.8),
        CatBlockShape(["#.", "##", "#."], weight: 0.8), CatBlockShape([".#", "##", ".#"], weight: 0.8),
        CatBlockShape(["##.", ".##"], weight: 0.8), CatBlockShape([".##", "##."], weight: 0.8),
        CatBlockShape(["#.", "##", ".#"], weight: 0.8), CatBlockShape([".#", "##", "#."], weight: 0.8),
        CatBlockShape(["#..", "###"], weight: 0.7), CatBlockShape(["..#", "###"], weight: 0.7),
        CatBlockShape(["###", "#.."], weight: 0.7), CatBlockShape(["###", "..#"], weight: 0.7),
        CatBlockShape(["##", "#.", "#."], weight: 0.7), CatBlockShape(["##", ".#", ".#"], weight: 0.7),
        CatBlockShape(["#.", "#.", "##"], weight: 0.7), CatBlockShape([".#", ".#", "##"], weight: 0.7),
        CatBlockShape(["##", "##", "##"], weight: 0.4), CatBlockShape(["###", "###"], weight: 0.4),
    ]
}
