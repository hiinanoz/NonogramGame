import Foundation

/// Derinlik öncelikli çözücü: iyi hamleleri önce dener (dal tamamlayan, aynı türün üstüne konan),
/// görülen durumları atlar ve düğüm sınırını aşınca vazgeçer. Üretilen her bölümün çözülebildiğini
/// doğrular ve bölümün yaklaşık hamle sayısını (par) verir; oyunda ipucu için de kullanılabilir.
public enum BirdSortSolver {
    public struct Solution: Sendable {
        public let moves: [BirdSortBoard.Move]
        public let explored: Int
    }

    public static func solve(_ board: BirdSortBoard, nodeLimit: Int = 200_000) -> Solution? {
        var seen = Set<[UInt8]>()
        var path: [BirdSortBoard.Move] = []
        var explored = 0
        var found = false

        func search(_ board: BirdSortBoard) {
            if board.isCleared {
                found = true
                return
            }
            explored += 1
            guard explored <= nodeLimit else { return }
            guard seen.insert(board.canonicalKey).inserted else { return }
            for (source, target) in orderedMoves(board) {
                var next = board
                guard let move = next.move(from: source, to: target) else { continue }
                path.append(move)
                search(next)
                if found { return }
                path.removeLast()
                if explored > nodeLimit { return }
            }
        }

        search(board)
        return found ? Solution(moves: path, explored: explored) : nil
    }

    /// Hamleler iyiden kötüye: dal tamamlayan, aynı türün üstüne konan, karışık daldan boş dala.
    /// Tek tür kuşun durduğu daldan boş dala uçmak bir şey değiştirmez, denenmez; boş hedeflerden
    /// yalnızca biri denenir (hepsi aynı durumu verir).
    static func orderedMoves(_ board: BirdSortBoard) -> [(Int, Int)] {
        var scored: [(score: Int, source: Int, target: Int)] = []
        let branches = board.branches
        for source in branches.indices where !branches[source].isEmpty {
            let run = board.topRun(source)
            let uniform = run == branches[source].count
            var triedEmpty = false
            for target in branches.indices {
                let count = board.movableCount(from: source, to: target)
                guard count > 0 else { continue }
                let destination = branches[target]
                if destination.isEmpty {
                    if uniform || triedEmpty { continue }
                    triedEmpty = true
                    scored.append((10 + count, source, target))
                    continue
                }
                var score = 100 + count * 10
                if destination.count + count == board.capacity, destination.allSatisfy({ $0 == destination[0] }) {
                    score += 1000
                }
                // Grubun tamamı taşınamıyorsa kaynakta yarım kalır: daha az iyi
                if count < run { score -= 60 }
                // Kaynak boşalıyor ya da altındaki tür açılıyor
                if count == branches[source].count { score += 40 }
                // Hedef dal tek türse onu büyütmek iyi
                if destination.allSatisfy({ $0 == destination[0] }) { score += 30 }
                scored.append((score, source, target))
            }
        }
        scored.sort { $0.score > $1.score }
        return scored.map { ($0.source, $0.target) }
    }
}
