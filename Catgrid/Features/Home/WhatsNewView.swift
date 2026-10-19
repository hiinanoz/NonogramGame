import SwiftUI

/// Güncellemeden sonra bir kez açılan "Yenilikler" penceresi (yeni modları duyurmak için).
/// Yeni sürümde `version` ve madde listesi güncellenir; o sürümü gören oyuncuya tekrar çıkmaz.
enum WhatsNew {
    static let version = "1.2"
    static let seenKey = "whatsNew.seenVersion"

    /// Yalnızca daha önce oynamış (güncelleme yapan) oyunculara; yeni oyuncuya hiç gösterilmez.
    @MainActor
    static func shouldShow(isReturningPlayer: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.string(forKey: seenKey) != version else { return false }
        if !isReturningPlayer {
            defaults.set(version, forKey: seenKey)
            return false
        }
        return true
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: seenKey)
    }
}

@MainActor
struct WhatsNewView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            MuffinView(pose: .cheer, speechID: 1)
                .frame(height: 120)
                .padding(.top, 24)
            Text("What's New")
                .font(.largeTitle.bold())
                .foregroundStyle(theme.textPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    item("bird.fill", "Bird Sort", "Bird Sort: sort the birds onto the branches across 6 islands and 450 levels. The cat cheers every flock that flies away!")
                    item("sparkles", "Meow Crush", "A brand-new match-3 mode: swipe cat toys, make special combos and climb 300 floors of the Cat Tower!")
                    item("cat.fill", "Cat Puzzle", "A brand-new mode: find the hidden cats, one per color, row and column. 335 levels!")
                    item("calendar", "Daily Puzzle history", "Missed a day? Solve the puzzles of the last 10 days.")
                    item("medal.fill", "More badges", "At least 20 badges for every mode.")
                    item("scope", "Cursor for big puzzles", "Play puzzles bigger than 10×10 with a two-hand cursor.")
                    item("music.note", "New music", "Fresh tracks for Energetic mode.")
                }
                .padding(.horizontal, 24)
            }
            Button {
                WhatsNew.markSeen()
                dismiss()
            } label: {
                Text("Let's Play!")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("whatsNew.close")
        }
        .themedScreen()
        .onDisappear { WhatsNew.markSeen() }
    }

    private func item(_ icon: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
