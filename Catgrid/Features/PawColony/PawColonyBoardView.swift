import NonogramKit
import SwiftUI

/// Renkler: kediler turuncu, fareler gri-mavi, sahipsizler bej.
enum PawColors {
    static let cats = Color(hex: "#FF8A3D")
    static let catsDeep = Color(hex: "#D9631C")
    static let mice = Color(hex: "#8C8AA6")
    static let miceDeep = Color(hex: "#5F5C7A")
    static let neutral = Color(hex: "#E8DCC6")
    static let neutralDeep = Color(hex: "#B8A98E")

    static func fill(_ owner: PawOwner) -> Color {
        switch owner {
        case .cats: cats
        case .mice: mice
        case .neutral: neutral
        }
    }

    static func deep(_ owner: PawOwner) -> Color {
        switch owner {
        case .cats: catsDeep
        case .mice: miceDeep
        case .neutral: neutralDeep
        }
    }
}

/// Oyun alanı: yollar (akan yün çizgileri), evler, sürükleme ve kesme izi.
/// Kendi evinden başka bir eve sürüklemek yol açar; boş yerden bir yolun üstünden kaydırmak keser.
struct PawColonyBoardView: View {
    let viewModel: PawColonyGameViewModel
    /// İlk bölümde gösterilen sürükleme (kaynak ve hedef ev).
    var guide: (from: Int, to: Int)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let game = viewModel.game
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    Canvas { context2, _ in
                        drawLinks(in: &context2, size: size, game: game, phase: context.date.timeIntervalSinceReferenceDate)
                        drawDrag(in: &context2, size: size, game: game)
                    }
                }
                .allowsHitTesting(false)
                ForEach(game.nodes) { node in
                    PawHouseView(node: node, links: game.outgoing(from: node.id).count,
                                 isSelected: viewModel.dragFrom == node.id)
                        .position(point(node.position, size))
                        .accessibilityElement()
                        .accessibilityLabel(label(for: node))
                        .accessibilityIdentifier("paw.house.\(node.id)")
                }
                if let guide, let a = game.node(guide.from), let b = game.node(guide.to) {
                    PawGuideHand(from: point(a.position, size), to: point(b.position, size))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = normalized(value.location, size)
                        if value.translation == .zero {
                            viewModel.dragBegan(at: p)
                        } else {
                            if viewModel.dragFrom == nil && viewModel.cutTrail.isEmpty { viewModel.dragBegan(at: normalized(value.startLocation, size)) }
                            viewModel.dragMoved(to: p)
                        }
                    }
                    .onEnded { value in viewModel.dragEnded(at: normalized(value.location, size)) }
            )
        }
    }

    private func label(for node: PawNode) -> Text {
        switch node.owner {
        case .cats: Text("Cat house: \(Int(node.count)) cats")
        case .mice: Text("Mouse house: \(Int(node.count)) mice")
        case .neutral: Text("Empty house: \(Int(node.count))")
        }
    }

    private func point(_ p: PawPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    private func normalized(_ p: CGPoint, _ size: CGSize) -> PawPoint {
        PawPoint(x: Double(p.x / max(size.width, 1)), y: Double(p.y / max(size.height, 1)))
    }

    private func drawLinks(in context: inout GraphicsContext, size: CGSize, game: PawColonyGame, phase: Double) {
        for link in game.links {
            guard let a = game.node(link.from), let b = game.node(link.to) else { continue }
            let start = point(a.position, size)
            let end = point(b.position, size)
            let t = link.length > 0 ? link.reach / link.length : 0
            let tip = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            var path = Path()
            path.move(to: start)
            path.addLine(to: tip)
            let color = PawColors.fill(link.owner)
            context.stroke(path, with: .color(PawColors.deep(link.owner).opacity(0.6)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            // Akan kediler: yol boyunca kayan beyaz patiler (kesik çizgi)
            if link.state == .connected {
                let offset = CGFloat(-phase * 40).truncatingRemainder(dividingBy: 18)
                context.stroke(path, with: .color(.white.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 15], dashPhase: offset))
            }
            // Yolun ucu: küçük yumak
            context.fill(Path(ellipseIn: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)), with: .color(color))
        }
    }

    private func drawDrag(in context: inout GraphicsContext, size: CGSize, game: PawColonyGame) {
        if let from = viewModel.dragFrom, let node = game.node(from), let finger = viewModel.dragPoint {
            var path = Path()
            path.move(to: point(node.position, size))
            path.addLine(to: point(finger, size))
            context.stroke(path, with: .color(PawColors.cats.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 8]))
        }
        if viewModel.cutTrail.count > 1 {
            var path = Path()
            path.addLines(viewModel.cutTrail.map { point($0, size) })
            context.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Kodla çizilmiş ev: kedi evi turuncu ve çatısında kedi kulakları, fare evi gri ve yuvarlak
/// fare kulakları, sahipsiz ev bej. Ortada sayı, altında açık yol hakları (noktalar).
struct PawHouseView: View {
    let node: PawNode
    let links: Int
    var isSelected = false

    var body: some View {
        let size: CGFloat = node.count >= 40 ? 70 : (node.count >= 15 ? 60 : 52)
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                // Gövde
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(PawColors.fill(node.owner))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).strokeBorder(PawColors.deep(node.owner), lineWidth: 2.5))
                    .frame(width: size, height: size * 0.72)
                    .offset(y: size * 0.3)
                // Çatı ve kulaklar
                roof(size)
                Text(verbatim: "\(Int(node.count))")
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(node.owner == .neutral ? PawColors.neutralDeep : .white)
                    .shadow(color: .black.opacity(node.owner == .neutral ? 0 : 0.3), radius: 1, y: 1)
                    .monospacedDigit()
                    .offset(y: size * 0.46)
            }
            .frame(width: size, height: size)
            .shadow(color: isSelected ? Gold.bright : .black.opacity(0.2), radius: isSelected ? 10 : 3, y: 2)
            .scaleEffect(isSelected ? 1.08 : 1)
            if node.owner != .neutral {
                HStack(spacing: 3) {
                    ForEach(0..<node.maxLinks, id: \.self) { index in
                        Circle()
                            .fill(index < links ? PawColors.deep(node.owner) : Color.white.opacity(0.8))
                            .overlay(Circle().strokeBorder(PawColors.deep(node.owner), lineWidth: 1))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .animation(.spring(response: 0.35), value: node.owner)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    @ViewBuilder
    private func roof(_ size: CGFloat) -> some View {
        ZStack {
            HouseRoof()
                .fill(PawColors.deep(node.owner))
                .frame(width: size * 1.08, height: size * 0.4)
            switch node.owner {
            case .cats:
                HStack(spacing: size * 0.38) {
                    EarShape().fill(PawColors.deep(.cats)).frame(width: size * 0.22, height: size * 0.24)
                    EarShape().fill(PawColors.deep(.cats)).frame(width: size * 0.22, height: size * 0.24)
                }
                .offset(y: -size * 0.2)
            case .mice:
                HStack(spacing: size * 0.34) {
                    Circle().fill(PawColors.deep(.mice)).frame(width: size * 0.26)
                    Circle().fill(PawColors.deep(.mice)).frame(width: size * 0.26)
                }
                .overlay(HStack(spacing: size * 0.48) {
                    Circle().fill(Color(hex: "#F5B8C8")).frame(width: size * 0.12)
                    Circle().fill(Color(hex: "#F5B8C8")).frame(width: size * 0.12)
                })
                .offset(y: -size * 0.18)
            case .neutral:
                EmptyView()
            }
        }
    }
}

private struct HouseRoof: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct EarShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// İlk bölümde: el kedi evinden hedef eve sürükler.
struct PawGuideHand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let from: CGPoint
    let to: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        PawPointer(bobs: false)
            .position(x: from.x + (to.x - from.x) * progress + 14, y: from.y + (to.y - from.y) * progress + 24)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).delay(0.3).repeatForever(autoreverses: false)) { progress = 1 }
            }
    }
}

/// Ana sayfa kartının çizimi: kedi evinden fare evine uzanan yün yolu.
struct PawColonyCardArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = false

    var body: some View {
        HStack(spacing: 0) {
            PawHouseView(node: PawNode(id: 1, position: PawPoint(x: 0, y: 0), owner: .cats, count: 24), links: 1)
                .scaleEffect(0.7)
            Capsule()
                .fill(PawColors.cats)
                .frame(width: 44, height: 6)
                .overlay(
                    Capsule().stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [2, 8], dashPhase: flow ? -20 : 0))
                )
            PawHouseView(node: PawNode(id: 2, position: PawPoint(x: 0, y: 0), owner: .mice, count: 9), links: 0)
                .scaleEffect(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { flow = true }
        }
        .accessibilityHidden(true)
    }
}
