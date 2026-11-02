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

    /// Başlangıç kolaylığı: 500 puana kadar tam (1), 2000 puanda biter (0).
    var ease: Double {
        min(max((2000 - Double(score)) / 1500, 0), 1)
    }

    /// Uzun oyunda zorlaşma: 5000 puanda başlar, 10000 puanda tam (1).
    var challenge: Double {
        min(max((Double(score) - 5000) / 5000, 0), 1)
    }

    /// Üç yeni parça. Zorluk puana bağlı:
    /// - Başta (kolaylık) çoğunlukla küçük parçalar gelir, üçü de tahtaya sığar ve sık sık bir
    ///   satır/sütun tamamlayan "yardımcı" parça gelir; oyuncu baştan pes etmez.
    /// - 500-2000 puan arasında yardım azalır, sonra normal oyun; 5000'den sonra büyük parçalar
    ///   biraz daha sık gelir.
    /// - Her durumda tahta doldukça küçük parçalar daha sık gelir; üçünden en az biri (mümkünse)
    ///   tahtaya sığar.
    private mutating func refillTray() {
        var pieces: [CatBlockPiece] = []
        let filled = Double(cells.compactMap { $0 }.count) / Double(cells.count)
        for _ in 0..<Self.trayCount {
            pieces.append(makePiece(filled: filled))
        }
        let ease = self.ease
        if ease > 0 {
            // Kolaylık sürerken sığmayan parçalar sığan küçük parçalarla değişir
            if ease >= 0.3 {
                for index in pieces.indices where !canPlaceAnywhere(pieces[index]) {
                    if let fitting = smallestFittingShape() {
                        pieces[index] = CatBlockPiece(id: takeID(), shape: fitting, color: randomColor())
                    }
                }
            }
            // Yardımcı parça: bir satırı ya da sütunu tamamlar
            if chance(0.7 * ease), let helper = lineCompletingShape() {
                pieces[Int(random.next() % UInt64(Self.trayCount))] = CatBlockPiece(
                    id: takeID(), shape: helper, color: randomColor())
            }
        }
        if !pieces.contains(where: canPlaceAnywhere), let fitting = smallestFittingShape() {
            pieces[Int(random.next() % UInt64(Self.trayCount))] = CatBlockPiece(
                id: takeID(), shape: fitting, color: randomColor())
        }
        tray = pieces
    }

    private mutating func makePiece(filled: Double) -> CatBlockPiece {
        let shapes = CatBlockShape.all
        let ease = self.ease
        let challenge = self.challenge
        // Ağırlık: büyük parçalar tahta doldukça ve oyunun başında seyrekleşir, uzun oyunda sıklaşır
        let weights: [Double] = shapes.map { shape in
            let size = Double(shape.cells.count)
            var weight = shape.weight * (size >= 5 ? max(0.25, 1 - filled * 1.2) : 1)
            if size <= 3 {
                weight *= 1 + 1.5 * ease
            } else if size >= 9 {
                weight *= 1 - 0.9 * ease
            } else if size >= 5 {
                weight *= 1 - 0.7 * ease
            }
            if size >= 5 {
                weight *= 1 + 0.5 * challenge
            }
            return weight
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
        return CatBlockPiece(id: takeID(), shape: chosen, color: randomColor())
    }

    private func smallestFittingShape() -> CatBlockShape? {
        CatBlockShape.all.sorted { $0.cells.count < $1.cells.count }.first { shape in
            canPlaceAnywhere(CatBlockPiece(id: 0, shape: shape, color: 0))
        }
    }

    /// Bir yere konunca en az bir satır ya da sütunu tamamlayan şekil (en büyüğü; yoksa `nil`).
    private func lineCompletingShape() -> CatBlockShape? {
        var best: CatBlockShape?
        for shape in CatBlockShape.all where shape.cells.count > (best?.cells.count ?? 0) {
            let piece = CatBlockPiece(id: 0, shape: shape, color: 0)
            outer: for row in 0..<Self.size {
                for column in 0..<Self.size where canPlace(piece, row: row, column: column) && completesLine(shape, row: row, column: column) {
                    best = shape
                    break outer
                }
            }
        }
        return best
    }

    private func completesLine(_ shape: CatBlockShape, row: Int, column: Int) -> Bool {
        let placed = Set(shape.cells.map { (row + $0.row) * Self.size + column + $0.column })
        func full(_ indices: [Int]) -> Bool { indices.allSatisfy { cells[$0] != nil || placed.contains($0) } }
        let rows = Set(shape.cells.map { row + $0.row })
        let columns = Set(shape.cells.map { column + $0.column })
        return rows.contains { r in full((0..<Self.size).map { r * Self.size + $0 }) }
            || columns.contains { c in full((0..<Self.size).map { $0 * Self.size + c }) }
    }

    private mutating func chance(_ probability: Double) -> Bool {
        Double(random.next() % 1_000_000) / 1_000_000 < probability
    }

    private mutating func randomColor() -> Int {
        Int(random.next() % UInt64(CatBlockPiece.colorCount))
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
