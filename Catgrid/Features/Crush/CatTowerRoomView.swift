import NonogramKit
import SwiftUI

/// Katmanlı oda: arka duvar → pencere → zemin → halı → ana mobilya → aksesuarlar → dolaşan kedi. Her katman
/// binanın görsel setinden (varsa) ya da kodla çizilen yedekten gelir; yerleri sabit yuvalardır,
/// böylece nesneler çakışmaz ve kedi hep mobilyanın üstünde durur.
@MainActor
struct CatTowerRoom: View {
    @Environment(\.appTheme) private var theme
    let floor: CatTowerFloor
    let plan: CatTowerRoomPlan
    let tower: CatTowerTheme
    let isHighlighted: Bool
    /// Odalarda dolaşan kedilerin renkleri (kedi türlerinden).
    var coats: [CatCoat] = []

    private var isLocked: Bool { floor.state == .locked }
    private var hasWallArt: Bool {
        (plan.kind == .milestone && tower.asset("special") != nil) || tower.asset("wall", plan.wall + 1) != nil
    }
    /// Pencere sağda mı (duvar rafı karşı tarafta durur).
    private var windowOnRight: Bool { plan.window % 2 == 0 }

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            let shape = CatTowerArch()
            ZStack(alignment: .topLeading) {
                wallLayer(size: size)
                // Görsel duvarlar zemini de içerir
                if !hasWallArt {
                    floorLayer(size: size)
                }
                if !isLocked {
                    rugLayer(size: size)
                    furnitureLayer(size: size)
                    accessoryLayer(size: size)
                    catLayer(size: size)
                }
                if plan.kind != .normal && !isLocked {
                    CatTowerBunting(colors: tower.flowers + [tower.furniture[0]], isMilestone: plan.kind == .milestone)
                        .frame(width: size.width, height: size.height * 0.2)
                }
                if isLocked {
                    CatTowerCurtains()
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(shape)
            .overlay {
                shape.stroke(frameColor, lineWidth: isHighlighted || plan.kind == .milestone ? 4 : 3)
            }
            .shadow(color: isHighlighted ? Color(hex: "#F0507E").opacity(0.45) : .clear, radius: 8)
            .saturation(isLocked ? 0.25 : 1)
            .opacity(isLocked ? 0.78 : 1)
        }
    }

    // MARK: - Katmanlar

    @ViewBuilder
    private func wallLayer(size: CGSize) -> some View {
        if plan.kind == .milestone, let special = tower.asset("special") {
            Image(uiImage: special).resizable().scaledToFill().frame(width: size.width, height: size.height)
        } else if let wall = tower.asset("wall", plan.wall + 1) {
            // Görsel duvarlar pencereyi ve zemini de içerir. Gece: varsa gece sürümü (pencerede ay ve
            // yıldızlar), yoksa gündüz görseli karartılır.
            let night = theme.isDark ? tower.asset("wall", plan.wall + 1, variant: "night") : nil
            Image(uiImage: night ?? wall).resizable().scaledToFill().frame(width: size.width, height: size.height)
                .overlay(Color(hex: "#2A1C3A").opacity(theme.isDark ? (night == nil ? 0.28 : 0.12) : 0))
        } else {
            let paper = tower.wallpapers[plan.wall % tower.wallpapers.count]
            ZStack(alignment: .topLeading) {
                CatTowerWallpaper(base: paper.base, pattern: paper.pattern, style: plan.wall % 3, isNight: theme.isDark)
                CatTowerWindow(scenery: tower.scenery, style: plan.window % 3, isNight: theme.isDark || tower.scenery == .night)
                    .frame(width: size.width * 0.2, height: size.height * 0.42)
                    .offset(x: windowOnRight ? size.width * 0.72 : size.width * 0.08, y: size.height * 0.12)
                // Sıcak oda ışığı
                RadialGradient(colors: [Color(hex: "#FFE3A8").opacity(theme.isDark ? 0.45 : 0.35), .clear],
                               center: .init(x: 0.5, y: 0.35), startRadius: 0, endRadius: size.width * 0.6)
            }
        }
    }

    private func floorLayer(size: CGSize) -> some View {
        let color = tower.floors[plan.floor % tower.floors.count]
        return CatTowerFloorBoards(color: color, isNight: theme.isDark)
            .frame(width: size.width, height: size.height * 0.2)
            .offset(y: size.height * 0.8)
    }

    /// Mobilyanın kapladığı alan (kedi bunun üstüne oturur).
    private func furnitureFrame(_ size: CGSize) -> CGRect {
        let w: CGFloat = size.width * 0.5
        let h: CGFloat = size.height * 0.36
        return CGRect(x: (size.width - w) / 2, y: size.height * 0.86 - h, width: w, height: h)
    }

    /// Halı: katların çoğunda mobilyanın altında (görsel set varsa).
    @ViewBuilder
    private func rugLayer(size: CGSize) -> some View {
        if let count = tower.assetCount("rug"), (floor.number * 7) % 10 < 7,
           let rug = tower.asset("rug", (floor.number * 3 + plan.floor) % count + 1) {
            Image(uiImage: rug)
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 0.6, height: size.height * 0.16)
                .offset(x: size.width * 0.2, y: size.height * 0.79)
        }
    }

    @ViewBuilder
    private func furnitureLayer(size: CGSize) -> some View {
        let rect = furnitureFrame(size)
        Group {
            if let image = tower.asset("furniture", plan.furniture + 1) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                CatTowerFurniture(kind: plan.furniture % 3, color: tower.furniture[plan.furniture % tower.furniture.count])
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .bottom)
        .offset(x: rect.minX, y: rect.minY)
    }

    private func accessoryLayer(size: CGSize) -> some View {
        let item: CGFloat = size.height * 0.24
        // Karlı Pati Kuleleri'nde iki yan da cam (gece): duvar süsü asılacak yer yok
        let skipWall = hasWallArt && tower.key == "snow"
        let entries = plan.accessories
            .filter { !(skipWall && $0.key == .wall) }
            .sorted { $0.key.rawValue < $1.key.rawValue }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                accessory(entry.value, size: item, onShelf: entry.key == .wall)
                    .offset(accessoryOffset(entry.key, size: size, item: item))
            }
        }
    }

    private func accessoryOffset(_ slot: CatTowerRoomPlan.Slot, size: CGSize, item: CGFloat) -> CGSize {
        switch slot {
        case .left:
            return CGSize(width: size.width * 0.04, height: size.height * 0.86 - item)
        case .right:
            return CGSize(width: size.width * 0.96 - item, height: size.height * 0.86 - item)
        case .wall:
            // Görselli odalarda pencere ortada: raf yan duvarda. Rezidansta sağ taraf
            // camla kaplı olduğundan süs sol duvara asılır.
            if hasWallArt {
                let x = tower.key == "seaside" ? size.width * 0.05 : size.width * 0.9 - item
                return CGSize(width: x, height: size.height * 0.22)
            }
            return CGSize(width: windowOnRight ? size.width * 0.1 : size.width * 0.9 - item, height: size.height * 0.16)
        }
    }

    @ViewBuilder
    private func accessory(_ index: Int, size: CGFloat, onShelf: Bool) -> some View {
        if onShelf, let count = tower.assetCount("wallitem"), let item = tower.asset("wallitem", index % count + 1) {
            // Duvar süsü (çerçeve, flama, raf): kendi askısı var, ayrıca raf çizilmez
            Image(uiImage: item)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.85, height: size * 0.85)
        } else {
            floorAccessory(index, size: size, onShelf: onShelf)
        }
    }

    @ViewBuilder
    private func floorAccessory(_ index: Int, size: CGFloat, onShelf: Bool) -> some View {
        VStack(spacing: 0) {
            if let image = tower.asset("accessory", index + 1) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                let item = tower.accessories[index % tower.accessories.count]
                Image(systemName: item.symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(item.color)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(size * 0.1)
            }
            if onShelf {
                // Raf
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#B07E55"))
                    .frame(height: 4)
            }
        }
        .frame(width: size, height: size + (onShelf ? 4 : 0))
    }

    private func catLayer(size: CGSize) -> some View {
        // Odada dolaşan piksel kedi; rengi katın türünden (tür portreleri)
        let coat = coats.isEmpty ? CatCoat.ginger : coats[(floor.number * 5 + plan.cat) % coats.count]
        return CatTowerPixelCat(coat: coat, room: size, seat: furnitureFrame(size), seed: floor.number)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var frameColor: Color {
        if isHighlighted { return Color(hex: "#F0507E") }
        if plan.kind == .milestone && !isLocked { return Gold.mid }
        return theme.isDark ? Color(hex: "#5E4E42") : Color(hex: "#D8B892")
    }
}

// MARK: - Çizim yedekleri

/// Duvar kâğıdı: puantiye, çizgili ya da baklava desen; altta lambri.
struct CatTowerWallpaper: View {
    let base: Color
    let pattern: Color
    let style: Int
    let isNight: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let wainscot: CGFloat = size.height * 0.5
            switch style {
            case 0:
                var y: CGFloat = 8
                var row = 0
                while y < wainscot {
                    var x: CGFloat = row.isMultiple(of: 2) ? 6 : 16
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)), with: .color(pattern))
                        x += 20
                    }
                    y += 14
                    row += 1
                }
            case 1:
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 6, height: wainscot)), with: .color(pattern.opacity(0.7)))
                    x += 16
                }
            default:
                var y: CGFloat = 0
                while y < wainscot {
                    var x: CGFloat = 0
                    while x < size.width {
                        var diamond = Path()
                        diamond.move(to: CGPoint(x: x + 8, y: y))
                        diamond.addLine(to: CGPoint(x: x + 14, y: y + 8))
                        diamond.addLine(to: CGPoint(x: x + 8, y: y + 16))
                        diamond.addLine(to: CGPoint(x: x + 2, y: y + 8))
                        diamond.closeSubpath()
                        context.stroke(diamond, with: .color(pattern), lineWidth: 1)
                        x += 16
                    }
                    y += 16
                }
            }
            // Lambri
            let panel = CGRect(x: 0, y: wainscot, width: size.width, height: size.height - wainscot)
            context.fill(Path(panel), with: .color(pattern.opacity(0.55)))
            var rail = Path()
            rail.move(to: CGPoint(x: 0, y: wainscot))
            rail.addLine(to: CGPoint(x: size.width, y: wainscot))
            context.stroke(rail, with: .color(Color(hex: "#B07E55").opacity(0.7)), lineWidth: 3)
            if isNight {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#3A2440").opacity(0.25)))
            }
        }
    }
}

/// Pencere: kemerli, yuvarlak ya da ikiz; içinde binanın manzarası.
struct CatTowerWindow: View {
    let scenery: CatTowerTheme.Scenery
    let style: Int
    let isNight: Bool

    var body: some View {
        ZStack {
            view
                .clipShape(windowShape)
            windowShape.stroke(Color(hex: "#B07E55"), lineWidth: 3)
            // Kayıt
            Rectangle().fill(Color(hex: "#B07E55")).frame(width: 2)
            if style != 1 {
                Rectangle().fill(Color(hex: "#B07E55")).frame(height: 2)
            }
        }
    }

    private var windowShape: AnyShape {
        switch style {
        case 1: AnyShape(Circle())
        case 2: AnyShape(RoundedRectangle(cornerRadius: 6))
        default: AnyShape(CatTowerArch())
        }
    }

    @ViewBuilder
    private var view: some View {
        GeometryReader { proxy in
            let w: CGFloat = proxy.size.width
            let h: CGFloat = proxy.size.height
            ZStack(alignment: .bottom) {
                LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                switch scenery {
                case .garden:
                    Ellipse().fill(Color(hex: isNight ? "#3E6A4F" : "#9FD18F")).frame(width: w * 1.6, height: h * 0.5).offset(y: h * 0.2)
                case .night:
                    Circle().fill(Color(hex: "#FFE9A8")).frame(width: w * 0.32).offset(x: w * 0.15, y: -h * 0.5)
                case .sea:
                    Rectangle().fill(Color(hex: isNight ? "#2C5C8A" : "#5FB7D9")).frame(height: h * 0.35)
                case .snow:
                    Ellipse().fill(Color.white).frame(width: w * 1.6, height: h * 0.45).offset(y: h * 0.2)
                }
            }
        }
    }

    private var skyColors: [Color] {
        if isNight { return [Color(hex: "#1E2250"), Color(hex: "#4A3A7A")] }
        switch scenery {
        case .sea: return [Color(hex: "#9ED9F5"), Color(hex: "#E2F5FC")]
        case .snow: return [Color(hex: "#CFE3F2"), Color(hex: "#F4F9FC")]
        default: return [Color(hex: "#BFE4FA"), Color(hex: "#EAF6FD")]
        }
    }
}

/// Ahşap zemin: tahta çizgileri ve ortada halı.
struct CatTowerFloorBoards: View {
    let color: Color
    let isNight: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color))
            var x: CGFloat = 0
            while x < size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x - 6, y: size.height))
                context.stroke(line, with: .color(.black.opacity(0.1)), lineWidth: 1)
                x += 22
            }
            let rug = CGRect(x: size.width * 0.22, y: size.height * 0.2, width: size.width * 0.56, height: size.height * 0.6)
            context.fill(Path(ellipseIn: rug), with: .color(.white.opacity(0.3)))
            if isNight {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.15)))
            }
        }
    }
}

/// Ana mobilya (çizim yedeği): koltuk, kedi yatağı ya da minder yığını.
struct CatTowerFurniture: View {
    let kind: Int
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let w: CGFloat = proxy.size.width
            let h: CGFloat = proxy.size.height
            switch kind {
            case 0:
                // Koltuk: arkalık, oturak, kolçaklar, ayaklar
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: h * 0.25).fill(color).frame(width: w * 0.86, height: h * 0.75).offset(y: -h * 0.15)
                    RoundedRectangle(cornerRadius: h * 0.2).fill(color.opacity(0.85)).frame(width: w, height: h * 0.45).offset(y: -h * 0.08)
                    RoundedRectangle(cornerRadius: h * 0.18).fill(.white.opacity(0.25)).frame(width: w * 0.7, height: h * 0.18).offset(y: -h * 0.3)
                    HStack {
                        Rectangle().fill(Color(hex: "#8A5A3C")).frame(width: 4, height: h * 0.1)
                        Spacer()
                        Rectangle().fill(Color(hex: "#8A5A3C")).frame(width: 4, height: h * 0.1)
                    }
                    .padding(.horizontal, w * 0.1)
                }
            case 1:
                // Yuvarlak kedi yatağı
                ZStack(alignment: .bottom) {
                    Ellipse().fill(color).frame(width: w * 0.9, height: h * 0.6)
                    Ellipse().fill(.white.opacity(0.45)).frame(width: w * 0.66, height: h * 0.32).offset(y: -h * 0.16)
                }
            default:
                // Minder yığını
                VStack(spacing: -h * 0.08) {
                    Capsule().fill(color.opacity(0.85)).frame(width: w * 0.62, height: h * 0.3)
                    Capsule().fill(color).frame(width: w * 0.86, height: h * 0.36)
                }
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
    }
}

/// Özel katlarda bayrak süsü; dönüm noktasında altın yıldızlı.
struct CatTowerBunting: View {
    let colors: [Color]
    let isMilestone: Bool

    var body: some View {
        Canvas { context, size in
            var rope = Path()
            rope.move(to: CGPoint(x: 0, y: size.height * 0.2))
            rope.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.2), control: CGPoint(x: size.width / 2, y: size.height * 0.75))
            context.stroke(rope, with: .color(Color(hex: "#B07E55")), lineWidth: 1.5)
            let count = 9
            for i in 1..<count {
                let t: CGFloat = CGFloat(i) / CGFloat(count)
                let x: CGFloat = size.width * t
                let y: CGFloat = size.height * 0.2 + (size.height * 0.55) * 4 * t * (1 - t) * 0.5
                var flag = Path()
                flag.move(to: CGPoint(x: x - 6, y: y))
                flag.addLine(to: CGPoint(x: x + 6, y: y))
                flag.addLine(to: CGPoint(x: x, y: y + 12))
                flag.closeSubpath()
                let color: Color = isMilestone && i.isMultiple(of: 2) ? Gold.bright : colors[i % colors.count]
                context.fill(flag, with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Kemerli açıklık: düz alt, yuvarlak üst köşeler.
struct CatTowerArch: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = min(rect.width, rect.height) * 0.38
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Kilitli odada kapalı perdeler.
struct CatTowerCurtains: View {
    var body: some View {
        GeometryReader { proxy in
            let w: CGFloat = proxy.size.width
            HStack(spacing: 0) {
                LinearGradient(colors: [Color(hex: "#CFC4D6"), Color(hex: "#B7AABF")], startPoint: .leading, endPoint: .trailing)
                    .frame(width: w / 2)
                LinearGradient(colors: [Color(hex: "#B7AABF"), Color(hex: "#CFC4D6")], startPoint: .leading, endPoint: .trailing)
                    .frame(width: w / 2)
            }
            .overlay {
                HStack(spacing: w / 8) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle().fill(.black.opacity(0.05)).frame(width: 2)
                    }
                }
            }
        }
    }
}
