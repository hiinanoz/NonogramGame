import Foundation
import NonogramKit
import SwiftUI

/// Ekrandaki tek eşya. `row` ve `column` ekran konumudur (yeni eşyalar tahtanın üstünden,
/// negatif satırdan düşer).
struct CrushTile: Identifiable, Equatable {
    let id: Int
    var piece: CrushPiece
    var row: Double
    var column: Double
    var isClearing = false
    var isSpawning = false
}

/// Patlama efektleri (tahtanın üstündeki katman çizer).
struct CrushEffect: Identifiable {
    enum Kind {
        /// Satır ya da sütun boyunca iplik
        case beam(isRow: Bool, index: Int, color: Color)
        /// Çıngırak kutusu halkası
        case blast(radius: Int, color: Color)
        /// Altın gözden hedeflere ışınlar
        case laser(targets: [GridPosition])
        /// Bütün tahta parlar
        case flash
    }

    let id = UUID()
    let kind: Kind
    let origin: GridPosition
    let start: Date
    var duration: TimeInterval = 0.45
}

/// Patlayan eşyadan saçılan tüy ve patiler.
struct CrushParticle {
    let origin: CGPoint
    let velocity: CGVector
    let color: Color
    let isPaw: Bool
    let size: CGFloat
    let spin: Double
    let start: Date
}

/// Puan balonu ("+120").
struct CrushScorePopup: Identifiable, Equatable {
    let id = UUID()
    let score: Int
    let row: Double
    let column: Double
}

/// Zincir yazısı: 2 → "Miyav!", 3 → "Harika!", 4+ → "Pati Gücü!".
enum CrushCheer: Equatable {
    case meow
    case great
    case pawPower
    case frenzy

    init?(cascade: Int) {
        switch cascade {
        case ..<2: return nil
        case 2: self = .meow
        case 3: self = .great
        default: self = .pawPower
        }
    }

    var text: LocalizedStringResource {
        switch self {
        case .meow: "Meow!"
        case .great: "Purrfect!"
        case .pawPower: "Paw Power!"
        case .frenzy: "Cat Frenzy!"
        }
    }
}

/// Miyav Crush oyununu yönetir: oyuncunun takasını oturuma iletir, motorun döndürdüğü adımları
/// sırayla ekrana oynatır (patla → özel eşya doğar → düş/dol) ve olayları (ses, titreşim) bildirir.
@MainActor
@Observable
final class CrushGameViewModel {
    enum Event {
        case swap
        case invalid
        case cleared(cascade: Int)
        case special
        case created
        case cheer(CrushCheer)
        case won
        case lost
        case finale
        case boosted
    }

    private(set) var session: CrushSession
    private(set) var tiles: [Int: CrushTile] = [:]
    private(set) var effects: [CrushEffect] = []
    private(set) var particles: [CrushParticle] = []
    private(set) var popups: [CrushScorePopup] = []
    private(set) var cheer: CrushCheer?
    private(set) var cheerID = 0
    /// Ekranda gösterilen puan (adımlar oynadıkça artar).
    private(set) var displayedScore = 0
    private(set) var isBusy = false
    private(set) var selected: GridPosition?
    /// Bir süre hamle yapılmazsa yanıp sönen ipucu.
    private(set) var hint: CrushSwap?
    /// Kazanınca kalan hamlelerin ödüle dönüşmesi bitti.
    private(set) var isFinished = false
    private(set) var frenzyMoves = 0

    var onEvent: ((Event) -> Void)?
    /// Bölüm bitince (Kedi Çılgınlığı dahil) bir kez.
    var onEnd: ((CrushSession) -> Void)?

    private var idleTask: Task<Void, Never>?
    let reduceMotion: Bool

    init(level: CrushLevel, seed: UInt64 = UInt64.random(in: 1...UInt64.max), reduceMotion: Bool = false) {
        session = CrushSession(level: level, seed: seed)
        self.reduceMotion = reduceMotion
        syncTiles(animated: false)
    }

    var level: CrushLevel { session.level }
    var board: CrushBoard { session.board }
    var status: CrushSession.Status { session.status }
    var movesLeft: Int { session.movesLeft }

    // MARK: - Oyuncu

    /// Hücreye dokunma: seçili komşuya dokunulursa takas, değilse seçim.
    func tap(_ position: GridPosition) {
        guard canPlay, board.isPlayable(position) else { return }
        if let selected, board.areAdjacent(selected, position) {
            self.selected = nil
            swap(from: selected, to: position)
        } else {
            selected = selected == position ? nil : position
        }
    }

    func clearSelection() { selected = nil }

    var canPlay: Bool { !isBusy && session.status == .playing }

    /// Kaydırarak takas.
    func swap(from: GridPosition, to: GridPosition) {
        guard canPlay, board.isPlayable(from), board.isPlayable(to), board.areAdjacent(from, to) else { return }
        selected = nil
        hint = nil
        isBusy = true
        onEvent?(.swap)
        let swap = CrushSwap(from: from, to: to)
        Task {
            await animateSwap(swap)
            switch session.play(swap) {
            case .failure:
                onEvent?(.invalid)
                await animateSwap(swap)
                isBusy = false
            case .success(let turn):
                await play(turn.move)
                await finishTurn()
            }
            scheduleIdleHint()
        }
    }

    /// Kedi Patisi: dokunulan eşyayı patlatır.
    func smash(_ position: GridPosition) -> Bool {
        guard canPlay, board[position] != nil else { return false }
        isBusy = true
        hint = nil
        guard let turn = session.usePaw(at: position) else {
            isBusy = false
            return false
        }
        onEvent?(.boosted)
        Task {
            await play(turn.move)
            await finishTurn()
            scheduleIdleHint()
        }
        return true
    }

    func shuffle() {
        guard canPlay else { return }
        isBusy = true
        hint = nil
        session.shuffle()
        onEvent?(.boosted)
        Task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { syncTiles(animated: true) }
            await delay(0.5)
            isBusy = false
            scheduleIdleHint()
        }
    }

    /// +5 hamle (güçlendirici, reklam ya da Premium).
    func addMoves(_ count: Int) {
        session.addMoves(count)
        isFinished = false
        scheduleIdleHint()
    }

    func start() {
        scheduleIdleHint()
    }

    func stop() {
        idleTask?.cancel()
    }

    // MARK: - Adımları oynatma

    private func play(_ move: CrushMoveResult) async {
        for step in move.steps {
            await play(step)
        }
        if move.shuffled {
            await delay(0.2)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { syncTiles(animated: true) }
            await delay(0.5)
        }
        // Son durum motorla eşitlenir (dönüşen eşyalar, hazır kutular)
        withAnimation(.snappy(duration: 0.2)) { syncTiles(animated: true) }
    }

    private func play(_ step: CrushStep) async {
        let now = Date()
        // Zincir yazısı
        if let cheer = CrushCheer(cascade: step.cascade) {
            showCheer(cheer)
        }
        // Özel eşya efektleri
        for activation in step.activations {
            effects.append(effect(for: activation, in: step, start: now))
        }
        if !step.activations.isEmpty { onEvent?(.special) }

        // Patlayanlar
        if !step.clears.isEmpty {
            onEvent?(.cleared(cascade: step.cascade))
            withAnimation(.easeIn(duration: 0.18)) {
                for clear in step.clears {
                    tiles[clear.piece.id]?.isClearing = true
                }
            }
            spawnParticles(for: step.clears, start: now)
            showPopup(step)
        }
        withAnimation(.snappy) { displayedScore += step.score }
        await delay(step.clears.isEmpty ? 0.05 : 0.2)
        for clear in step.clears {
            if tiles[clear.piece.id]?.isClearing == true { tiles[clear.piece.id] = nil }
        }

        // Doğan özel eşyalar
        if !step.creations.isEmpty {
            onEvent?(.created)
            for creation in step.creations {
                tiles[creation.piece.id] = CrushTile(
                    id: creation.piece.id, piece: creation.piece,
                    row: Double(creation.position.row), column: Double(creation.position.column), isSpawning: true
                )
            }
            await nextFrame()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                for creation in step.creations { tiles[creation.piece.id]?.isSpawning = false }
            }
            await delay(0.12)
        }

        // Düşüş ve dolum: yeni eşyalar tahtanın üstünden başlar
        guard !step.falls.isEmpty else { return }
        for fall in step.falls where fall.isNew {
            tiles[fall.piece.id] = CrushTile(id: fall.piece.id, piece: fall.piece, row: Double(fall.fromRow), column: Double(fall.to.column))
        }
        await nextFrame()
        let distance = step.falls.map { $0.to.row - $0.fromRow }.max() ?? 1
        withAnimation(.spring(response: 0.22 + 0.035 * Double(distance), dampingFraction: 0.62)) {
            for fall in step.falls {
                tiles[fall.piece.id]?.row = Double(fall.to.row)
                tiles[fall.piece.id]?.column = Double(fall.to.column)
            }
        }
        await delay(0.2 + 0.03 * Double(distance))
    }

    private func finishTurn() async {
        await delay(0.1)
        switch session.status {
        case .playing:
            isBusy = false
        case .won:
            onEvent?(.won)
            await delay(0.5)
            await playFinale()
        case .lost:
            onEvent?(.lost)
            isBusy = false
            onEnd?(session)
        }
    }

    /// Kedi Çılgınlığı: kalan hamleler çizgili yumağa dönüşüp patlar.
    private func playFinale() async {
        frenzyMoves = session.movesLeft
        if let finale = session.celebrate(), !finale.steps.isEmpty {
            if finale.movesConverted > 0 {
                showCheer(.frenzy)
                onEvent?(.finale)
            }
            for step in finale.steps {
                await play(step)
            }
            withAnimation(.snappy(duration: 0.2)) { syncTiles(animated: true) }
        }
        displayedScore = session.score
        isFinished = true
        isBusy = false
        await delay(0.4)
        onEnd?(session)
    }

    private func animateSwap(_ swap: CrushSwap) async {
        guard let a = tileID(at: swap.from), let b = tileID(at: swap.to) else { return }
        let first = (tiles[a]!.row, tiles[a]!.column)
        let second = (tiles[b]!.row, tiles[b]!.column)
        withAnimation(.easeInOut(duration: 0.16)) {
            tiles[a]?.row = second.0
            tiles[a]?.column = second.1
            tiles[b]?.row = first.0
            tiles[b]?.column = first.1
        }
        await delay(0.17)
    }

    private func tileID(at position: GridPosition) -> Int? {
        tiles.values.first { Int($0.row.rounded()) == position.row && Int($0.column.rounded()) == position.column && !$0.isClearing }?.id
    }

    /// Ekrandaki eşyaları tahtanın gerçek durumuna eşitler.
    private func syncTiles(animated: Bool) {
        var next: [Int: CrushTile] = [:]
        for position in board.playablePositions {
            guard let piece = board[position] else { continue }
            var tile = tiles[piece.id] ?? CrushTile(id: piece.id, piece: piece, row: Double(position.row), column: Double(position.column))
            tile.piece = piece
            tile.row = Double(position.row)
            tile.column = Double(position.column)
            tile.isClearing = false
            tile.isSpawning = false
            next[piece.id] = tile
        }
        tiles = next
    }

    // MARK: - Efektler

    private func effect(for activation: CrushActivation, in step: CrushStep, start: Date) -> CrushEffect {
        let color = step.clears.first { $0.position == activation.position }?.piece.color?.tint ?? Gold.bright
        switch activation.kind {
        case .row:
            return CrushEffect(kind: .beam(isRow: true, index: activation.position.row, color: color), origin: activation.position, start: start)
        case .column:
            return CrushEffect(kind: .beam(isRow: false, index: activation.position.column, color: color), origin: activation.position, start: start)
        case .explosion(let radius):
            return CrushEffect(kind: .blast(radius: radius, color: color), origin: activation.position, start: start, duration: 0.5)
        case .colorBomb:
            let targets = step.clears.compactMap { clear -> GridPosition? in
                if case .colorBomb(let origin) = clear.reason, origin == activation.position { return clear.position }
                return nil
            }
            return CrushEffect(kind: .laser(targets: targets), origin: activation.position, start: start, duration: 0.6)
        case .board:
            return CrushEffect(kind: .flash, origin: activation.position, start: start, duration: 0.7)
        }
    }

    private func spawnParticles(for clears: [CrushClear], start: Date) {
        guard !reduceMotion else { return }
        // Çok eşya patlayınca parçacık sayısı azalır (akıcılık)
        let perPiece = clears.count > 30 ? 2 : (clears.count > 12 ? 3 : 5)
        for clear in clears {
            let color = clear.piece.color?.tint ?? Gold.bright
            for index in 0..<perPiece {
                let angle = Double.random(in: 0..<(2 * .pi))
                let speed = Double.random(in: 0.8...2.2)
                particles.append(CrushParticle(
                    origin: CGPoint(x: Double(clear.position.column) + 0.5, y: Double(clear.position.row) + 0.5),
                    velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 1.2),
                    color: index == 0 ? .white : color,
                    isPaw: index == 0 && clear.piece.isSpecial || index == 1,
                    size: Double.random(in: 0.1...0.2),
                    spin: Double.random(in: -6...6),
                    start: start
                ))
            }
        }
        if particles.count > 500 { particles.removeFirst(particles.count - 500) }
        pruneLater()
    }

    private func showPopup(_ step: CrushStep) {
        guard step.score > 0, !step.clears.isEmpty else { return }
        let rows = step.clears.map { Double($0.position.row) }
        let columns = step.clears.map { Double($0.position.column) }
        let popup = CrushScorePopup(
            score: step.score,
            row: rows.reduce(0, +) / Double(rows.count),
            column: columns.reduce(0, +) / Double(columns.count)
        )
        popups.append(popup)
        Task {
            await delay(0.9)
            popups.removeAll { $0.id == popup.id }
        }
    }

    private func showCheer(_ cheer: CrushCheer) {
        self.cheer = cheer
        cheerID += 1
        let id = cheerID
        onEvent?(.cheer(cheer))
        Task {
            await delay(1.1)
            if cheerID == id { withAnimation(.easeOut(duration: 0.25)) { self.cheer = nil } }
        }
    }

    private var pruneTask: Task<Void, Never>?

    /// Süresi dolan efektler ve parçacıklar silinir.
    private func pruneLater() {
        pruneTask?.cancel()
        pruneTask = Task {
            await delay(1.2)
            guard !Task.isCancelled else { return }
            let now = Date()
            effects.removeAll { now.timeIntervalSince($0.start) > $0.duration }
            particles.removeAll { now.timeIntervalSince($0.start) > 1 }
        }
    }

    // MARK: - İpucu

    private func scheduleIdleHint() {
        idleTask?.cancel()
        hint = nil
        guard session.status == .playing else { return }
        idleTask = Task {
            await delay(6)
            guard !Task.isCancelled, canPlay else { return }
            withAnimation { hint = session.hint() }
        }
        pruneLater()
    }

    /// Yeni eklenen eşyalar önce başlangıç yerinde çizilsin, animasyon ondan sonra başlasın.
    private func nextFrame() async {
        try? await Task.sleep(for: .milliseconds(20))
    }

    private func delay(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(reduceMotion ? min(seconds, 0.15) : seconds))
    }
}
