import SwiftUI

/// Miyav Crush ve Miyav Sort duraklatma kartı: tahta örtülür; devam, baştan başla ya da haritaya
/// dön (bölüm kaydedilir, dönünce kaldığı yerden sürer).
struct ModePauseOverlay: View {
    @Environment(\.appTheme) private var theme
    let onContinue: () -> Void
    let onRestart: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            theme.background
                .opacity(0.94)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            VStack(spacing: 14) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent)
                Text("Paused")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("Take a break. Your puzzle will wait for you.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("pause.continue")
                    Button(action: onRestart) {
                        Label("Start Over", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("pause.restart")
                    Button(action: onMap) {
                        Label("Back to Map", systemImage: "map.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("pause.map")
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .card()
            .padding(.horizontal, 20)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}

/// Oyun ekranlarının üst köşesindeki duraklat düğmesi.
struct ModePauseButton: View {
    @Environment(\.appTheme) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pause.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(theme.surface.opacity(0.95)))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Pause"))
    }
}
