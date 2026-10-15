import NonogramKit
import SwiftUI

/// Kedi Bulmaca'nın giriş ekranı: bir sezonun (Bahar Bahçesi, Yaz Sahili, Sonbahar Ormanı,
/// Kış Masalı) serüven haritası. Ekran oyuncunun kaldığı sezonla açılır; üstteki oklarla diğer
/// sezonlara geçilir. Bölümler sezonun manzarası üstünde kıvrılan bir yolda sıralanır.
/// Altta sıradaki bölümün kartı ve "Oyna".
@MainActor
struct CatHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    /// Oyuncunun seçtiği sezon; `nil` ise kalınan bölümün sezonu.
    @State private var selectedSeason: CatTheme?

    var body: some View {
        let cats = model.cats
        let current = cats.resumableLevel ?? cats.nextLevel
        let season = selectedSeason ?? current.map { CatTheme.theme(forSize: $0.size) } ?? .spring
        let levels = cats.levels.filter { season.sizes.contains($0.size) }
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { offset, level in
                        CatMapRow(
                            level: level,
                            index: offset,
                            isFirstInTheme: offset == 0,
                            isLastInTheme: offset == levels.count - 1,
                            isCurrent: level.id == current?.id
                        ) {
                            router.push(.catGame(levelID: level.id))
                        }
                        .id(level.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                cats.refillIfNeeded(isPremium: store.isPremium, today: model.today)
                if let current, season.sizes.contains(current.size) {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
            .onChange(of: season) { _, newSeason in
                if let current, newSeason.sizes.contains(current.size) {
                    proxy.scrollTo(current.id, anchor: .center)
                } else if let first = levels.first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
        .background {
            // Sezonun manzarası tam ekran; yoksa sezonun renkleri
            ZStack {
                LinearGradient(colors: season.colors(theme), startPoint: .top, endPoint: .bottom)
                if Illustration.exists(season.mapBackground) {
                    Color.clear
                        .overlay { IllustrationView(name: season.mapBackground, contentMode: .fill) }
                        .clipped()
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: season)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header(season: season) }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer(current: current) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        // Harita başlık çubuğunun arkasına kadar uzanır; geri tuşu ve başlık görselin
        // üstünde okunabilsin diye beyaz kapsül içinde
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.92)))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("cat.hub.back")
            }
            ToolbarItem(placement: .principal) {
                Text(BadgeMode.cats.title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
    }

    /// Sezon seçici, sezonun ilerlemesi ve kalan yardım hakları.
    private func header(season: CatTheme) -> some View {
        let cats = model.cats
        let levels = cats.levels.filter { season.sizes.contains($0.size) }
        let solved = levels.filter { cats.isSolved($0) }.count
        let tint = season.tint(theme)
        let all = CatTheme.allCases
        let index = all.firstIndex(of: season) ?? 0
        let isUnlocked = cats.isSizeUnlocked(levels.map(\.size).min() ?? season.sizes.lowerBound)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                seasonArrow("chevron.left", enabled: index > 0) { selectedSeason = all[index - 1] }
                    .accessibilityLabel(Text("Previous season"))
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: season.icon)
                            .foregroundStyle(tint)
                        Text(verbatim: "\(season.rawValue). ") + Text(season.title)
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    Text(verbatim: "\(season.sizes.lowerBound)×\(season.sizes.lowerBound) – \(season.sizes.upperBound)×\(season.sizes.upperBound)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                seasonArrow("chevron.right", enabled: index < all.count - 1) { selectedSeason = all[index + 1] }
                    .accessibilityLabel(Text("Next season"))
            }
            HStack(spacing: 10) {
                Text(verbatim: "\(solved)/\(levels.count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(tint)
                ProgressBar(value: levels.isEmpty ? 0 : Double(solved) / Double(levels.count), tint: tint)
                chip(icon: "cat.fill", value: cats.findCharges, tint: theme.accent)
                    .accessibilityLabel(Text("Cat Finder: \(cats.findCharges)"))
                chip(icon: "questionmark", value: cats.markCharges, tint: Color(red: 0.55, green: 0.42, blue: 0.82))
                    .accessibilityLabel(Text("Hints: \(cats.markCharges)"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func seasonArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary.opacity(0.3))
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.surface.opacity(enabled ? 0.9 : 0.4)))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }

    private func chip(icon: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(verbatim: "\(value)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(theme.surface))
    }

    /// Sıradaki bölümün kartı ve kısa yollar (Tüm Bölümler, İstatistikler, Rozetlerim).
    private func footer(current: CatLevel?) -> some View {
        let cats = model.cats
        let mode = BadgeMode.cats
        let badgeCount = Badge.all(in: mode).filter { model.badges.isEarned($0) }.count
        return VStack(spacing: 10) {
            if let level = current {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        CatLevelPreview(level: level)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Level \(cats.number(of: level))")
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            Text(verbatim: "\(level.size)×\(level.size) · ") + Text(level.difficultyTitle)
                            HStack(spacing: 4) {
                                Image(systemName: CatTheme.theme(forSize: level.size).icon)
                                Text(CatTheme.theme(forSize: level.size).title)
                            }
                            .font(.caption)
                            .foregroundStyle(CatTheme.theme(forSize: level.size).tint(theme))
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    Button {
                        router.push(.catGame(levelID: level.id))
                    } label: {
                        Label(cats.hasSavedGame(level) ? "Resume" : "Play", systemImage: cats.hasSavedGame(level) ? "arrow.clockwise" : "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("hub.continue")
                }
                .padding(14)
                .card(cornerRadius: 22)
            } else {
                AllDoneCard(message: "More cats are on their way.")
            }
            HStack(spacing: 8) {
                shortcut(icon: "map.fill", title: "All Levels", detail: Text(verbatim: "\(cats.solvedCount)/\(cats.levels.count)"), tint: ModeStyle.collection.tint(theme)) {
                    router.push(.catLevels)
                }
                .accessibilityIdentifier("cat.hub.levels")
                shortcut(icon: "chart.bar.fill", title: "Statistics", detail: nil, tint: ModeStyle.daily.tint(theme)) {
                    router.push(.catStats)
                }
                shortcut(icon: "medal.fill", title: "My Badges", detail: Text(verbatim: "\(badgeCount)/\(Badge.all(in: mode).count)"), tint: Gold.deep) {
                    router.push(.badges(mode))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [theme.background.opacity(0), theme.background, theme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func shortcut(icon: String, title: LocalizedStringKey, detail: Text?, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let detail {
                    detail
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.vertical, 6)
            .card(cornerRadius: 16)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Temanın başında afiş: başlık, boyut aralığı, ilerleme; kilitliyse nasıl açılacağı.
@MainActor
struct CatMapThemeHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    let catTheme: CatTheme
    let levels: [CatLevel]

    var body: some View {
        let cats = model.cats
        let solved = levels.filter { cats.isSolved($0) }.count
        let firstSize = levels.map(\.size).min() ?? catTheme.sizes.lowerBound
        let isUnlocked = cats.isSizeUnlocked(firstSize)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: catTheme.icon)
                        .foregroundStyle(catTheme.tint(theme))
                    Text(verbatim: "\(catTheme.rawValue). ") + Text(catTheme.title)
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                Text(verbatim: "\(solved)/\(levels.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }
            .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width * 0.5 }
            Spacer(minLength: 0)
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(catTheme.tint(theme))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(theme.isDark ? 0.1 : 0.75)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background {
            LinearGradient(colors: catTheme.colors(theme), startPoint: .leading, endPoint: .trailing)
                .overlay {
                    Color.clear
                        .overlay(alignment: .trailing) {
                            IllustrationView(name: catTheme.illustration, contentMode: .fill)
                        }
                        .clipped()
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black, location: 0.7)], startPoint: .leading, endPoint: .trailing))
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .shadow(color: catTheme.tint(theme).opacity(theme.isDark ? 0 : 0.18), radius: 8, y: 4)
        .saturation(isUnlocked ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

/// Haritada tek bölüm: bölüm düğmesi ve bir sonraki düğmeye uzanan taş yol. Düğmeler sağa
/// sola kıvrılan bir çizgide durur; yol iki düğme arasında yumuşak bir S eğrisiyle akar ve
/// satırın dışına taşarak sonraki satırın düğmesinin altına girer (kesintisiz görünür).
@MainActor
struct CatMapRow: View {
    @Environment(\.appTheme) private var theme
    let level: CatLevel
    let index: Int
    let isFirstInTheme: Bool
    let isLastInTheme: Bool
    let isCurrent: Bool
    let action: () -> Void

    static let height: CGFloat = 104

    /// Düğmenin yatay konumu (genişliğin oranı): yumuşak bir dalga.
    static func x(_ index: Int) -> CGFloat {
        0.5 + 0.27 * sin(Double(index) * 0.85)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let h = Self.height
            let start = CGPoint(x: Self.x(index) * width, y: h / 2)
            let end = CGPoint(x: Self.x(index + 1) * width, y: h / 2 + h)
            ZStack(alignment: .topLeading) {
                if !isLastInTheme {
                    CatMapPath(start: start, end: end)
                }
                CatMapNode(level: level, isCurrent: isCurrent, action: action)
                    .position(start)
            }
        }
        .frame(height: Self.height)
    }
}

/// İki düğme arasındaki taş yol: koyu kenar, açık kum dolgu ve ortada basamak taşları.
struct CatMapPath: View {
    let start: CGPoint
    let end: CGPoint

    private var path: Path {
        Path { path in
            let dy = end.y - start.y
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: start.y + dy * 0.55),
                control2: CGPoint(x: end.x, y: end.y - dy * 0.55)
            )
        }
    }

    var body: some View {
        ZStack {
            path.stroke(Color(hex: "#C9AE84").opacity(0.55), style: StrokeStyle(lineWidth: 32, lineCap: .round))
            path.stroke(Color(hex: "#F6E8CC"), style: StrokeStyle(lineWidth: 25, lineCap: .round))
            path.stroke(Color(hex: "#E2CDA4"), style: StrokeStyle(lineWidth: 9, lineCap: .round, dash: [1, 16]))
        }
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension CatLevelResult {
    /// 3 üzerinden yıldız: hatasız ve ipucusuz 3, en fazla bir hata 2, gerisi 1.
    var stars: Int {
        if flawless { return 3 }
        return fewestMistakes <= 1 ? 2 : 1
    }
}

/// Bölüm düğmesi: içinde bölüm numarası. Çözülenler sezon renginde ve üstünde 3 üzerinden
/// yıldızlar; sıradaki büyük, beyaz ve nabız gibi atan halkalı; kilitliler soluk ve kilitli.
@MainActor
struct CatMapNode: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: CatLevel
    let isCurrent: Bool
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        let cats = model.cats
        let number = cats.number(of: level)
        let isUnlocked = cats.isUnlocked(level)
        let result = cats.results[level.id]
        let tint = CatTheme.theme(forSize: level.size).tint(theme)
        let size: CGFloat = isCurrent ? 66 : 54
        Button(action: action) {
            VStack(spacing: 2) {
                if let result {
                    stars(result.stars)
                }
                ZStack {
                    Circle()
                        .fill(fill(isUnlocked: isUnlocked, isSolved: result != nil, tint: tint))
                    Circle()
                        .strokeBorder(.white.opacity(isUnlocked ? 0.95 : 0.6), lineWidth: isCurrent ? 4 : 3)
                    if isUnlocked {
                        Text(verbatim: "\(number)")
                            .font(.system(size: isCurrent ? 24 : 19, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(result != nil ? .white : tint)
                            .minimumScaleFactor(0.6)
                            .padding(6)
                    } else {
                        VStack(spacing: 0) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(verbatim: "\(number)")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        .foregroundStyle(Color(hex: "#7D7488"))
                    }
                }
                .frame(width: size, height: size)
                .background {
                    if isCurrent {
                        Circle()
                            .fill(.white.opacity(0.7))
                            .scaleEffect(glow ? 1.45 : 1.08)
                            .opacity(glow ? 0 : 0.9)
                    }
                }
                .overlay(alignment: .top) {
                    if isCurrent {
                        // "Buradasın" patisi
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(tint))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(y: -22)
                    }
                }
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isUnlocked)
        .accessibilityLabel(Text("Level \(number)"))
        .accessibilityValue(result.map { Text("\($0.stars) of 3 stars") } ?? (isUnlocked ? Text(verbatim: "") : Text("Locked")))
        .onAppear {
            guard isCurrent, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { glow = true }
        }
    }

    private func fill(isUnlocked: Bool, isSolved: Bool, tint: Color) -> AnyShapeStyle {
        if isSolved {
            return AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
        }
        if isUnlocked {
            return AnyShapeStyle(Color.white)
        }
        return AnyShapeStyle(Color(hex: "#E9E4EE").opacity(0.92))
    }

    /// Düğmenin üstünde 3 yıldız (kazanılanlar altın).
    private func stars(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: index == 1 ? 14 : 11, weight: .bold))
                    .foregroundStyle(index < count ? Gold.bright : Color.white.opacity(0.75))
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .offset(y: index == 1 ? -2 : 0)
            }
        }
    }
}

/// Bölümün renk bölgelerinden küçük önizleme (kediler gizli).
struct CatLevelPreview: View {
    let level: CatLevel

    var body: some View {
        Canvas { context, size in
            let n = level.size
            let cell = min(size.width, size.height) / CGFloat(n)
            for row in 0..<n {
                for column in 0..<n {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    let region = level.region(at: GridPosition(row: row, column: column))
                    context.fill(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(CatPalette.color(region)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 2))
        .accessibilityHidden(true)
    }
}

extension CatTheme {
    /// Serüven haritasının dikey zemin görseli (Assets'te varsa).
    var mapBackground: String { "cat-map-\(rawValue)" }
}
