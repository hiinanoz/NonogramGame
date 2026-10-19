import NonogramKit
import SwiftUI

/// Ana sayfadaki Miyav Crush kartı: solda başlık ve sıradaki bölüm, sağda eşyalar.
@MainActor
struct CrushHomeCard: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    var compact = false
    let action: () -> Void

    var body: some View {
        let crush = model.crush
        let style = ModeStyle.crush
        Button(action: action) {
            HStack(spacing: 10) {
                ModeIcon(style: style, size: compact ? 30 : 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meow Crush")
                        .font(compact ? Font.headline.bold() : .title3.bold())
                        .foregroundStyle(style.ink(theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        if let level = crush.currentLevel {
                            Text("Level \(crush.number(of: level))")
                        }
                        Text(verbatim: "·")
                        Image(systemName: "star.fill")
                            .foregroundStyle(Gold.mid)
                        Text(verbatim: "\(crush.totalStars)")
                        Text(verbatim: "·")
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color(hex: "#F0506E"))
                        if store.isPremium {
                            Text(verbatim: "∞")
                        } else {
                            Text(verbatim: "\(crush.livesCount())")
                        }
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(style.ink(theme).opacity(0.85))
                    .lineLimit(1)
                }
                Spacer(minLength: 4)
                art
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(style.tint(theme)))
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, 6)
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

    /// Telefonda oyun oynayan hareketli kedi; yoksa çizim ya da yan yana eşyalar.
    @ViewBuilder
    private var art: some View {
        if LoopingCatAnimation.isAvailable(LoopingCatAnimation.crushCat) {
            // Kartın yüksekliğini doldurur; genişliği en-boy oranından gelir
            LoopingCatView(name: LoopingCatAnimation.crushCat)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.vertical, -4)
        } else if Illustration.exists(ModeStyle.crush.illustration) {
            IllustrationView(name: ModeStyle.crush.illustration)
                .frame(maxHeight: .infinity)
        } else {
            HStack(spacing: -6) {
                CrushPieceView(piece: CrushPiece(id: 0, color: .yarn, special: .stripedRow))
                CrushPieceView(piece: CrushPiece(id: 0, color: nil, special: .colorBomb))
                    .scaleEffect(1.15)
                    .zIndex(1)
                CrushPieceView(piece: CrushPiece(id: 0, color: .mouse))
            }
            .frame(width: compact ? 96 : 120, height: compact ? 36 : 44)
        }
    }
}
