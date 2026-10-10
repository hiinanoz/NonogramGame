import SwiftUI

/// Alt menünün sekmeleri.
enum MainTab: Hashable {
    case home
    case badges
    case settings
}

/// Uygulamanın kökü: seçili sekmenin ekranı ve altında menü. Bir ekrana girildiğinde
/// (oyun, bölümler…) menü gizlenir; geri dönünce yeniden görünür.
@MainActor
struct MainTabsView: View {
    @State private var tab: MainTab = .home

    var body: some View {
        Group {
            switch tab {
            case .home: HomeView { tab = .settings }
            case .badges: BadgesTabView()
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selection: $tab)
        }
    }
}

@MainActor
struct MainTabBar: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            item(.home, icon: "house.fill", title: "Home", identifier: "tab.home")
            item(.badges, icon: "trophy.fill", title: "Badges", identifier: "tab.badges")
            item(.settings, icon: "gearshape.fill", title: "Settings", identifier: "tab.settings")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            theme.surface
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: theme.textPrimary.opacity(theme.isDark ? 0 : 0.06), radius: 8, y: -2)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.separator.opacity(0.7))
                .frame(height: 0.5)
        }
    }

    private func item(_ tab: MainTab, icon: String, title: LocalizedStringKey, identifier: String) -> some View {
        let isSelected = selection == tab
        return Button {
            guard selection != tab else { return }
            Haptics.selection()
            withAnimation(.snappy(duration: 0.2)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 52, height: 28)
                    .background(Capsule().fill(isSelected ? theme.accent.opacity(0.16) : .clear))
                Text(title)
                    .font(.caption2.weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}
