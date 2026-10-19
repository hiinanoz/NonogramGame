import Foundation

/// Kuş sıralama tahtası: iki sütun dal, her dalda en fazla `capacity` kuş. Her dal dizisinin başı
/// gövde tarafı, sonu dalın ucudur; kuşlar uca konar ve uçtan kalkar.
///
/// Kurallar: bir daldan ötekine, kaynağın ucundaki aynı türden kuş grubunun tamamı (sığdığı kadarı)
/// uçar. Hedef ya boştur ya da ucunda aynı tür kuş vardır. Bir dal `capacity` kadar aynı tür kuşla
/// dolunca o kuşlar uçup gider (dal boşalır). Bütün dallar boşalınca bölüm biter.
public struct BirdSortBoard: Hashable, Codable, Sendable {
    public private(set) var branches: [[Int]]
    public let capacity: Int

    public init(branches: [[Int]], capacity: Int) {
        self.branches = branches
        self.capacity = capacity
    }

    public var isCleared: Bool { branches.allSatisfy(\.isEmpty) }
    public var birdCount: Int { branches.reduce(0) { $0 + $1.count } }

    /// Dalın ucundaki aynı tür kuş sayısı.
    public func topRun(_ index: Int) -> Int {
        let branch = branches[index]
        guard let top = branch.last else { return 0 }
        var count = 0
        for bird in branch.reversed() {
            guard bird == top else { break }
            count += 1
        }
        return count
    }

    /// Bu hamlede uçacak kuş sayısı; hamle geçersizse 0.
    public func movableCount(from source: Int, to target: Int) -> Int {
        guard source != target, branches.indices.contains(source), branches.indices.contains(target),
              let bird = branches[source].last else { return 0 }
        let destination = branches[target]
        if let top = destination.last, top != bird { return 0 }
        let free = capacity - destination.count
        return min(free, topRun(source))
    }

    /// Bir hamlenin sonucu: kaç kuş, hangi tür, hedef dal doldu mu.
    public struct Move: Hashable, Codable, Sendable {
        public let source: Int
        public let target: Int
        public let count: Int
        public let species: Int
        /// Hedef dal aynı türle dolup boşaldı mı (kuşlar uçup gitti).
        public let clearedTarget: Bool
    }

    @discardableResult
    public mutating func move(from source: Int, to target: Int) -> Move? {
        let count = movableCount(from: source, to: target)
        guard count > 0, let species = branches[source].last else { return nil }
        branches[source].removeLast(count)
        branches[target].append(contentsOf: repeatElement(species, count: count))
        let full = branches[target].count == capacity && branches[target].allSatisfy { $0 == species }
        if full { branches[target].removeAll() }
        return Move(source: source, target: target, count: count, species: species, clearedTarget: full)
    }

    /// Geri almak için: hamleden önceki tahta saklanır (bkz. `BirdSortSession`).
    public mutating func addBranch() {
        branches.append([])
    }

    /// Geçerli bütün hamleler (kaynak, hedef).
    public func legalMoves() -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for source in branches.indices where !branches[source].isEmpty {
            for target in branches.indices where movableCount(from: source, to: target) > 0 {
                result.append((source, target))
            }
        }
        return result
    }

    /// Dal sırası önemsiz: aynı dalların başka sırada olduğu tahtalar aynı durumdur.
    var canonicalKey: [UInt8] {
        let encoded = branches.map { branch in branch.map { UInt8(truncatingIfNeeded: $0 + 1) } }
            .sorted { $0.lexicographicallyPrecedes($1) }
        var key: [UInt8] = []
        key.reserveCapacity(birdCount + branches.count)
        for branch in encoded {
            key.append(contentsOf: branch)
            key.append(0)
        }
        return key
    }
}
