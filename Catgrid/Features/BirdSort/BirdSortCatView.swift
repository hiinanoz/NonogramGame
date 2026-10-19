import SwiftUI

/// Alttaki kedi: kare kare canlandırılır. Boştayken oturur ve göz kırpar; doğru hamlede sevinir,
/// dal dolunca uçan kuşlara uzanır, ipucunda değnekle gösterir, yanlış hamlede üzülür, bölüm
/// bitince kutlar. Görseller: sortcat-idle/cheer/wand/reach-<n>.
@MainActor
struct BirdSortCatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mood: BirdSortCatMood
    @State private var sadNudge = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 12)
            Image(frameName(tick: reduceMotion ? 0 : tick))
                .resizable()
                .scaledToFit()
        }
        .rotationEffect(.degrees(mood == .sad && sadNudge ? -4 : 0), anchor: .bottom)
        .offset(y: mood == .sad ? 3 : 0)
        .overlay(alignment: .topTrailing) {
            if mood == .sad {
                // Üzgün kedi: kafasının üstünde küçük bir damla ve soru işareti
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#6FB6F0"))
                    Text(verbatim: "?")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#6E8BD8"))
                }
                .padding(.trailing, 6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: mood)
        .onChange(of: mood) { _, new in
            guard new == .sad, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.14).repeatCount(5, autoreverses: true)) { sadNudge.toggle() }
        }
        .accessibilityHidden(true)
    }

    private func frameName(tick: Int) -> String {
        switch mood {
        case .idle:
            // Uzun süre ilk karede oturur; arada göz kırpar (2) ve göz kırpıp gülümser (3)
            let cycle = tick % 60
            let frame = cycle == 20 || cycle == 21 ? 2 : (cycle >= 44 && cycle < 47 ? 3 : 1)
            return "sortcat-idle-\(frame)"
        case .sad:
            // Şaşkın ve üzgün yüz (ağzı açık)
            return "sortcat-idle-\(tick % 8 < 4 ? 4 : 5)"
        case .pleased:
            return "sortcat-cheer-\(tick / 3 % 2 + 1)"
        case .delighted:
            return "sortcat-reach-\(tick / 2 % 8 + 1)"
        case .pointing:
            return "sortcat-wand-\(tick / 2 % 7 + 1)"
        case .celebrating:
            return "sortcat-cheer-\(tick / 2 % 7 + 1)"
        }
    }
}
