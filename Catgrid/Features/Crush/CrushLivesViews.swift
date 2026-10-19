import NonogramKit
import SwiftUI

/// Can göstergesi: kalp, sayı ve bir sonraki cana kalan süre. Premium'da sonsuz.
@MainActor
struct CrushLivesBadge: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    var showsTimer = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let crush = model.crush
            let count = crush.livesCount(at: timeline.date)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color(hex: "#F0506E"))
                if store.isPremium {
                    Text(verbatim: "∞")
                } else {
                    Text(verbatim: "\(count)")
                    if showsTimer, let remaining = crush.timeToNextLife(at: timeline.date) {
                        Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(theme.surface.opacity(0.92)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Lives"))
            .accessibilityValue(store.isPremium ? Text("Unlimited") : Text(verbatim: "\(count)"))
        }
        .accessibilityIdentifier("crush.lives")
    }
}

/// Can bitince: ödüllü reklamla +1 can, Premium'la sınırsız can ya da beklemek.
@MainActor
struct CrushNoLivesOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    let canWatchAd: Bool
    let onWatchAd: () -> Void
    let onPremium: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color(hex: "#F0506E").opacity(0.25))
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color(hex: "#F0506E"))
                }
                Text("Out of lives!")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    if let remaining = model.crush.timeToNextLife(at: timeline.date) {
                        Text("Next life in \(Text(Duration.seconds(remaining.rounded(.up)), format: .time(pattern: .minuteSecond)))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Text("A new life arrives every 30 minutes. Win a level to keep your life.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                VStack(spacing: 10) {
                    if canWatchAd {
                        Button(action: onWatchAd) {
                            Label("Watch Video (+1 Life)", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("crush.lives.ad")
                    }
                    Button(action: onPremium) {
                        Label("Unlimited Lives with Premium", systemImage: "crown.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Back to Map", action: onMap)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.top, 2)
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .card()
            .padding(20)
        }
    }
}
