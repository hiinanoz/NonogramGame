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
    /// Toplam dal sayısı (iki sütuna sırayla dağılır).
    public let branchCount: Int
    /// Kaç takım kuş (her takım `capacity` aynı tür kuş).
    public let sets: Int
    /// Bu adada kullanılabilen kuş türleri.
    public let speciesCount: Int

    public var id: String { "bird-\(number)" }
    /// Bir sütundaki en fazla dal (sol sütun sağdan bir fazla olabilir).
    public var branchesPerSide: Int { (branchCount + 1) / 2 }
    public var localNumber: Int { (number - 1) % BirdSortCatalog.levelsPerIsland + 1 }
    /// Başlangıçta boş dal: en fazla bir tane.
    public var emptyBranches: Int { 1 }
}

public enum BirdSortCatalog {
    public static let islandCount = 6
    public static let levelsPerIsland = 75
    public static var levelCount: Int { islandCount * levelsPerIsland }
    /// İlk adadaki tür sayısı; her adada bir tür eklenir.
    public static let firstIslandSpecies = 10

    /// Dal sayısı ilerledikçe artar: ilk bölüm 7 dalla başlar, ilk adanın sonunda iki yanda 5'er
    /// (10), son adada iki yanda 9'ar (18) dala çıkar. Dalda 4 kuştan başlar, 6'ya kadar çıkar.
    /// Başta tek dal boştur; kuşlar geri kalan dallara dağılır (biri yarım doludur).
    public static func level(_ number: Int) -> BirdSortLevel {
        let number = min(max(number, 1), levelCount)
        let island = (number - 1) / levelsPerIsland
        let local = (number - 1) % levelsPerIsland
        let progress = Double(local) / Double(levelsPerIsland - 1)
        let capacity: Int
        let branches: ClosedRange<Int>
        switch island {
        case 0: capacity = 4; branches = 7...10
        case 1: capacity = local < 38 ? 4 : 5; branches = 10...12
        case 2: capacity = 5; branches = 12...14
        case 3: capacity = local < 38 ? 5 : 6; branches = 14...15
        case 4: capacity = 6; branches = 15...17
        default: capacity = 6; branches = 17...18
        }
        // Adanın ilk yarısında dal sayısı çabuk artar, sonra sabitlenir; her 5. bölüm bir dal az (nefes)
        let eased = min(1, progress * 1.6)
        var count = branches.lowerBound + Int((Double(branches.count - 1) * eased).rounded())
        if (local + 1) % 5 == 0 { count = max(branches.lowerBound, count - 1) }
        let sets = count - 2
        let species = firstIslandSpecies + island
        return BirdSortLevel(number: number, island: island, capacity: capacity, branchCount: count,
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
            i < level.sets ? Array(repeating: i % level.speciesCount, count: level.capacity) : []
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
        // Tek dal boş; kuşlar kalan dallara dağılır (takımlardan bir dal fazla: biri yarım dolar)
        let filled = level.branchCount - level.emptyBranches
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
