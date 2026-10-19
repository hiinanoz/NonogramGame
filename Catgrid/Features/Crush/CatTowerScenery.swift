import NonogramKit
import SwiftUI

// Kedi Kulesi dış görünümü: taş duvar, balkon, merdiven, fener, çatı, kule dibi ve gökyüzü.
// Renkler ve manzara binaya göre (CatTowerTheme), gündüz/gece uygulamanın temasına göre değişir.

/// Taş duvar: binanın taş rengi, tuğla derzleri ve yuvarlaklık gölgesi. Binanın cephe görseli
/// (tower-<anahtar>-facade, gece: -facade-night) varsa her katta o kullanılır.
struct CatTowerWall: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let tower: CatTowerTheme

    var body: some View {
        let night: UIImage? = theme.isDark ? tower.asset("facade", variant: "night") : nil
        if let facade = night ?? tower.asset("facade") {
            Image(uiImage: facade)
                .resizable()
                .scaledToFill()
                .overlay(Color(hex: "#1E1A33").opacity(theme.isDark && night == nil ? 0.42 : 0))
                .clipped()
        } else {
            drawn
        }
    }

    @ViewBuilder
    private var drawn: some View {
        let top: Color = tower.stone.top
        let bottom: Color = tower.stone.bottom
        let joint: Color = tower.stone.joint.opacity(0.7)
        let isNight = theme.isDark
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let rowHeight: CGFloat = 14
            var row = 0
            var y: CGFloat = rowHeight
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(joint), lineWidth: 1)
                let offset: CGFloat = (row + number).isMultiple(of: 2) ? 0 : 22
                var x: CGFloat = offset
                while x < size.width {
                    var joinPath = Path()
                    joinPath.move(to: CGPoint(x: x, y: y - rowHeight))
                    joinPath.addLine(to: CGPoint(x: x, y: y))
                    context.stroke(joinPath, with: .color(joint), lineWidth: 1)
                    x += 44
                }
                y += rowHeight
                row += 1
            }
            if isNight {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#1E1A33").opacity(0.42)))
            }
        }
        .overlay {
            LinearGradient(colors: [.black.opacity(0.12), .clear, .clear, .black.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

/// Çiçekli balkon: taş korkuluk, sarmaşık ve binanın çiçek renkleri (karlı binada kar).
struct CatTowerBalcony: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let isLocked: Bool
    let tower: CatTowerTheme

    var body: some View {
        let stone: Color = tower.stone.top
        let edge: Color = tower.stone.joint
        let flowers = tower.flowers
        let isSnow = tower.scenery == .snow
        let isNight = theme.isDark
        Canvas { context, size in
            let ledge = Path(roundedRect: CGRect(x: 0, y: size.height * 0.25, width: size.width, height: size.height * 0.75), cornerRadius: 6)
            context.fill(ledge, with: .color(stone))
            context.stroke(ledge, with: .color(edge), lineWidth: 1)
            if isSnow {
                let snow = Path(roundedRect: CGRect(x: -2, y: size.height * 0.18, width: size.width + 4, height: size.height * 0.2), cornerRadius: 5)
                context.fill(snow, with: .color(.white))
            }
            if isNight {
                context.fill(ledge, with: .color(Color(hex: "#1E1A33").opacity(0.35)))
            }
            guard !isLocked else { return }
            var seed = UInt64(number) &* 2_654_435_761 &+ 97
            func next() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max)
            }
            let count: Int = Int(size.width / 14)
            for _ in 0..<count {
                let x: CGFloat = next() * size.width
                let y: CGFloat = size.height * (0.15 + next() * 0.35)
                let leaf = Path(ellipseIn: CGRect(x: x - 5, y: y - 3, width: 10, height: 6))
                context.fill(leaf, with: .color(Color(hex: next() > 0.5 ? "#6FB06E" : "#4E9460")))
            }
            for i in 0..<(count / 2) {
                let x: CGFloat = next() * size.width
                let y: CGFloat = size.height * (0.1 + next() * 0.3)
                let flower = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                context.fill(flower, with: .color(flowers[i % flowers.count]))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Kulenin dışında dönen taş merdiven: her katta bir yana tırmanan basamaklar.
struct CatTowerStairs: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let side: CGFloat
    let tower: CatTowerTheme

    var body: some View {
        let step: Color = theme.isDark ? tower.stone.bottom.opacity(0.75) : tower.stone.bottom
        let edge: Color = tower.stone.joint
        Canvas { context, size in
            let leftSide = number.isMultiple(of: 2)
            let x0: CGFloat = leftSide ? 2 : size.width - side - 2
            let steps = 6
            for i in 0..<steps {
                let t: CGFloat = CGFloat(i) / CGFloat(steps)
                let y: CGFloat = size.height * (0.9 - t * 0.85)
                let path = Path(roundedRect: CGRect(x: x0, y: y, width: side - 2, height: 7), cornerRadius: 2)
                context.fill(path, with: .color(step))
                context.stroke(path, with: .color(edge), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Duvar feneri; gece yanar.
struct CatTowerLantern: View {
    let isLit: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: "#5B4A3E")).frame(width: 2, height: 8)
            RoundedRectangle(cornerRadius: 3)
                .fill(isLit ? Color(hex: "#FFD27A") : Color(hex: "#F3E3C0"))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "#5B4A3E"), lineWidth: 2))
                .frame(width: 14, height: 18)
                .shadow(color: isLit ? Color(hex: "#FFC85A") : .clear, radius: 10)
        }
        .allowsHitTesting(false)
    }
}

/// Binaya özgü çatı (görsel yoksa kodla çizilir):
/// Yumak Apartmanı: konik kiremit çatı, tepede yumak. Ay Işığı Konağı: mansart çatı, kubbe ve hilal.
/// Deniz Tatili Rezidansı: teras, çizgili şemsiye ve flama. Karlı Pati Kuleleri: karlı düz çatı, anten.
struct CatTowerRoof: View {
    @Environment(\.appTheme) private var theme
    let tower: CatTowerTheme

    var body: some View {
        if let image = (theme.isDark ? tower.asset("roof", variant: "night") : nil) ?? tower.asset("roof") {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            let colors: [Color] = tower.roof
            let key: String = tower.key
            Canvas { context, size in
                switch key {
                case "moon": CatTowerRoofArt.drawMansion(context, size: size, colors: colors)
                case "seaside": CatTowerRoofArt.drawTerrace(context, size: size, colors: colors)
                case "snow": CatTowerRoofArt.drawSnowyTop(context, size: size, colors: colors)
                default: CatTowerRoofArt.drawCone(context, size: size, colors: colors)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Çatı çizimleri (Canvas içinde çağrılır).
private enum CatTowerRoofArt {
    static let ink = Color(hex: "#5B4A3E")

    /// Kiremit sıraları (verilen şeklin içine kırpılır).
    private static func tiles(_ context: GraphicsContext, in shape: Path, from top: CGFloat, to bottom: CGFloat, width: CGFloat) {
        var clipped = context
        clipped.clip(to: shape)
        var y: CGFloat = top + 12
        while y < bottom + 10 {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addQuadCurve(to: CGPoint(x: width, y: y), control: CGPoint(x: width / 2, y: y + 10))
            clipped.stroke(line, with: .color(.black.opacity(0.12)), lineWidth: 1.5)
            y += 13
        }
    }

    static func drawCone(_ context: GraphicsContext, size: CGSize, colors: [Color]) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let base: CGFloat = h * 0.92
        let apex = CGPoint(x: w / 2, y: h * 0.2)
        var roof = Path()
        roof.move(to: apex)
        roof.addLine(to: CGPoint(x: w - 10, y: base))
        roof.addQuadCurve(to: CGPoint(x: 10, y: base), control: CGPoint(x: w / 2, y: base + h * 0.1))
        roof.closeSubpath()
        context.fill(roof, with: .linearGradient(Gradient(colors: colors), startPoint: apex, endPoint: CGPoint(x: w / 2, y: base)))
        tiles(context, in: roof, from: apex.y, to: base, width: w)
        // Çatı penceresi
        let dormer = CGRect(x: w / 2 - 14, y: h * 0.56, width: 28, height: 26)
        var dormerPath = Path(roundedRect: dormer, cornerRadius: 12)
        dormerPath.addRect(CGRect(x: dormer.minX, y: dormer.midY, width: dormer.width, height: dormer.height / 2))
        context.fill(dormerPath, with: .color(Color(hex: "#FFF4E2")))
        context.stroke(dormerPath, with: .color(ink.opacity(0.6)), lineWidth: 2)
        context.fill(Path(roundedRect: dormer.insetBy(dx: 6, dy: 6), cornerRadius: 6), with: .color(Color(hex: "#9ED2E6")))
        // Tepede yumak ve şiş
        var pole = Path()
        pole.move(to: apex)
        pole.addLine(to: CGPoint(x: apex.x, y: apex.y - h * 0.06))
        context.stroke(pole, with: .color(ink), lineWidth: 2)
        let r: CGFloat = min(14, h * 0.08)
        let ball = CGRect(x: apex.x - r, y: apex.y - h * 0.06 - r * 2, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: ball), with: .color(Color(hex: "#F28AA8")))
        for i in 0..<3 {
            var strand = Path()
            let dy: CGFloat = CGFloat(i - 1) * r * 0.5
            strand.move(to: CGPoint(x: ball.minX + 2, y: ball.midY + dy))
            strand.addQuadCurve(to: CGPoint(x: ball.maxX - 2, y: ball.midY + dy), control: CGPoint(x: ball.midX, y: ball.midY + dy - r * 0.6))
            context.stroke(strand, with: .color(Color(hex: "#C95F82")), lineWidth: 1.2)
        }
        var needle = Path()
        needle.move(to: CGPoint(x: ball.minX - 4, y: ball.minY))
        needle.addLine(to: CGPoint(x: ball.maxX + 4, y: ball.maxY - 2))
        context.stroke(needle, with: .color(Color(hex: "#C9A36B")), lineWidth: 2)
    }

    static func drawMansion(_ context: GraphicsContext, size: CGSize, colors: [Color]) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let base: CGFloat = h * 0.92
        let top: CGFloat = h * 0.58
        // Mansart: eğimli alt kat, düz üst
        var mansard = Path()
        mansard.move(to: CGPoint(x: 10, y: base))
        mansard.addLine(to: CGPoint(x: w * 0.12, y: top))
        mansard.addLine(to: CGPoint(x: w * 0.88, y: top))
        mansard.addLine(to: CGPoint(x: w - 10, y: base))
        mansard.closeSubpath()
        context.fill(mansard, with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: w / 2, y: top), endPoint: CGPoint(x: w / 2, y: base)))
        tiles(context, in: mansard, from: top, to: base, width: w)
        // Korniş
        context.fill(Path(roundedRect: CGRect(x: w * 0.1, y: top - 5, width: w * 0.8, height: 7), cornerRadius: 3), with: .color(Color(hex: "#F3E7D6")))
        // Yuvarlak çatı pencereleri
        for fx in [0.28, 0.72] as [CGFloat] {
            let c = CGRect(x: w * fx - 12, y: (top + base) / 2 - 12, width: 24, height: 24)
            context.fill(Path(ellipseIn: c), with: .color(Color(hex: "#FFE9A8")))
            context.stroke(Path(ellipseIn: c), with: .color(Color(hex: "#F3E7D6")), lineWidth: 3)
        }
        // Kubbe
        let domeWidth: CGFloat = w * 0.34
        let domeRect = CGRect(x: (w - domeWidth) / 2, y: h * 0.26, width: domeWidth, height: (top - h * 0.26) * 2)
        var dome = Path()
        dome.addArc(center: CGPoint(x: domeRect.midX, y: top), radius: domeWidth / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        var squash = CGAffineTransform(translationX: 0, y: top)
        squash = squash.scaledBy(x: 1, y: (top - h * 0.26) / (domeWidth / 2))
        squash = squash.translatedBy(x: 0, y: -top)
        let domePath = dome.applying(squash)
        context.fill(domePath, with: .linearGradient(Gradient(colors: [colors.first ?? .purple, colors.last ?? .purple]),
                                                     startPoint: CGPoint(x: domeRect.minX, y: h * 0.26), endPoint: CGPoint(x: domeRect.maxX, y: top)))
        // Kubbe kaburgaları
        var ribs = context
        ribs.clip(to: domePath)
        for i in 1..<4 {
            var rib = Path()
            let x: CGFloat = domeRect.minX + domeWidth * CGFloat(i) / 4
            rib.move(to: CGPoint(x: domeRect.midX, y: h * 0.26))
            rib.addQuadCurve(to: CGPoint(x: x, y: top), control: CGPoint(x: x, y: h * 0.32))
            ribs.stroke(rib, with: .color(.white.opacity(0.25)), lineWidth: 1.5)
        }
        // Hilal
        let moonR: CGFloat = min(13, h * 0.08)
        let moonCenter = CGPoint(x: w / 2, y: h * 0.26 - moonR - 6)
        var pole = Path()
        pole.move(to: CGPoint(x: w / 2, y: h * 0.26))
        pole.addLine(to: CGPoint(x: w / 2, y: moonCenter.y + moonR))
        context.stroke(pole, with: .color(Color(hex: "#C9A36B")), lineWidth: 2)
        var crescent = Path(ellipseIn: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2))
        crescent = crescent.subtracting(Path(ellipseIn: CGRect(x: moonCenter.x - moonR * 0.45, y: moonCenter.y - moonR * 1.15, width: moonR * 2, height: moonR * 2)))
        context.fill(crescent, with: .color(Color(hex: "#F5D77A")))
    }

    static func drawTerrace(_ context: GraphicsContext, size: CGSize, colors: [Color]) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let base: CGFloat = h * 0.92
        let deck: CGFloat = h * 0.78
        // Teras zemini ve korkuluk
        context.fill(Path(roundedRect: CGRect(x: 8, y: deck, width: w - 16, height: base - deck + 4), cornerRadius: 4),
                     with: .color(Color(hex: "#F7EBDD")))
        context.fill(Path(CGRect(x: 8, y: deck, width: w - 16, height: 5)), with: .color(colors.last ?? .teal))
        var rail = Path()
        rail.move(to: CGPoint(x: 12, y: h * 0.66))
        rail.addLine(to: CGPoint(x: w - 12, y: h * 0.66))
        var x: CGFloat = 16
        while x < w - 12 {
            rail.move(to: CGPoint(x: x, y: h * 0.66))
            rail.addLine(to: CGPoint(x: x, y: deck))
            x += 14
        }
        context.stroke(rail, with: .color(.white), lineWidth: 2.5)
        context.stroke(rail, with: .color(colors.last?.opacity(0.35) ?? .teal), lineWidth: 0.8)
        // Çizgili plaj şemsiyesi
        let center = CGPoint(x: w * 0.36, y: h * 0.3)
        let radius: CGFloat = min(w * 0.2, h * 0.32)
        var pole = Path()
        pole.move(to: center)
        pole.addLine(to: CGPoint(x: center.x + 6, y: deck))
        context.stroke(pole, with: .color(ink), lineWidth: 2)
        let stripes: [Color] = [colors.first ?? .teal, .white]
        for i in 0..<6 {
            var slice = Path()
            let start: Double = 180 + Double(i) * 30
            slice.move(to: center)
            slice.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + 30), clockwise: false)
            slice.closeSubpath()
            context.fill(slice, with: .color(stripes[i % 2]))
        }
        var rim = Path()
        rim.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        context.stroke(rim, with: .color(colors.last ?? .teal), lineWidth: 1.5)
        // Şezlong
        var lounger = Path()
        lounger.move(to: CGPoint(x: w * 0.56, y: deck - 4))
        lounger.addLine(to: CGPoint(x: w * 0.74, y: deck - 4))
        lounger.addLine(to: CGPoint(x: w * 0.8, y: deck - 18))
        context.stroke(lounger, with: .color(Color(hex: "#F28A6C")), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        // Can simidi
        let buoy = CGRect(x: w * 0.82, y: h * 0.62, width: 18, height: 18)
        context.stroke(Path(ellipseIn: buoy.insetBy(dx: 3, dy: 3)), with: .color(Color(hex: "#F06A5A")), lineWidth: 5)
        // Flama direği
        let flagX: CGFloat = w * 0.7
        var mast = Path()
        mast.move(to: CGPoint(x: flagX, y: deck))
        mast.addLine(to: CGPoint(x: flagX, y: h * 0.12))
        context.stroke(mast, with: .color(ink), lineWidth: 2)
        var flag = Path()
        flag.move(to: CGPoint(x: flagX, y: h * 0.12))
        flag.addQuadCurve(to: CGPoint(x: flagX + 26, y: h * 0.17), control: CGPoint(x: flagX + 14, y: h * 0.09))
        flag.addQuadCurve(to: CGPoint(x: flagX, y: h * 0.24), control: CGPoint(x: flagX + 12, y: h * 0.22))
        flag.closeSubpath()
        context.fill(flag, with: .color(Color(hex: "#F5C04E")))
    }

    static func drawSnowyTop(_ context: GraphicsContext, size: CGSize, colors: [Color]) {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        let base: CGFloat = h * 0.92
        let top: CGFloat = h * 0.6
        // Basamaklı çatı katı
        let body = CGRect(x: 10, y: top + (base - top) * 0.35, width: w - 20, height: (base - top) * 0.65 + 4)
        context.fill(Path(body), with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: body.minY), endPoint: CGPoint(x: 0, y: body.maxY)))
        let upper = CGRect(x: w * 0.22, y: top, width: w * 0.56, height: body.minY - top + 2)
        context.fill(Path(upper), with: .color(colors.first ?? .red))
        // Pencere şeridi
        var x: CGFloat = upper.minX + 8
        while x + 12 < upper.maxX {
            context.fill(Path(roundedRect: CGRect(x: x, y: upper.minY + 8, width: 12, height: upper.height - 14), cornerRadius: 2),
                         with: .color(Color(hex: "#BFE0F2")))
            x += 18
        }
        // Kar örtüleri ve sarkıtlar
        for ledge in [CGRect(x: 6, y: body.minY - 6, width: w - 12, height: 10), CGRect(x: upper.minX - 4, y: top - 6, width: upper.width + 8, height: 10)] {
            context.fill(Path(roundedRect: ledge, cornerRadius: 5), with: .color(.white))
            var icicle = ledge.minX + 10
            var index = 0
            while icicle < ledge.maxX - 8 {
                let length: CGFloat = index % 3 == 0 ? 10 : 6
                var drop = Path()
                drop.move(to: CGPoint(x: icicle - 3, y: ledge.maxY - 1))
                drop.addLine(to: CGPoint(x: icicle + 3, y: ledge.maxY - 1))
                drop.addLine(to: CGPoint(x: icicle, y: ledge.maxY + length))
                drop.closeSubpath()
                context.fill(drop, with: .color(Color(hex: "#DDF0FA")))
                icicle += 16
                index += 1
            }
        }
        // Anten ve ışık
        var antenna = Path()
        antenna.move(to: CGPoint(x: w / 2, y: top - 4))
        antenna.addLine(to: CGPoint(x: w / 2, y: h * 0.12))
        antenna.move(to: CGPoint(x: w / 2 - 8, y: h * 0.3))
        antenna.addLine(to: CGPoint(x: w / 2 + 8, y: h * 0.3))
        antenna.move(to: CGPoint(x: w / 2 - 5, y: h * 0.2))
        antenna.addLine(to: CGPoint(x: w / 2 + 5, y: h * 0.2))
        context.stroke(antenna, with: .color(ink), lineWidth: 2)
        context.fill(Path(ellipseIn: CGRect(x: w / 2 - 4, y: h * 0.12 - 8, width: 8, height: 8)), with: .color(Color(hex: "#F06A5A")))
        // Kardan kedi
        let snowCat = CGPoint(x: w * 0.82, y: body.minY - 4)
        context.fill(Path(ellipseIn: CGRect(x: snowCat.x - 10, y: snowCat.y - 16, width: 20, height: 16)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: snowCat.x - 7, y: snowCat.y - 28, width: 14, height: 13)), with: .color(.white))
        for side in [-1, 1] as [CGFloat] {
            var ear = Path()
            ear.move(to: CGPoint(x: snowCat.x + side * 6, y: snowCat.y - 25))
            ear.addLine(to: CGPoint(x: snowCat.x + side * 6, y: snowCat.y - 32))
            ear.addLine(to: CGPoint(x: snowCat.x + side * 1, y: snowCat.y - 27))
            ear.closeSubpath()
            context.fill(ear, with: .color(.white))
        }
        context.fill(Path(ellipseIn: CGRect(x: snowCat.x - 4, y: snowCat.y - 23, width: 2.5, height: 2.5)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: snowCat.x + 1.5, y: snowCat.y - 23, width: 2.5, height: 2.5)), with: .color(ink))
    }
}

/// Kulenin dibi: kapı, zemin (çimen, kum ya da kar) ve çalılar.
struct CatTowerBase: View {
    @Environment(\.appTheme) private var theme
    let tower: CatTowerTheme

    var body: some View {
        if let image = (theme.isDark ? tower.asset("base", variant: "night") : nil) ?? tower.asset("base") {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            GeometryReader { proxy in
                let w: CGFloat = proxy.size.width
                let h: CGFloat = proxy.size.height
                ZStack(alignment: .top) {
                    CatTowerWall(number: 0, tower: tower)
                        .frame(width: w - 52, height: h * 0.7)
                    CatTowerArch()
                        .fill(Color(hex: "#9C6B47"))
                        .overlay(CatTowerArch().stroke(Color(hex: "#6E4A30"), lineWidth: 3))
                        .frame(width: 56, height: h * 0.55)
                        .offset(y: h * 0.15)
                    Capsule()
                        .fill(groundColor)
                        .frame(width: w, height: h * 0.4)
                        .offset(y: h * 0.62)
                    HStack {
                        bush
                        Spacer()
                        bush
                    }
                    .padding(.horizontal, 18)
                    .offset(y: h * 0.45)
                }
                .frame(width: w, height: h)
            }
            .allowsHitTesting(false)
        }
    }

    private var groundColor: Color {
        switch tower.scenery {
        case .sea: Color(hex: "#F1DDB0")
        case .snow: Color.white
        case .night: theme.isDark ? Color(hex: "#3A4A5C") : Color(hex: "#9DBF9A")
        case .garden: theme.isDark ? Color(hex: "#3E5A44") : Color(hex: "#8CCB84")
        }
    }

    private var bush: some View {
        let flower = tower.flowers[0]
        let leaf: Color = tower.scenery == .snow ? Color(hex: "#5E8F74") : Color(hex: "#6FB877")
        return ZStack {
            Circle().fill(leaf.opacity(0.85)).frame(width: 34, height: 34).offset(x: -10)
            Circle().fill(leaf).frame(width: 40, height: 40)
            Circle().fill(flower).frame(width: 7, height: 7).offset(x: -6, y: -8)
            Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: 9, y: -2)
        }
    }
}

/// Kulenin arkasında sabit gökyüzü: binanın manzarasına göre şehir, deniz ya da karlı tepeler;
/// gece ay, yıldızlar ve ışıklı pencereler. Ay Işığı Konağı gündüz de alacakaranlıktadır.
struct CatTowerSky: View {
    @Environment(\.appTheme) private var theme
    let tower: CatTowerTheme

    var body: some View {
        let isNight = theme.isDark
        if let image = tower.asset(isNight ? "sky-night" : "sky") ?? tower.asset("sky") {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            let sky: [Color] = isNight ? tower.nightSky : tower.sky
            let scenery = tower.scenery
            let showStars = isNight || scenery == .night
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                var seed: UInt64 = 42
                func next() -> CGFloat {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                }
                if showStars {
                    for _ in 0..<60 {
                        let x: CGFloat = next() * size.width
                        let y: CGFloat = next() * size.height * 0.6
                        let r: CGFloat = 0.6 + next() * 1.4
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.4 + next() * 0.5)))
                    }
                    let moon = CGRect(x: size.width * 0.78, y: size.height * 0.08, width: 34, height: 34)
                    context.fill(Path(ellipseIn: moon), with: .color(Color(hex: "#FFE9A8")))
                    context.fill(Path(ellipseIn: moon.offsetBy(dx: 9, dy: -5)), with: .color(sky[0]))
                } else {
                    for _ in 0..<5 {
                        let x: CGFloat = next() * size.width
                        let y: CGFloat = next() * size.height * 0.45
                        let w: CGFloat = 60 + next() * 50
                        for k in 0..<3 {
                            let dx: CGFloat = CGFloat(k) * w * 0.3
                            let r: CGFloat = w * (k == 1 ? 0.32 : 0.24)
                            context.fill(Path(ellipseIn: CGRect(x: x + dx, y: y - r * 0.5, width: r * 2, height: r * 1.3)), with: .color(.white.opacity(0.75)))
                        }
                    }
                }
                switch scenery {
                case .sea:
                    // Deniz ufku ve güneş/ay yansıması
                    let horizon: CGFloat = size.height * 0.78
                    context.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)),
                                 with: .linearGradient(Gradient(colors: isNight ? [Color(hex: "#24507A"), Color(hex: "#163352")] : [Color(hex: "#6FC6E3"), Color(hex: "#3F9CC4")]),
                                                       startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)))
                    for i in 0..<12 {
                        let y: CGFloat = horizon + 8 + CGFloat(i) * 9
                        let x: CGFloat = next() * size.width
                        context.fill(Path(roundedRect: CGRect(x: x, y: y, width: 26, height: 2), cornerRadius: 1), with: .color(.white.opacity(0.4)))
                    }
                case .snow:
                    for i in 0..<3 {
                        let top: CGFloat = size.height * (0.72 + CGFloat(i) * 0.08)
                        let hill = Path(ellipseIn: CGRect(x: -size.width * 0.3 + CGFloat(i) * size.width * 0.35, y: top, width: size.width * 1.1, height: size.height * 0.5))
                        context.fill(hill, with: .color(isNight ? Color(hex: "#C9D6E8").opacity(0.85 - Double(i) * 0.1) : Color.white.opacity(0.95 - Double(i) * 0.1)))
                    }
                    for _ in 0..<70 {
                        let x: CGFloat = next() * size.width
                        let y: CGFloat = next() * size.height
                        let r: CGFloat = 1 + next() * 2
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
                    }
                case .garden, .night:
                    // Uzaktaki şehir silueti
                    var x: CGFloat = 0
                    let lit = isNight || scenery == .night
                    while x < size.width {
                        let w: CGFloat = 26 + next() * 34
                        let h: CGFloat = size.height * (0.1 + next() * 0.16)
                        let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                        let building: Color = lit ? Color(hex: "#2C2A55") : Color(hex: "#F4D9CF")
                        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(building))
                        if next() > 0.5 {
                            var roof = Path()
                            roof.move(to: CGPoint(x: x, y: size.height - h))
                            roof.addLine(to: CGPoint(x: x + w / 2, y: size.height - h - w * 0.45))
                            roof.addLine(to: CGPoint(x: x + w, y: size.height - h))
                            context.fill(roof, with: .color(lit ? Color(hex: "#3A3368") : Color(hex: "#EFC2B5")))
                        }
                        if lit {
                            for _ in 0..<3 {
                                let wx: CGFloat = x + 4 + next() * (w - 10)
                                let wy: CGFloat = size.height - h + 6 + next() * (h - 14)
                                context.fill(Path(CGRect(x: wx, y: wy, width: 4, height: 5)), with: .color(Color(hex: "#FFD27A").opacity(0.8)))
                            }
                        }
                        x += w + 4
                    }
                }
            }
        }
    }
}
