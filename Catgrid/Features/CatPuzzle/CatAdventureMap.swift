import NonogramKit
import SwiftUI

/// Kedi Bulmaca'nın giriş ekranı: bölümler bir serüven haritasında, kıvrılan bir yol üzerinde
/// sıralanır. Çözülenler renkli, sıradaki büyük ve parlak, kilitliler soluk. Her temanın
/// (Bahar Bahçesi, Yaz Sahili…) başında afişi durur. Altta sıradaki bölümün kartı ve "Oyna".
@MainActor
struct CatHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme

    var body: some View {
        let cats = model.cats
        let current = cats.resumableLevel ?? cats.nextLevel
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(cats.levels.enumerated()), id: \.element.id) { offset, level in
                        let catTheme = CatTheme.theme(forSize: level.size)
                        if offset == 0 || CatTheme.theme(forSize: cats.levels[offset - 1].size) != catTheme {
                            CatMapThemeHeader(catTheme: catTheme, levels: cats.levels.filter { catTheme.sizes.contains($0.size) })
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        CatMapRow(
                            level: level,
                            index: offset,
                            isFirstInTheme: offset == 0 || CatTheme.theme(forSize: cats.levels[offset - 1].size) != catTheme,
                            isLastInTheme: offset == cats.levels.count - 1 || CatTheme.theme(forSize: cats.levels[offset + 1].size) != catTheme,
                            isCurrent: level.id == current?.id
                        ) {
                            router.push(.catGame(levelID: level.id))
                        }
                        .id(level.id)
                    }
                }
                .padding(.bottom, 12)
            }
            .onAppear {
                cats.refillIfNeeded(isPremium: store.isPremium, today: model.today)
                if let current {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
        }
        .background {
            // Sıradaki bölümün temasının harita zemini (varsa); yoksa düz tema renkleri
            if let current, Illustration.exists(CatTheme.theme(forSize: current.size).mapBackground) {
                Color.clear
                    .overlay { IllustrationView(name: CatTheme.theme(forSize: current.size).mapBackground, contentMode: .fill) }
                    .clipped()
                    .ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer(current: current) }
        .themedScreen()
        .screenTitle(BadgeMode.cats.title)
    }

    /// İlerleme ve kalan yardım hakları.
    private var header: some View {
        let cats = model.cats
        let tint = ModeStyle.cats.tint(theme)
        return HStack(spacing: 10) {
            Text(verbatim: "\(cats.solvedCount)/\(cats.levels.count)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(tint)
            ProgressBar(value: cats.levels.isEmpty ? 0 : Double(cats.solvedCount) / Double(cats.levels.count), tint: tint)
            chip(icon: "cat.fill", value: cats.findCharges, tint: theme.accent)
                .accessibilityLabel(Text("Cat Finder: \(cats.findCharges)"))
            chip(icon: "questionmark", value: cats.markCharges, tint: Color(red: 0.55, green: 0.42, blue: 0.82))
                .accessibilityLabel(Text("Hints: \(cats.markCharges)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.background.opacity(0.94))
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

/// Haritada tek bölüm: yolun bir parçası ve bölüm düğmesi. Düğmeler sağa sola kıvrılan bir
/// çizgide durur; yol her satırda bir önceki ve sonraki düğmeye bağlanır.
@MainActor
struct CatMapRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    let level: CatLevel
    let index: Int
    let isFirstInTheme: Bool
    let isLastInTheme: Bool
    let isCurrent: Bool
    let action: () -> Void

    static let height: CGFloat = 96

    /// Düğmenin yatay konumu (genişliğin oranı): yumuşak bir dalga.
    static func x(_ index: Int) -> CGFloat {
        0.5 + 0.28 * sin(Double(index) * 0.9)
    }

    var body: some View {
        let catTheme = CatTheme.theme(forSize: level.size)
        GeometryReader { proxy in
            let width = proxy.size.width
            let h = Self.height
            let x = Self.x(index) * width
            ZStack(alignment: .topLeading) {
                // Yol: önceki düğmeyle arası (üst yarı) ve sonrakiyle arası (alt yarı)
                Path { path in
                    let top = CGPoint(x: (Self.x(index - 1) + Self.x(index)) / 2 * width, y: 0)
                    let mid = CGPoint(x: x, y: h / 2)
                    let bottom = CGPoint(x: (Self.x(index) + Self.x(index + 1)) / 2 * width, y: h)
                    path.move(to: isFirstInTheme ? mid : top)
                    if !isFirstInTheme {
                        path.addQuadCurve(to: mid, control: CGPoint(x: x, y: h * 0.2))
                    }
                    if !isLastInTheme {
                        path.addQuadCurve(to: bottom, control: CGPoint(x: x, y: h * 0.8))
                    }
                }
                // Zemin görselinin üstünde kum rengi taş yol, düz zeminde temanın rengi
                .stroke(
                    Illustration.exists(catTheme.mapBackground)
                        ? Color(hex: "#F4E4C6").opacity(0.95)
                        : catTheme.tint(theme).opacity(theme.isDark ? 0.35 : 0.28),
                    style: StrokeStyle(lineWidth: Illustration.exists(catTheme.mapBackground) ? 18 : 14, lineCap: .round)
                )
                .overlay {
                    Path { path in
                        let top = CGPoint(x: (Self.x(index - 1) + Self.x(index)) / 2 * width, y: 0)
                        let mid = CGPoint(x: x, y: h / 2)
                        let bottom = CGPoint(x: (Self.x(index) + Self.x(index + 1)) / 2 * width, y: h)
                        path.move(to: isFirstInTheme ? mid : top)
                        if !isFirstInTheme { path.addQuadCurve(to: mid, control: CGPoint(x: x, y: h * 0.2)) }
                        if !isLastInTheme { path.addQuadCurve(to: bottom, control: CGPoint(x: x, y: h * 0.8)) }
                    }
                    .stroke(.white.opacity(theme.isDark ? 0.15 : 0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
                }
                CatMapNode(level: level, isCurrent: isCurrent, action: action)
                    .position(x: x, y: h / 2)
            }
        }
        .frame(height: Self.height)
        .background {
            if !Illustration.exists(catTheme.mapBackground) {
                LinearGradient(colors: catTheme.colors(theme).map { $0.opacity(0.45) }, startPoint: .leading, endPoint: .trailing)
            }
        }
    }
}

/// Bölüm düğmesi: çözülen renkli ve taçlı (hatasızsa), sıradaki büyük ve parlak, kilitli soluk.
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
        let size: CGFloat = isCurrent ? 70 : 56
        Button(action: action) {
            ZStack(alignment: .bottom) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? theme.surface : theme.surfaceMuted)
                    portrait
                        .clipShape(Circle())
                        .padding(4)
                        .saturation(isUnlocked ? 1 : 0)
                        .opacity(isUnlocked ? 1 : 0.45)
                    Circle()
                        .strokeBorder(isCurrent ? tint : (result != nil ? tint.opacity(0.6) : theme.separator), lineWidth: isCurrent ? 4 : 2.5)
                }
                .frame(width: size, height: size)
                .background {
                    if isCurrent {
                        Circle()
                            .fill(tint.opacity(0.35))
                            .scaleEffect(glow ? 1.35 : 1.1)
                            .opacity(glow ? 0 : 0.8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(theme.textSecondary))
                    } else if result?.flawless == true {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Gold.deep)
                            .padding(4)
                            .background(Circle().fill(Gold.light))
                    } else if result != nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(tint))
                    }
                }
                Text(verbatim: "\(number)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(isCurrent ? .white : theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(isCurrent ? tint : theme.surface))
                    .shadow(color: theme.cardShadow, radius: 2, y: 1)
                    .offset(y: 12)
            }
            .shadow(color: theme.cardShadow, radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isUnlocked)
        .accessibilityLabel(Text("Level \(number)"))
        .accessibilityValue(result != nil ? Text("Solved") : (isUnlocked ? Text(verbatim: "") : Text("Locked")))
        .onAppear {
            guard isCurrent, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { glow = true }
        }
    }

    /// Bölümün ilk kedisinin portresi; yoksa kedi simgesi.
    @ViewBuilder
    private var portrait: some View {
        if let breed = level.breeds.first, let photo = BreedPhoto.portrait(breed) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "cat.fill")
                .font(.title2)
                .foregroundStyle(CatTheme.theme(forSize: level.size).tint(theme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
