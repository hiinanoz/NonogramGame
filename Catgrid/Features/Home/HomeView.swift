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
        }
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
            HomeHero(compact: compact, openSettings: openSettings)
            VStack(spacing: compact ? 10 : 14) {
                modeCards(compact: compact)
                HomeStatsStrip()
                HomeCollectionPreview(tileWidth: compact ? 78 : 92) { shownCard = $0 }
                if !store.isPremium {
                    PremiumBanner { isShowingPaywall = true }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, compact ? 6 : 12)
    }

    private func modeCards(compact: Bool) -> some View {
        let streak = model.dailyStreak
        let collected = model.collectedBreeds.count
        let cats = model.cats
        return HStack(spacing: 10) {
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

            ModeCard(style: .collection, title: "Cat Card Collection", compact: compact) {
                Text("\(collected)/\(model.breeds.count) breeds")
            } action: {
                router.push(.collectionHub)
            }
            .accessibilityIdentifier("home.mode.collection")

            ModeCard(style: .cats, title: "Cat Puzzle", compact: compact) {
                Text("Level \(min(cats.solvedCount + 1, max(cats.levels.count, 1)))")
            } action: {
                router.push(.catHub)
            }
            .accessibilityIdentifier("home.mode.cats")
        }
        .fixedSize(horizontal: false, vertical: true)
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
    let openSettings: () -> Void

    private var hasArt: Bool { Illustration.exists("home-hero") }

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
                Spacer(minLength: compact ? 70 : 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, hasArt ? 0 : 2)
        .background(alignment: .bottom) {
            if hasArt {
                IllustrationView(name: "home-hero", contentMode: .fill)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0.75), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea(edges: .top)
            }
        }
        .clipped()
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
            VStack(spacing: compact ? 6 : 8) {
                ModeIcon(style: style, size: compact ? 32 : 40)
                Text(title)
                    .font((compact ? Font.subheadline : .headline).bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(style.ink(theme))
                    .frame(maxWidth: .infinity)
                IllustrationView(name: style.illustration)
                    .frame(maxHeight: compact ? 56 : 84)
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

