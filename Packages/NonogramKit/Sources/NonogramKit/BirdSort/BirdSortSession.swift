import Foundation

/// Oynanan bir kuş sıralama bölümü: tahta, hamle sayısı, geri alma geçmişi ve ekstra dal.
public struct BirdSortSession: Codable, Sendable {
    public let level: BirdSortLevel
    public private(set) var board: BirdSortBoard
    /// Üreticinin çözümünün hamle sayısı (yıldızlar buna göre).
    public let par: Int
    public private(set) var moves = 0
    public private(set) var history: [BirdSortBoard] = []
    public private(set) var extraBranches = 0
    /// İpucu planı: hesaplandığı tahta ve kalan hamleler. Oyuncu plandan çıkınca yeniden hesaplanır;
    /// her seferinde baştan çözmek ipuçlarını bir ileri bir geri gidip gelen hamlelere sokabilir.
    private var plan: (board: BirdSortBoard, moves: [BirdSortBoard.Move])?

    /// İpucu planı kaydedilmez (dönüşte yeniden hesaplanır).
    private enum CodingKeys: String, CodingKey {
        case level, board, par, moves, history, extraBranches
    }
    public static let maxExtraBranches = 1

    public init(level: BirdSortLevel) {
        let puzzle = BirdSortCatalog.puzzle(for: level)
        self.init(level: level, board: puzzle.board, par: puzzle.par)
    }

    public init(level: BirdSortLevel, board: BirdSortBoard, par: Int) {
        self.level = level
        self.board = board
        self.par = max(1, par)
    }

    public var isWon: Bool { board.isCleared }
    public var canUndo: Bool { !history.isEmpty }
    public var canAddBranch: Bool { extraBranches < Self.maxExtraBranches && !isWon }

    /// Takılma: geçerli hamle kalmadı (geri al ya da ekstra dal gerekir).
    public var isStuck: Bool { !isWon && board.legalMoves().isEmpty }

    @discardableResult
    public mutating func play(from source: Int, to target: Int) -> BirdSortBoard.Move? {
        var next = board
        guard let move = next.move(from: source, to: target) else { return nil }
        history.append(board)
        board = next
        moves += 1
        if let current = plan, let step = current.moves.first, step.source == source, step.target == target {
            plan = (next, Array(current.moves.dropFirst()))
        } else {
            plan = nil
        }
        return move
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = history.popLast() else { return false }
        // Ekstra dal geri alınmaz: önceki tahtaya da eklenir
        var restored = previous
        while restored.branches.count < board.branches.count { restored.addBranch() }
        board = restored
        plan = nil
        return true
    }

    @discardableResult
    public mutating func addBranch() -> Bool {
        guard canAddBranch else { return false }
        board.addBranch()
        history = history.map { var old = $0; old.addBranch(); return old }
        extraBranches += 1
        plan = nil
        return true
    }

    /// 3 yıldız: çözüm hamlesine yakın; 2 yıldız: biraz fazlası; yoksa 1.
    public var stars: Int {
        guard isWon else { return 0 }
        if moves <= par + max(2, par / 5) && extraBranches == 0 { return 3 }
        if moves <= par + max(5, par / 2) { return 2 }
        return 1
    }

    /// İpucu: şu anki tahtadan çözüme giden sıradaki hamle (bulunamazsa nil).
    public mutating func hint(nodeLimit: Int = 60_000) -> (source: Int, target: Int)? {
        if plan == nil || plan?.board != board {
            guard let solution = BirdSortSolver.solve(board, nodeLimit: nodeLimit) else { return nil }
            plan = (board, solution.moves)
        }
        guard let step = plan?.moves.first else { return nil }
        return (step.source, step.target)
    }
}
