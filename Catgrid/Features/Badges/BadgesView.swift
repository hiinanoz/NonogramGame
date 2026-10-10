import SwiftUI

/// Rozetler: kazanılanlar renkli ve tarihli, kalanlar soluk ve nasıl kazanılacağıyla.
@MainActor
struct BadgesView: View {
    let mode: BadgeMode

    var body: some View {
        ScrollView {
            BadgeGrid(mode: mode)
                .padding(20)
        }
        .themedScreen()
        .screenTitle("My Badges")
    }
}

/// Alt menüdeki Rozetler sekmesi: üç modun rozetleri, üstte mod seçici.
@MainActor
struct BadgesTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    @State private var mode: BadgeMode = .collection

    var body: some View {
        let total = BadgeMode.allCases.flatMap { Badge.all(in: $0) }
        let earned = total.filter { model.badges.isEarned($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(Gold.deep)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Gold.light.opacity(theme.isDark ? 0.2 : 0.9)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Badges")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                        Text(verbatim: "\(earned)/\(total.count)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(theme.textPrimary)
                    }
                    Spacer()
                }
                PillPicker(selection: $mode, options: BadgeMode.allCases.map { ($0, Text($0.title)) })
                BadgeGrid(mode: mode)
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Badges")
    }
}

/// Bir modun rozet ızgarası; kazanılanlar önce (kazanma sırasıyla), sonra kalanlar.
@MainActor
struct BadgeGrid: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    let mode: BadgeMode

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let badges = model.badges
        let list = Badge.all(in: mode)
        let earned = list.filter { badges.earned[$0] != nil }
        let locked = list.filter { badges.earned[$0] == nil }
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.headline)
                    .foregroundStyle(theme.textSecondary)
                Text(verbatim: "\(earned.count)/\(list.count)")
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                ProgressBar(value: list.isEmpty ? 0 : Double(earned.count) / Double(list.count), tint: Gold.deep)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(earned + locked) { badge in
                    BadgeTile(badge: badge, earnedAt: badges.earned[badge])
                }
            }
        }
    }
}

@MainActor
struct BadgeTile: View {
    @Environment(\.appTheme) private var theme
    let badge: Badge
    let earnedAt: Date?

    var body: some View {
        let isEarned = earnedAt != nil
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.surfaceMuted))
                Image(systemName: isEarned ? badge.icon : "lock.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isEarned ? Gold.ink : theme.textSecondary.opacity(0.6))
            }
            .frame(width: 56, height: 56)
            Text(badge.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? theme.textPrimary : theme.textSecondary)
            Text(badge.detail)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let earnedAt {
                Text(earnedAt, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(Gold.deep)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
        .padding(12)
        .card(cornerRadius: 18)
        .opacity(isEarned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
    }
}
