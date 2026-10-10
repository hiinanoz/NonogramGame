import SwiftUI

/// Kullanıcının Ayarlar'dan seçtiği renk paleti. Her palet açık ve koyu varyanta sahiptir;
/// hangisinin kullanılacağını `AppearanceMode` belirler.
enum ThemePalette: String, CaseIterable, Identifiable {
    case pastel
    case midnight
    case coffee
    case matcha

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .pastel: "Pastel"
        case .midnight: "Midnight Blue"
        case .coffee: "Coffee"
        case .matcha: "Matcha"
        }
    }

    func spec(isDark: Bool) -> ThemeSpec {
        switch (self, isDark) {
        case (.pastel, false):
            ThemeSpec(background: "#FFF6EE", surface: "#FFFFFF", surfaceMuted: "#F9ECE3", separator: "#F0E0D6",
                      textPrimary: "#3F3236", textSecondary: "#8A777C", accent: "#E5847F", onAccent: "#FFFFFF",
                      cellFilled: "#463840", cellCross: "#C9A9B0", gridLine: "#EEE0DA", gridLineMajor: "#BFA3A8",
                      highlight: "#FCE3DC", mistake: "#E5484D", success: "#5FA884")
        case (.pastel, true):
            ThemeSpec(background: "#1E1A1F", surface: "#2A2429", surfaceMuted: "#342C33", separator: "#3E353D",
                      textPrimary: "#F6E9EC", textSecondary: "#B9A6AD", accent: "#F2A7A7", onAccent: "#2A1E22",
                      cellFilled: "#F6D6DC", cellCross: "#7E6870", gridLine: "#3E353D", gridLineMajor: "#6B5A63",
                      highlight: "#3A2E35", mistake: "#FF6B6B", success: "#8FD1B0")
        case (.midnight, false):
            ThemeSpec(background: "#EEF3FB", surface: "#FFFFFF", surfaceMuted: "#DDE7F6", separator: "#CCD9EE",
                      textPrimary: "#1D2B4A", textSecondary: "#5D6E8F", accent: "#3D5A99", onAccent: "#FFFFFF",
                      cellFilled: "#22345C", cellCross: "#9FB0CC", gridLine: "#D3DEEF", gridLineMajor: "#8EA1C2",
                      highlight: "#DCE6F7", mistake: "#D64545", success: "#3F9675")
        case (.midnight, true):
            ThemeSpec(background: "#0D1528", surface: "#16213A", surfaceMuted: "#1D2A47", separator: "#26365A",
                      textPrimary: "#E4ECFA", textSecondary: "#93A4C4", accent: "#7FA7FF", onAccent: "#0D1528",
                      cellFilled: "#C9D8F5", cellCross: "#4E6189", gridLine: "#26365A", gridLineMajor: "#4A5F8C",
                      highlight: "#1F2E50", mistake: "#FF7A7A", success: "#6FD3A8")
        case (.coffee, false):
            ThemeSpec(background: "#F7F1EA", surface: "#FFFCF8", surfaceMuted: "#EDE2D5", separator: "#E0D1C0",
                      textPrimary: "#3E2C23", textSecondary: "#846B5B", accent: "#A0673F", onAccent: "#FFFFFF",
                      cellFilled: "#4B3226", cellCross: "#C2A994", gridLine: "#E3D5C5", gridLineMajor: "#A88E78",
                      highlight: "#F0E3D2", mistake: "#C8453C", success: "#5E8F5A")
        case (.coffee, true):
            ThemeSpec(background: "#1B1411", surface: "#261C17", surfaceMuted: "#30241E", separator: "#3D2F27",
                      textPrimary: "#F2E6DA", textSecondary: "#B8A190", accent: "#D49A6A", onAccent: "#1B1411",
                      cellFilled: "#E8D2BC", cellCross: "#7A6352", gridLine: "#3D2F27", gridLineMajor: "#6E5848",
                      highlight: "#33261F", mistake: "#F07167", success: "#8CC084")
        case (.matcha, false):
            ThemeSpec(background: "#F3F6EE", surface: "#FFFFFF", surfaceMuted: "#E3EBD8", separator: "#D4DFC5",
                      textPrimary: "#2F3A2A", textSecondary: "#6D7A63", accent: "#6A8F4E", onAccent: "#FFFFFF",
                      cellFilled: "#34432C", cellCross: "#A9B89A", gridLine: "#D8E2CB", gridLineMajor: "#94A684",
                      highlight: "#E6EEDB", mistake: "#D0503F", success: "#4E8E5E")
        case (.matcha, true):
            ThemeSpec(background: "#141A12", surface: "#1D251A", surfaceMuted: "#252F21", separator: "#2F3B2A",
                      textPrimary: "#E7EFDD", textSecondary: "#A3B394", accent: "#A6C77F", onAccent: "#141A12",
                      cellFilled: "#D5E4C2", cellCross: "#5D6E52", gridLine: "#2F3B2A", gridLineMajor: "#56684B",
                      highlight: "#26321F", mistake: "#F07A6A", success: "#86CF95")
        }
    }
}

/// Bir palet varyantının ham renkleri (hex). `AppTheme` bunları SwiftUI renklerine çevirir.
struct ThemeSpec {
    let background: String
    let surface: String
    let surfaceMuted: String
    let separator: String
    let textPrimary: String
    let textSecondary: String
    let accent: String
    let onAccent: String
    let cellFilled: String
    let cellCross: String
    let gridLine: String
    let gridLineMajor: String
    let highlight: String
    let mistake: String
    let success: String
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
