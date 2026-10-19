import NonogramKit
import SwiftUI

/// Dalda duran ya da uçan tek kuş: kimliği sabit kalır, böylece daldan dala uçuşu canlandırılır.
struct BirdToken: Identifiable, Hashable {
    enum Phase: Hashable {
        case perched
        case flying
        /// Dal dolunca sürü ekrandan uçup gider.
        case leaving
    }

    let id: Int
    let species: Int
    var branch: Int
    var slot: Int
    var phase: Phase = .perched
}

/// Alttaki kedinin hâli: oyuncunun hamlelerine tepki verir.
enum BirdSortCatMood: Equatable {
    case idle
    /// Doğru hamle: hafif sevinç.
    case pleased
    /// Dal tamamlandı: uçan kuşlara uzanır.
    case delighted
    /// Geçersiz hamle: üzülür.
    case sad
    /// İpucu: değnekle gösterir.
    case pointing
    /// Bölüm bitti: kutlama.
    case celebrating
}

@MainActor
@Observable
final class BirdSortGameViewModel {
    let level: BirdSortLevel
    private(set) var session: BirdSortSession?
    private(set) var birds: [BirdToken] = []
    private(set) var selected: Int?
    /// Geçersiz hamlede sallanan dal.
    private(set) var shaking: Int?
    private(set) var shakeCount = 0
    private(set) var hint: (source: Int, target: Int)?
    private(set) var catMood: BirdSortCatMood = .idle
    private(set) var isAnimating = false
    private(set) var isWon = false
    private(set) var isStuck = false
    private var nextID = 0
    /// Baştan başlatmak için ilk tahta.
    private var initialBoard: BirdSortBoard?
    private var moodTask: Task<Void, Never>?

    var onFlap: () -> Void = {}
    var onBirdsAway: () -> Void = {}
    var onMistake: () -> Void = {}
    var onSelect: () -> Void = {}
    var onWin: () -> Void = {}

    /// Kayıttan dönülen bölüm (varsa); `load()` tahtayı üretmek yerine bunu kullanır.
    private var resumed: BirdSortSession?

    init(level: BirdSortLevel, resuming saved: BirdSortSession? = nil) {
        self.level = level
        resumed = saved
    }

    var hasProgress: Bool { (session?.moves ?? 0) > 0 && !isWon }

    var branchCount: Int { session?.board.branches.count ?? level.branchCount }
    var capacity: Int { level.capacity }
    var moves: Int { session?.moves ?? 0 }
    var canUndo: Bool { (session?.canUndo ?? false) && !isAnimating && !isWon }
    var canAddBranch: Bool { session?.canAddBranch ?? false }

    /// Tahta arka planda üretilir (ileri bölümlerde birkaç yüz milisaniye sürebilir).
    func load() async {
        guard session == nil else { return }
        if let resumed {
            session = resumed
            // Baştan başlatmak için ilk tahta: kayıttaki geçmişin ilki
            initialBoard = BirdSortBoard(branches: Array((resumed.history.first ?? resumed.board).branches.prefix(level.branchCount)),
                                         capacity: level.capacity)
            isStuck = resumed.isStuck
            rebuild(animated: false)
            return
        }
        let level = level
        let made = await Task.detached(priority: .userInitiated) { BirdSortSession(level: level) }.value
        session = made
        initialBoard = made.board
        rebuild(animated: false)
    }

    // MARK: - Dokunma

    func tap(branch index: Int) {
        guard let session, !isAnimating, !isWon else { return }
        if let source = selected {
            if source == index {
                withAnimation(.spring(response: 0.25)) { selected = nil }
                return
            }
            if session.board.movableCount(from: source, to: index) > 0 {
                Task { await move(from: source, to: index) }
            } else {
                // Başka tür kuşun üstüne ya da dolu dala konulamaz
                mistake(on: index)
            }
        } else {
            select(index)
        }
    }

    private func select(_ index: Int) {
        guard let session, !session.board.branches[index].isEmpty else {
            withAnimation(.spring(response: 0.25)) { selected = nil }
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selected = index }
        onSelect()
    }

    private func mistake(on index: Int) {
        onMistake()
        shaking = index
        withAnimation(.default) { shakeCount += 1 }
        setMood(.sad, for: 1.4)
        withAnimation(.spring(response: 0.25)) { selected = nil }
    }

    // MARK: - Hamle

    private func move(from source: Int, to target: Int) async {
        guard var session else { return }
        guard let move = session.play(from: source, to: target) else { return }
        self.session = session
        isAnimating = true
        hint = nil
        withAnimation(.spring(response: 0.25)) { selected = nil }
        // Uçan kuşlar: kaynağın ucundaki `count` kuş, uca en yakın olan önce kalkar
        let sourceBirds = birds.filter { $0.branch == source && $0.phase == .perched }.sorted { $0.slot > $1.slot }
        let flyers = Array(sourceBirds.prefix(move.count))
        let landed = birds.filter { $0.branch == target && $0.phase == .perched }.count
        onFlap()
        for (k, token) in flyers.enumerated() {
            guard let i = birds.firstIndex(where: { $0.id == token.id }) else { continue }
            birds[i].phase = .flying
            withAnimation(.easeInOut(duration: 0.42).delay(Double(k) * 0.06)) {
                birds[i].branch = target
                birds[i].slot = landed + k
            }
        }
        try? await Task.sleep(for: .seconds(0.42 + Double(flyers.count - 1) * 0.06))
        for token in flyers {
            if let i = birds.firstIndex(where: { $0.id == token.id }) { birds[i].phase = .perched }
        }
        if move.clearedTarget {
            setMood(.delighted, for: 1.6)
            try? await Task.sleep(for: .seconds(0.12))
            onBirdsAway()
            withAnimation(.easeIn(duration: 0.75)) {
                for i in birds.indices where birds[i].branch == target { birds[i].phase = .leaving }
            }
            try? await Task.sleep(for: .seconds(0.75))
            birds.removeAll { $0.phase == .leaving }
        } else {
            setMood(.pleased, for: 0.9)
        }
        isAnimating = false
        if session.isWon {
            isWon = true
            moodTask?.cancel()
            catMood = .celebrating
            onWin()
        } else {
            isStuck = session.isStuck
        }
    }

    // MARK: - Yardımcılar

    func undo() {
        guard var session else { return }
        guard session.undo() else { return }
        self.session = session
        hint = nil
        selected = nil
        isStuck = false
        withAnimation(.easeInOut(duration: 0.3)) { rebuild(animated: true) }
    }

    func addBranch() -> Bool {
        guard var session else { return false }
        guard session.addBranch() else { return false }
        self.session = session
        isStuck = false
        hint = nil
        return true
    }

    func showHint() async -> Bool {
        guard var session else { return false }
        let found = session.hint()
        self.session = session
        guard let found else { return false }
        withAnimation(.spring(response: 0.3)) {
            selected = nil
            hint = found
        }
        setMood(.pointing, for: 2.2)
        return true
    }

    func restart() {
        guard let session, let initialBoard else { return }
        self.session = BirdSortSession(level: level, board: initialBoard, par: session.par)
        selected = nil
        hint = nil
        isStuck = false
        isWon = false
        catMood = .idle
        withAnimation(.easeInOut(duration: 0.3)) { rebuild(animated: true) }
    }

    var stars: Int { session?.stars ?? 0 }

    private func rebuild(animated: Bool) {
        guard let session else { return }
        var tokens: [BirdToken] = []
        for (b, branch) in session.board.branches.enumerated() {
            for (s, species) in branch.enumerated() {
                tokens.append(BirdToken(id: nextID, species: species, branch: b, slot: s))
                nextID += 1
            }
        }
        birds = tokens
    }

    private func setMood(_ mood: BirdSortCatMood, for seconds: Double) {
        moodTask?.cancel()
        catMood = mood
        moodTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.catMood = self?.isWon == true ? .celebrating : .idle
        }
    }

    /// Seçili dalın ucundan kalkacak kuşlar (yukarı kalkık gösterilir).
    func isLifted(_ token: BirdToken) -> Bool {
        guard let selected, token.branch == selected, token.phase == .perched, let session else { return false }
        let count = session.board.branches[selected].count
        return token.slot >= count - session.board.topRun(selected)
    }
}
