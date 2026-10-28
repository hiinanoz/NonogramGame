import GameKit
import UIKit

/// Game Center: oturum açma, sıralama listelerine skor gönderme ve listeleri gösterme.
/// Oyuncu Game Center'a girmemişse her şey sessizce atlanır; oyun bundan etkilenmez.
@MainActor
final class GameCenterService: NSObject {
    static let shared = GameCenterService()

    /// App Store Connect'teki sıralama listeleri (Tools/asc_gamecenter.py ile aynı kimlikler).
    enum Leaderboard: String, CaseIterable {
        /// En uzun günlük bulmaca serisi
        case dailyStreak = "catgrid.daily.streak"
        /// Çözülen nonogram sayısı
        case nonogramsSolved = "catgrid.nonogram.solved"
        /// Bitirilen Kedi Bulmaca bölümü sayısı
        case catLevelsSolved = "catgrid.cats.levels"
        /// Geçilen Miyav Crush bölümü sayısı
        case crushLevels = "catgrid.crush.levels"
        /// Geçilen Miyav Sort bölümü sayısı
        case sortLevels = "catgrid.sort.levels"
        /// Kedi Kutusu en yüksek skoru
        case blockBest = "catgrid.block.best"
    }

    private var lastSubmitted: [Leaderboard: Int] = [:]
    private var didStart = false

    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Uygulama açılınca bir kez. Testlerde ve ekran görüntüsü çekiminde çalışmaz
    /// (giriş penceresi otomatik testleri kapatmasın).
    func start(onAuthenticated: @escaping @MainActor () -> Void) {
        guard !didStart, !Self.isAutomated else { return }
        didStart = true
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor in
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                } else if GKLocalPlayer.local.isAuthenticated {
                    onAuthenticated()
                }
            }
        }
    }

    /// Güncel değerleri gönderir; değişmeyen değer tekrar gönderilmez.
    func submit(_ scores: [Leaderboard: Int]) {
        guard isAuthenticated else { return }
        for (board, value) in scores where value > 0 && lastSubmitted[board] != value {
            lastSubmitted[board] = value
            GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board.rawValue]) { _ in }
        }
    }

    /// Sıralama listelerini açar (giriş yapılmamışsa Game Center giriş ekranı gelir).
    func showLeaderboards() {
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = self
        Self.topViewController()?.present(controller, animated: true)
    }

    private static var isAutomated: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return NSClassFromString("XCTestCase") != nil
            || arguments.contains("-disableAds")
            || arguments.contains("-screenshots")
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension GameCenterService: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in gameCenterViewController.dismiss(animated: true) }
    }
}
