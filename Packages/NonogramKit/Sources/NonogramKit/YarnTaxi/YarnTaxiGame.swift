import Foundation

/// Yumak Taksi (park et ve bindir): otoparkta yöne bakan renkli kedi arabaları, üstte renkli
/// yumak sırası ve arada sınırlı yerli bir durak.
///
/// - Bir arabaya dokununca önü (baktığı yön boyunca otoparkın kenarına kadar) boşsa otoparktan
///   çıkar ve duraktaki ilk boş yere gelir. Önü kapalıysa ya da durakta yer yoksa hiçbir şey olmaz.
/// - Sıranın önündeki yumak, durakta kendi rengindeki ilk gelen ve yeri olan arabaya biner; bu,
///   sıranın önü binemeyene kadar sürer. Dolan araba duraktan ayrılır, yeri boşalır.
/// - Bütün yumaklar binince bölüm kazanılır. Durak dolu ve sıranın önündeki yumak binemiyorsa
///   oyun takılır (kaybedilir).
public enum YarnDirection: Int, Codable, Sendable, CaseIterable {
    case up, down, left, right

    public var isHorizontal: Bool { self == .left || self == .right }

    var step: (row: Int, column: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }
}

public struct YarnCell: Hashable, Codable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct YarnCar: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let color: Int
    /// Arabanın sol üst karesi.
    public let row: Int
    public let column: Int
    /// Kare cinsinden uzunluk (2, 3 ya da 4).
    public let length: Int
    public let direction: YarnDirection

    public init(id: Int, color: Int, row: Int, column: Int, length: Int, direction: YarnDirection) {
        self.id = id
        self.color = color
        self.row = row
        self.column = column
        self.length = length
        self.direction = direction
    }

    /// Koltuk sayısı: küçük araba 4, orta 6, otobüs 10.
    public var seats: Int {
        switch length {
        case ...2: 4
        case 3: 6
        default: 10
        }
    }

    public var cells: [YarnCell] {
        (0..<length).map { i in
            direction.isHorizontal ? YarnCell(row: row, column: column + i) : YarnCell(row: row + i, column: column)
        }
    }

    /// Arabanın baktığı uçtaki kare.
    public var front: YarnCell {
        switch direction {
        case .up: YarnCell(row: row, column: column)
        case .left: YarnCell(row: row, column: column)
        case .down: YarnCell(row: row + length - 1, column: column)
        case .right: YarnCell(row: row, column: column + length - 1)
        }
    }
}

/// Duraktaki araba ve bindiği yumak sayısı.
public struct YarnStationCar: Hashable, Codable, Sendable {
    public let car: YarnCar
    public var riders: Int

    public var isFull: Bool { riders >= car.seats }
}

public struct YarnTaxiGame: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case playing, won, stuck
    }

    public enum TapResult: Equatable, Sendable {
        /// Araba durağa geldi; `boarded` binen yumak sayısı, `departed` dolup ayrılan arabalar.
        case moved(boarded: Int, departed: [Int])
        case blocked
        case noSpace
        case ignored
    }

    public let rows: Int
    public let columns: Int
    public private(set) var lot: [YarnCar]
    /// Durak yerleri (geliş sırasına göre); `nil` boş yer.
    public private(set) var station: [YarnStationCar?]
    public private(set) var queue: [Int]
    public private(set) var head = 0
    public private(set) var status: Status = .playing
    public private(set) var moves = 0

    public init(rows: Int, columns: Int, cars: [YarnCar], queue: [Int], slots: Int) {
        self.rows = rows
        self.columns = columns
        lot = cars
        self.queue = queue
        station = Array(repeating: nil, count: slots)
    }

    public var remainingYarns: Int { queue.count - head }
    public var frontColor: Int? { head < queue.count ? queue[head] : nil }
    public var freeSlots: Int { station.filter { $0 == nil }.count }

    public func car(at cell: YarnCell) -> YarnCar? {
        lot.first { $0.cells.contains(cell) }
    }

    /// Arabanın önü kenara kadar boş mu?
    public func canExit(_ car: YarnCar) -> Bool {
        let occupied = Set(lot.filter { $0.id != car.id }.flatMap(\.cells))
        var cell = car.front
        while true {
            cell = YarnCell(row: cell.row + car.direction.step.row, column: cell.column + car.direction.step.column)
            guard (0..<rows).contains(cell.row), (0..<columns).contains(cell.column) else { return true }
            if occupied.contains(cell) { return false }
        }
    }

    /// Önü boş arabalar.
    public var exitableCars: [YarnCar] { lot.filter(canExit) }

    @discardableResult
    public mutating func tap(carID: Int) -> TapResult {
        guard status == .playing, let index = lot.firstIndex(where: { $0.id == carID }) else { return .ignored }
        let car = lot[index]
        guard canExit(car) else { return .blocked }
        guard let slot = station.firstIndex(where: { $0 == nil }) else { return .noSpace }
        lot.remove(at: index)
        station[slot] = YarnStationCar(car: car, riders: 0)
        // Geliş sırası korunur: boş yerler sona kaydırılır
        compactStation()
        moves += 1
        let result = board()
        updateStatus()
        return .moved(boarded: result.boarded, departed: result.departed)
    }

    mutating func lotRemove(_ id: Int) {
        lot.removeAll { $0.id == id }
    }

    /// Ek durak yeri (güçlendirici).
    public mutating func addSlot() {
        station.append(nil)
        if status == .stuck { status = .playing }
        updateStatus()
    }

    private mutating func compactStation() {
        let cars = station.compactMap { $0 }
        station = cars.map { Optional($0) } + Array(repeating: nil, count: station.count - cars.count)
    }

    private mutating func board() -> (boarded: Int, departed: [Int]) {
        var boarded = 0
        var departed: [Int] = []
        while let color = frontColor,
              let slot = station.firstIndex(where: { $0 != nil && $0!.car.color == color && !$0!.isFull }) {
            station[slot]!.riders += 1
            head += 1
            boarded += 1
            if station[slot]!.isFull {
                departed.append(station[slot]!.car.id)
                station[slot] = nil
                compactStation()
            }
        }
        return (boarded, departed)
    }

    private mutating func updateStatus() {
        if head >= queue.count, lot.isEmpty {
            status = .won
            return
        }
        // Durak dolu ve sıranın önü binemiyor: takıldı
        if freeSlots == 0 {
            status = .stuck
        } else if lot.isEmpty, head < queue.count {
            status = .stuck
        } else {
            status = .playing
        }
    }
}
