import Foundation

/// Yumak Taksi çözücüsü: derinlik öncelikli arama, görülen durumlar hatırlanır.
/// İpucu (sıradaki doğru araba) ve bölüm testleri için.
public enum YarnTaxiSolver {
    public struct Solution: Sendable {
        /// Sırayla dokunulacak arabalar.
        public let cars: [Int]
        public let explored: Int
    }

    public static func solve(_ game: YarnTaxiGame, nodeLimit: Int = 50_000) -> Solution? {
        var seen = Set<String>()
        var explored = 0
        var path: [Int] = []

        func key(_ game: YarnTaxiGame) -> String {
            let lot = game.lot.map(\.id).sorted().map(String.init).joined(separator: ",")
            let station = game.station.map { $0.map { "\($0.car.color):\($0.riders)" } ?? "-" }.joined(separator: ",")
            return "\(lot)|\(station)|\(game.head)"
        }

        func search(_ game: YarnTaxiGame) -> Bool {
            if game.status == .won { return true }
            guard game.status == .playing, explored < nodeLimit else { return false }
            guard seen.insert(key(game)).inserted else { return false }
            explored += 1
            // Önce sıranın önündeki renkteki arabalar denenir
            let front = game.frontColor
            let candidates = game.exitableCars.sorted { ($0.color == front ? 0 : 1) < ($1.color == front ? 0 : 1) }
            for car in candidates {
                var next = game
                guard case .moved = next.tap(carID: car.id) else { continue }
                path.append(car.id)
                if search(next) { return true }
                path.removeLast()
            }
            return false
        }

        return search(game) ? Solution(cars: path, explored: explored) : nil
    }

    /// Sıradaki önerilen araba: çözüme götüren ilk hamle; çözüm bulunamazsa sıranın önündeki
    /// renkte, önü açık bir araba.
    public static func hint(_ game: YarnTaxiGame) -> Int? {
        if let first = solve(game, nodeLimit: 20_000)?.cars.first { return first }
        let front = game.frontColor
        return (game.exitableCars.first { $0.color == front } ?? game.exitableCars.first)?.id
    }
}
