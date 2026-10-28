import SwiftUI

@main
@MainActor
struct CatgridApp: App {
    @State private var model = AppModel.live()
    @State private var themeManager = ThemeManager()
    @State private var router = Router()
    @State private var audio = AudioManager()
    @State private var ads = AdCoordinator.live()
    @State private var store = StoreManager()
    @State private var reminders = ReminderManager()
    /// Açılışta 3 saniyelik THiNKS animasyonu; uygulama arkasında hazırlanır.
    @State private var isShowingSplash = !ThinksSplash.isSkipped

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(model)
                    .environment(themeManager)
                    .environment(router)
                    .environment(audio)
                    .environment(ads)
                    .environment(store)
                    .environment(reminders)
                if isShowingSplash {
                    ThinksSplashView {
                        withAnimation(.easeOut(duration: 0.35)) { isShowingSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
