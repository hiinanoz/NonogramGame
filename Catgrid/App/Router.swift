import SwiftUI

enum Route: Hashable {
    /// Kedi Kart Koleksiyonu (resimli bulmacalar) modunun giriş ekranı.
    case collectionHub
    case chapters
    case chapter(id: String)
    case game(puzzleID: String)
    /// Günlük bulmaca: bugün ve önceki 10 gün.
    case daily
    case settings
    case stats
    case badges(BadgeMode)
    case collection
    /// Kedi Bulmaca modu.
    case catHub
    case catLevels
    /// Kedi Bulmaca teması (1–4): o temanın boyutlarındaki bölümler.
    case catTheme(Int)
    case catGame(levelID: String)
    case catStats
    /// Miyav Crush (3'lü eşleştirme) modu.
    case crushHub
    case crushGame(levelID: String)
}

/// Uygulama içi gezinme yığını. Ekranlar doğrudan `NavigationLink` yerine bunu kullanır
/// ki "Sonraki Bulmaca" gibi akışlar yığını kontrollü değiştirebilsin.
@MainActor
@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    /// En üstteki ekranı değiştirir (ör. oyun → sonraki oyun); geri tuşu bir önceki listeye döner.
    func replaceTop(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Ana sayfaya döner.
    func popToRoot() {
        path.removeAll()
    }
}
