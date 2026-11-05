import Foundation

/// Pati Kolonisi (Tentacle Wars benzeri): haritada kedi evleri. Her evde kedi sayısı yazar.
///
/// - Kendi evinden başka bir eve yün yolu uzatılır. Yol uzarken uzunluğu kadar kedi harcanır
///   (yolda yürürler); yol karşı eve ulaşınca kediler akmaya başlar.
/// - Kendi evine giden akış onu güçlendirir; sahipsiz ya da fare evine giden akış sayısını
///   azaltır, sıfırın altına inen ev akışı gönderenin olur.
/// - İki karşıt yol aynı iki ev arasında karşılaşırsa ortada çarpışır: akışlar birbirini yer.
/// - Yolu kesmek: kesilen noktadan sonrası karşı eve (saldırı ya da destek), öncesi geri döner.
/// - Evler zamanla kendiliğinden büyür (sahipsizler büyümez). Büyük ev aynı anda daha çok yol
///   açabilir: 15 kediden az 1, 40'tan az 2, fazlası 3 yol.
/// - Bütün fare evleri kazanılınca (rakipsiz bölümde bütün evler bizim olunca) bölüm biter;
///   hiç evimiz kalmazsa kaybedilir.
public enum PawOwner: Int, Codable, Sendable {
    case neutral, cats, mice
}

public struct PawPoint: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func distance(to other: PawPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}

public struct PawNode: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    /// 0-1 arası konum (ekrana göre ölçeklenir).
    public let position: PawPoint
    public var owner: PawOwner
    public var count: Double
    /// Ev bu sayıdan fazla büyümez.
    public let capacity: Double

    public init(id: Int, position: PawPoint, owner: PawOwner, count: Double, capacity: Double = 100) {
        self.id = id
        self.position = position
        self.owner = owner
        self.count = count
        self.capacity = capacity
    }

    /// Aynı anda açılabilecek yol sayısı.
    public var maxLinks: Int { count >= 40 ? 3 : (count >= 15 ? 2 : 1) }
}

public struct PawLink: Hashable, Codable, Sendable, Identifiable {
    public enum State: String, Codable, Sendable {
        /// Uzuyor (kedi harcanarak).
        case extending
        /// Karşı eve ulaştı, akış var.
        case connected
        /// Geri çekiliyor (kediler eve döner).
        case retracting
    }

    public let id: Int
    public let from: Int
    public let to: Int
    public var owner: PawOwner
    public var state: State
    /// Ulaşılan uzunluk (0...length).
    public var reach: Double
    public let length: Double
}

public struct PawColonyGame: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case playing, won, lost
    }

    // Kurallar (birim: saniye)
    /// Uzunluk birimi başına yol maliyeti (1 uzunluk = haritanın genişliği).
    public static let costPerLength = 12.0
    public static let extendSpeed = 0.35
    public static let retractSpeed = 0.7
    /// Bağlı yol başına saniyede akan kedi.
    public static let flowRate = 2.5
    /// Saniyede büyüme (evin büyüklüğüne göre artar).
    public static func growth(_ count: Double) -> Double { 0.35 + min(count, 60) / 100 }

    public private(set) var nodes: [PawNode]
    public private(set) var links: [PawLink] = []
    public private(set) var status: Status = .playing
    public private(set) var time: Double = 0
    /// Farelerin hızı ve saldırganlığı (0 rakipsiz).
    public let miceLevel: Double
    private var nextLinkID = 1
    private var random: CrushRandom
    private var aiClock: Double = 0

    public init(nodes: [PawNode], miceLevel: Double, seed: UInt64 = 1) {
        self.nodes = nodes
        self.miceLevel = miceLevel
        random = CrushRandom(seed: seed)
    }

    public func node(_ id: Int) -> PawNode? { nodes.first { $0.id == id } }

    public func outgoing(from id: Int) -> [PawLink] {
        links.filter { $0.from == id && $0.state != .retracting }
    }

    /// Kedi gönderilebilir mi: evimiz, boş yol hakkı var, aynı hedefe yol yok.
    public func canLink(from: Int, to: Int, owner: PawOwner = .cats) -> Bool {
        guard status == .playing, from != to, let source = node(from), node(to) != nil, source.owner == owner else { return false }
        let out = outgoing(from: from)
        return out.count < source.maxLinks && !out.contains { $0.to == to }
    }

    @discardableResult
    public mutating func link(from: Int, to: Int, owner: PawOwner = .cats) -> Bool {
        guard canLink(from: from, to: to, owner: owner), let a = node(from), let b = node(to) else { return false }
        // Aynı yolda geri çekilen eski yol varsa kaldırılır (yeniden uzatılır)
        links.removeAll { $0.from == from && $0.to == to }
        links.append(PawLink(id: nextLinkID, from: from, to: to, owner: owner, state: .extending, reach: 0,
                             length: a.position.distance(to: b.position)))
        nextLinkID += 1
        return true
    }

    /// Yolu `fraction` (0 kaynak, 1 hedef) noktasından keser: sonrası hedefe, öncesi kaynağa gider.
    public mutating func cut(linkID: Int, at fraction: Double = 0.5, owner: PawOwner = .cats) {
        guard let index = links.firstIndex(where: { $0.id == linkID && $0.owner == owner }), links[index].state != .retracting else { return }
        let link = links[index]
        let units = link.reach * Self.costPerLength
        if link.state == .connected {
            let forward = units * (1 - min(max(fraction, 0), 1))
            deliver(forward, from: link.owner, to: link.to)
            links[index].reach = link.reach * fraction
        }
        links[index].state = .retracting
    }

    /// Bir noktaya en yakın kendi yolumuz ve kesilen nokta (ekranda parmakla kesmek için).
    public func linkNear(_ point: PawPoint, owner: PawOwner = .cats, tolerance: Double = 0.04) -> (id: Int, fraction: Double)? {
        var best: (id: Int, fraction: Double, distance: Double)?
        for link in links where link.owner == owner && link.state != .retracting {
            guard let a = node(link.from)?.position, let b = node(link.to)?.position else { continue }
            let dx = b.x - a.x, dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { continue }
            var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared
            t = min(max(t, 0), link.reach / link.length)
            let closest = PawPoint(x: a.x + dx * t, y: a.y + dy * t)
            let distance = closest.distance(to: point)
            if distance < tolerance, best == nil || distance < best!.distance {
                best = (link.id, t, distance)
            }
        }
        return best.map { ($0.id, $0.fraction) }
    }

    // MARK: - Zaman

    /// `seconds` kadar ilerletir (0,1 sn'lik adımlarla; sonuç kare hızından bağımsız).
    public mutating func advance(_ seconds: Double) {
        var left = seconds
        while left > 1e-9, status == .playing {
            let dt = min(0.1, left)
            step(dt)
            left -= dt
        }
    }

    private mutating func step(_ dt: Double) {
        time += dt
        // Büyüme
        for i in nodes.indices where nodes[i].owner != .neutral {
            // Fareler kolay bölümlerde daha yavaş büyür
            let factor = nodes[i].owner == .mice ? 0.5 + 0.55 * miceLevel : 1
            nodes[i].count = min(nodes[i].capacity, nodes[i].count + Self.growth(nodes[i].count) * factor * dt)
        }
        // Yollar
        var removed: Set<Int> = []
        for i in links.indices {
            let link = links[i]
            guard let sourceIndex = nodes.firstIndex(where: { $0.id == link.from }) else { removed.insert(link.id); continue }
            switch link.state {
            case .extending:
                let opposing = links.contains { $0.from == link.to && $0.to == link.from && $0.owner != link.owner && $0.state != .retracting }
                let limit = opposing ? link.length / 2 : link.length
                let wanted = min(Self.extendSpeed * dt, limit - link.reach)
                let cost = wanted * Self.costPerLength
                if nodes[sourceIndex].count >= cost {
                    nodes[sourceIndex].count -= cost
                    links[i].reach += wanted
                    if links[i].reach >= limit - 1e-9 { links[i].state = .connected }
                } else {
                    // Kedi yetmedi: yol geri çekilir
                    links[i].state = .retracting
                }
            case .connected:
                let opposing = links.firstIndex { $0.from == link.to && $0.to == link.from && $0.owner != link.owner && $0.state == .connected }
                let amount = min(Self.flowRate * dt, nodes[sourceIndex].count)
                nodes[sourceIndex].count -= amount
                if opposing == nil {
                    deliver(amount, from: link.owner, to: link.to)
                }
                // Karşıt yolla çarpışmada iki akış ortada birbirini yer (kimse kazanmaz)
            case .retracting:
                let back = min(Self.retractSpeed * dt, link.reach)
                links[i].reach -= back
                if nodes[sourceIndex].owner == link.owner {
                    nodes[sourceIndex].count = min(nodes[sourceIndex].capacity, nodes[sourceIndex].count + back * Self.costPerLength)
                }
                if links[i].reach <= 1e-9 { removed.insert(link.id) }
            }
        }
        links.removeAll { removed.contains($0.id) }
        // Yarıya kadar uzamış ama karşıtı geri çekilmiş yollar tekrar uzasın
        for i in links.indices where links[i].state == .connected && links[i].reach < links[i].length - 1e-9 {
            let opposing = links.contains { $0.from == links[i].to && $0.to == links[i].from && $0.owner != links[i].owner && $0.state != .retracting }
            if !opposing { links[i].state = .extending }
        }
        if miceLevel > 0 { thinkMice(dt) }
        updateStatus()
    }

    private mutating func deliver(_ amount: Double, from owner: PawOwner, to target: Int) {
        guard amount > 0, let index = nodes.firstIndex(where: { $0.id == target }) else { return }
        if nodes[index].owner == owner {
            nodes[index].count = min(nodes[index].capacity, nodes[index].count + amount)
            return
        }
        nodes[index].count -= amount
        if nodes[index].count < 0 {
            // Ev el değiştirir; eski sahibinin bu evden çıkan yolları geri çekilir
            nodes[index].owner = owner
            nodes[index].count = -nodes[index].count
            for i in links.indices where links[i].from == target && links[i].owner != owner {
                links[i].state = .retracting
                links[i].reach = 0
            }
        }
    }

    private mutating func updateStatus() {
        let cats = nodes.contains { $0.owner == .cats }
        let mice = nodes.contains { $0.owner == .mice }
        if !cats {
            status = .lost
        } else if miceLevel > 0 ? !mice : nodes.allSatisfy({ $0.owner == .cats }) {
            status = .won
        }
    }

    // MARK: - Fareler

    /// Fareler belli aralıklarla düşünür: güçlü evlerinden, yenebilecekleri en yakın zayıf eve yol
    /// açar; zor durumdaki evlerine destek gönderir; kaybedecekleri saldırıları keser.
    private mutating func thinkMice(_ dt: Double) {
        aiClock += dt
        // Kolay bölümlerde fareler ilk saniyelerde uykulu
        guard time >= 18 * (1 - miceLevel) else { return }
        let interval = max(0.8, 3.2 - miceLevel * 2.2)
        guard aiClock >= interval else { return }
        aiClock = 0
        let mice = nodes.filter { $0.owner == .mice }
        for source in mice.shuffled(using: &random) {
            let out = outgoing(from: source.id)
            // Kaynak çok zayıfladıysa en uzak saldırısını keser
            if source.count < 6, let weakest = out.first(where: { link in node(link.to)?.owner != .mice }) {
                cut(linkID: weakest.id, at: 0.5, owner: .mice)
                continue
            }
            guard out.count < source.maxLinks, source.count > 12 - miceLevel * 4 else { continue }
            let targets = nodes.filter { target in target.id != source.id && !out.contains { $0.to == target.id } }
            let scored = targets.map { target -> (PawNode, Double) in
                let distance = source.position.distance(to: target.position)
                let cost = distance * Self.costPerLength
                var score = -distance * 30
                switch target.owner {
                case .mice:
                    // Destek: zayıf fare evine
                    score += target.count < 10 ? 18 - target.count : -100
                case .neutral:
                    score += 20 - target.count
                case .cats:
                    // Güçlüyse (ya da dolmuşsa) saldırır; akış zamanla ev büyümesini geçer
                    score += (source.count - cost - target.count * 0.6) * (0.4 + miceLevel)
                    if source.count > 55 { score += 25 }
                }
                if source.count - cost < 4 { score -= 100 }
                return (target, score)
            }
            if let best = scored.max(by: { $0.1 < $1.1 }), best.1 > -20, Double.random(in: 0..<1, using: &random) < 0.4 + miceLevel * 0.6 {
                link(from: source.id, to: best.0.id, owner: .mice)
            }
        }
    }
}
