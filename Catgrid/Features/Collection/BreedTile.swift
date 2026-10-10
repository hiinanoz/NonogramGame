import NonogramKit
import SwiftUI

/// Kedi türünün portre kartı (koleksiyon ızgarası ve ana sayfa önizlemesi).
/// Kilitli olanlar soluk; kartı kazanılan türde köşede yıldız, Altın Kartta taç ve altın çerçeve.
@MainActor
struct BreedTile: View {
    @Environment(\.appTheme) private var theme
    let chapter: Chapter
    /// Türün kartı kazanıldı.
    let isCollected: Bool
    var isGolden = false
    /// Soluk ve kilitli gösterilir (henüz açılmamış ya da kartı kazanılmamış).
    var isLocked = false
    /// Çözülen / toplam bulmaca; verilirse adın altında gösterilir.
    var progress: (solved: Int, total: Int)?

    private var tint: Color { chapter.accentColor.map { Color($0) } ?? theme.accent }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            portrait
            Text(verbatim: chapter.title.resolved)
                .font(.caption.bold())
                .foregroundStyle(isLocked ? theme.textSecondary : theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let progress {
                HStack(spacing: 3) {
                    Image(systemName: progress.solved >= progress.total ? "star.fill" : "star")
                        .foregroundStyle(progress.solved >= progress.total ? Gold.mid : theme.textSecondary.opacity(0.6))
                    Text(verbatim: "\(progress.solved)/\(progress.total)")
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: 0)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(theme.textSecondary.opacity(0.7))
                    }
                }
                .font(.caption2.weight(.semibold))
            }
        }
        .padding(7)
        .background(shape.fill(isGolden ? AnyShapeStyle(LinearGradient(colors: [Gold.light, theme.surface], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(theme.surface)))
        .overlay(
            shape.strokeBorder(
                isGolden ? AnyShapeStyle(Gold.foil) : AnyShapeStyle(isLocked ? theme.separator : tint.opacity(0.55)),
                lineWidth: isGolden ? 2 : 1
            )
        )
        .shadow(color: theme.cardShadow, radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isGolden ? Text("Golden Card") : (isCollected ? Text("Collected") : (isLocked ? Text("Locked") : Text(verbatim: ""))))
    }

    private var portrait: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return ZStack {
            shape.fill(tint.opacity(isLocked ? 0.1 : 0.25))
            if let photo = BreedPhoto.portrait(chapter.id) {
                Color.clear
                    .overlay {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else if let art = chapter.portrait {
                ArtworkThumbnail(artwork: art)
                    .padding(10)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(shape)
        .saturation(isLocked ? 0 : 1)
        .opacity(isLocked ? 0.65 : 1)
        .overlay(alignment: .topLeading) {
            if isCollected, let card = chapter.card {
                Image(systemName: isGolden ? "crown.fill" : "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isGolden ? Gold.deep : card.rarity.frameColors[1])
                    .padding(4)
                    .background(Circle().fill(.white.opacity(0.9)))
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isLocked && progress == nil {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .padding(4)
            }
        }
    }
}
