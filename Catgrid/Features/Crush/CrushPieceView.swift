import NonogramKit
import SwiftUI
import UIKit

/// Miyav Crush eşyalarının renkleri, şekilleri ve adları. Her eşyanın kendine özgü zemin şekli
/// var (renk körlüğünde de ayırt edilsin).
extension CrushColor {
    var tint: Color {
        switch self {
        case .yarn: Color(hex: "#4C8DEB")
        case .wand: Color(hex: "#EA5466")
        case .treat: Color(hex: "#F4BE34")
        case .bowl: Color(hex: "#43B873")
        case .mouse: Color(hex: "#9C6ADB")
        case .paw: Color(hex: "#F38A35")
        }
    }

    /// Parlak üst ton (degrade için).
    var highlight: Color {
        switch self {
        case .yarn: Color(hex: "#9CC6FF")
        case .wand: Color(hex: "#FF9AA6")
        case .treat: Color(hex: "#FFE48A")
        case .bowl: Color(hex: "#93E6B1")
        case .mouse: Color(hex: "#CFADFF")
        case .paw: Color(hex: "#FFC08A")
        }
    }

    var shade: Color {
        switch self {
        case .yarn: Color(hex: "#2A5FB8")
        case .wand: Color(hex: "#B42E43")
        case .treat: Color(hex: "#C98D10")
        case .bowl: Color(hex: "#23854C")
        case .mouse: Color(hex: "#6A3CAD")
        case .paw: Color(hex: "#C2601A")
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .yarn: "Yarn Ball"
        case .wand: "Feather Wand"
        case .treat: "Fish Treat"
        case .bowl: "Food Bowl"
        case .mouse: "Toy Mouse"
        case .paw: "Paw Scratcher"
        }
    }

    /// Kullanıcının çizeceği görsel (Assets'te varsa çizilen yerine kullanılır).
    var assetName: String { "crush-\(self)" }
}

/// Tek bir eşya: renkli parlak taş ve üstünde kedi eşyası; özel eşyalarda çizgiler, kutu ya da
/// altın göz.
@MainActor
struct CrushPieceView: View {
    let piece: CrushPiece
    var isPrimed: Bool { piece.special == .wrappedPrimed }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                if piece.special == .colorBomb {
                    GoldenCatEye(size: size)
                } else if let color = piece.color {
                    token(color, size: size)
                    if piece.special.isStriped {
                        Stripes(isHorizontal: piece.special == .stripedRow)
                            .fill(.white.opacity(0.75))
                            .frame(width: size * 0.82, height: size * 0.82)
                            .mask(TokenShape(color: color).frame(width: size * 0.82, height: size * 0.82))
                            .blendMode(.overlay)
                        Stripes(isHorizontal: piece.special == .stripedRow)
                            .stroke(.white.opacity(0.85), lineWidth: max(1, size * 0.025))
                            .frame(width: size * 0.82, height: size * 0.82)
                            .mask(TokenShape(color: color).frame(width: size * 0.82, height: size * 0.82))
                    }
                    if piece.special.isWrapped {
                        RattleBox(color: color, size: size, isPrimed: isPrimed)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func token(_ color: CrushColor, size: CGFloat) -> some View {
        if let image = UIImage(named: color.assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.9, height: size * 0.9)
        } else {
            ZStack {
                TokenShape(color: color)
                    .fill(LinearGradient(colors: [color.highlight, color.tint, color.shade], startPoint: .top, endPoint: .bottom))
                    .shadow(color: color.shade.opacity(0.45), radius: size * 0.04, y: size * 0.04)
                // Parlama
                TokenShape(color: color)
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center))
                    .scaleEffect(x: 0.78, y: 0.62, anchor: .top)
                    .offset(y: size * 0.04)
                CrushGlyph(color: color)
                    .frame(width: size * 0.46, height: size * 0.46)
                    .offset(y: size * 0.02)
            }
            .frame(width: size * 0.82, height: size * 0.82)
        }
    }
}

/// Eşyanın zemin şekli: yumak daire, olta yuvarlak kare, mama damla, kap altıgen, fare elmas,
/// pati yuvarlak yıldız.
struct TokenShape: Shape {
    let color: CrushColor

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let c = CGPoint(x: rect.midX, y: rect.midY)
        switch color {
        case .yarn:
            return Path(ellipseIn: rect)
        case .wand:
            return Path(roundedRect: rect.insetBy(dx: w * 0.04, dy: h * 0.04), cornerRadius: w * 0.28)
        case .treat:
            // Damla: üstte sivri
            var path = Path()
            path.move(to: CGPoint(x: c.x, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62),
                          control1: CGPoint(x: c.x + w * 0.18, y: rect.minY + h * 0.18),
                          control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.34))
            path.addArc(center: CGPoint(x: c.x, y: rect.minY + h * 0.62), radius: w / 2,
                        startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            path.addCurve(to: CGPoint(x: c.x, y: rect.minY),
                          control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.34),
                          control2: CGPoint(x: c.x - w * 0.18, y: rect.minY + h * 0.18))
            return path
        case .bowl:
            return polygon(sides: 6, in: rect, rotation: .degrees(30), corner: 0.18)
        case .mouse:
            return polygon(sides: 4, in: rect, rotation: .degrees(0), corner: 0.22)
        case .paw:
            return roundedStar(in: rect)
        }
    }

    private func polygon(sides: Int, in rect: CGRect, rotation: Angle, corner: CGFloat) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var points: [CGPoint] = []
        for i in 0..<sides {
            let step: Double = 2 * Double.pi / Double(sides)
            let angle: Double = rotation.radians + Double(i) * step - Double.pi / 2
            let x: CGFloat = c.x + r * CGFloat(cos(angle))
            let y: CGFloat = c.y + r * CGFloat(sin(angle))
            points.append(CGPoint(x: x, y: y))
        }
        return rounded(points, radius: r * corner)
    }

    private func roundedStar(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var points: [CGPoint] = []
        for i in 0..<16 {
            let angle: Double = Double(i) * Double.pi / 8 - Double.pi / 2
            let radius: CGFloat = i.isMultiple(of: 2) ? r : r * 0.84
            points.append(CGPoint(x: c.x + radius * CGFloat(cos(angle)), y: c.y + radius * CGFloat(sin(angle))))
        }
        return rounded(points, radius: r * 0.12)
    }

    private func rounded(_ points: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        let count = points.count
        for i in 0..<count {
            let previous = points[(i + count - 1) % count]
            let current = points[i]
            let next = points[(i + 1) % count]
            let start = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            let end = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            if i == 0 { path.move(to: start) }
            path.addArc(tangent1End: current, tangent2End: end, radius: radius)
        }
        path.closeSubpath()
        return path
    }
}

/// Taşın üstündeki beyaz kedi eşyası.
struct CrushGlyph: View {
    let color: CrushColor

    var body: some View {
        switch color {
        case .yarn:
            YarnGlyph()
                .stroke(.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .wand:
            Image(systemName: "wand.and.stars")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .foregroundStyle(.white)
        case .treat:
            Image(systemName: "fish.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        case .bowl:
            BowlGlyph()
                .fill(.white)
        case .mouse:
            MouseGlyph()
                .fill(.white)
        case .paw:
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        }
    }
}

/// Yün yumağı: daire ve üstünde kıvrık iplikler.
struct YarnGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        let offsets: [CGFloat] = [-0.45, 0, 0.45]
        for offset in offsets {
            let base: CGFloat = c.y + r * offset
            path.move(to: CGPoint(x: c.x - r * 0.9, y: base - r * 0.35))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 0.9, y: base + r * 0.35), control: CGPoint(x: c.x, y: base - r * 0.6))
        }
        // Sarkan iplik ucu
        path.move(to: CGPoint(x: c.x + r * 0.7, y: c.y + r * 0.7))
        path.addQuadCurve(to: CGPoint(x: c.x + r * 1.15, y: c.y + r * 1.1), control: CGPoint(x: c.x + r * 1.2, y: c.y + r * 0.7))
        return path
    }
}

/// Mama kabı: yarım daire kap ve üstünde mama tepesi.
struct BowlGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        // Mama tepesi
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.2, y: rect.minY + h * 0.18, width: w * 0.6, height: h * 0.36))
        // Kap
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.42))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.42))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.42),
                      control1: CGPoint(x: rect.maxX - w * 0.05, y: rect.maxY + h * 0.05),
                      control2: CGPoint(x: rect.minX + w * 0.05, y: rect.maxY + h * 0.05))
        path.closeSubpath()
        return path
    }
}

/// Peluş fare: gövde, iki kulak ve kuyruk.
struct MouseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.36, width: w * 0.7, height: h * 0.5))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.1, y: rect.minY + h * 0.14, width: w * 0.3, height: h * 0.3))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.46, y: rect.minY + h * 0.1, width: w * 0.3, height: h * 0.3))
        // Kuyruk
        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + w * 0.8, y: rect.minY + h * 0.66))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.4), control: CGPoint(x: rect.maxX + w * 0.05, y: rect.minY + h * 0.75))
        path.addPath(tail.strokedPath(StrokeStyle(lineWidth: max(1.5, w * 0.08), lineCap: .round)))
        return path
    }
}

/// Çizgili yumağın parlak çizgileri.
struct Stripes: Shape {
    let isHorizontal: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = 5
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) / CGFloat(count)
            if isHorizontal {
                let y = rect.minY + rect.height * t
                path.addRect(CGRect(x: rect.minX, y: y - rect.height * 0.05, width: rect.width, height: rect.height * 0.1))
            } else {
                let x = rect.minX + rect.width * t
                path.addRect(CGRect(x: x - rect.width * 0.05, y: rect.minY, width: rect.width * 0.1, height: rect.height))
            }
        }
        return path
    }
}

/// Çıngırak Kutusu: eşyayı saran kurdele ve üstte çıngırak. İlk patlamadan sonra parlar.
struct RattleBox: View {
    let color: CrushColor
    let size: CGFloat
    let isPrimed: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white, color.highlight, .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: size * 0.09
                )
                .frame(width: size * 0.92, height: size * 0.92)
            // Kurdele
            Rectangle().fill(.white.opacity(0.8)).frame(width: size * 0.1, height: size * 0.9)
            Rectangle().fill(.white.opacity(0.8)).frame(width: size * 0.9, height: size * 0.1)
            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(Gold.bright)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                .offset(x: size * 0.3, y: -size * 0.32)
        }
        .shadow(color: isPrimed ? Gold.bright : .clear, radius: pulse ? size * 0.25 : size * 0.08)
        .scaleEffect(isPrimed && pulse ? 1.08 : 1)
        .onAppear {
            guard isPrimed else { return }
            withAnimation(.easeInOut(duration: 0.35).repeatForever()) { pulse = true }
        }
    }
}

/// Altın Kedi Gözü: altın küre, dikey göz bebeği ve gökkuşağı halkası.
struct GoldenCatEye: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: CrushColor.allCases.map(\.tint) + [CrushColor.yarn.tint], center: .center))
                .frame(width: size * 0.9, height: size * 0.9)
            Circle()
                .fill(RadialGradient(colors: [Gold.light, Gold.bright, Gold.deep], center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.4))
                .frame(width: size * 0.74, height: size * 0.74)
            Capsule()
                .fill(Color(hex: "#2B1B0A"))
                .frame(width: size * 0.13, height: size * 0.52)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: -size * 0.14, y: -size * 0.16)
        }
        .shadow(color: Gold.mid.opacity(0.6), radius: size * 0.08)
    }
}
