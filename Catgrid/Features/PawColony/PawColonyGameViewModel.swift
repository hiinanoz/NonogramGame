import Foundation
import NonogramKit
import SwiftUI

/// Pati Kolonisi oyun durumu: zamanı ilerletir, sürükleyerek yol çizme ve kaydırarak kesme.
@MainActor
@Observable
final class PawColonyGameViewModel {
    let level: PawColonyLevel
    private let start: PawColonyGame
    private(set) var game: PawColonyGame
    /// Parmakla sürüklenen yol: başlangıç evi ve parmağın yeri (0-1 koordinatlarda).
    private(set) var dragFrom: Int?
    private(set) var dragPoint: PawPoint?
    /// Kesme izi (parmağın son noktaları).
    private(set) var cutTrail: [PawPoint] = []
    var isPaused = false
    /// Evlerin üstünde uçan "+3" / "−2" yazıları.
    private(set) var floats: [PawFloat] = []
    /// Ev kazanılınca / kaybedilince halka efekti.
    private(set) var bursts: [PawBurst] = []
    /// Yolun kesildiği noktalarda makas izi.
    private(set) var cuts: [PawCutMark] = []
    private var pendingTransfers: [Int: Double] = [:]
    private var floatClock = 0.0
    /// Oyun hızı: 1× ya da 2×.
    var speedMultiplier = 1.0
    /// Öğretici için: oyuncu kendi evine destek gönderdi mi, yol kesti mi.
    private(set) var didReinforce = false
    private(set) var didCut = false

    var onLink: (() -> Void)?
    var onCut: (() -> Void)?
    var onCapture: ((PawOwner) -> Void)?
    var onEnd: ((PawColonyGame.Status) -> Void)?

    init(level: PawColonyLevel, resuming saved: PawColonySavedGame? = nil) {
        self.level = level
        start = PawColonyCatalog.game(for: level)
        game = saved?.game ?? start
    }

    var isOver: Bool { game.status != .playing }
    var hasProgress: Bool { game.time > 1 }
    var savedState: PawColonySavedGame { PawColonySavedGame(level: level.number, game: game) }

    /// 3 yıldız: hedef sürede; 2: bir buçuk katında; 1: daha uzun.
    var stars: Int {
        game.time <= level.parTime ? 3 : (game.time <= level.parTime * 1.6 ? 2 : 1)
    }

    /// Ekran karesiyle zamanı ilerletir (en fazla 0,1 sn; uygulama arka plandayken atlamaz).
    func tick(_ dt: Double) {
        guard !isPaused, game.status == .playing else { return }
        let owners = game.nodes.map(\.owner)
        let step = min(max(dt, 0), 0.1)
        game.advance(step * speedMultiplier)
        let now = Date()
        for (old, node) in zip(owners, game.nodes) where old != node.owner {
            onCapture?(node.owner)
            bursts.append(PawBurst(node: node.id, owner: node.owner, start: now))
            pendingTransfers[node.id] = nil
        }
        // Yollardan gelen kediler birikir; belli aralıklarla "+3" / "−2" olarak uçar
        for (id, amount) in game.takeTransfers() { pendingTransfers[id, default: 0] += amount }
        floatClock += step
        if floatClock >= 0.8 {
            for (id, amount) in pendingTransfers where abs(amount) >= 1 {
                floats.append(PawFloat(node: id, amount: Int(amount.rounded()), start: now))
                pendingTransfers[id] = 0
            }
            floatClock = 0
        }
        floats.removeAll { now.timeIntervalSince($0.start) > 1.2 }
        bursts.removeAll { now.timeIntervalSince($0.start) > 0.9 }
        cuts.removeAll { now.timeIntervalSince($0.start) > 0.7 }
        if game.status != .playing { onEnd?(game.status) }
    }

    /// Farelerin yol açmak üzere olduğu evler (titrer).
    var alertNodes: Set<Int> { Set(game.micePlans.map(\.from)) }

    /// Sürüklenen yolun kedi maliyeti (parmağın altında ev varsa).
    var dragCost: Int? {
        guard let from = dragFrom, let hover = dragOutlook else { return nil }
        return Int(game.linkCost(from: from, to: hover.target).rounded(.up))
    }

    /// Sürüklerken parmağın altındaki evi almanın tahmini.
    var dragOutlook: (target: Int, outlook: PawColonyGame.LinkOutlook)? {
        guard let from = dragFrom, let point = dragPoint, let target = node(at: point), target.id != from else { return nil }
        return (target.id, game.outlook(from: from, to: target.id))
    }

    /// Parmağın altındaki ev (yarıçap içinde).
    func node(at point: PawPoint, radius: Double = 0.09) -> PawNode? {
        game.nodes.min { $0.position.distance(to: point) < $1.position.distance(to: point) }
            .flatMap { $0.position.distance(to: point) <= radius ? $0 : nil }
    }

    func dragBegan(at point: PawPoint) {
        guard game.status == .playing else { return }
        if let node = node(at: point), node.owner == .cats {
            dragFrom = node.id
            dragPoint = point
        } else {
            dragFrom = nil
            cutTrail = [point]
        }
    }

    func dragMoved(to point: PawPoint) {
        if dragFrom != nil {
            dragPoint = point
            return
        }
        cutTrail.append(point)
        if cutTrail.count > 12 { cutTrail.removeFirst() }
        // Parmak kendi yolumuzun üstünden geçince yol o noktadan kesilir
        if let hit = game.linkNear(point) {
            game.cut(linkID: hit.id, at: hit.fraction)
            cuts.append(PawCutMark(point: point, start: Date()))
            didCut = true
            onCut?()
        }
    }

    func dragEnded(at point: PawPoint) {
        defer {
            dragFrom = nil
            dragPoint = nil
            cutTrail = []
        }
        guard let from = dragFrom, let target = node(at: point), target.id != from else { return }
        if game.link(from: from, to: target.id) {
            if target.owner == .cats { didReinforce = true }
            onLink?()
        }
    }

    func restart() {
        game = start
        isPaused = false
        floats = []
        bursts = []
        cuts = []
        pendingTransfers = [:]
    }
}

struct PawFloat: Identifiable {
    let id = UUID()
    let node: Int
    let amount: Int
    let start: Date
}

struct PawCutMark: Identifiable {
    let id = UUID()
    let point: PawPoint
    let start: Date
}

struct PawBurst: Identifiable {
    let id = UUID()
    let node: Int
    let owner: PawOwner
    let start: Date
}
