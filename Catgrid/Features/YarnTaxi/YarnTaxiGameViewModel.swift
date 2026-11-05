import Foundation
import NonogramKit
import SwiftUI

/// Yumak Taksi oyun durumu: dokunuşlar, geri alma, yardımcılar ve kedinin ruh hâli.
@MainActor
@Observable
final class YarnTaxiGameViewModel {
    let level: YarnTaxiLevel
    private let start: YarnTaxiGame
    private(set) var game: YarnTaxiGame
    private var history: [YarnTaxiGame] = []
    /// Kullanılan ipucu ve ek yer sayısı (yıldızı düşürür; geri almak serbest).
    private(set) var boostersUsed: Int
    private(set) var mood: BirdSortCatMood = .idle
    /// İpucunun gösterdiği araba.
    private(set) var hintCar: Int?
    /// Önü kapalı olduğu için sallanan araba.
    private(set) var shakingCar: Int?
    private(set) var shakeID = 0

    var onMove: (() -> Void)?
    var onBoard: ((Int) -> Void)?
    var onDepart: (() -> Void)?
    var onBlocked: (() -> Void)?
    var onWin: (() -> Void)?
    var onStuck: (() -> Void)?

    private var moodTask: Task<Void, Never>?

    init(level: YarnTaxiLevel, resuming saved: YarnTaxiSavedGame? = nil) {
        self.level = level
        start = YarnTaxiCatalog.game(for: level)
        game = saved?.game ?? start
        boostersUsed = saved?.boostersUsed ?? 0
    }

    var isWon: Bool { game.status == .won }
    var isStuck: Bool { game.status == .stuck }
    var canUndo: Bool { !history.isEmpty && !isWon }
    var hasProgress: Bool { game.moves > 0 }
    var savedState: YarnTaxiSavedGame { YarnTaxiSavedGame(level: level.number, game: game, boostersUsed: boostersUsed) }

    /// 3 yıldız: yardımcısız; 2: bir yardımcı; 1: daha fazla.
    var stars: Int { max(1, 3 - boostersUsed) }

    /// İlk bölümde el, sıradaki doğru arabayı gösterir.
    var guideCar: Int? {
        guard level.number == 1, game.status == .playing else { return nil }
        return YarnTaxiSolver.hint(game)
    }

    func tap(_ car: YarnCar) {
        guard game.status == .playing else { return }
        var next = game
        switch next.tap(carID: car.id) {
        case .blocked:
            shakingCar = car.id
            shakeID += 1
            setMood(.sad)
            onBlocked?()
        case .noSpace:
            setMood(.sad)
            onBlocked?()
        case .ignored:
            break
        case .moved(let boarded, let departed):
            history.append(game)
            hintCar = nil
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { game = next }
            onMove?()
            if boarded > 0 { onBoard?(boarded) }
            if !departed.isEmpty {
                onDepart?()
                setMood(.delighted)
            } else if boarded > 0 {
                setMood(.pleased)
            }
            if game.status == .won {
                mood = .celebrating
                onWin?()
            } else if game.status == .stuck {
                setMood(.sad, hold: true)
                onStuck?()
            }
        }
    }

    func undo() {
        guard let previous = history.popLast() else { return }
        hintCar = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { game = previous }
        mood = .idle
    }

    /// Ek durak yeri.
    func addSlot() {
        guard !isWon else { return }
        history.append(game)
        boostersUsed += 1
        withAnimation(.spring(response: 0.4)) { game.addSlot() }
        setMood(.pleased)
    }

    /// İpucu: sıradaki doğru araba parlar.
    @discardableResult
    func showHint() -> Bool {
        guard game.status == .playing, let car = YarnTaxiSolver.hint(game) else { return false }
        boostersUsed += 1
        withAnimation { hintCar = car }
        setMood(.pointing)
        return true
    }

    func restart() {
        history = []
        boostersUsed = 0
        hintCar = nil
        withAnimation { game = start }
        mood = .idle
    }

    private func setMood(_ new: BirdSortCatMood, hold: Bool = false) {
        moodTask?.cancel()
        mood = new
        guard !hold else { return }
        moodTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self, self.game.status == .playing else { return }
            self.mood = .idle
        }
    }
}
