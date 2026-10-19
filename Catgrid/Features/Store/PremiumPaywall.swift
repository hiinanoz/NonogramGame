import StoreKit
import SwiftUI

/// "Catgrid Premium" abonelik ekranı. Fiyat, süre, otomatik yenileme ve iptal bilgisini
/// Apple'ın `SubscriptionStoreView`'ı gösterir; App Store inceleme kurallarına uygundur.
///
/// Ayarlardan, ana sayfa bannerından, bölüm ekranındaki altın bulmaca tanıtımından ve
/// birkaç geçiş reklamından sonra tanıtım olarak açılır.
@MainActor
struct PremiumPaywall: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    /// Reklamlardan sonra kendiliğinden açıldıysa başlık farklı.
    var isPromo = false

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.productIDs) {
            VStack(spacing: 14) {
                ZStack(alignment: .top) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Gold.foil, lineWidth: 3)
                        )
                        .padding(.top, 16)
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(Gold.foil)
                        .shadow(color: Gold.deep.opacity(0.4), radius: 2, y: 1)
                }
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    if isPromo {
                        Text("Enjoying Catgrid?")
                            .font(.headline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Text(verbatim: "Catgrid Premium")
                        .font(.title.bold())
                        .foregroundStyle(theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    benefit("No ads between puzzles", icon: "nosign")
                    benefit("9 golden puzzles for every breed", icon: "crown.fill")
                    benefit("Collect shiny Golden Cards", icon: "rectangle.stack.fill")
                    benefit("Cat Puzzle: 6 Cat Finders and 6 hints every day", icon: "cat.fill")
                    benefit("Meow Crush: unlimited lives and a free +5 moves in every level", icon: "heart.circle.fill")
                    benefit("Support new cat breeds and puzzles", icon: "heart.fill")
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
            // Apple'ın ekranı dili App Store hesabının ülkesinden alır (ör. ABD hesabında İngilizce);
            // kendi yazılarımız uygulamanın dilinde kalsın
            .environment(\.locale, Self.appLocale)
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: AppLinks.termsOfUse, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            if case .success(let purchase) = result {
                await store.handlePurchase(purchase)
            }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
        .tint(Gold.deep)
    }

    /// Uygulamanın o an kullandığı dil (telefonun ya da Ayarlar'dan seçilen uygulama dili).
    private static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    private func benefit(_ title: LocalizedStringKey, icon: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Gold.deep)
        }
        .font(.subheadline.weight(.medium))
    }
}

/// Ana sayfadaki "Premium'a geç" bannerı (yalnızca abone olmayanlara).
@MainActor
struct PremiumBanner: View {
    @Environment(\.appTheme) private var theme
    let action: () -> Void

    /// Şampanya tonları: göze batmayan, zarif bir altın şerit.
    private var champagne: LinearGradient {
        theme.isDark
            ? LinearGradient(colors: [Color(hex: "#4A3B1E"), Color(hex: "#3A2E17")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color(hex: "#FFF6DD"), Color(hex: "#F8E6B4")], startPoint: .leading, endPoint: .trailing)
    }

    private var ink: Color { theme.isDark ? Gold.light : Gold.ink }

    private var hasPeekCat: Bool { LoopingCatAnimation.isAvailable(LoopingCatAnimation.peekCat) }

    /// Kenardan bakan kedinin boyu ve şeridin üstüne taşan kısmı.
    private static let peekHeight: CGFloat = 80
    private static let peekRise: CGFloat = 26
    /// Videodaki duvar kenarı karenin genişliğinin %92'sinde; patiler kenarın dışına taşar.
    private static let peekEdge: CGFloat = 0.92
    private static var peekWidth: CGFloat { peekHeight * 300 / 338 * peekEdge }

    /// Şeridin sağ kenarının arkasından bakan kedi: gövdesi kenarda kesilir, patileri kenara
    /// tutunur; başı şeridin üstüne taşar. Alt köşede şeridin yuvarlak köşesiyle kırpılır.
    private var peekCat: some View {
        let overhang: CGFloat = 12
        return ZStack(alignment: .bottomTrailing) {
            Color.clear
            LoopingCatView(name: LoopingCatAnimation.peekCat)
                .frame(height: Self.peekHeight)
                .padding(.trailing, overhang - Self.peekHeight * 300 / 338 * (1 - Self.peekEdge))
        }
        .padding(.top, -Self.peekRise)
        .padding(.trailing, -overhang)
        // Görünür alan: şeridin kendisi (yuvarlak köşeli) ve üstüyle sağındaki taşma payı;
        // yalnızca en alttaki birkaç noktada şeridin yuvarlak köşesiyle kırpılır
        .mask {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .padding(.top, Self.peekRise)
                    .padding(.trailing, overhang)
                Rectangle()
                    .padding(.bottom, 8)
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.headline)
                    .foregroundStyle(Gold.deep)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Gold.light.opacity(theme.isDark ? 0.2 : 0.9)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("More with Premium")
                        .font(.subheadline.bold())
                    Text("Ad-free · Golden puzzles · Special cards")
                        .font(.caption)
                        .opacity(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(ink)
                Spacer(minLength: 4)
                if !hasPeekCat {
                    IllustrationView(name: "premium-cat")
                        .frame(maxHeight: 44)
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundStyle(ink.opacity(0.6))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, hasPeekCat ? Self.peekWidth + 2 : 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(champagne))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Gold.mid.opacity(0.45), lineWidth: 1)
            )
            .overlay { if hasPeekCat { peekCat } }
            .shadow(color: Gold.deep.opacity(theme.isDark ? 0 : 0.12), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("home.premiumBanner")
    }
}

