#if DEBUG
import Foundation
import NonogramKit

/// App Store ekran görüntüleri için örnek ilerleme (yalnızca Debug, `-screenshots` ile açılınca).
///
/// Eğitim ve ilk 4 tür bitmiş (kartları koleksiyonda), (Premium içeriği gösterilmez: Altın Kart yok),
/// 5. türün zor bölümü yarıya kadar çözülmüş olarak açılır. Veriler bellekte tutulur,
/// gerçek ilerlemeye dokunulmaz.
enum DemoContent {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshots")
    }

    @MainActor
    static func seed(_ model: AppModel) {
        let catalog = model.catalog
        let breeds = catalog.chapters.filter { $0.kind == .breed }
        let now = Date()
        func complete(_ puzzle: Puzzle) {
            model.record(PuzzleCompletion(puzzleID: puzzle.id, completedAt: now, elapsed: 120, mistakes: 0))
        }
        catalog.chapters.first { $0.kind == .tutorial }?.puzzles.forEach(complete)
        breeds.prefix(4).forEach { $0.puzzles.forEach(complete) }

        guard breeds.count > 4 else { return }
        let current = breeds[4]
        current.puzzles.prefix(12).forEach(complete)
        let target = current.puzzles[min(12, current.puzzles.count - 1)]
        var game = NonogramGame(puzzle: target, rules: catalog.rules(for: target))
        // Dolu karelerin yaklaşık %60'ı: oynanmakta olan bir tahta
        for (index, position) in target.solution.positions.filter({ target.solution[$0] }).enumerated() where index % 5 < 3 {
            game.mark(.filled, at: position)
        }
        model.progress.saveGame(game.snapshot)

        seedDaily(model, now: now)
        seedCats(model)
        seedModes(model)
    }

    /// Miyav Crush ve Miyav Sort: ilk bölümler 1-3 yıldızla bitmiş (tanıtım kartları görülmüş).
    /// Kedi Kutusu: rekor ve yarım kalmış, yarısı dolu bir oyun ("Devam et").
    @MainActor
    private static func seedModes(_ model: AppModel) {
        model.crush.seedDemoProgress(completed: 13)
        let birds = model.birds
        birds.markIntroSeen()
        for level in 1...20 {
            birds.recordWin(level: level, stars: level % 5 == 2 ? 2 : 3, moves: 20)
        }

        let blocks = model.blocks
        _ = blocks.report(score: 12_540)
        var game = CatBlockGame(seed: 7)
        // Satır ya da sütun tamamlamadan ~yarısı dolu tahta: her taş alttan başlayarak ilk boş yere
        for _ in 0..<12 {
            guard let slot = game.tray.indices.first(where: { game.tray[$0] != nil }), let piece = game.tray[slot] else { break }
            let size = CatBlockGame.size
            let spot = (0..<(size * size)).reversed().lazy.map { ($0 / size, $0 % size) }.first { row, column in
                guard game.canPlace(piece, row: row, column: column) else { return false }
                var trial = game
                return trial.place(trayIndex: slot, row: row, column: column)?.lineCount == 0
            }
            guard let (row, column) = spot else { break }
            game.place(trayIndex: slot, row: row, column: column)
        }
        blocks.saveGame(game)
    }

    /// Son 6 günün günlük bulmacası çözülmüş (seri); bugünkü oynanmayı bekliyor.
    @MainActor
    private static func seedDaily(_ model: AppModel, now: Date) {
        for daysAgo in 1...6 {
            let day = DayKey(now.addingTimeInterval(-86_400 * Double(daysAgo)))
            guard model.puzzle(withID: day.puzzleID) != nil else { continue }
            model.record(PuzzleCompletion(puzzleID: day.puzzleID, completedAt: now, elapsed: 240, mistakes: daysAgo % 3 == 0 ? 1 : 0))
        }
    }

    /// Kedi Bulmaca: ilk bölümler 1-3 yıldızla bitmiş, sıradaki bölüm yarıya kadar çözülmüş.
    @MainActor
    private static func seedCats(_ model: AppModel) {
        let cats = model.cats
        let levels = cats.levels
        guard levels.count > 24 else { return }
        for (index, level) in levels.prefix(23).enumerated() {
            let mistakes = index % 4 == 1 ? 1 : (index % 7 == 3 ? 2 : 0)
            cats.record(CatPuzzleModel.Completion(
                level: level, score: 900 + index * 35, mistakes: mistakes, usedHints: false,
                elapsed: 70 + Double(index) * 4, bestCombo: 3, perfectlyMarked: 2
            ))
        }
        // Oynanan bölüm: kedilerin yarısı bulunmuş, çevrelerine X'ler konmuş
        let current = levels[23]
        var game = CatGame(level: current)
        let n = current.size
        for region in 0..<(n / 2) {
            let cat = current.catPosition(ofRegion: region)
            game.placeCat(at: cat)
            for index in CatRules.attacked(by: cat.row * n + cat.column, in: current) {
                game.paint(cross: true, at: GridPosition(row: index / n, column: index % n))
            }
        }
        cats.save(game.snapshot, for: current)
        model.refreshBadges()
    }
}
#endif
