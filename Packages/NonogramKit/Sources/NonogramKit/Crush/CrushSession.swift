import Foundation

/// Bir Miyav Crush bölümünün oyunu: hamle sayısı, puan, hedef sayaçları, yıldızlar ve bölüm sonu.
///
/// Kurallar:
/// - Her geçerli takas bir hamle harcar; geçersiz takas hamle harcamaz.
/// - **Toplama ve özel eşya hedefli bölümler** hedefler tamamlanınca hemen kazanılır; kalan hamleler
///   "Kedi Çılgınlığı"yla puana döner (`celebrate()`).
/// - **Yalnızca puan hedefli bölümler** bütün hamleler oynanınca biter; puan hedefe ulaştıysa kazanılır.
/// - Hamleler biter ve hedefler tamamlanmadıysa bölüm kaybedilir (+5 hamleyle devam edilebilir).
/// - Yıldız: kazanılan bölüm en az 1 yıldız; 2. ve 3. yıldız puan eşiklerinden.
public struct CrushSession: Sendable {
    public enum Status: Hashable, Sendable {
        case playing
        case won
        case lost
    }

    /// Hedefin anlık durumu (üst çubukta gösterilir).
    public struct GoalProgress: Hashable, Sendable {
        public let goal: CrushGoal
        public let current: Int

        public var target: Int { goal.target }
        public var isComplete: Bool { current >= target }
        /// Kalan miktar (toplama hedeflerinde sayaç geriye sayar)
        public var remaining: Int { max(0, target - current) }
        public var fraction: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
    }

    /// Bir hamlenin oyuncuya yansıyan sonucu.
    public struct Turn: Sendable {
        public let move: CrushMoveResult
        /// Bu hamleyle hedeflere eklenenler (UI eşyaları sayaca uçurur)
        public let collected: [CrushColor: Int]
        public let specialsUsed: Int
        /// Hamleden sonraki durum
        public let status: Status
    }

    /// Kedi Çılgınlığı sonucu.
    public struct Finale: Sendable {
        public let steps: [CrushStep]
        public let movesConverted: Int
        public var score: Int { steps.reduce(0) { $0 + $1.score } }
    }

    public let level: CrushLevel
    public private(set) var engine: CrushEngine
    public private(set) var movesLeft: Int
    public private(set) var movesUsed = 0
    public private(set) var score = 0
    public private(set) var collected: [CrushColor: Int] = [:]
    public private(set) var specialsUsed = 0
    /// Bir hamlede ulaşılan en uzun zincir
    public private(set) var bestCascade = 0
    public private(set) var status: Status = .playing
    public private(set) var hasCelebrated = false

    public init(level: CrushLevel, seed: UInt64) {
        self.level = level
        self.engine = CrushEngine(level: level, seed: seed)
        self.movesLeft = level.moves
    }

    public var board: CrushBoard { engine.board }

    /// Yalnızca puan hedefli bölüm: hamleler bitene kadar oynanır.
    public var isScoreLevel: Bool {
        level.goals.allSatisfy { if case .score = $0 { true } else { false } }
    }

    public var goals: [GoalProgress] {
        level.goals.map { goal in
            switch goal {
            case .score: GoalProgress(goal: goal, current: score)
            case .collect(let color, _): GoalProgress(goal: goal, current: collected[color, default: 0])
            case .specials: GoalProgress(goal: goal, current: specialsUsed)
            }
        }
    }

    public var goalsComplete: Bool { goals.allSatisfy(\.isComplete) }

    /// Şu anki puana göre yıldız (oyun sırasında üstteki çubuk için; kazanılmadıysa en az 0).
    public var stars: Int {
        guard status == .won else { return 0 }
        return Self.stars(score: score, thresholds: level.starScores)
    }

    /// Puan çubuğunda dolan yıldızlar (bölüm bitmeden de).
    public var starsReached: Int {
        level.starScores.filter { score >= $0 }.count
    }

    public static func stars(score: Int, thresholds: [Int]) -> Int {
        max(1, thresholds.filter { score >= $0 }.count)
    }

    public func isValid(_ swap: CrushSwap) -> Bool {
        status == .playing && engine.isValid(swap)
    }

    public func hint() -> CrushSwap? {
        status == .playing ? engine.hint() : nil
    }

    /// Takası oynar. Geçersizse hamle harcanmaz.
    public mutating func play(_ swap: CrushSwap) -> Result<Turn, CrushMoveError> {
        guard status == .playing else { return .failure(.levelOver) }
        switch engine.apply(swap) {
        case .failure(let error):
            return .failure(error)
        case .success(let move):
            movesLeft -= 1
            movesUsed += 1
            return .success(account(move))
        }
    }

    /// Kedi Patisi: tek eşyayı patlatır; hamle harcamaz.
    public mutating func usePaw(at position: GridPosition) -> Turn? {
        guard status == .playing, let move = engine.smash(position) else { return nil }
        return account(move)
    }

    /// Karıştır güçlendiricisi: hamle harcamaz.
    public mutating func shuffle() {
        guard status == .playing else { return }
        engine.shuffle()
    }

    private mutating func account(_ move: CrushMoveResult) -> Turn {
        score += move.score
        bestCascade = max(bestCascade, move.cascades)
        var gained: [CrushColor: Int] = [:]
        var specials = 0
        for step in move.steps {
            for clear in step.clears {
                if let color = clear.piece.color { gained[color, default: 0] += 1 }
                if clear.piece.isSpecial { specials += 1 }
            }
        }
        for (color, count) in gained { collected[color, default: 0] += count }
        specialsUsed += specials
        updateStatus()
        return Turn(move: move, collected: gained, specialsUsed: specials, status: status)
    }

    private mutating func updateStatus() {
        if isScoreLevel {
            if movesLeft <= 0 { status = goalsComplete ? .won : .lost }
        } else if goalsComplete {
            status = .won
        } else if movesLeft <= 0 {
            status = .lost
        }
    }

    /// Kazanılan bölümde kalan hamleleri Kedi Çılgınlığı'na çevirir (bir kez).
    public mutating func celebrate() -> Finale? {
        guard status == .won, !hasCelebrated else { return nil }
        hasCelebrated = true
        let moves = movesLeft
        let steps = engine.celebrate(movesLeft: moves)
        movesLeft = 0
        let finale = Finale(steps: steps, movesConverted: moves)
        score += finale.score
        return finale
    }

    /// +5 hamle güçlendiricisi: kaybedilen bölüme devam ettirir.
    public mutating func addMoves(_ count: Int) {
        guard count > 0, status != .won else { return }
        movesLeft += count
        status = .playing
    }
}
