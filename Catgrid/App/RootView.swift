import SwiftUI

@MainActor
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(ReminderManager.self) private var reminders
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.playMode) private var playMode = PlayMode.dopamine

    var body: some View {
        @Bindable var router = router
        @Bindable var ads = ads
        NavigationStack(path: $router.path) {
            MainTabsView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .collectionHub: CollectionHubView()
                    case .chapters: ChaptersView()
                    case .chapter(let id): ChapterView(chapterID: id)
                    case .game(let puzzleID): GameScreen(puzzleID: puzzleID)
                    case .daily: DailyHubView()
                    case .settings: SettingsView()
                    case .stats: StatsView()
                    case .badges(let mode): BadgesView(mode: mode)
                    case .collection: CollectionView()
                    case .catHub: CatHubView()
                    case .catLevels: CatLevelsView()
                    case .catTheme(let index): CatThemeLevelsView(catTheme: CatTheme(rawValue: index) ?? .spring)
                    case .catGame(let levelID): CatGameScreen(levelID: levelID)
                    case .catStats: CatStatsView()
                    }
                }
        }
        // appChrome temayı okuduğu için environment'ın içinde kalmalı
        .appChrome()
        .environment(\.appTheme, themeManager.theme(for: colorScheme))
        .onAppear {
            themeManager.applyInterfaceStyle()
            audio.prepare()
            audio.setPlaylist(playMode.playlist)
            audio.startMusic()
        }
        .onChange(of: playMode) { _, mode in
            audio.setPlaylist(mode.playlist)
        }
        // Onay formu, izleme izni ve reklam SDK'sı; ekran çizildikten sonra
        .task {
            await ads.start()
            // Game Center girişi, onay ve izleme pencereleri kapandıktan sonra (üst üste binmesin)
            try? await Task.sleep(for: .seconds(1.5))
            GameCenterService.shared.start { model.reportToGameCenter() }
        }
        .task { await store.start() }
        // Birkaç reklamdan sonra Premium tanıtımı
        .sheet(isPresented: $ads.isPremiumPromoPresented) {
            PremiumPaywall(isPromo: true)
                .environment(\.appTheme, themeManager.theme(for: colorScheme))
        }
        .onChange(of: store.isPremium, initial: true) { _, removed in
            ads.interstitialsDisabled = removed
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                audio.resumeMusic()
                // Abonelik bu arada bitmiş ya da yenilenmiş olabilir
                Task { await store.refreshEntitlements() }
            } else if phase == .background {
                audio.pauseMusic()
                // Bugün oynandıysa bugünün hatırlatması atlanır
                let lastPlayed = model.lastPlayedAt
                let streak = model.dailyStreak
                Task { await reminders.reschedule(lastPlayedAt: lastPlayed, streak: streak) }
            }
        }
    }
}
