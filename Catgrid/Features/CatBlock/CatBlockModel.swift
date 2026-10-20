import Foundation
import NonogramKit
import SwiftUI

/// Kedi Kutusu: en yüksek puan, oyun sayısı ve yarıda bırakılan oyun. Her oyun sıfırdan başlar;
/// bölüm ilerlemesi yoktur. Kayıtlar UserDefaults'ta.
@MainActor
@Observable
final class CatBlockModel {
    enum Keys {
        static let best = "catblock.best"
        static let gamesPlayed = "catblock.gamesPlayed"
        static let savedGame = "catblock.savedGame"
    }

    private let defaults: UserDefaults
    private(set) var bestScore: Int
    private(set) var gamesPlayed: Int
    private(set) var savedGame: CatBlockGame?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        bestScore = defaults.integer(forKey: Keys.best)
        gamesPlayed = defaults.integer(forKey: Keys.gamesPlayed)
        savedGame = defaults.data(forKey: Keys.savedGame).flatMap { try? JSONDecoder().decode(CatBlockGame.self, from: $0) }
    }

    static func inMemory() -> CatBlockModel {
        let name = "catblock-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return CatBlockModel(defaults: defaults)
    }

    /// Yeni en yüksek puan mı (kaydeder).
    @discardableResult
    func report(score: Int) -> Bool {
        guard score > bestScore else { return false }
        bestScore = score
        defaults.set(score, forKey: Keys.best)
        return true
    }

    func recordFinishedGame(score: Int) {
        report(score: score)
        gamesPlayed += 1
        defaults.set(gamesPlayed, forKey: Keys.gamesPlayed)
        clearSavedGame()
    }

    func saveGame(_ game: CatBlockGame) {
        savedGame = game
        defaults.set(try? JSONEncoder().encode(game), forKey: Keys.savedGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Keys.savedGame)
    }

    func reset() {
        bestScore = 0
        gamesPlayed = 0
        savedGame = nil
        for key in [Keys.best, Keys.gamesPlayed, Keys.savedGame] { defaults.removeObject(forKey: key) }
    }
}

/// Blok renkleri: uygulamanın pastel mod renkleri.
enum CatBlockPalette {
    static func color(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#9A7BE0"), Color(hex: "#F09A4A"), Color(hex: "#3FB3A2"), Color(hex: "#EC6A8F"),
            Color(hex: "#3E9FD4"), Color(hex: "#EDBE45"), Color(hex: "#7CC064"),
        ]
        return colors[((index % colors.count) + colors.count) % colors.count]
    }
}

/// Tek blok: yumuşak kabartma, üstte parlaklık ve blokla aynı renkte soluk pati izi.
struct CatBlockTile: View {
    let color: Int
    var size: CGFloat
    var isGhost = false

    var body: some View {
        let base = CatBlockPalette.color(color)
        let radius: CGFloat = size * 0.2
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [base.opacity(0.92), base], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.55), .black.opacity(0.18)], startPoint: .top, endPoint: .bottom),
                    lineWidth: max(1, size * 0.07)
                )
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                // Aynı renk, biraz koyu ve soluk
                .foregroundStyle(Color.black.opacity(0.13))
                .rotationEffect(.degrees(-12))
        }
        .frame(width: size, height: size)
        .opacity(isGhost ? 0.45 : 1)
    }
}
