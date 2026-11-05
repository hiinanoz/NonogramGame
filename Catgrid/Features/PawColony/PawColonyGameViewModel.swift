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
        game.advance(min(max(dt, 0), 0.1))
        for (old, node) in zip(owners, game.nodes) where old != node.owner {
            onCapture?(node.owner)
        }
        if game.status != .playing { onEnd?(game.status) }
    }

    /// Parmağın altındaki ev (yarıçap içinde).
    func node(at point: PawPoint, radius: Double = 0.07) -> PawNode? {
        game.nodes.min { $0.position.distance(point) < $1.position.distance(point) }
            .flatMap { $0.position.distance(point) <= radius ? $0 : nil }
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
        if game.link(from: from, to: target.id) { onLink?() }
    }

    func restart() {
        game = start
        isPaused = false
    }
}

extension PawPoint {
    func distance(_ other: PawPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
