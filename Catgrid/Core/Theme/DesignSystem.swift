import SwiftUI
import UIKit

/// Oyun modlarının renk kimliği: Günlük Bulmaca lavanta, Kart Koleksiyonu şeftali,
/// Kedi Bulmaca nane. Kartlar, ikonlar ve ilerleme göstergeleri bunları kullanır.
enum ModeStyle: CaseIterable {
    case daily
    case collection
    case cats

    /// İkon, ok ve ilerleme rengi.
    func tint(_ theme: AppTheme) -> Color {
        switch (self, theme.isDark) {
        case (.daily, false): Color(hex: "#8A6BD6")
        case (.daily, true): Color(hex: "#B9A2F2")
        case (.collection, false): Color(hex: "#DE8A3A")
        case (.collection, true): Color(hex: "#F2B577")
        case (.cats, false): Color(hex: "#2F9E8F")
        case (.cats, true): Color(hex: "#7FD6C8")
        }
    }

    /// Kart zemini: yukarıdan aşağı yumuşak pastel geçiş.
    func background(_ theme: AppTheme) -> LinearGradient {
        let colors: [Color] = switch (self, theme.isDark) {
        case (.daily, false): [Color(hex: "#F1E9FF"), Color(hex: "#DDD0FA")]
        case (.daily, true): [Color(hex: "#352E4A"), Color(hex: "#2A243B")]
        case (.collection, false): [Color(hex: "#FFF2DD"), Color(hex: "#FBE0BC")]
        case (.collection, true): [Color(hex: "#43352A"), Color(hex: "#352A21")]
        case (.cats, false): [Color(hex: "#E2F6F1"), Color(hex: "#C3EAE1")]
        case (.cats, true): [Color(hex: "#25403C"), Color(hex: "#1D3330")]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// Kartın yazı rengi (açık zeminde koyu, koyu zeminde açık).
    func ink(_ theme: AppTheme) -> Color {
        switch (self, theme.isDark) {
        case (.daily, false): Color(hex: "#5A3FA8")
        case (.collection, false): Color(hex: "#8A4E14")
        case (.cats, false): Color(hex: "#1F6B61")
        case (_, true): theme.textPrimary
        }
    }

    var icon: String {
        switch self {
        case .daily: "calendar"
        case .collection: "rectangle.portrait.on.rectangle.portrait.fill"
        case .cats: "square.grid.3x3.fill"
        }
    }

    /// Modun hareketli kedisi (videodan; yoksa sabit çizim gösterilir).
    var animation: String {
        switch self {
        case .daily: LoopingCatAnimation.dailyCat
        case .collection: LoopingCatAnimation.cardsCat
        case .cats: LoopingCatAnimation.yarnCat
        }
    }

    /// Kullanıcının göndereceği çizim (Assets'te yoksa gösterilmez).
    var illustration: String {
        switch self {
        case .daily: "mode-daily"
        case .collection: "mode-collection"
        case .cats: "mode-cats"
        }
    }
}

/// Kullanıcının hazırladığı çizimler (Assets/Illustrations). Dosya yoksa hiçbir şey çizilmez:
/// tasarım çizimsiz de düzgün görünür, yer tutucu kullanılmaz.
enum Illustration {
    static func image(_ name: String) -> UIImage? {
        UIImage(named: name)
    }

    static func exists(_ name: String) -> Bool {
        image(name) != nil
    }
}

/// Assets'te varsa çizimi gösterir; yoksa boş kalır (yer kaplamaz).
struct IllustrationView: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = Illustration.image(name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .accessibilityHidden(true)
        }
    }
}

/// Yuvarlatılmış kare içinde mod ikonu (kartların üstünde).
struct ModeIcon: View {
    @Environment(\.appTheme) private var theme
    let style: ModeStyle
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: style.icon)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(style.tint(theme))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(theme.isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.85))
            )
            .shadow(color: style.tint(theme).opacity(theme.isDark ? 0 : 0.18), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

/// Ekranın üstündeki bölüm başlığı: solda başlık, sağda isteğe bağlı "Tümü".
struct SectionHeader: View {
    @Environment(\.appTheme) private var theme
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var actionIdentifier: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(theme.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.accent)
                }
                .accessibilityIdentifier(actionIdentifier ?? "")
            }
        }
    }
}

/// Segmentli seçici: yuvarlak kapsüller, seçili olan vurgu renginde.
struct PillPicker<Value: Hashable>: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: Value
    let options: [(value: Value, title: Text)]
    var tint: Color?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option.value }
                } label: {
                    option.title
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(isSelected ? theme.onAccent : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(isSelected ? (tint ?? theme.accent) : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(theme.surfaceMuted))
    }
}
