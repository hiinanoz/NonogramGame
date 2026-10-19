import Foundation

/// Kuş sıralama bölümleri: 6 ada, her adada 75 bölüm. Bölüm tahtası numarasından tohumla üretilir
/// ve çözücüyle doğrulanır; aynı bölüm her açılışta aynıdır.
///
/// Zorluk: ilk bölümler iki yanda 5'er dal ve dalda 4 kuşla başlar; ilerledikçe iki yanda 9'ar dal
/// ve dalda 6 kuşa kadar çıkar. İlk adada 10 kuş türü vardır, sonraki her adaya bir tür eklenir.
public struct BirdSortLevel: Hashable, Sendable {
    /// 1'den başlayan bölüm numarası (bütün adalar boyunca).
    public let number: Int
    public let island: Int
    public let capacity: Int
    /// Her yandaki dal sayısı (sol ve sağ eşit).
    public let branchesPerSide: Int
    /// Kaç takım kuş (her takım `capacity` aynı tür kuş).
    public let sets: Int
    /// Bu adada kullanılabilen kuş türleri.
    public let speciesCount: Int

    public var id: String { "bird-\(number)" }
    public var branchCount: Int { branchesPerSide * 2 }
    public var localNumber: Int { (number - 1) % BirdSortCatalog.levelsPerIsland + 1 }
}

public enum BirdSortCatalog {
    public static let islandCount = 6
    public static let levelsPerIsland = 75
    public static var levelCount: Int { islandCount * levelsPerIsland }
    /// İlk adadaki tür sayısı; her adada bir tür eklenir.
    public static let firstIslandSpecies = 10

    public static func level(_ number: Int) -> BirdSortLevel {
        let number = min(max(number, 1), levelCount)
        let island = (number - 1) / levelsPerIsland
        let local = (number - 1) % levelsPerIsland
        let half = local >= 38
        let capacity: Int
        let sides: ClosedRange<Int>
        switch island {
        case 0: capacity = 4; sides = 5...7
        case 1: capacity = half ? 5 : 4; sides = half ? 5...6 : 6...7
        case 2: capacity = 5; sides = 6...8
        case 3: capacity = half ? 6 : 5; sides = half ? 6...7 : 7...8
        case 4: capacity = 6; sides = 7...9
        default: capacity = 6; sides = 8...9
        }
        // Yarım adalarda ilerleme o yarının içinde ölçülür
        let span: Double
        let position: Double
        if island == 1 || island == 3 {
            span = half ? Double(levelsPerIsland - 39) : 37
            position = half ? Double(local - 38) : Double(local)
        } else {
            span = Double(levelsPerIsland - 1)
            position = Double(local)
        }
        let progress = span > 0 ? position / span : 0
        let perSide = min(sides.upperBound, sides.lowerBound + Int(Double(sides.count) * progress))
        let branches = perSide * 2
        // Boş dal sayısı: çoğunlukla 2; her 5. bölümde ve adanın ilk bölümlerinde 3 (nefes)
        var empty = 2
        if local < 3 || (local + 1) % 5 == 0 { empty = 3 }
        var sets = branches - empty
        if island == 0 && local < 10 {
            // İlk bölümler: az takım, öğretici
            sets = min(sets, 3 + local / 2)
        }
        let species = firstIslandSpecies + island
        return BirdSortLevel(number: number, island: island, capacity: capacity, branchesPerSide: perSide,
                             sets: sets, speciesCount: species)
    }

    /// Bölümün tahtası ve çözümün hamle sayısı. Çözülemeyen ya da çok kolay dağılımlar atlanır.
    public static func puzzle(for level: BirdSortLevel, nodeLimit: Int = 20_000) -> (board: BirdSortBoard, par: Int) {
        // İleri adalarda birkaç çözülebilir dağılım arasından çözücünün en çok uğraştığı seçilir
        let wanted = 1 + level.island * 2 + (level.localNumber > 50 ? 2 : 0)
        var best: (board: BirdSortBoard, par: Int, effort: Int)?
        var found = 0
        for attempt in 0..<200 {
            var random = CrushRandom(seed: UInt64(level.number) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(attempt) &* 0xBF58_476D)
            let board = deal(level, random: &random)
            if hasReadyBranch(board) { continue }
            guard let solution = BirdSortSolver.solve(board, nodeLimit: nodeLimit) else { continue }
            let effort = solution.explored - solution.moves.count
            if best == nil || effort > best!.effort {
                best = (board, solution.moves.count, effort)
            }
            found += 1
            if found >= wanted { break }
        }
        if let best { return (best.board, best.par) }
        // Güvenli yedek: kuşlar tek tür dallarda (her zaman çözülür)
        let board = BirdSortBoard(branches: (0..<level.branchCount).map { i in
            i < level.sets ? Array(repeating: i % level.speciesCount, count: level.capacity - 1) : []
        }, capacity: level.capacity)
        return (board, level.sets)
    }

    /// Kuşları karıştırıp dallara dağıtır: takımlar kadar dal (artı bazen bir dal) kuşla doludur,
    /// kalanlar boştur. Bazı dallar tam dolu, bazıları yarım.
    static func deal(_ level: BirdSortLevel, random: inout CrushRandom) -> BirdSortBoard {
        var palette = Array(0..<level.speciesCount)
        palette.shuffle(using: &random)
        var birds: [Int] = []
        for set in 0..<level.sets {
            birds.append(contentsOf: repeatElement(palette[set % palette.count], count: level.capacity))
        }
        birds.shuffle(using: &random)
        let spare = level.branchCount - level.sets
        // Dolu dal sayısı: takım sayısı ya da bir fazlası (kuşlar daha dağınık)
        let filled = min(level.branchCount - 1, level.sets + (spare > 2 && random.next() % 2 == 0 ? 1 : 0))
        var counts = Array(repeating: 0, count: filled)
        var remaining = birds.count
        // Önce her dala en az bir kuş, sonra rastgele dağıt
        for i in counts.indices where remaining > 0 {
            counts[i] = 1
            remaining -= 1
        }
        while remaining > 0 {
            let i = Int(random.next() % UInt64(filled))
            if counts[i] < level.capacity {
                counts[i] += 1
                remaining -= 1
            }
        }
        var branches: [[Int]] = []
        var cursor = 0
        for count in counts {
            branches.append(Array(birds[cursor..<cursor + count]))
            cursor += count
        }
        branches.append(contentsOf: repeatElement([], count: level.branchCount - filled))
        branches.shuffle(using: &random)
        return BirdSortBoard(branches: branches, capacity: level.capacity)
    }

    /// Başlangıçta tamamlanmış dal olmasın.
    static func hasReadyBranch(_ board: BirdSortBoard) -> Bool {
        board.branches.contains { $0.count == board.capacity && Set($0).count == 1 }
    }
}
