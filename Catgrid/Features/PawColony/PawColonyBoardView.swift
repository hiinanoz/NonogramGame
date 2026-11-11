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
    /// Öğreticide elin gösterdiği hareket.
    var guide: PawGuide?

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
                                 isSelected: viewModel.dragFrom == node.id,
                                 isUnderAttack: game.isUnderAttack(node.id),
                                 isAlert: viewModel.alertNodes.contains(node.id))
                        .position(point(node.position, size))
                        .accessibilityElement()
                        .accessibilityLabel(label(for: node))
                        .accessibilityIdentifier("paw.house.\(node.id)")
                }
                // Ev kazanılınca halka
                ForEach(viewModel.bursts) { burst in
                    if let node = game.node(burst.node) {
                        PawBurstView(owner: burst.owner).position(point(node.position, size))
                    }
                }
                // Uçan "+3" / "−2"
                ForEach(viewModel.floats) { item in
                    if let node = game.node(item.node) {
                        PawFloatView(amount: item.amount)
                            .position(point(node.position, size))
                    }
                }
                // Sürüklerken hedef evin üstünde: alabilir mi?
                ForEach(viewModel.cuts) { cut in
                    PawCutView().position(point(cut.point, size))
                }
                if let hover = viewModel.dragOutlook, let node = game.node(hover.target) {
                    PawOutlookBadge(outlook: hover.outlook, cost: viewModel.dragCost)
                        .position(x: point(node.position, size).x, y: point(node.position, size).y - 58)
                        .allowsHitTesting(false)
                }
                switch guide {
                case .drag(let from, let to):
                    if let a = game.node(from), let b = game.node(to) {
                        PawGuideHand(from: point(a.position, size), to: point(b.position, size))
                            .id("drag-\(from)-\(to)")
                    }
                case .cut(let linkID):
                    // El, yolun ortasından dik geçer
                    if let link = game.links.first(where: { $0.id == linkID }), let a = game.node(link.from), let b = game.node(link.to) {
                        let start = point(a.position, size), end = point(b.position, size)
                        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                        let length = max(hypot(end.x - start.x, end.y - start.y), 1)
                        let normal = CGPoint(x: -(end.y - start.y) / length * 46, y: (end.x - start.x) / length * 46)
                        PawGuideHand(from: CGPoint(x: mid.x - normal.x, y: mid.y - normal.y),
                                     to: CGPoint(x: mid.x + normal.x, y: mid.y + normal.y))
                            .id("cut-\(linkID)")
                    }
                case nil:
                    EmptyView()
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
                // Yolda yürüyen patiler
                let distance = hypot(tip.x - start.x, tip.y - start.y)
                let gap: CGFloat = 22
                let shift = CGFloat(phase * 34).truncatingRemainder(dividingBy: gap)
                let paw = context.resolve(Text(Image(systemName: "pawprint.fill")).font(.system(size: 9, weight: .bold)).foregroundColor(.white))
                var travelled = shift
                while travelled < distance - 4 {
                    let t = travelled / max(distance, 1)
                    context.draw(paw, at: CGPoint(x: start.x + (tip.x - start.x) * t, y: start.y + (tip.y - start.y) * t))
                    travelled += gap
                }
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
            // Açılamayacak yol kırmızı
            let blocked = viewModel.dragOutlook?.outlook == .cannot
            context.stroke(path, with: .color((blocked ? Color(hex: "#E5484D") : PawColors.cats).opacity(0.8)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 8]))
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
    /// Düşman akışı altında: çerçeve kırmızı yanıp söner.
    var isUnderAttack = false
    /// Fareler bu evden yol açmak üzere: ev titrer.
    var isAlert = false
    @State private var flash = false

    var body: some View {
        let size: CGFloat = node.count >= 40 ? 70 : (node.count >= 15 ? 60 : 52)
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                // Doluluk halkası: evin gücü (100 üzerinden)
                Circle()
                    .trim(from: 0, to: min(node.count / node.capacity, 1))
                    .stroke(isUnderAttack && flash ? Color(hex: "#E5484D") : PawColors.deep(node.owner).opacity(0.75),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 1.32, height: size * 1.32)
                    .offset(y: -size * 0.12)
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
            .rotationEffect(.degrees(isAlert ? (flash ? 5 : -5) : 0))
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) { flash = true }
        }
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

/// Evin üstünden yükselip kaybolan değişim yazısı.
struct PawFloatView: View {
    let amount: Int
    @State private var rise = false

    var body: some View {
        Text(verbatim: amount > 0 ? "+\(amount)" : "\(amount)")
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(amount > 0 ? Color(hex: "#3FA34D") : Color(hex: "#E5484D"))
            .shadow(color: .white, radius: 2)
            .offset(x: 26, y: rise ? -52 : -24)
            .opacity(rise ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { rise = true } }
    }
}

/// Ev el değiştirince genişleyen renkli halka ve yıldızlar.
struct PawBurstView: View {
    let owner: PawOwner
    @State private var grow = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(PawColors.fill(owner), lineWidth: 6)
                .frame(width: grow ? 130 : 40, height: grow ? 130 : 40)
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: owner == .cats ? "pawprint.fill" : "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(owner == .cats ? PawColors.cats : PawColors.mice)
                    .offset(y: grow ? -60 : -10)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }
        .opacity(grow ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { grow = true } }
    }
}

/// Sürüklenen yolun hedefi için kısa tahmin.
struct PawOutlookBadge: View {
    let outlook: PawColonyGame.LinkOutlook
    /// Yolun kedi maliyeti.
    var cost: Int?

    var body: some View {
        let (symbol, text, color): (String, LocalizedStringResource, Color) = switch outlook {
        case .easily: ("checkmark.circle.fill", "Easy win", Color(hex: "#3FA34D"))
        case .slowly: ("hourglass", "Takes time", Color(hex: "#E39B2D"))
        case .cannot: ("xmark.circle.fill", "Not enough cats", Color(hex: "#E5484D"))
        case .reinforce: ("heart.fill", "Send help", Color(hex: "#3D9BE9"))
        }
        Label {
            HStack(spacing: 4) {
                Text(text)
                if let cost, outlook != .cannot {
                    Text(verbatim: "−\(cost)")
                    Image(systemName: "cat.fill")
                }
            }
        } icon: {
            Image(systemName: symbol)
        }
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .fixedSize()
    }
}

/// Öğreticide elin gösterdiği hareket.
enum PawGuide: Equatable {
    /// Bir evden diğerine sürükle.
    case drag(from: Int, to: Int)
    /// Yolun üstünden kaydırıp kes.
    case cut(link: Int)
}

/// Kesilen noktada kısa süre görünen makas.
struct PawCutView: View {
    @State private var fade = false

    var body: some View {
        Image(systemName: "scissors")
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .scaleEffect(fade ? 1.5 : 0.8)
            .opacity(fade ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { fade = true } }
    }
}
