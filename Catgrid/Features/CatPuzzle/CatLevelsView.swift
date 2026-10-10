import NonogramKit
import SwiftUI

/// Kedi Bulmaca'nın dört teması; her biri tahta boyutlarından bir grubu kapsar.
/// Bölüm numaraları ve kilit kuralları (bir boyuttan 10 bölüm → sonraki boyut) değişmez.
enum CatTheme: Int, CaseIterable, Identifiable {
    case spring = 1
    case summer
    case autumn
    case winter

    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .spring: "Spring Garden"
        case .summer: "Summer Beach"
        case .autumn: "Autumn Forest"
        case .winter: "Winter Tale"
        }
    }

    var sizes: ClosedRange<Int> {
        switch self {
        case .spring: 5...7
        case .summer: 8...10
        case .autumn: 11...13
        case .winter: 14...15
        }
    }

    var icon: String {
        switch self {
        case .spring: "leaf.fill"
        case .summer: "sun.max.fill"
        case .autumn: "tree.fill"
        case .winter: "snowflake"
        }
    }

    /// Kullanıcının göndereceği tema afişi (yoksa yalnızca renkli zemin).
    var illustration: String { "cat-theme-\(rawValue)" }

    func colors(_ theme: AppTheme) -> [Color] {
        switch (self, theme.isDark) {
        case (.spring, false): [Color(hex: "#DDF0C8"), Color(hex: "#F7E3C4")]
        case (.summer, false): [Color(hex: "#CDE8F7"), Color(hex: "#E7F4FB")]
        case (.autumn, false): [Color(hex: "#F6CDA6"), Color(hex: "#F3B892")]
        case (.winter, false): [Color(hex: "#DCE5F2"), Color(hex: "#EEF2F8")]
        case (.spring, true): [Color(hex: "#2C3A24"), Color(hex: "#3A3226")]
        case (.summer, true): [Color(hex: "#1F3442"), Color(hex: "#24394A")]
        case (.autumn, true): [Color(hex: "#45301F"), Color(hex: "#3B2A1C")]
        case (.winter, true): [Color(hex: "#2A3240"), Color(hex: "#323A48")]
        }
    }

    func tint(_ theme: AppTheme) -> Color {
        switch (self, theme.isDark) {
        case (.spring, false): Color(hex: "#5E9A3A")
        case (.summer, false): Color(hex: "#2F7FB0")
        case (.autumn, false): Color(hex: "#B5622A")
        case (.winter, false): Color(hex: "#5B6E91")
        case (.spring, true): Color(hex: "#A6D98A")
        case (.summer, true): Color(hex: "#8CC8EE")
        case (.autumn, true): Color(hex: "#F2A877")
        case (.winter, true): Color(hex: "#B3C3E0")
        }
    }

    static func theme(forSize size: Int) -> CatTheme {
        allCases.first { $0.sizes.contains(size) } ?? (size < 5 ? .spring : .winter)
    }
}

extension CatLevel {
    /// Bölümün zorluk adı (üretici puanı 0–3).
    var difficultyTitle: LocalizedStringResource {
        switch difficulty {
        case ...0: "Easy"
        case 1: "Medium"
        case 2: "Hard"
        default: "Expert"
        }
    }
}

/// Kedi Bulmaca bölümleri: "Bölümler" sekmesinde dört tema kartı, "Zorluklar" sekmesinde
/// zorluğa göre gruplu bölümler.
@MainActor
struct CatLevelsView: View {
    enum Tab: Hashable {
        case chapters
        case difficulties
    }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var tab = Tab.chapters

    private let columns = [GridItem(.adaptive(minimum: 58), spacing: 10)]

    var body: some View {
        let cats = model.cats
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PillPicker(selection: $tab, options: [(.chapters, Text("Chapters")), (.difficulties, Text("Difficulties"))])
                switch tab {
                case .chapters:
                    ForEach(CatTheme.allCases) { catTheme in
                        let levels = cats.levels.filter { catTheme.sizes.contains($0.size) }
                        if !levels.isEmpty {
                            themeCard(catTheme, levels: levels)
                        }
                    }
                case .difficulties:
                    ForEach(0...3, id: \.self) { difficulty in
                        let levels = cats.levels.filter { min(max($0.difficulty, 0), 3) == difficulty }
                        if let first = levels.first {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(first.difficultyTitle)
                                        .font(.title3.bold())
                                        .foregroundStyle(theme.textPrimary)
                                    Spacer()
                                    Text(verbatim: "\(levels.filter { cats.isSolved($0) }.count)/\(levels.count)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(theme.textSecondary)
                                }
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(levels) { level in
                                        CatLevelButton(level: level)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle(BadgeMode.cats.title)
    }

    private func themeCard(_ catTheme: CatTheme, levels: [CatLevel]) -> some View {
        let cats = model.cats
        let firstSize = catTheme.sizes.lowerBound
        let isUnlocked = cats.isSizeUnlocked(levels.map(\.size).min() ?? firstSize)
        let solved = levels.filter { cats.isSolved($0) }.count
        let tint = catTheme.tint(theme)
        let previous = cats.sizes.last { $0 < (levels.map(\.size).min() ?? firstSize) }
        return Button {
            router.push(.catTheme(catTheme.rawValue))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: catTheme.icon)
                            .foregroundStyle(tint)
                        Text(verbatim: "\(catTheme.rawValue). ") + Text(catTheme.title)
                    }
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    Text(verbatim: "\(catTheme.sizes.lowerBound)×\(catTheme.sizes.lowerBound) – \(catTheme.sizes.upperBound)×\(catTheme.sizes.upperBound)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    if isUnlocked {
                        HStack(spacing: 8) {
                            ProgressBar(value: Double(solved) / Double(max(levels.count, 1)), tint: tint)
                            Text(verbatim: "\(solved)/\(levels.count)")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(theme.textSecondary)
                        }
                    } else if let previous {
                        Label {
                            Text("Solve \(CatPuzzleModel.unlockThreshold) levels of \(previous)×\(previous) to unlock.")
                        } icon: {
                            Image(systemName: "lock.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(theme.isDark ? 0.1 : 0.7)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background {
                ZStack(alignment: .trailing) {
                    LinearGradient(colors: catTheme.colors(theme), startPoint: .leading, endPoint: .trailing)
                    // Tema afişi varsa sağda, solu yazı için açık
                    IllustrationView(name: catTheme.illustration, contentMode: .fill)
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .center))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .shadow(color: tint.opacity(theme.isDark ? 0 : 0.18), radius: 8, y: 4)
            .saturation(isUnlocked ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("cat.theme.\(catTheme.rawValue)")
    }
}

/// Bir temanın bölümleri, tahta boyutuna göre gruplu. Bölümler sırayla açılır.
@MainActor
struct CatThemeLevelsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme
    let catTheme: CatTheme

    private let columns = [GridItem(.adaptive(minimum: 58), spacing: 10)]

    var body: some View {
        let cats = model.cats
        let sizes = cats.sizes.filter { catTheme.sizes.contains($0) }
        let unlocked = cats.unlockedSizes
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(sizes, id: \.self) { size in
                        let levels = cats.levels.filter { $0.size == size }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if !unlocked.contains(size) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(theme.textSecondary)
                                }
                                Text(verbatim: "\(size)×\(size)")
                                    .font(.title3.bold())
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text(verbatim: "\(levels.filter { cats.isSolved($0) }.count)/\(levels.count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(theme.textSecondary)
                            }
                            if !unlocked.contains(size), let previous = cats.sizes.last(where: { $0 < size }) {
                                Text("Solve \(CatPuzzleModel.unlockThreshold) levels of \(previous)×\(previous) to unlock.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(levels) { level in
                                    CatLevelButton(level: level)
                                        .id(level.id)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .onAppear {
                if let next = cats.nextLevel, catTheme.sizes.contains(next.size) {
                    proxy.scrollTo(next.id, anchor: .center)
                }
            }
        }
        .themedScreen()
        .screenTitle(catTheme.title)
    }
}

/// Bölüm düğmesi: çözülenler renkli, sıradaki çerçeveli, kilitliler soluk.
@MainActor
struct CatLevelButton: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    let level: CatLevel

    var body: some View {
        let cats = model.cats
        let isUnlocked = cats.isUnlocked(level)
        let result = cats.results[level.id]
        let isNext = level.id == cats.nextLevel?.id
        let tint = CatTheme.theme(forSize: level.size).tint(theme)
        Button {
            router.push(.catGame(levelID: level.id))
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(result != nil ? CatPalette.color(cats.number(of: level) % CatPalette.colors.count) : theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isNext ? tint : (result == nil && isUnlocked ? theme.separator : .clear), lineWidth: isNext ? 3 : 1)
                    }
                    .shadow(color: isUnlocked ? theme.cardShadow : .clear, radius: 4, y: 2)
                if isUnlocked {
                    Text(verbatim: "\(cats.number(of: level))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(result != nil ? .white : theme.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if result?.flawless == true {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Gold.bright)
                        .padding(4)
                }
            }
            .frame(height: 58)
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isUnlocked)
        .accessibilityLabel(Text("Level \(cats.number(of: level))"))
        .accessibilityValue(result != nil ? Text("Solved") : (isUnlocked ? Text(verbatim: "") : Text("Locked")))
    }
}
