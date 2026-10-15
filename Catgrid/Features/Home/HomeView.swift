import NonogramKit
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(ReminderManager.self) private var reminders
    @Environment(\.appTheme) private var theme
    /// Sağ üstteki ayarlar düğmesi: alt menüde Ayarlar sekmesine geçer.
    var openSettings: () -> Void = {}
    @State private var isShowingPaywall = false
    @State private var isOfferingReminder = false
    @State private var isShowingWhatsNew = false
    @State private var shownCard: CardSelection?
    /// Durum çubuğunun yüksekliği: üstteki çizim bu kadar yukarı uzatılır.
    @State private var topInset: CGFloat = 0

    var body: some View {
        // Ekrana sığan ilk düzen seçilir: önce rahat, sonra sıkı; o da sığmazsa (çok küçük
        // ekran ya da büyük yazı boyutu) kaydırılabilir.
        ViewThatFits(in: .vertical) {
            content(compact: false)
            content(compact: true)
            ScrollView {
                content(compact: true)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Üstteki çizim kaydırılınca da durum çubuğunun arkasına uzansın (krem bant kalmasın)
            .scrollClipDisabled()
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .themedScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPaywall) {
            PremiumPaywall()
        }
        .sheet(item: $shownCard) { selection in
            CardDetailSheet(chapter: selection.chapter, isGolden: selection.isGolden)
        }
        // Birkaç bulmacadan sonra bir kez: günlük hatırlatma ister misin?
        .task {
            // Güncellemeden sonra önce "Yenilikler"; o gün hatırlatma sorulmaz
            if WhatsNew.shouldShow(isReturningPlayer: isReturningPlayer) {
                try? await Task.sleep(for: .seconds(0.6))
                isShowingWhatsNew = true
                return
            }
            guard canOfferReminder else { return }
            try? await Task.sleep(for: .seconds(0.8))
            isOfferingReminder = true
        }
        .sheet(isPresented: $isShowingWhatsNew) {
            WhatsNewView()
        }
        .alert("Daily reminder?", isPresented: $isOfferingReminder) {
            Button("Remind Me") {
                Task { _ = await reminders.enable() }
            }
            Button("Not Now", role: .cancel) { reminders.markAsked() }
        } message: {
            Text("We'll send one gentle reminder a day, only on days you haven't played. You can change this in Settings.")
        }
    }

    /// Üstte karşılama alanı, altında üç oyun modu, kısa istatistikler, koleksiyon önizlemesi
    /// ve en altta (abone olmayanlara) Premium şeridi.
    private func content(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 16) {
            HomeHero(compact: compact, topInset: topInset, openSettings: openSettings)
            VStack(spacing: compact ? 10 : 14) {
                modeCards(compact: compact)
                    // Kartlar çizimin solan alt kenarına biner: arada boşluk kalmaz
                    .padding(.top, compact ? -16 : -26)
                HomeStatsStrip()
                HomeCollectionPreview(tileWidth: compact ? 72 : 84) { shownCard = $0 }
                if !store.isPremium {
                    PremiumBanner { isShowingPaywall = true }
                } else {
                    // Premium oyunculara şerit yerine kedili bir sahne (çizim varsa)
                    PremiumHomeArt()
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .padding(.bottom, compact ? 6 : 12)
    }

    /// Kedi Bulmaca öne çıkar: üstte tam genişlikte büyük kart, altında Günlük Bulmaca ve
    /// Kart Koleksiyonu yan yana.
    private func modeCards(compact: Bool) -> some View {
        // Üç kart aynı yükseklikte: büyük kart ile alttaki iki kart hizalı dursun
        let cardHeight: CGFloat = compact ? 132 : 158
        let streak = model.dailyStreak
        let collected = model.collectedBreeds.count
        let cats = model.cats
        return VStack(spacing: 10) {
            FeaturedModeCard(style: .cats, title: "Cat Puzzle", subtitle: Text("One cat per color, row and column"), compact: compact) {
                Text("Level \(min(cats.solvedCount + 1, max(cats.levels.count, 1)))")
            } action: {
                router.push(.catHub)
            }
            .frame(height: cardHeight)
            .accessibilityIdentifier("home.mode.cats")

            HStack(spacing: 10) {
                ModeCard(style: .daily, title: "Daily Puzzle", compact: compact) {
                    if model.isTodaysPuzzleSolved {
                        Text("Solved! A new one tomorrow.")
                    } else if streak > 0 {
                        Text("\(streak)-day streak")
                    } else {
                        Text("Today's nonogram")
                    }
                } action: {
                    router.push(.daily)
                }
                .accessibilityIdentifier("home.daily")

                ModeCard(style: .collection, title: "Card Collection", compact: compact) {
                    Text("\(collected)/\(model.breeds.count) breeds")
                } action: {
                    router.push(.collectionHub)
                }
                .accessibilityIdentifier("home.mode.collection")
            }
            .frame(height: cardHeight)
        }
    }

    /// Daha önce oynamış oyuncu (güncelleme yapan): çözülmüş bulmaca ya da atlanmış eğitim.
    private var isReturningPlayer: Bool {
        #if DEBUG
        if DemoContent.isEnabled || ProcessInfo.processInfo.arguments.contains("-disableAds") { return false }
        #endif
        return !model.progress.completedIDs.isEmpty || model.isTutorialSkipped
    }

    private var canOfferReminder: Bool {
        #if DEBUG
        // Ekran görüntüsü çekimini bölmesin
        if DemoContent.isEnabled { return false }
        #endif
        return reminders.shouldOffer(solvedCount: model.completedCount)
    }
}

/// Karşılama alanı: solda logo, sağda ayarlar, ortada oyunun adı. "home-hero" çizimi
/// eklendiğinde arkada pencere önü sahnesi görünür; yoksa alan kompakt kalır.
@MainActor
struct HomeHero: View {
    @Environment(\.appTheme) private var theme
    let compact: Bool
    /// Durum çubuğunun yüksekliği; çizim bu kadar yukarı taşar.
    var topInset: CGFloat = 0
    let openSettings: () -> Void

    /// Koyu temada gece çizimi (varsa).
    private var artName: String {
        theme.isDark && Illustration.exists("home-hero-dark") ? "home-hero-dark" : "home-hero"
    }

    private var hasArt: Bool { Illustration.exists(artName) }

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            HStack {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .accessibilityHidden(true)
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                        .background(Circle().fill(theme.surface.opacity(0.92)))
                        .shadow(color: theme.cardShadow, radius: 4, y: 2)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Settings"))
                .accessibilityIdentifier("home.settings")
            }
            VStack(spacing: 2) {
                Text(verbatim: "Catgrid Collection")
                    .font(.system(size: compact ? 26 : 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Nonogram · Cat Puzzle · Cards")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, hasArt ? 6 : 0)
            .background {
                // Çizimin üstünde okunabilsin
                if hasArt {
                    Capsule().fill(theme.background.opacity(0.75)).blur(radius: 8)
                }
            }
            if hasArt {
                // Uyuyan kedilere yer: sabit yükseklik (boş alanı esneyip doldurmasın)
                Color.clear.frame(height: compact ? 64 : 88)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, hasArt ? 0 : 2)
        .background {
            if hasArt {
                // Çizim durum çubuğunun arkasına kadar uzanır (hangi düzen seçilirse seçilsin,
                // kaydırılabilir olanda da): alan, ölçülen durum çubuğu kadar yukarı büyütülür
                Color.clear
                    .padding(.top, -(topInset + 8))
                    .overlay(alignment: .bottom) {
                        IllustrationView(name: artName, contentMode: .fill)
                    }
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

/// Ana sayfanın büyük kartı (Kedi Bulmaca): solda başlık, açıklama ve durum, sağda büyük çizim.
@MainActor
struct FeaturedModeCard<Caption: View>: View {
    @Environment(\.appTheme) private var theme
    let style: ModeStyle
    let title: LocalizedStringKey
    let subtitle: Text
    var compact = false
    @ViewBuilder let caption: () -> Caption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    // İkon başlıkla aynı satırda: kart, alttaki kartlarla aynı yükseklikte sığar
                    HStack(spacing: 6) {
                        ModeIcon(style: style, size: compact ? 28 : 32)
                        Text(title)
                            .font(.system(size: compact ? 21 : 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(style.ink(theme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    subtitle
                        .font(.caption.weight(.medium))
                        .foregroundStyle(style.ink(theme).opacity(0.8))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        caption()
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(style.tint(theme)))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(style.tint(theme)))
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Yumakla oynayan kedi videosu (varsa), yoksa tek parça çizim; büyük ve kartın
                // sağ alt köşesine yaslı
                Group {
                    if LoopingCatAnimation.isAvailable(style.animation) {
                        LoopingCatView(name: style.animation)
                    } else {
                        CatIllustration(rig: style == .cats ? .yarnCat : nil, fallback: style.illustration, isLively: true)
                    }
                }
                .frame(width: compact ? 160 : 190)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.trailing, -8)
                .padding(.bottom, -8)
            }
            .padding(compact ? 12 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(style.background(theme)))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(theme.isDark ? 0.06 : 0.7), lineWidth: 1)
            )
            .shadow(color: style.tint(theme).opacity(theme.isDark ? 0 : 0.2), radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Ana sayfadaki üç oyun modundan biri: renkli kart, ikon, başlık, isteğe bağlı çizim
/// ve altta kısa durum bilgisiyle ok. Kartın tamamı tıklanır.
@MainActor
struct ModeCard<Caption: View>: View {
    @Environment(\.appTheme) private var theme
    let style: ModeStyle
    let title: LocalizedStringKey
    var compact = false
    @ViewBuilder let caption: () -> Caption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                // Üstte ikon ve çizim yan yana: kart, büyük kartla aynı yükseklikte kalır
                HStack(alignment: .top, spacing: 4) {
                    ModeIcon(style: style, size: compact ? 30 : 36)
                    Group {
                        // Hareketli kedi (videodan), yoksa sabit çizim
                        if LoopingCatAnimation.isAvailable(style.animation) {
                            LoopingCatView(name: style.animation)
                        } else {
                            IllustrationView(name: style.illustration)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: compact ? 44 : 58)
                }
                Text(title)
                    .font((compact ? Font.subheadline : .headline).bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(style.ink(theme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 4) {
                    caption()
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style.ink(theme).opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(style.tint(theme)))
                }
            }
            .padding(compact ? 9 : 11)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(style.background(theme)))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(theme.isDark ? 0.06 : 0.7), lineWidth: 1)
            )
            .shadow(color: style.tint(theme).opacity(theme.isDark ? 0 : 0.16), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Oyun kartlarının altındaki kısa ilerleme şeridi: günlük seri, toplanan tür, son Kedi Bulmaca bölümü.
@MainActor
struct HomeStatsStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    var body: some View {
        let cats = model.cats
        let lastLevel = cats.lastPlayedLevelID.flatMap(cats.level(withID:)).map(cats.number(of:))
        HStack(spacing: 0) {
            item(icon: "flame.fill", tint: Color(hex: "#F06A5A"), value: Text(verbatim: "\(model.dailyStreak)"), label: "Daily streak")
            divider
            item(
                icon: ModeStyle.collection.icon, tint: ModeStyle.collection.tint(theme),
                value: Text(verbatim: "\(model.collectedBreeds.count)/\(model.breeds.count)"), label: "Collection"
            )
            divider
            item(
                icon: ModeStyle.cats.icon, tint: ModeStyle.cats.tint(theme),
                value: Text(verbatim: lastLevel.map { "\($0)" } ?? "–"), label: "Last level"
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .card(cornerRadius: 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(width: 1, height: 28)
    }

    private func item(icon: String, tint: Color, value: Text, label: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                value
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// "Koleksiyonumdan Kediler": toplanan türler önce (en yenisi başta), sonra henüz
/// tanışılmayanlar soluk ve kilitli. Toplanan karta dokununca kart açılır; diğerleri türün sayfasına gider.
@MainActor
struct HomeCollectionPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let tileWidth: CGFloat
    let showCard: (CardSelection) -> Void

    var body: some View {
        let collected = Array(model.collectedBreeds.reversed())
        let others = model.breeds.filter { !model.isCollected($0) }
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Cats from My Collection", actionTitle: "All", actionIdentifier: "home.collection") {
                router.push(.collection)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(collected + others) { chapter in
                        let isCollected = model.isCollected(chapter)
                        let isGolden = model.isGoldenCollected(chapter)
                        Button {
                            if isCollected {
                                showCard(CardSelection(chapter: chapter, isGolden: isGolden))
                            } else {
                                router.push(.chapter(id: chapter.id))
                            }
                        } label: {
                            BreedTile(chapter: chapter, isCollected: isCollected, isGolden: isGolden, isLocked: !isCollected)
                                .frame(width: tileWidth)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            // Sıkışık ekranda kartlar ezilmesin: portre (kare) + ad + kenar boşlukları
            .frame(height: tileWidth + 42)
        }
    }
}

/// Kullanıcının hazırladığı tür görselleri (Assets: Cards/card-<tür>, Portraits/portrait-<tür>).
/// Yoksa piksel portreye dönülür.
enum BreedPhoto {
    static func portrait(_ breedID: String) -> UIImage? {
        UIImage(named: "portrait-\(breedID)")
    }

    static func card(_ breedID: String) -> UIImage? {
        UIImage(named: "card-\(breedID)")
    }
}

/// Bölümün vurgu renginde kedi rozeti.
@MainActor
struct ChapterBadge: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    var size: CGFloat = 48

    var body: some View {
        let tint = chapter.accentColor.map { Color($0) } ?? theme.accent
        ZStack {
            Circle().fill(tint.opacity(0.3).gradient)
            if let photo = BreedPhoto.portrait(chapter.id) {
                // Türün portre fotoğrafı (yuvarlak)
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(tint.opacity(0.6), lineWidth: max(size * 0.03, 1)))
            } else if let portrait = chapter.portrait {
                // Türün piksel portresi
                ArtworkThumbnail(artwork: portrait)
                    .padding(size * 0.14)
            } else {
                Image(systemName: chapter.kind == .tutorial ? "graduationcap.fill" : "cat.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}


/// Premium oyuncuların ana sayfasının altındaki kedi sahnesi (açık/koyu tema).
@MainActor
struct PremiumHomeArt: View {
    @Environment(\.appTheme) private var theme

    private var name: String {
        theme.isDark && Illustration.exists("home-premium-dark") ? "home-premium-dark" : "home-premium"
    }

    var body: some View {
        if Illustration.exists(name) {
            Color.clear
                .aspectRatio(1600.0 / 460.0, contentMode: .fit)
                .overlay {
                    IllustrationView(name: name, contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: theme.cardShadow, radius: 8, y: 3)
                .accessibilityHidden(true)
        }
    }
}
