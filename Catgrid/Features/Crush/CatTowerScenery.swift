import NonogramKit
import SwiftUI

// Kedi Kulesi dış görünümü: taş duvar, balkon, merdiven, fener, çatı, kule dibi ve gökyüzü.
// Renkler ve manzara binaya göre (CatTowerTheme), gündüz/gece uygulamanın temasına göre değişir.

/// Taş duvar: binanın taş rengi, tuğla derzleri ve yuvarlaklık gölgesi.
struct CatTowerWall: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let tower: CatTowerTheme

    var body: some View {
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

/// Konik kiremit çatı ve rüzgâr gülü (karlı binada kar örtüsü).
struct CatTowerRoof: View {
    let tower: CatTowerTheme

    var body: some View {
        if let image = tower.asset("roof") {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: .infinity, alignment: .bottom)
        } else {
            let colors: [Color] = tower.roof
            let isSnow = tower.scenery == .snow
            Canvas { context, size in
                let w: CGFloat = size.width
                let h: CGFloat = size.height
                let base: CGFloat = h * 0.92
                let apex = CGPoint(x: w / 2, y: h * 0.18)
                var roof = Path()
                roof.move(to: apex)
                roof.addLine(to: CGPoint(x: w - 10, y: base))
                roof.addQuadCurve(to: CGPoint(x: 10, y: base), control: CGPoint(x: w / 2, y: base + h * 0.1))
                roof.closeSubpath()
                context.fill(roof, with: .linearGradient(Gradient(colors: colors), startPoint: apex, endPoint: CGPoint(x: w / 2, y: base)))
                var clipped = context
                clipped.clip(to: roof)
                var y: CGFloat = apex.y + 12
                while y < base + 10 {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addQuadCurve(to: CGPoint(x: w, y: y), control: CGPoint(x: w / 2, y: y + 10))
                    clipped.stroke(line, with: .color(.black.opacity(0.12)), lineWidth: 1.5)
                    y += 13
                }
                if isSnow {
                    var cap = Path()
                    cap.move(to: apex)
                    cap.addLine(to: CGPoint(x: w / 2 + w * 0.12, y: apex.y + h * 0.2))
                    cap.addQuadCurve(to: CGPoint(x: w / 2 - w * 0.12, y: apex.y + h * 0.2), control: CGPoint(x: w / 2, y: apex.y + h * 0.28))
                    cap.closeSubpath()
                    clipped.fill(cap, with: .color(.white))
                }
                var pole = Path()
                pole.move(to: apex)
                pole.addLine(to: CGPoint(x: apex.x, y: apex.y - h * 0.14))
                context.stroke(pole, with: .color(Color(hex: "#5B4A3E")), lineWidth: 2)
                var arrow = Path()
                arrow.move(to: CGPoint(x: apex.x - 14, y: apex.y - h * 0.1))
                arrow.addLine(to: CGPoint(x: apex.x + 14, y: apex.y - h * 0.1))
                arrow.addLine(to: CGPoint(x: apex.x + 8, y: apex.y - h * 0.13))
                context.stroke(arrow, with: .color(Color(hex: "#5B4A3E")), lineWidth: 2)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Kulenin dibi: kapı, zemin (çimen, kum ya da kar) ve çalılar.
struct CatTowerBase: View {
    @Environment(\.appTheme) private var theme
    let tower: CatTowerTheme

    var body: some View {
        if let image = tower.asset("base") {
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
