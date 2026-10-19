import Foundation

/// Miyav Crush tahta motoru: takas, eşleşme bulma, özel eşya üretme ve etkinleştirme,
/// yerçekimi/dolum, zincirleme (kaskad), olası hamle ve karıştırma.
///
/// Saf değer tipidir: arayüzden, zamandan ve animasyondan bağımsızdır. Her hamle, UI'ın sırayla
/// oynatacağı adımlar (`CrushStep`) döndürür; tahtanın son hâli `board`'dadır.
public struct CrushEngine: Sendable {
    public private(set) var board: CrushBoard
    public let colors: [CrushColor]
    private var random: CrushRandom
    private var nextID: Int

    /// Bir zincirde en fazla adım (sonsuz döngüye karşı güvenlik).
    static let maxCascades = 60

    // MARK: - Puanlar

    public enum Points {
        /// Eşleşmeyle ya da özel eşyayla temizlenen her eşya (zincir adımıyla çarpılır)
        public static let perPiece = 20
        public static let striped = 60
        public static let wrapped = 100
        public static let colorBomb = 200
    }

    // MARK: - Kurulum

    /// Bölüm için başlangıç tahtası: hazır eşleşme yok, en az bir geçerli hamle var.
    public init(level: CrushLevel, seed: UInt64) {
        self.init(rows: level.rows, columns: level.columns, playable: level.playableMask, colors: level.colors, seed: seed)
    }

    public init(rows: Int = 9, columns: Int = 9, playable: [Bool]? = nil, colors: [CrushColor] = CrushColor.allCases, seed: UInt64) {
        self.board = CrushBoard(rows: rows, columns: columns, playable: playable)
        self.colors = colors
        self.random = CrushRandom(seed: seed)
        self.nextID = 1
        fillWithoutMatches()
    }

    /// Hazır bir tahtayla (testler ve kayıttan dönüş için). Tahta olduğu gibi kullanılır.
    public init(board: CrushBoard, colors: [CrushColor] = CrushColor.allCases, seed: UInt64) {
        self.board = board
        self.colors = colors
        self.random = CrushRandom(seed: seed)
        self.nextID = (board.cells.compactMap { $0?.id }.max() ?? 0) + 1
    }

    // MARK: - Hamleler

    /// Takas geçerli mi: komşu, ikisi de dolu ve ya eşleşme oluşturuyor ya da özel eşya birleşimi.
    public func isValid(_ swap: CrushSwap) -> Bool {
        guard board.areAdjacent(swap.from, swap.to),
              let a = board[swap.from], let b = board[swap.to] else { return false }
        if Self.comboKind(a, b) != nil { return true }
        // Yalnızca takas edilen iki hücrenin çevresine bakılır (bütün tahtayı taramaktan çok hızlı)
        return makesLine(b.color, at: swap.from, ignoring: swap.to)
            || makesLine(a.color, at: swap.to, ignoring: swap.from)
    }

    /// `color` rengindeki eşya `position`'a konunca yatay ya da dikey 3'lü olur mu?
    /// `ignoring`: takasın öbür hücresi (orada artık eski eşya yok).
    private func makesLine(_ color: CrushColor?, at position: GridPosition, ignoring other: GridPosition) -> Bool {
        guard let color else { return false }
        func same(_ dr: Int, _ dc: Int) -> Int {
            var count = 0
            var cell = GridPosition(row: position.row + dr, column: position.column + dc)
            while cell != other, board.isPlayable(cell), board[cell]?.color == color {
                count += 1
                cell = GridPosition(row: cell.row + dr, column: cell.column + dc)
            }
            return count
        }
        return same(0, -1) + same(0, 1) >= 2 || same(-1, 0) + same(1, 0) >= 2
    }

    /// Takası uygular. Eşleşme yoksa tahta değişmez ve hata döner (UI eşyaları geri kaydırır).
    public mutating func apply(_ swap: CrushSwap) -> Result<CrushMoveResult, CrushMoveError> {
        guard board.areAdjacent(swap.from, swap.to) else { return .failure(.notAdjacent) }
        guard let a = board[swap.from], let b = board[swap.to] else { return .failure(.notPlayable) }

        board[swap.from] = b
        board[swap.to] = a

        var steps: [CrushStep] = []
        if let combo = Self.comboKind(a, b) {
            var step = CrushStep(cascade: 1)
            let (initial, activation) = comboClears(combo, moved: a, target: b, swap: swap)
            if let activation { step.activations.append(activation) }
            resolve(initial: initial, consumed: [swap.from, swap.to], step: &step)
            settle(&step)
            steps.append(step)
        } else {
            let groups = Self.findMatches(in: board)
            guard !groups.isEmpty else {
                board[swap.from] = a
                board[swap.to] = b
                return .failure(.noMatch)
            }
            steps.append(resolveMatches(groups, cascade: 1, swap: swap))
        }

        // Zincirleme: yeni eşleşmeler ve ikinci kez patlayacak çıngırak kutuları bitene kadar
        var cascade = 2
        while cascade <= Self.maxCascades {
            let groups = Self.findMatches(in: board)
            let primed = board.playablePositions.filter { board[$0]?.special == .wrappedPrimed }
            if groups.isEmpty && primed.isEmpty { break }
            steps.append(resolveMatches(groups, cascade: cascade, swap: nil, primed: primed))
            cascade += 1
        }

        var shuffled = false
        if possibleMoves().isEmpty {
            shuffled = shuffle()
        }
        return .success(CrushMoveResult(swap: swap, steps: steps, shuffled: shuffled))
    }

    /// Tahtadaki bütün geçerli hamleler.
    public func possibleMoves() -> [CrushSwap] {
        var moves: [CrushSwap] = []
        for position in board.playablePositions {
            for neighbor in [GridPosition(row: position.row, column: position.column + 1),
                             GridPosition(row: position.row + 1, column: position.column)]
            where board.isPlayable(neighbor) {
                let swap = CrushSwap(from: position, to: neighbor)
                if isValid(swap) { moves.append(swap) }
            }
        }
        return moves
    }

    /// Takılan oyuncuya gösterilecek hamle: özel eşya birleşimi, sonra en çok eşya temizleyen.
    public func hint() -> CrushSwap? {
        possibleMoves().max { score(of: $0) < score(of: $1) }
    }

    private func score(of swap: CrushSwap) -> Int {
        guard let a = board[swap.from], let b = board[swap.to] else { return 0 }
        if Self.comboKind(a, b) != nil { return 1_000 }
        var copy = board
        copy[swap.from] = b
        copy[swap.to] = a
        return Self.findMatches(in: copy).reduce(0) { $0 + $1.cells.count * 10 + ($1.special == .none ? 0 : 50) }
    }

    /// Geçerli hamle kalmayınca eşyaları (özel eşyalar dahil) yeniden dağıtır; hazır eşleşme
    /// oluşmaz ve en az bir hamle olur. Başaramazsa tahtayı yeni eşyalarla doldurur.
    @discardableResult
    public mutating func shuffle() -> Bool {
        let positions = board.playablePositions.filter { board[$0] != nil }
        var pieces = positions.compactMap { board[$0] }
        for _ in 0..<200 {
            pieces.shuffle(using: &random)
            var copy = board
            for (position, piece) in zip(positions, pieces) { copy[position] = piece }
            if Self.findMatches(in: copy).isEmpty {
                let saved = board
                board = copy
                if !possibleMoves().isEmpty { return true }
                board = saved
            }
        }
        fillWithoutMatches()
        return true
    }

    // MARK: - Eşleşme bulma

    /// Aynı renkte en az 3 eşyalık yatay ya da dikey dizi.
    struct Run: Hashable {
        let cells: [GridPosition]
        let isHorizontal: Bool
    }

    /// Birbirine değen dizilerden oluşan eşleşme grubu ve doğuracağı özel eşya.
    public struct MatchGroup: Hashable, Sendable {
        public let color: CrushColor
        public let cells: Set<GridPosition>
        public let special: CrushSpecial
        /// Özel eşyanın doğacağı hücre için aday (takas yoksa)
        let anchor: GridPosition
        let longestIsHorizontal: Bool
    }

    static func runs(in board: CrushBoard) -> [Run] {
        var runs: [Run] = []
        func scan(_ line: [GridPosition], horizontal: Bool) {
            var current: [GridPosition] = []
            var color: CrushColor?
            func flush() {
                if current.count >= 3 { runs.append(Run(cells: current, isHorizontal: horizontal)) }
            }
            for position in line {
                let pieceColor = board.isPlayable(position) ? board[position]?.color : nil
                if let pieceColor, pieceColor == color {
                    current.append(position)
                } else {
                    flush()
                    current = pieceColor == nil ? [] : [position]
                    color = pieceColor
                }
            }
            flush()
        }
        for row in 0..<board.rows {
            scan((0..<board.columns).map { GridPosition(row: row, column: $0) }, horizontal: true)
        }
        for column in 0..<board.columns {
            scan((0..<board.rows).map { GridPosition(row: $0, column: column) }, horizontal: false)
        }
        return runs
    }

    /// Eşleşme grupları: birbirine değen yatay ve dikey diziler tek grup olur (T ve L şekilleri).
    public static func findMatches(in board: CrushBoard) -> [MatchGroup] {
        let runs = runs(in: board)
        guard !runs.isEmpty else { return [] }
        // Ortak hücresi olan dizileri birleştir
        var parent = Array(runs.indices)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        var owner: [GridPosition: Int] = [:]
        for (index, run) in runs.enumerated() {
            for cell in run.cells {
                if let other = owner[cell] { parent[find(index)] = find(other) } else { owner[cell] = index }
            }
        }
        var grouped: [Int: [Run]] = [:]
        for index in runs.indices { grouped[find(index), default: []].append(runs[index]) }

        return grouped.keys.sorted().compactMap { key in
            let members = grouped[key]!
            let cells = Set(members.flatMap(\.cells))
            guard let first = members.first?.cells.first, let color = board[first]?.color else { return nil }
            let longest = members.max { $0.cells.count < $1.cells.count }!
            let hasBoth = members.contains { $0.isHorizontal } && members.contains { !$0.isHorizontal }
            let special: CrushSpecial
            let anchor: GridPosition
            if longest.cells.count >= 5 {
                special = .colorBomb
                anchor = longest.cells[longest.cells.count / 2]
            } else if hasBoth {
                special = .wrapped
                // Kesişim hücresi
                let horizontal = Set(members.filter(\.isHorizontal).flatMap(\.cells))
                let vertical = Set(members.filter { !$0.isHorizontal }.flatMap(\.cells))
                anchor = horizontal.intersection(vertical).sorted { ($0.row, $0.column) < ($1.row, $1.column) }.first
                    ?? longest.cells[longest.cells.count / 2]
            } else if longest.cells.count == 4 {
                // Zincirde oluşan 4'lü: yatay dizi sütunu, dikey dizi satırı temizleyen yumak verir
                special = longest.isHorizontal ? .stripedColumn : .stripedRow
                anchor = longest.cells[1]
            } else {
                special = .none
                anchor = longest.cells[longest.cells.count / 2]
            }
            return MatchGroup(color: color, cells: cells, special: special, anchor: anchor,
                              longestIsHorizontal: longest.isHorizontal)
        }
    }

    // MARK: - Çözümleme

    /// Bir adımı çözer: eşleşen ve (varsa) ikinci kez patlayacak hücreleri temizler, özel eşyaları
    /// doğurur, ardından yerçekimi ve dolum.
    private mutating func resolveMatches(_ groups: [MatchGroup], cascade: Int, swap: CrushSwap?,
                                         primed: [GridPosition] = []) -> CrushStep {
        var step = CrushStep(cascade: cascade)
        var initial: [GridPosition: CrushClearReason] = [:]
        var creations: [(GridPosition, CrushPiece)] = []

        for group in groups {
            var spawn: GridPosition?
            if group.special != .none {
                // Oyuncunun taşıdığı eşyanın yerinde doğar; yoksa grubun merkezinde
                let candidates = [swap?.to, swap?.from].compactMap { $0 }.filter { group.cells.contains($0) }
                spawn = candidates.first ?? group.anchor
                // Doğacağı hücrede zaten özel eşya varsa grubun başka bir hücresi
                if board[spawn!]?.isSpecial == true {
                    spawn = group.cells.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
                        .first { board[$0]?.isSpecial != true }
                }
            }
            for cell in group.cells where cell != spawn {
                initial[cell] = .match
            }
            if let spawn {
                var special = group.special
                // Oyuncunun yaptığı 4'lü: yumağın yönü takas yönünü izler (Candy Crush gibi)
                if special.isStriped, let swap {
                    special = swap.isHorizontal ? .stripedRow : .stripedColumn
                }
                let piece = CrushPiece(id: makeID(), color: group.color, special: special)
                creations.append((spawn, piece))
                if let old = board[spawn] {
                    step.clears.append(CrushClear(position: spawn, piece: old, reason: .match))
                }
            }
        }

        // İkinci patlama: düşmüş çıngırak kutuları
        for position in primed {
            step.activations.append(CrushActivation(position: position, kind: .explosion(radius: 1)))
            for cell in square(around: position, radius: 1) where initial[cell] == nil {
                initial[cell] = .explosion(position)
            }
            initial[position] = .explosion(position)
        }

        resolve(initial: initial, consumed: Set(primed), step: &step)

        for (position, piece) in creations {
            board[position] = piece
            step.creations.append(CrushCreation(position: position, piece: piece))
            switch piece.special {
            case .stripedRow, .stripedColumn: step.score += Points.striped
            case .wrapped: step.score += Points.wrapped
            case .colorBomb: step.score += Points.colorBomb
            default: break
            }
        }
        settle(&step)
        return step
    }

    /// Temizlenecek hücreleri işler; temizlenen özel eşyalar kendi efektlerini zincirleme tetikler.
    /// `consumed`: zaten etkinleşmiş (birleşimdeki ya da ikinci patlamasını yapan) eşyalar.
    private mutating func resolve(initial: [GridPosition: CrushClearReason], consumed: Set<GridPosition>,
                                  step: inout CrushStep) {
        var queue = initial.sorted { ($0.key.row, $0.key.column) < ($1.key.row, $1.key.column) }
        var handled = Set<GridPosition>()
        var cleared = 0

        while !queue.isEmpty {
            let (position, reason) = queue.removeFirst()
            guard handled.insert(position).inserted, let piece = board[position] else { continue }

            if !consumed.contains(position) {
                switch piece.special {
                case .stripedRow:
                    step.activations.append(CrushActivation(position: position, kind: .row))
                    queue += (0..<board.columns).map { (GridPosition(row: position.row, column: $0), .stripe(position)) }
                case .stripedColumn:
                    step.activations.append(CrushActivation(position: position, kind: .column))
                    queue += (0..<board.rows).map { (GridPosition(row: $0, column: position.column), .stripe(position)) }
                case .wrapped:
                    // İlk patlama: kutu yerinde kalır, düştükten sonra bir kez daha patlar
                    step.activations.append(CrushActivation(position: position, kind: .explosion(radius: 1)))
                    queue += square(around: position, radius: 1).map { ($0, .explosion(position)) }
                    board[position] = CrushPiece(id: piece.id, color: piece.color, special: .wrappedPrimed)
                    continue
                case .wrappedPrimed:
                    // İkinci patlamasını bekliyor: bu adımda yok olmaz
                    continue
                case .colorBomb:
                    let color = mostCommonColor()
                    step.activations.append(CrushActivation(position: position, kind: .colorBomb(color)))
                    if let color {
                        queue += board.playablePositions.filter { board[$0]?.color == color }.map { ($0, .colorBomb(position)) }
                    }
                case .none:
                    break
                }
            }
            step.clears.append(CrushClear(position: position, piece: piece, reason: reason))
            board[position] = nil
            cleared += 1
        }
        step.score += cleared * Points.perPiece * step.cascade
    }

    /// Yerçekimi ve dolum; düşüşler adıma yazılır.
    private mutating func settle(_ step: inout CrushStep) {
        for column in 0..<board.columns {
            let cells = (0..<board.rows).map { GridPosition(row: $0, column: column) }.filter(board.isPlayable)
            // Alttan yukarı: dolu eşyalar aşağı kayar (delikleri atlayarak)
            let pieces = cells.reversed().compactMap { cell in board[cell].map { (cell, $0) } }
            var target = cells.reversed().makeIterator()
            for (origin, piece) in pieces {
                guard let destination = target.next() else { break }
                if destination != origin {
                    board[origin] = nil
                    board[destination] = piece
                    step.falls.append(CrushFall(piece: piece, fromRow: origin.row, to: destination, isNew: false))
                }
            }
            // Kalan boşluklar: üstten yeni eşyalar
            var above = -1
            while let destination = target.next() {
                let piece = CrushPiece(id: makeID(), color: randomColor())
                board[destination] = piece
                step.falls.append(CrushFall(piece: piece, fromRow: above, to: destination, isNew: true))
                above -= 1
            }
        }
    }

    // MARK: - Özel eşya birleşimleri

    enum Combo {
        case doubleColorBomb
        case colorBomb(with: CrushPiece)
        case stripedStriped
        case stripedWrapped
        case wrappedWrapped
    }

    static func comboKind(_ a: CrushPiece, _ b: CrushPiece) -> Combo? {
        switch (a.special, b.special) {
        case (.colorBomb, .colorBomb): return .doubleColorBomb
        case (.colorBomb, _): return .colorBomb(with: b)
        case (_, .colorBomb): return .colorBomb(with: a)
        case (let x, let y) where x.isStriped && y.isStriped: return .stripedStriped
        case (let x, let y) where (x.isStriped && y.isWrapped) || (x.isWrapped && y.isStriped): return .stripedWrapped
        case (let x, let y) where x.isWrapped && y.isWrapped: return .wrappedWrapped
        default: return nil
        }
    }

    /// Birleşimin temizleyeceği hücreler. Takas edilen iki eşya da (`consumed`) yok olur.
    private mutating func comboClears(_ combo: Combo, moved: CrushPiece, target: CrushPiece,
                                      swap: CrushSwap) -> ([GridPosition: CrushClearReason], CrushActivation?) {
        let center = swap.to
        var clears: [GridPosition: CrushClearReason] = [swap.from: .match, swap.to: .match]
        func add(_ cells: [GridPosition], _ reason: CrushClearReason) {
            for cell in cells where board.isPlayable(cell) && clears[cell] == nil { clears[cell] = reason }
        }
        switch combo {
        case .doubleColorBomb:
            add(board.playablePositions, .colorBomb(center))
            return (clears, CrushActivation(position: center, kind: .board))
        case .colorBomb(let other):
            guard let color = other.color else { return (clears, nil) }
            let targets = board.playablePositions.filter { board[$0]?.color == color && $0 != swap.from && $0 != swap.to }
            switch other.special {
            case .stripedRow, .stripedColumn:
                // O renkteki her eşya çizgili yumağa dönüşüp patlar
                for cell in targets {
                    let special: CrushSpecial = Bool.random(using: &random) ? .stripedRow : .stripedColumn
                    board[cell] = CrushPiece(id: board[cell]!.id, color: color, special: special)
                }
            case .wrapped, .wrappedPrimed:
                for cell in targets {
                    board[cell] = CrushPiece(id: board[cell]!.id, color: color, special: .wrapped)
                }
            default:
                break
            }
            add(targets, .colorBomb(center))
            return (clears, CrushActivation(position: center, kind: .colorBomb(color)))
        case .stripedStriped:
            add((0..<board.columns).map { GridPosition(row: center.row, column: $0) }, .stripe(center))
            add((0..<board.rows).map { GridPosition(row: $0, column: center.column) }, .stripe(center))
            return (clears, CrushActivation(position: center, kind: .row))
        case .stripedWrapped:
            // 3 satır ve 3 sütun
            for offset in -1...1 {
                add((0..<board.columns).map { GridPosition(row: center.row + offset, column: $0) }, .stripe(center))
                add((0..<board.rows).map { GridPosition(row: $0, column: center.column + offset) }, .stripe(center))
            }
            return (clears, CrushActivation(position: center, kind: .explosion(radius: 1)))
        case .wrappedWrapped:
            add(square(around: center, radius: 2), .explosion(center))
            return (clears, CrushActivation(position: center, kind: .explosion(radius: 2)))
        }
    }

    // MARK: - Yardımcılar

    private func square(around center: GridPosition, radius: Int) -> [GridPosition] {
        (-radius...radius).flatMap { dr in
            (-radius...radius).map { dc in GridPosition(row: center.row + dr, column: center.column + dc) }
        }.filter(board.isPlayable)
    }

    private func mostCommonColor() -> CrushColor? {
        var counts: [CrushColor: Int] = [:]
        for position in board.playablePositions {
            if let color = board[position]?.color { counts[color, default: 0] += 1 }
        }
        return counts.max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }?.key
    }

    private mutating func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private mutating func randomColor() -> CrushColor {
        colors.randomElement(using: &random) ?? .yarn
    }

    /// Tahtayı hazır eşleşmesiz doldurur ve en az bir hamle olana kadar tekrarlar.
    private mutating func fillWithoutMatches() {
        for _ in 0..<100 {
            for position in board.positions where board.isPlayable(position) {
                var options = colors
                let left1 = board[GridPosition(row: position.row, column: position.column - 1)]?.color
                let left2 = board[GridPosition(row: position.row, column: position.column - 2)]?.color
                if let left1, left1 == left2 { options.removeAll { $0 == left1 } }
                let up1 = board[GridPosition(row: position.row - 1, column: position.column)]?.color
                let up2 = board[GridPosition(row: position.row - 2, column: position.column)]?.color
                if let up1, up1 == up2 { options.removeAll { $0 == up1 } }
                let color = options.randomElement(using: &random) ?? colors[0]
                board[position] = CrushPiece(id: makeID(), color: color)
            }
            if !possibleMoves().isEmpty { return }
        }
    }
}
