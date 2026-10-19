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
    /// Odalarda dolaşan kedilerin renkleri.
    var coats: [CatCoat] = []
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
        let tower = CatTowerTheme(index: episode.index)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Görselli çatı ve kule dibi kendi oranında, çizilenler sabit yükseklikte
                    // Görselli çatı en üst katın kornişine biraz biner, arada gökyüzü görünmez
                    CatTowerRoof(tower: tower)
                        .frame(height: tower.asset("roof") == nil ? height * 1.25 : nil)
                        .padding(.bottom, tower.asset("roof") == nil ? 0 : -6)
                        .zIndex(1)
                    ForEach(floors.reversed()) { floor in
                        CatTowerFloorView(
                            floor: floor,
                            tower: tower,
                            coats: coats,
                            isSelected: floor.id == selectedID,
                            height: height,
                            onTap: { tap(floor) }
                        )
                        .frame(height: height)
                        .id(floor.id)
                    }
                    // Görselli giriş, ilk katın odasının hemen altından başlar (katın alt kornişini örter)
                    CatTowerBase(tower: tower)
                        .frame(height: tower.asset("base") == nil ? height * 0.75 : nil)
                        .padding(.top, tower.asset("base") == nil ? 0 : -height * 0.15)
                        .zIndex(1)
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
        .background { CatTowerSky(tower: tower).ignoresSafeArea() }
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
    let tower: CatTowerTheme
    var coats: [CatCoat] = []
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
                let balcony: CGFloat = height * 0.15
                let plan = CatTowerRoomPlan.make(level: floor.number, tower: tower.index, counts: tower.counts)
                // Cephe görseli varsa kendi sütunları, sarmaşıkları ve kornişi var: çizilen merdiven ve
                // balkon eklenmez; oda soldaki sütunun yanından başlar (sütun görünür kalır)
                let hasFacade = tower.asset("facade") != nil
                let roomInset: CGFloat = hasFacade ? height * 0.22 : 12
                let roomWidth: CGFloat = wallWidth * 0.64 - (roomInset - 12) * 0.5
                let roomEnd: CGFloat = side + roomInset + roomWidth
                ZStack(alignment: .topLeading) {
                    if !hasFacade {
                        CatTowerStairs(number: floor.number, side: side, tower: tower)
                            .frame(width: width, height: height)
                    }
                    CatTowerWall(number: floor.number, tower: tower)
                        .frame(width: wallWidth, height: height)
                        .offset(x: side)
                    CatTowerRoom(floor: floor, plan: plan, tower: tower, isHighlighted: isCurrent || isSelected, coats: coats)
                        .frame(width: roomWidth, height: height - balcony - 10)
                        .offset(x: side + roomInset, y: 8)
                    if !hasFacade {
                        CatTowerBalcony(number: floor.number, isLocked: isLocked, tower: tower)
                            .frame(width: wallWidth + 8, height: balcony)
                            .offset(x: side - 4, y: height - balcony)
                    }
                    // Cephe görselinin kendi fenerleri var
                    if floor.number % 3 == 1 && !hasFacade {
                        CatTowerLantern(isLit: theme.isDark && !isLocked)
                            .frame(width: 18, height: 34)
                            .offset(x: width - side - 2, y: height * 0.22)
                    }
                    CatTowerBadge(floor: floor, isSelected: isSelected, reduceMotion: reduceMotion)
                        .frame(width: side + wallWidth - roomEnd, height: height - balcony)
                        .offset(x: roomEnd, y: 0)
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
