import SwiftUI

/// Çözülen bulmacayı paylaşma: bulmacanın görseli, oyunun adı ve kısa bir sonuç satırıyla
/// hazırlanmış bir kart görseli ve davet metni (uygulamanın sayfasına bağlantıyla).
@MainActor
struct ShareResultButton<Art: View>: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.locale) private var locale
    /// Kartın altındaki sonuç satırı (ör. "4 yıldız · 2:15").
    let headline: Text
    var style: Style = .light
    @ViewBuilder let art: () -> Art

    @State private var image: Image?

    enum Style {
        /// Açık zemin üstünde (kutlama ekranı)
        case light
        /// Koyu, yarı saydam zemin üstünde (Kedi Bulmaca sonucu)
        case dark
    }

    private var message: String {
        String(localized: "I solved this puzzle in Catgrid Collection! Can you? 🐾") + "\n" + AppLinks.marketing.absoluteString
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(
                    item: image,
                    message: Text(verbatim: message),
                    preview: SharePreview(Text(verbatim: "Catgrid Collection"), image: image)
                ) {
                    label
                }
            } else {
                label.opacity(0.4)
            }
        }
        .accessibilityLabel(Text("Share"))
        .accessibilityIdentifier("result.share")
        .task { render() }
    }

    private var label: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.body.weight(.bold))
            .foregroundStyle(style == .light ? theme.textPrimary : .white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(style == .light ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.white.opacity(0.18))))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    /// Paylaşılacak kart bir kez çizilir (1080 piksel kare).
    private func render() {
        guard image == nil else { return }
        let card = ShareCard(headline: headline, art: art)
            .environment(\.appTheme, theme)
            .environment(\.locale, locale)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        }
    }
}

/// Paylaşılan görsel: krem zemin, ortada bulmaca, altta oyunun adı ve sonuç.
private struct ShareCard<Art: View>: View {
    let headline: Text
    let art: () -> Art

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                Text(verbatim: "Catgrid Collection")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#3B2A24"))
            }
            art()
                .padding(14)
                .frame(width: 250, height: 250)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            headline
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#3B2A24"))
                .multilineTextAlignment(.center)
            Text("Nonogram · Cat Puzzle · Cards")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#8A6F62"))
        }
        .padding(24)
        .frame(width: 360, height: 420)
        .background(
            LinearGradient(colors: [Color(hex: "#FFF6EA"), Color(hex: "#FBE3CF")], startPoint: .top, endPoint: .bottom)
        )
    }
}
