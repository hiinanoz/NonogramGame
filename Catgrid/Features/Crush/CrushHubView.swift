import NonogramKit
import SwiftUI

/// Miyav Crush binaları (75'er bölüm): her macera bir kedi binası. Yeni bölümler yeni binalarla eklenir.
struct CrushEpisode: Hashable {
    let index: Int

    var title: LocalizedStringResource {
        switch index {
        case 0: "Yarn Apartments"
        case 1: "Moonlight Mansion"
        case 2: "Seaside Residence"
        default: "Snowy Paw Towers"
        }
    }

    var icon: String {
        switch index {
        case 0: "building.2.fill"
        case 1: "moon.stars.fill"
        case 2: "beach.umbrella.fill"
        default: "snowflake"
        }
    }

    func colors(_ theme: AppTheme) -> [Color] {
        switch (index, theme.isDark) {
        case (0, false): [Color(hex: "#E3F4FF"), Color(hex: "#CDEBDA")]
        case (1, false): [Color(hex: "#FFF1DC"), Color(hex: "#FFD9C2")]
        case (2, false): [Color(hex: "#F1E8FF"), Color(hex: "#DCCFF7")]
        case (_, false): [Color(hex: "#FFE9EF"), Color(hex: "#F6D6C9")]
        case (0, true): [Color(hex: "#1F3340"), Color(hex: "#1B2E27")]
        case (1, true): [Color(hex: "#3D2F22"), Color(hex: "#3A2620")]
        case (2, true): [Color(hex: "#2D2640"), Color(hex: "#251F36")]
        default: [Color(hex: "#3A2630"), Color(hex: "#33241F")]
        }
    }

    func tint(_ theme: AppTheme) -> Color {
        switch index {
        case 0: CrushColor.yarn.tint
        case 1: CrushColor.paw.tint
        case 2: CrushColor.mouse.tint
        default: CrushColor.wand.tint
        }
    }

    /// Haritanın zemin görseli (Assets'te varsa).
    var mapBackground: String { "crush-map-\(index + 1)" }
}

/// Miyav Crush'ın giriş ekranı: maceranın haritası, sıradaki bölüm, güçlendiriciler, yıldız
/// sandığı ve rozetler.
@MainActor
struct CrushHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var selectedEpisode: Int?
    @State private var isShowingBadges = false

    /// Oyuncunun dokunarak seçtiği bölüm; `nil` ise binadaki sıradaki bölüm. Modelde tutulur:
    /// oyundan dönünce seçim ve kule konumu korunur.
    private var selectedLevelID: String? {
        get { model.crush.selectedTowerLevelID }
        nonmutating set { model.crush.selectedTowerLevelID = newValue }
    }
    /// Kilitli kata dokununca kısa uyarı.
    @State private var lockedNote: Int?

    var body: some View {
        let crush = model.crush
        let current = crush.currentLevel
        let episodeIndex = selectedEpisode ?? current.map { crush.episode(of: $0) } ?? 0
        let episode = CrushEpisode(index: episodeIndex)
        let levels = crush.catalog.levels(in: episodeIndex)
        let selected = selectedLevel(in: levels, current: current)
        // Kule açılışta ve macera değişince sıradaki bölüme (yoksa son açık bölüme) kayar
        let currentInEpisode: String? = levels.first(where: { $0.id == current?.id })?.id
        let restored: String? = levels.first(where: { $0.id == selectedLevelID && crush.isUnlocked($0) })?.id
        let focusID: String? = restored ?? currentInEpisode ?? levels.last(where: { crush.isUnlocked($0) })?.id
        Group {
            if CatTowerFlag.isTowerEnabled {
                CatTowerLevelMap(
                    floors: crush.towerFloors(episode: episodeIndex),
                    episode: episode,
                    selectedID: selected?.id,
                    focusID: focusID,
                    onSelect: { floor in
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { selectedLevelID = floor.id }
                    },
                    onPlay: { floor in router.push(.crushGame(levelID: floor.id)) },
                    onLocked: showLockedNote
                )
            } else {
                classicMap(levels: levels, current: current, episode: episode, episodeIndex: episodeIndex)
            }
        }
        .overlay(alignment: .center) {
            if let lockedNote {
                Label {
                    Text("Win level \(lockedNote) to open this floor")
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(theme.surface).shadow(color: .black.opacity(0.15), radius: 8, y: 3))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .allowsHitTesting(false)
            }
        }
        .onChange(of: episodeIndex) { _, _ in selectedLevelID = nil }
        .safeAreaInset(edge: .top, spacing: 0) { header(episode: episode, levels: levels) }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer(current: selected) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
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
                .accessibilityIdentifier("crush.hub.back")
            }
            ToolbarItem(placement: .principal) {
                Text("Meow Crush")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.92)))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
        .sheet(isPresented: $isShowingBadges) {
            CrushBadgesSheet()
                .appChrome()
        }
    }

    /// Alt panelde gösterilen bölüm: seçilen; yoksa bu maceradaki sıradaki, o da yoksa maceranın
    /// son açık bölümü.
    private func selectedLevel(in levels: [CrushLevel], current: CrushLevel?) -> CrushLevel? {
        let crush = model.crush
        if let id = selectedLevelID, let level = levels.first(where: { $0.id == id }), crush.isUnlocked(level) {
            return level
        }
        if let current, levels.contains(where: { $0.id == current.id }) { return current }
        return levels.last(where: { crush.isUnlocked($0) }) ?? levels.first
    }

    private func showLockedNote(_ floor: CatTowerFloor) {
        Haptics.play(.mistake)
        let needed = model.crush.currentLevel.map { model.crush.number(of: $0) } ?? max(1, floor.number - 1)
        withAnimation(.snappy) { lockedNote = needed }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if lockedNote == needed { withAnimation(.easeOut) { lockedNote = nil } }
        }
    }

    /// Eski kıvrımlı yol haritası (ayarla geri açılabilir).
    private func classicMap(levels: [CrushLevel], current: CrushLevel?, episode: CrushEpisode, episodeIndex: Int) -> some View {
        let crush = model.crush
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { offset, level in
                        CrushMapRow(
                            level: level,
                            index: offset,
                            isLast: offset == levels.count - 1,
                            isCurrent: level.id == current?.id,
                            tint: episode.tint(theme)
                        ) {
                            router.push(.crushGame(levelID: level.id))
                        }
                        .id(level.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .task {
                guard let current, crush.episode(of: current) == episodeIndex else { return }
                proxy.scrollTo(current.id, anchor: .center)
                try? await Task.sleep(for: .milliseconds(60))
                proxy.scrollTo(current.id, anchor: .center)
            }
            .onChange(of: episodeIndex) { _, newIndex in
                if let current, crush.episode(of: current) == newIndex {
                    proxy.scrollTo(current.id, anchor: .center)
                } else if let first = crush.catalog.levels(in: newIndex).first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
        .background {
            ZStack {
                LinearGradient(colors: episode.colors(theme), startPoint: .top, endPoint: .bottom)
                if Illustration.exists(episode.mapBackground) {
                    Color.clear
                        .overlay { IllustrationView(name: episode.mapBackground, contentMode: .fill) }
                        .clipped()
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: episodeIndex)
        }
    }

    /// Macera seçici, yıldız ilerlemesi ve sıradaki sandık.
    private func header(episode: CrushEpisode, levels: [CrushLevel]) -> some View {
        let crush = model.crush
        let stars = levels.map { crush.stars(for: $0) }.reduce(0, +)
        let tint = episode.tint(theme)
        let isUnlocked = levels.first.map { crush.isUnlocked($0) } ?? false
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                arrow("chevron.left", enabled: episode.index > 0) { selectedEpisode = episode.index - 1 }
                    .accessibilityLabel(Text("Previous building"))
                VStack(spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: episode.icon)
                            .foregroundStyle(tint)
                        Text(verbatim: "\(episode.index + 1). ") + Text(episode.title)
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Gold.mid)
                        Text(verbatim: "\(stars)/\(levels.count * 3)")
                    }
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                arrow("chevron.right", enabled: episode.index < crush.catalog.episodeCount - 1) { selectedEpisode = episode.index + 1 }
                    .accessibilityLabel(Text("Next building"))
            }
            HStack(spacing: 8) {
                CrushLivesBadge()
                CrushChestProgress(totalStars: crush.totalStars, starsToNext: crush.progress.starsToNextChest)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func arrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
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

    /// Sıradaki bölüm, güçlendiriciler ve rozetler.
    private func footer(current: CrushLevel?) -> some View {
        let crush = model.crush
        let earned = crush.progress.badges.count
        let all = CrushBadge.all(episodes: crush.catalog.episodeCount).count
        return VStack(spacing: 10) {
            if let level = current {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Level \(crush.number(of: level))")
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            HStack(spacing: 6) {
                                ForEach(Array(level.goals.enumerated()), id: \.offset) { _, goal in
                                    HStack(spacing: 3) {
                                        CrushGoalIcon(goal: goal)
                                            .frame(width: 22, height: 22)
                                        Text(goal.target, format: .number)
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(theme.textSecondary)
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            ForEach(CrushBooster.allCases, id: \.self) { booster in
                                boosterChip(booster, count: crush.count(of: booster))
                            }
                        }
                    }
                    Button {
                        router.push(.crushGame(levelID: level.id))
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("crush.hub.play")
                }
                .padding(14)
                .card(cornerRadius: 22)
            }
            Button {
                isShowingBadges = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(Gold.deep)
                    Text("My Badges")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(verbatim: "\(earned)/\(all)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .card(cornerRadius: 16)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("crush.hub.badges")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            LinearGradient(colors: [theme.background.opacity(0), theme.background, theme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func boosterChip(_ booster: CrushBooster, count: Int) -> some View {
        VStack(spacing: 1) {
            Image(systemName: booster.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(booster.tint)
            Text(verbatim: "\(count)")
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(theme.textPrimary)
        }
        .frame(width: 38, height: 40)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.surfaceMuted))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(booster.title))
        .accessibilityValue(Text(verbatim: "\(count)"))
    }
}

/// Bir sonraki yıldız sandığına ilerleme.
struct CrushChestProgress: View {
    @Environment(\.appTheme) private var theme
    let totalStars: Int
    let starsToNext: Int

    var body: some View {
        let per = CrushProgress.starsPerChest
        let done = per - starsToNext
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Gold.deep)
            ProgressBar(value: Double(done) / Double(per), tint: Gold.mid)
            Text("\(starsToNext) ★ to next chest")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Haritada bir bölüm ve sonrakine uzanan yol.
@MainActor
struct CrushMapRow: View {
    let level: CrushLevel
    let index: Int
    let isLast: Bool
    let isCurrent: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let h = CatMapRow.height
            let start = CGPoint(x: CatMapRow.x(index) * width, y: h / 2)
            let end = CGPoint(x: CatMapRow.x(index + 1) * width, y: h / 2 + h)
            ZStack(alignment: .topLeading) {
                if !isLast {
                    CatMapPath(start: start, end: end)
                }
                CrushMapNode(level: level, isCurrent: isCurrent, tint: tint, action: action)
                    .position(start)
            }
        }
        .frame(height: CatMapRow.height)
    }
}

/// Bölüm düğmesi: numara; kazanılanlar renkli ve üstünde yıldızlar; sıradaki büyük ve atan
/// halkalı; kilitliler soluk.
@MainActor
struct CrushMapNode: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: CrushLevel
    let isCurrent: Bool
    let tint: Color
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        let crush = model.crush
        let number = crush.number(of: level)
        let isUnlocked = crush.isUnlocked(level)
        let stars = crush.stars(for: level)
        let isDone = stars > 0
        let size: CGFloat = isCurrent ? 66 : 54
        Button(action: action) {
            VStack(spacing: 2) {
                if isDone {
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: index == 1 ? 14 : 11, weight: .bold))
                                .foregroundStyle(index < stars ? Gold.bright : Color.white.opacity(0.75))
                                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                                .offset(y: index == 1 ? -2 : 0)
                        }
                    }
                }
                ZStack {
                    Circle().fill(isDone
                        ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(isUnlocked ? Color.white : Color(hex: "#E9E4EE").opacity(0.92)))
                    Circle().strokeBorder(.white.opacity(isUnlocked ? 0.95 : 0.6), lineWidth: isCurrent ? 4 : 3)
                    if isUnlocked {
                        Text(verbatim: "\(number)")
                            .font(.system(size: isCurrent ? 24 : 19, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(isDone ? .white : tint)
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
        .accessibilityValue(isDone ? Text("\(stars) of 3 stars") : (isUnlocked ? Text(verbatim: "") : Text("Locked")))
        .onAppear {
            guard isCurrent, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { glow = true }
        }
    }
}

/// Rozetler ve istatistikler.
@MainActor
struct CrushBadgesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let crush = model.crush
        NavigationStack {
            List {
                Section {
                    stat("Levels won", value: crush.completedCount)
                    stat("Stars", value: crush.totalStars)
                    stat("Best chain", value: crush.stats.bestCascade)
                    stat("Special items popped", value: crush.stats.specialsUsed)
                }
                Section("Badges") {
                    ForEach(CrushBadge.all(episodes: crush.catalog.episodeCount), id: \.self) { badge in
                        let isEarned = crush.progress.badges.contains(badge)
                        HStack(spacing: 14) {
                            Image(systemName: badge.icon)
                                .font(.title3)
                                .foregroundStyle(isEarned ? Gold.ink : theme.textSecondary.opacity(0.5))
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(isEarned ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(theme.surfaceMuted)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(badge.title)
                                    .font(.headline)
                                    .foregroundStyle(isEarned ? theme.textPrimary : theme.textSecondary)
                                Text(badge.detail)
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .opacity(isEarned ? 1 : 0.7)
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(isEarned ? Text("Earned") : Text("Locked"))
                    }
                }
            }
            .navigationTitle(Text("Meow Crush"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value, format: .number)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
    }
}
