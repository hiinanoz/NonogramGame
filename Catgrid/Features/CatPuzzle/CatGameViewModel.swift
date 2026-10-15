import Foundation
import NonogramKit

/// Kedi Bulmaca ekranındaki olaylar (ses ve titreşim).
enum CatEvent: Equatable {
    case crossed
    case cleared
    case found(combo: Int)
    case wrong
    case solved
    case failed
}

/// Karenin yanında kısa süre uçuşan küçük yazılar: "+576", "Tamam!" (biten satır).
struct CatEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        case points(Int)
        case clear
    }

    let id = UUID()
    let kind: Kind
    let position: GridPosition
}

/// Tahtanın ortasında büyük çıkan motivasyon yazısı.
struct CatBanner: Identifiable, Equatable {
    enum Kind: Equatable {
        case found
        case combo(Int)
        case perfectlyMarked
        /// Son kedi bulununca.
        case allFound(Int)
    }

    let id = UUID()
    let kind: Kind
}

/// Bir karenin son değişimi: X'ler çizilerek, kediler zıplayarak, hatalar sallanarak gelir.
struct CatMarkAnimation: Equatable {
    enum Kind: Equatable {
        case cross
        case cat
        case wrong
    }

    let kind: Kind
    let start: Date
    static let duration: TimeInterval = 0.45
}

/// Kedi Bulmaca ekranının durumu: dokunma/sürükleme, puan ve seri, ipucu önizlemesi, zamanlayıcı.
@MainActor
@Observable
final class CatGameViewModel {
    private(set) var game: CatGame
    private(set) var score = 0
    /// Art arda hızlı bulunan kedi sayısı (seri).
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var perfectlyMarkedCount = 0
    private(set) var usedHints = false
    private(set) var effects: [CatEffect] = []
    /// Ortadaki büyük yazı (bir süre sonra kaybolur).
    private(set) var banner: CatBanner?
    /// Son değişen karelerin animasyonları.
    private(set) var animations: [GridPosition: CatMarkAnimation] = [:]
    /// Son yanlış kedinin bozduğu kural (kural şeridi ve tahta bunu vurgular).
    private(set) var lastConflict: CatConflict?
    /// "?" ipucu: kısa bir an gösterilir, sonra tahtaya kendiliğinden işlenir.
    private(set) var pendingHint: CatHint?
    /// Sihirli silgi: açıkken dokunulan/sürüklenen X'ler silinir; boş kareye dokununca kapanır.
    private(set) var isErasing = false
    /// Son yanlış kedi denemesi (kısa sallanma için).
    private(set) var lastWrong: GridPosition?
    /// Parmağın altındaki kare.
    private(set) var activeCell: GridPosition?
    private(set) var isPaused = false

    var onEvent: ((CatEvent) -> Void)?
    var onSolved: ((CatPuzzleModel.Completion) -> Void)?

    /// Seri için iki kedi arasındaki en uzun süre.
    static let comboWindow: TimeInterval = 25

    private var lastFindAt: Date?
    private var touchStart: GridPosition?
    private var paintCross: Bool?
    private var timerTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private let now: () -> Date

    init(level: CatLevel, saved: CatSnapshot? = nil, now: @escaping () -> Date = { Date() }) {
        game = saved.map { CatGame(level: level, restoring: $0) } ?? CatGame(level: level)
        self.now = now
        completedGroups = Self.completeGroups(in: game)
    }

    /// Zaten bitmiş gruplar (kayıttan dönülünce "Tamam!" yeniden çıkmasın).
    private static func completeGroups(in game: CatGame) -> Set<CatGroup> {
        let n = game.size
        let all = (0..<n).flatMap { i in
            [CatGroup(axis: .row, index: i), CatGroup(axis: .column, index: i), CatGroup(axis: .region, index: i)]
        }
        return Set(all.filter { game.isComplete($0) })
    }

    var level: CatLevel { game.level }
    var isFinished: Bool { game.status != .playing }

    var snapshotToSave: CatSnapshot? {
        game.status == .playing ? game.snapshot : nil
    }

    // MARK: - Dokunma

    /// Dokunma bırakılınca işlenir (kedi kutlaması parmak kalkınca gelir); sürükleme
    /// başka bir kareye geçince X boyamaya döner.
    func touchBegan(at position: GridPosition) {
        guard !isFinished, game.contains(position) else { return }
        // Gösterilmekte olan ipucu beklemeden işlenir
        applyHint()
        activeCell = position
        if isErasing {
            switch game[position] {
            case .cross:
                // Silgi: bu X silinir, sürüklenince geçilen X'ler de silinir
                touchStart = position
                paintCross = false
                paint(at: position)
            case .blank:
                // Boş kareye dokunmak silgiyi kapatır (kare işaretlenmez)
                touchStart = nil
                isErasing = false
            default:
                // Bulunan kediler ve yanlış kediler silinmez
                touchStart = nil
            }
            return
        }
        touchStart = position
        paintCross = nil
    }

    /// Sihirli silgi düğmesi.
    func toggleEraser() {
        guard !isFinished else { return }
        isErasing.toggle()
    }

    func touchMoved(to position: GridPosition) {
        guard !isFinished, let start = touchStart, game.contains(position), position != activeCell else { return }
        activeCell = position
        lastTap = nil
        if paintCross == nil {
            // İlk karenin durumu ne yapılacağını belirler: boşsa X koy, X'liyse sil
            switch game[start] {
            case .blank: paintCross = true
            case .cross: paintCross = false
            default: paintCross = true
            }
            paint(at: start)
        }
        paint(at: position)
    }

    /// İki dokunuş arasında çift dokunuş sayılan en uzun süre.
    static let doubleTapWindow: TimeInterval = 0.35
    private var lastTap: (position: GridPosition, time: Date)?

    /// Tek dokunuş: boş kareye X, X'e dokununca silinir. Aynı kareye hızlı çift dokunuş: kedi.
    func touchEnded() {
        defer {
            touchStart = nil
            paintCross = nil
            activeCell = nil
        }
        guard let start = touchStart, paintCross == nil, !isFinished else { return }
        let time = now()
        if let last = lastTap, last.position == start, time.timeIntervalSince(last.time) <= Self.doubleTapWindow {
            lastTap = nil
            handle(game.placeCat(at: start), at: start)
            return
        }
        lastTap = (start, time)
        switch game[start] {
        case .blank: handle(game.paint(cross: true, at: start), at: start)
        case .cross: handle(game.paint(cross: false, at: start), at: start)
        default: break
        }
    }

    private func paint(at position: GridPosition) {
        guard let cross = paintCross else { return }
        handle(game.paint(cross: cross, at: position), at: position)
    }

    // MARK: - İpuçları

    /// "?" düğmesi: bir sonraki mantık adımını kısa bir an gösterir (ilgili kareler vurgulanır),
    /// sonra kendiliğinden uygular: X'ler sırayla çizilir, kedi açılacaksa karesinde belirir.
    /// Adım yoksa `false`.
    @discardableResult
    func useHint() -> Bool {
        guard !isFinished, pendingHint == nil, let hint = game.hint() else { return false }
        isErasing = false
        pendingHint = hint
        hintTask?.cancel()
        // Konacak X kalmadıysa ipucu kediyi koymaz, yalnızca karesini gösterir (oyuncu çift dokunur)
        if hint.pointsAtCat {
            usedHints = true
            return true
        }
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            self?.applyHint()
        }
        return true
    }

    /// Gösterilmekte olan ipucunu hemen işler (yoksa bir şey yapmaz).
    func applyHint() {
        hintTask?.cancel()
        hintTask = nil
        guard let hint = pendingHint else { return }
        guard !hint.pointsAtCat else {
            // Kedinin yerini gösteren ipucu: yalnızca kapanır
            pendingHint = nil
            return
        }
        pendingHint = nil
        usedHints = true
        let before = game.marks
        handle(game.apply(hint))
        // İpucunun X'leri sırayla, çizilerek gelsin
        let time = now()
        var order = 0
        for i in before.indices where before[i] == .blank && game.marks[i] == .cross {
            animations[GridPosition(row: i / level.size, column: i % level.size)] = CatMarkAnimation(
                kind: .cross, start: time.addingTimeInterval(Double(order) * 0.06)
            )
            order += 1
        }
        if order > 0 { onEvent?(.crossed) }
        checkCompletedGroups(around: hint.cells)
        scheduleAnimationCleanup(extra: Double(order) * 0.06)
    }

    /// Kedi bulucu: bir kedinin yerini gösterir ve yerleştirir.
    func revealCat() {
        guard !isFinished else { return }
        applyHint()
        isErasing = false
        usedHints = true
        handle(game.revealCat())
    }

    /// Kaybedince ödüllü reklamla bir can.
    func revive() {
        game.revive()
        start()
    }

    func restart() {
        stop()
        game = CatGame(level: level)
        score = 0
        combo = 0
        bestCombo = 0
        perfectlyMarkedCount = 0
        usedHints = false
        effects = []
        banner = nil
        animations = [:]
        lastConflict = nil
        completedGroups = []
        hintTask?.cancel()
        pendingHint = nil
        isErasing = false
        lastWrong = nil
        lastFindAt = nil
        isPaused = false
        start()
    }

    // MARK: - Sonuçlar

    private func handle(_ move: CatMove, at touched: GridPosition? = nil) {
        switch move {
        case .ignored:
            break
        case .crossed:
            if let touched {
                animate(.cross, at: touched)
                checkCompletedGroups(around: [touched])
            }
            onEvent?(.crossed)
        case .cleared:
            if let touched { animations[touched] = nil }
            onEvent?(.cleared)
        case .found(let find):
            animate(.cat, at: find.position)
            celebrate(find)
            checkCompletedGroups(around: [find.position])
            onEvent?(.found(combo: find.revealed ? 0 : combo))
        case .solved(let find):
            animate(.cat, at: find.position)
            celebrate(find)
            showBanner(.allFound(Int.random(in: 0..<3)), duration: 1.6)
            stop()
            onEvent?(.solved)
            onSolved?(CatPuzzleModel.Completion(
                level: level,
                score: score,
                mistakes: game.mistakes,
                usedHints: usedHints,
                elapsed: game.elapsed,
                bestCombo: bestCombo,
                perfectlyMarked: perfectlyMarkedCount
            ))
        case .mistake(let position):
            wrong(at: position)
            onEvent?(.wrong)
        case .failed(let position):
            wrong(at: position)
            stop()
            onEvent?(.failed)
        }
    }

    private func animate(_ kind: CatMarkAnimation.Kind, at position: GridPosition) {
        animations[position] = CatMarkAnimation(kind: kind, start: now())
        scheduleAnimationCleanup()
    }

    private var cleanupTask: Task<Void, Never>?

    /// Biten animasyonlar silinir; tahta yeniden durgun çizime döner.
    private func scheduleAnimationCleanup(extra: TimeInterval = 0) {
        cleanupTask?.cancel()
        cleanupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(CatMarkAnimation.duration + 0.6 + extra))
            guard let self, !Task.isCancelled else { return }
            let time = self.now()
            self.animations = self.animations.filter { time.timeIntervalSince($0.value.start) < CatMarkAnimation.duration + 0.5 }
        }
    }

    /// Kedisi bulunmuş ve tüm diğer kareleri X'li satır/sütun/renk: "Tamam!" yazısı.
    private func checkCompletedGroups(around cells: [GridPosition]) {
        var seen = Set<CatGroup>()
        var shown: [CatEffect] = []
        for cell in cells {
            let groups = [
                CatGroup(axis: .row, index: cell.row),
                CatGroup(axis: .column, index: cell.column),
                CatGroup(axis: .region, index: level.region(at: cell)),
            ]
            for group in groups where !seen.contains(group) && !completedGroups.contains(group) {
                seen.insert(group)
                if game.isComplete(group) {
                    completedGroups.insert(group)
                    shown.append(CatEffect(kind: .clear, position: cell))
                }
            }
        }
        guard !shown.isEmpty else { return }
        // Aynı karede birden çok grup bittiyse tek yazı yeter
        let unique = Dictionary(shown.map { ($0.position, $0) }, uniquingKeysWith: { first, _ in first }).values
        addEffects(Array(unique))
    }

    private var completedGroups = Set<CatGroup>()

    private func wrong(at position: GridPosition) {
        lastWrong = position
        combo = 0
        animate(.wrong, at: position)
        lastConflict = game.conflict(at: position)
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            if lastWrong == position {
                lastWrong = nil
                lastConflict = nil
            }
        }
    }

    private func celebrate(_ find: CatFind) {
        var shown: [CatEffect] = []
        guard !find.revealed else {
            showBanner(.found)
            return
        }
        let time = now()
        if let last = lastFindAt, time.timeIntervalSince(last) <= Self.comboWindow {
            combo += 1
        } else {
            combo = 1
        }
        lastFindAt = time
        bestCombo = max(bestCombo, combo)
        var points = 480 + 96 * (combo - 1)
        if find.perfectlyMarked {
            points += 192
            perfectlyMarkedCount += 1
        }
        score += points
        shown.append(CatEffect(kind: .points(points), position: find.position))
        addEffects(shown)
        if combo >= 2 {
            showBanner(.combo(combo))
        } else if find.perfectlyMarked {
            showBanner(.perfectlyMarked)
        } else {
            showBanner(.found)
        }
    }

    private func addEffects(_ shown: [CatEffect]) {
        effects.append(contentsOf: shown)
        let ids = Set(shown.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            effects.removeAll { ids.contains($0.id) }
        }
    }

    private func showBanner(_ kind: CatBanner.Kind, duration: TimeInterval = 1.2) {
        let new = CatBanner(kind: kind)
        banner = new
        Task {
            try? await Task.sleep(for: .seconds(duration))
            if banner?.id == new.id { banner = nil }
        }
    }

    // MARK: - Zamanlayıcı

    func start() {
        guard timerTask == nil, !isFinished, !isPaused else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.isFinished else { return }
                self.game.elapsed += 1
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func pause() {
        guard !isFinished else { return }
        isPaused = true
        stop()
    }

    func resume() {
        isPaused = false
        start()
    }
}

extension CatHint {
    /// Tek yer ipucu: kedinin karesini gösterir (X koymaz).
    var pointsAtCat: Bool {
        if case .onlySpot = kind { return true }
        return false
    }
}
