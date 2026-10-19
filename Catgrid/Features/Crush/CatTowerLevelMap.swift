import NonogramKit
import SwiftUI

// Kedi Kulesi: Miyav Crush bölüm seçme ekranı. Her bölüm kulenin bir katı; katlar aşağıdan yukarı
// artan numarayla dizilir, oyuncu ilerledikçe kule yukarı uzar. Odalar, kediler ve süsler
// bileşenlerden çizilir; bölüm numarası, yıldızlar ve kilit ayrı arayüz parçalarıdır (görsele
// işlenmez), böylece aynı oda tasarımları yüzlerce bölümde tekrar kullanılır.
//
// Gerçek çizimler geldiğinde Assets'e şu adlarla eklenirse kendiliğinden kullanılır:
//   crush-tower-room-<1…n>  (oda içi, kedisiz ya da kedili; numara/yıldız olmadan)
//   crush-tower-roof, crush-tower-base, crush-tower-sky-day, crush-tower-sky-night

/// Bir katın durumu (mevcut ilerleme kurallarından türetilir).
enum CatTowerFloorState: Equatable {
    /// Kazanıldı; en iyi yıldız sayısı (1-3)
    case completed(stars: Int)
    /// Sıradaki (açık, henüz kazanılmamış) bölüm
    case current
    /// Açık ama sıradaki değil (ileride bölümler sırasız açılırsa)
    case open
    case locked

    var isPlayable: Bool { self != .locked }
}

/// Kuledeki tek kat.
struct CatTowerFloor: Identifiable, Equatable {
    let id: String
    /// 1'den başlayan bölüm numarası (bütün maceralar boyunca)
    let number: Int
    let state: CatTowerFloorState
}

extension CrushModel {
    /// Bir maceranın katları, alttan üste (1. kat ilk eleman).
    func towerFloors(episode: Int) -> [CatTowerFloor] {
        let current = currentLevel?.id
        return catalog.levels(in: episode).map { level in
            let stars = self.stars(for: level)
            let state: CatTowerFloorState
            if stars > 0 {
                state = .completed(stars: stars)
            } else if level.id == current {
                state = .current
            } else if isUnlocked(level) {
                state = .open
            } else {
                state = .locked
            }
            return CatTowerFloor(id: level.id, number: number(of: level), state: state)
        }
    }
}

/// Kule ayarı: yeni Kedi Kulesi ya da eski kıvrımlı yol haritası.
enum CatTowerFlag {
    static let classicMapKey = "crush.classicMap"

    /// Varsayılan kule; Ayarlar'da gizli anahtar ya da `-crushClassicMap` başlatma argümanıyla eski harita.
    static var isTowerEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("-crushClassicMap") { return false }
        return !UserDefaults.standard.bool(forKey: classicMapKey)
    }
}

/// Dikey kaydırılan kule. Katlar tembel çizilir (yüzlerce bölümde de akıcı).
@MainActor
struct CatTowerLevelMap: View {
    @Environment(\.appTheme) private var theme
    let floors: [CatTowerFloor]
    let episode: CrushEpisode
    let selectedID: String?
    /// Açılışta ve değişince ortalanacak kat.
    let focusID: String?
    let onSelect: (CatTowerFloor) -> Void
    let onPlay: (CatTowerFloor) -> Void
    let onLocked: (CatTowerFloor) -> Void

    @State private var viewportHeight: CGFloat = 0

    /// Görünen alanda yaklaşık 4,5 kat; çok küçük ve çok büyük ekranlarda sınırlı.
    private var floorHeight: CGFloat {
        guard viewportHeight > 0 else { return 132 }
        return min(176, max(112, viewportHeight / 4.4))
    }

    var body: some View {
        let height = floorHeight
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    CatTowerRoof(episode: episode)
                        .frame(height: height * 1.25)
                    ForEach(floors.reversed()) { floor in
                        CatTowerFloorView(
                            floor: floor,
                            episode: episode,
                            isSelected: floor.id == selectedID,
                            height: height,
                            onTap: { tap(floor) }
                        )
                        .frame(height: height)
                        .id(floor.id)
                    }
                    CatTowerBase()
                        .frame(height: height * 0.75)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .task(id: focusID) {
                guard let focusID else { return }
                // İlk düzen bitmeden yapılan kaydırma yok sayılabildiği için bir kare sonra tekrar
                proxy.scrollTo(focusID, anchor: .center)
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(focusID, anchor: .center) }
            }
        }
        .background { CatTowerSky().ignoresSafeArea() }
        .accessibilityIdentifier("crush.tower")
    }

    private func tap(_ floor: CatTowerFloor) {
        guard floor.state.isPlayable else {
            onLocked(floor)
            return
        }
        if floor.id == selectedID {
            onPlay(floor)
        } else {
            onSelect(floor)
        }
    }
}

// MARK: - Kat

/// Tek kat: taş duvar, kemerli oda (kedi ve süsler), çiçekli balkon, dışta merdiven ve fener,
/// sağda bölüm rozeti. Bütün kat tek dokunma alanıdır.
@MainActor
struct CatTowerFloorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let floor: CatTowerFloor
    let episode: CrushEpisode
    let isSelected: Bool
    let height: CGFloat
    let onTap: () -> Void

    private var isLocked: Bool { floor.state == .locked }
    private var isCurrent: Bool { floor.state == .current }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { proxy in
                let width: CGFloat = proxy.size.width
                let side: CGFloat = 26
                let wallWidth: CGFloat = width - side * 2
                let roomWidth: CGFloat = wallWidth * 0.64
                let balcony: CGFloat = height * 0.15
                ZStack(alignment: .topLeading) {
                    CatTowerStairs(number: floor.number, height: height, side: side)
                        .frame(width: width, height: height)
                    CatTowerWall(number: floor.number)
                        .frame(width: wallWidth, height: height)
                        .offset(x: side)
                    CatTowerRoom(floor: floor, episode: episode, isHighlighted: isCurrent || isSelected)
                        .frame(width: roomWidth, height: height - balcony - 10)
                        .offset(x: side + 12, y: 8)
                    CatTowerBalcony(number: floor.number, isLocked: isLocked)
                        .frame(width: wallWidth + 8, height: balcony)
                        .offset(x: side - 4, y: height - balcony)
                    if floor.number % 3 == 1 {
                        CatTowerLantern(isLit: theme.isDark && !isLocked)
                            .frame(width: 18, height: 34)
                            .offset(x: width - side - 2, y: height * 0.22)
                    }
                    CatTowerBadge(floor: floor, isSelected: isSelected, reduceMotion: reduceMotion)
                        .frame(width: wallWidth - roomWidth - 12, height: height - balcony)
                        .offset(x: side + roomWidth + 12, y: 0)
                }
            }
        }
        .buttonStyle(CatTowerFloorButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(floor.number)"))
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isLocked ? Text("Locked") : (isSelected ? Text("Double-tap to play") : Text("Double-tap to select")))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("crush.floor.\(floor.number)")
    }

    private var accessibilityValue: Text {
        switch floor.state {
        case .completed(let stars): Text("\(stars) of 3 stars")
        case .current, .open: Text(verbatim: "")
        case .locked: Text("Locked")
        }
    }
}

/// Kata basınca hafif çökme (kule kayarken kendiliğinden tetiklenmez).
private struct CatTowerFloorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.04 : 0)
            .contentShape(Rectangle())
    }
}

/// Krem taş duvar: sıcak degrade ve yatay/dikey taş derzleri.
struct CatTowerWall: View {
    @Environment(\.appTheme) private var theme
    let number: Int

    var body: some View {
        let top: Color = theme.isDark ? Color(hex: "#8C7A6B") : Color(hex: "#F6E7D2")
        let bottom: Color = theme.isDark ? Color(hex: "#76665A") : Color(hex: "#EBD5B8")
        let joint: Color = theme.isDark ? Color.black.opacity(0.18) : Color(hex: "#D9BE9C").opacity(0.7)
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
        }
        .overlay(alignment: .leading) {
            // Kulenin yuvarlaklığı: kenarlarda gölge
            LinearGradient(colors: [.black.opacity(0.12), .clear, .clear, .black.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

/// Kemerli oda: sıcak iç ışık, arka pencere, süsler ve kedi. Kilitliyse perdeler kapalı, soluk.
struct CatTowerRoom: View {
    @Environment(\.appTheme) private var theme
    let floor: CatTowerFloor
    let episode: CrushEpisode
    let isHighlighted: Bool

    private var isLocked: Bool { floor.state == .locked }

    /// Odanın kedisi (5 kedi, sırayla ve yansıtılarak çeşitlenir).
    private var catIndex: Int { (floor.number * 2 + floor.number / 5) % 5 + 1 }
    private var isFlipped: Bool { floor.number % 2 == 1 }

    /// Hareketli halleri (yalnızca seçili/aktif katta oynar).
    private static let loops = [LoopingCatAnimation.sleepyCat, LoopingCatAnimation.yarnCat, LoopingCatAnimation.cardsCat,
                                LoopingCatAnimation.crushCat, LoopingCatAnimation.dailyCat]

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = proxy.size
            let shape = CatTowerArch()
            ZStack(alignment: .bottom) {
                shape.fill(LinearGradient(colors: interiorColors, startPoint: .top, endPoint: .bottom))
                if let room = UIImage(named: "crush-tower-room-\((floor.number - 1) % 8 + 1)") {
                    Image(uiImage: room)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipShape(shape)
                } else {
                    CatTowerDecor(number: floor.number, size: size)
                        .clipShape(shape)
                }
                if isLocked {
                    CatTowerCurtains()
                        .clipShape(shape)
                } else {
                    cat(height: size.height * 0.62)
                        .padding(.bottom, size.height * 0.04)
                }
            }
            .overlay {
                shape.stroke(frameColor, lineWidth: isHighlighted ? 4 : 3)
            }
            .shadow(color: isHighlighted ? Color(hex: "#F0507E").opacity(0.45) : .clear, radius: 8)
            .saturation(isLocked ? 0.25 : 1)
            .opacity(isLocked ? 0.75 : 1)
        }
    }

    @ViewBuilder
    private func cat(height: CGFloat) -> some View {
        let loop = Self.loops[catIndex - 1]
        Group {
            if floor.state == .current, LoopingCatAnimation.isAvailable(loop) {
                LoopingCatView(name: loop)
            } else if let image = UIImage(named: "crush-tower-cat-\(catIndex)") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(height: height)
        .scaleEffect(x: isFlipped ? -1 : 1)
        .allowsHitTesting(false)
    }

    private var interiorColors: [Color] {
        if isLocked {
            return theme.isDark ? [Color(hex: "#4A4553"), Color(hex: "#3B3743")] : [Color(hex: "#E7E1E8"), Color(hex: "#D6CFD8")]
        }
        return theme.isDark
            ? [Color(hex: "#7A4E32"), Color(hex: "#A8683A"), Color(hex: "#C98A4E")]
            : [Color(hex: "#FFE9C7"), Color(hex: "#FFD9A6"), Color(hex: "#F6C287")]
    }

    private var frameColor: Color {
        if isHighlighted { return Color(hex: "#F0507E") }
        return theme.isDark ? Color(hex: "#5E4E42") : Color(hex: "#D8B892")
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

/// Oda süsleri: arka pencere ve sırayla seçilen iki eşya (kitaplık, yumak, yastık, bitki, oyuncak).
struct CatTowerDecor: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let size: CGSize

    enum Item: CaseIterable {
        case bookshelf, yarn, cushion, plant, toy
    }

    private var items: [Item] {
        let all = Item.allCases
        let first = all[number % all.count]
        let second = all[(number * 3 + 1) % all.count]
        return first == second ? [first] : [first, second]
    }

    var body: some View {
        let w: CGFloat = size.width
        let h: CGFloat = size.height
        ZStack(alignment: .topLeading) {
            // Arka duvardaki küçük kemerli pencere
            CatTowerArch()
                .fill(theme.isDark ? Color(hex: "#2E3A66") : Color(hex: "#CFE8F7"))
                .overlay(CatTowerArch().stroke(Color(hex: "#C8945E"), lineWidth: 2))
                .overlay {
                    Rectangle().fill(Color(hex: "#C8945E")).frame(width: 2)
                }
                .frame(width: w * 0.16, height: h * 0.36)
                .offset(x: number.isMultiple(of: 2) ? w * 0.72 : w * 0.1, y: h * 0.12)
            // Zemin
            Rectangle()
                .fill(theme.isDark ? Color(hex: "#6B4630") : Color(hex: "#E7B98A"))
                .frame(width: w, height: h * 0.14)
                .offset(y: h * 0.86)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                itemView(item)
                    .offset(x: index == 0 ? w * 0.04 : w * 0.76, y: h * 0.48)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    @ViewBuilder
    private func itemView(_ item: Item) -> some View {
        let unit: CGFloat = size.height * 0.36
        switch item {
        case .bookshelf:
            Image(systemName: "books.vertical.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Color(hex: "#9C6B47"), Color(hex: "#5C8D7A"))
                .frame(width: unit * 0.9, height: unit)
        case .yarn:
            ZStack {
                Circle().fill(Color(hex: "#F28AA8"))
                YarnGlyph().stroke(.white.opacity(0.8), lineWidth: 1.4).padding(unit * 0.08)
            }
            .frame(width: unit * 0.6, height: unit * 0.6)
            .offset(y: unit * 0.38)
        case .cushion:
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "#C8B6F0"), Color(hex: "#9F8AD8")], startPoint: .top, endPoint: .bottom))
                .frame(width: unit * 0.95, height: unit * 0.42)
                .offset(y: unit * 0.56)
        case .plant:
            VStack(spacing: -2) {
                Image(systemName: "leaf.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color(hex: "#5FA86B"))
                    .frame(width: unit * 0.6, height: unit * 0.55)
                Trapezoid()
                    .fill(Color(hex: "#D97C55"))
                    .frame(width: unit * 0.45, height: unit * 0.35)
            }
        case .toy:
            MouseGlyph()
                .fill(Color(hex: "#A889D6"))
                .frame(width: unit * 0.55, height: unit * 0.45)
                .offset(y: unit * 0.5)
        }
    }
}

/// Saksı.
struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.maxY))
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

/// Çiçekli balkon: taş korkuluk ve üstünde sarmaşık, pembe çiçekler.
struct CatTowerBalcony: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let isLocked: Bool

    var body: some View {
        Canvas { context, size in
            let ledge = Path(roundedRect: CGRect(x: 0, y: size.height * 0.25, width: size.width, height: size.height * 0.75), cornerRadius: 6)
            let stone: Color = theme.isDark ? Color(hex: "#9A8676") : Color(hex: "#F3E2CB")
            context.fill(ledge, with: .color(stone))
            context.stroke(ledge, with: .color(theme.isDark ? Color.black.opacity(0.25) : Color(hex: "#D9BE9C")), lineWidth: 1)
            guard !isLocked else { return }
            // Sarmaşık: bölüm numarasından tekrarlanabilir rastgele dizilim
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
            for _ in 0..<(count / 2) {
                let x: CGFloat = next() * size.width
                let y: CGFloat = size.height * (0.1 + next() * 0.3)
                let flower = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                context.fill(flower, with: .color(Color(hex: next() > 0.4 ? "#F49AB8" : "#FFFFFF")))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Kulenin dışında dönen taş merdiven: her katta bir yana tırmanan basamaklar.
struct CatTowerStairs: View {
    @Environment(\.appTheme) private var theme
    let number: Int
    let height: CGFloat
    let side: CGFloat

    var body: some View {
        Canvas { context, size in
            let step: Color = theme.isDark ? Color(hex: "#A08C7A") : Color(hex: "#EAD3B5")
            let edge: Color = theme.isDark ? Color.black.opacity(0.3) : Color(hex: "#CDAE88")
            let leftSide = number.isMultiple(of: 2)
            let x0: CGFloat = leftSide ? 2 : size.width - side - 2
            let steps = 6
            for i in 0..<steps {
                let t: CGFloat = CGFloat(i) / CGFloat(steps)
                let y: CGFloat = size.height * (0.9 - t * 0.85)
                let rect = CGRect(x: x0, y: y, width: side - 2, height: 7)
                let path = Path(roundedRect: rect, cornerRadius: 2)
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

// MARK: - Rozet

/// Bölüm rozeti: numara, üstte yıldızlar; aktifte pembe ve nefes alır, kilitlide gri ve kilitli.
struct CatTowerBadge: View {
    @Environment(\.appTheme) private var theme
    let floor: CatTowerFloor
    let isSelected: Bool
    let reduceMotion: Bool
    @State private var breathe = false

    private var isActive: Bool { floor.state == .current || isSelected }

    var body: some View {
        VStack(spacing: 2) {
            stars
                .frame(height: 18)
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(border, lineWidth: isActive ? 3 : 2)
                if floor.state == .locked {
                    VStack(spacing: 0) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(verbatim: "\(floor.number)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(Color(hex: "#8E8597"))
                } else {
                    Text(verbatim: "\(floor.number)")
                        .font(.system(size: floor.number >= 100 ? 22 : 26, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(isActive ? Color(hex: "#E2416F") : Color(hex: "#5A4636"))
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: 62, height: 62)
            .shadow(color: isActive ? Color(hex: "#F0507E").opacity(0.5) : .black.opacity(0.15), radius: isActive ? 10 : 4, y: 3)
            .scaleEffect(isActive && breathe ? 1.06 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isActive, initial: true) { _, active in
            guard active, !reduceMotion else {
                breathe = false
                return
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) { breathe = true }
        }
    }

    @ViewBuilder
    private var stars: some View {
        if case .completed(let count) = floor.state {
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: index == 1 ? 17 : 14, weight: .bold))
                        .foregroundStyle(index < count ? Gold.bright : Color.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .offset(y: index == 1 ? -3 : 0)
                }
            }
        } else {
            Color.clear
        }
    }

    private var fill: AnyShapeStyle {
        switch floor.state {
        case .locked:
            return AnyShapeStyle(Color(hex: "#E4DFE8"))
        default:
            if isActive {
                return AnyShapeStyle(LinearGradient(colors: [Color(hex: "#FFE3EC"), Color(hex: "#FFC3D5")], startPoint: .top, endPoint: .bottom))
            }
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: "#FFF8EE"), Color(hex: "#F2E2CC")], startPoint: .top, endPoint: .bottom))
        }
    }

    private var border: Color {
        if floor.state == .locked { return Color(hex: "#CFC7D6") }
        return isActive ? Color(hex: "#F0507E") : Color(hex: "#E2CBAE")
    }
}

// MARK: - Çatı, zemin ve gökyüzü

/// Mercan kiremitli konik çatı ve rüzgâr gülü.
struct CatTowerRoof: View {
    @Environment(\.appTheme) private var theme
    let episode: CrushEpisode

    var body: some View {
        if let image = UIImage(named: "crush-tower-roof") {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: .infinity, alignment: .bottom)
        } else {
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
                let colors: [Color] = roofColors
                context.fill(roof, with: .linearGradient(Gradient(colors: colors), startPoint: apex, endPoint: CGPoint(x: w / 2, y: base)))
                // Kiremit sıraları
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
                // Rüzgâr gülü
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

    private var roofColors: [Color] {
        switch episode.index {
        case 0: [Color(hex: "#F08A6C"), Color(hex: "#D9634A")]
        case 1: [Color(hex: "#E9A05F"), Color(hex: "#C7743A")]
        case 2: [Color(hex: "#8FA3E0"), Color(hex: "#5F73B8")]
        default: [Color(hex: "#F09AB5"), Color(hex: "#CF6F8F")]
        }
    }
}

/// Kulenin dibi: kapı, çimen ve çalılar.
struct CatTowerBase: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let image = UIImage(named: "crush-tower-base") {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            GeometryReader { proxy in
                let w: CGFloat = proxy.size.width
                let h: CGFloat = proxy.size.height
                ZStack(alignment: .top) {
                    CatTowerWall(number: 0)
                        .frame(width: w - 52, height: h * 0.7)
                    CatTowerArch()
                        .fill(Color(hex: "#9C6B47"))
                        .overlay(CatTowerArch().stroke(Color(hex: "#6E4A30"), lineWidth: 3))
                        .frame(width: 56, height: h * 0.55)
                        .offset(y: h * 0.15)
                    Capsule()
                        .fill(theme.isDark ? Color(hex: "#3E5A44") : Color(hex: "#8CCB84"))
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

    private var bush: some View {
        ZStack {
            Circle().fill(Color(hex: "#5FA86B")).frame(width: 34, height: 34).offset(x: -10)
            Circle().fill(Color(hex: "#6FB877")).frame(width: 40, height: 40)
            Circle().fill(Color(hex: "#F49AB8")).frame(width: 7, height: 7).offset(x: -6, y: -8)
            Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: 9, y: -2)
        }
    }
}

/// Kulenin arkasında sabit gökyüzü: gündüz bulutlar ve pastel şehir; gece ay, yıldızlar ve
/// ışıklı pencereler.
struct CatTowerSky: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        let name = theme.isDark ? "crush-tower-sky-night" : "crush-tower-sky-day"
        if let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Canvas { context, size in
                let isNight = theme.isDark
                let sky: [Color] = isNight
                    ? [Color(hex: "#1E2250"), Color(hex: "#3B3172"), Color(hex: "#6B4C8E")]
                    : [Color(hex: "#BFE4FA"), Color(hex: "#E7F1FB"), Color(hex: "#FFE4D2")]
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                var seed: UInt64 = 42
                func next() -> CGFloat {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                }
                if isNight {
                    for _ in 0..<60 {
                        let x: CGFloat = next() * size.width
                        let y: CGFloat = next() * size.height * 0.6
                        let r: CGFloat = 0.6 + next() * 1.4
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.4 + next() * 0.5)))
                    }
                    // Hilal
                    let moon = CGRect(x: size.width * 0.78, y: size.height * 0.08, width: 34, height: 34)
                    var moonContext = context
                    moonContext.fill(Path(ellipseIn: moon), with: .color(Color(hex: "#FFE9A8")))
                    moonContext.fill(Path(ellipseIn: moon.offsetBy(dx: 9, dy: -5)), with: .color(sky[0]))
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
                // Uzaktaki şehir silueti
                var x: CGFloat = 0
                while x < size.width {
                    let w: CGFloat = 26 + next() * 34
                    let h: CGFloat = size.height * (0.1 + next() * 0.16)
                    let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                    let building: Color = isNight ? Color(hex: "#2C2A55") : Color(hex: "#F4D9CF")
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(building))
                    if next() > 0.5 {
                        var roof = Path()
                        roof.move(to: CGPoint(x: x, y: size.height - h))
                        roof.addLine(to: CGPoint(x: x + w / 2, y: size.height - h - w * 0.45))
                        roof.addLine(to: CGPoint(x: x + w, y: size.height - h))
                        context.fill(roof, with: .color(isNight ? Color(hex: "#3A3368") : Color(hex: "#EFC2B5")))
                    }
                    if isNight {
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
