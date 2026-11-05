import NonogramKit
import SwiftUI

/// Yumak ve araba renkleri (8 renk; birbirinden kolay ayrılır).
enum YarnPalette {
    static let colors: [Color] = [
        Color(hex: "#F0506E"), // kırmızı
        Color(hex: "#3D9BE9"), // mavi
        Color(hex: "#F6B73C"), // sarı
        Color(hex: "#4CC38A"), // yeşil
        Color(hex: "#A970E8"), // mor
        Color(hex: "#FF8A3D"), // turuncu
        Color(hex: "#F27EC0"), // pembe
        Color(hex: "#3CC6C8"), // turkuaz
    ]

    static func color(_ index: Int) -> Color { colors[index % colors.count] }
}

/// Kodla çizilmiş yün yumağı: renkli küre, üstünde kıvrımlı iplikler ve küçük bir ucu.
struct YarnBallView: View {
    let color: Int
    var size: CGFloat = 26

    var body: some View {
        let tint = YarnPalette.color(color)
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.75), tint], center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 1, endRadius: size * 0.6))
            // İplik kıvrımları
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(.white.opacity(0.45), lineWidth: max(1, size * 0.05))
                    .frame(width: size * (0.9 - Double(i) * 0.18), height: size * 0.4)
                    .rotationEffect(.degrees(Double(i) * 55 - 30))
            }
            Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            // İpliğin ucu
            Capsule()
                .fill(tint)
                .frame(width: size * 0.32, height: max(1.5, size * 0.07))
                .rotationEffect(.degrees(25))
                .offset(x: size * 0.12, y: -size * 0.02)
        }
        .accessibilityHidden(true)
    }
}

/// Yukarıdan bakış kedi arabası (yukarı bakacak şekilde çizilir, yönüne döndürülür): yuvarlak
/// gövde, önde kedi kulakları ve farlar, ön camı ve tavanında koltuk sayısı.
struct YarnCarView: View {
    let color: Int
    let length: Int
    let seats: Int
    /// Kare boyu.
    let cell: CGFloat
    var direction: YarnDirection = .up
    var riders: Int? = nil

    var body: some View {
        let width = cell * 0.78
        let height = cell * CGFloat(length) - cell * 0.18
        car(width: width, height: height)
            .frame(width: width, height: height)
            .rotationEffect(angle)
            .frame(width: direction.isHorizontal ? height : width, height: direction.isHorizontal ? width : height)
    }

    private var angle: Angle {
        switch direction {
        case .up: .zero
        case .right: .degrees(90)
        case .down: .degrees(180)
        case .left: .degrees(-90)
        }
    }

    private func car(width: CGFloat, height: CGFloat) -> some View {
        let tint = YarnPalette.color(color)
        return ZStack(alignment: .top) {
            // Tekerlekler
            VStack {
                wheels(width: width)
                Spacer()
                wheels(width: width)
            }
            .padding(.vertical, height * 0.12)
            // Gövde
            RoundedRectangle(cornerRadius: width * 0.32, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.32, style: .continuous)
                        .strokeBorder(.black.opacity(0.18), lineWidth: 1.5)
                )
            // Kedi kulakları (önde)
            HStack {
                ear(width * 0.26, tint: tint)
                Spacer()
                ear(width * 0.26, tint: tint)
            }
            .padding(.horizontal, width * 0.04)
            .offset(y: -width * 0.16)
            // Ön cam
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(Color(hex: "#DFF3FF").opacity(0.95))
                .frame(width: width * 0.68, height: min(height * 0.2, width * 0.42))
                .padding(.top, width * 0.2)
            // Farlar
            HStack {
                Circle().fill(Color(hex: "#FFE08A")).frame(width: width * 0.14)
                Spacer()
                Circle().fill(Color(hex: "#FFE08A")).frame(width: width * 0.14)
            }
            .padding(.horizontal, width * 0.1)
            .padding(.top, width * 0.04)
            // Tavanda koltuk sayısı ya da binenler
            VStack {
                Spacer()
                Text(verbatim: riders.map { "\($0)/\(seats)" } ?? "\(seats)")
                    .font(.system(size: max(8, width * 0.3), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .rotationEffect(-angle)
                Spacer()
            }
            .padding(.top, height * 0.25)
        }
    }

    private func wheels(width: CGFloat) -> some View {
        HStack {
            Capsule().fill(Color(hex: "#3A3340")).frame(width: width * 0.16, height: width * 0.3)
            Spacer()
            Capsule().fill(Color(hex: "#3A3340")).frame(width: width * 0.16, height: width * 0.3)
        }
        .padding(.horizontal, -width * 0.06)
    }

    private func ear(_ size: CGFloat, tint: Color) -> some View {
        Triangle()
            .fill(tint)
            .overlay(Triangle().fill(Color(hex: "#FFC7D6")).scaleEffect(0.5, anchor: .bottom))
            .frame(width: size, height: size * 0.9)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Otopark: ızgara zemin ve arabalar. Dokunulan araba yönüne doğru çıkar.
struct YarnLotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let game: YarnTaxiGame
    var hintCar: Int?
    var guideCar: Int?
    var shakingCar: Int?
    var shakeID: Int
    let namespace: Namespace.ID
    let onTap: (YarnCar) -> Void

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / CGFloat(game.columns), proxy.size.height / CGFloat(game.rows))
            let width = cell * CGFloat(game.columns)
            let height = cell * CGFloat(game.rows)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#5E6472"))
                    .overlay(lines(cell: cell))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(hex: "#F6D365"), style: StrokeStyle(lineWidth: 3, dash: [10, 7]))
                    )
                ForEach(game.lot) { car in
                    let frame = frame(of: car, cell: cell)
                    YarnCarView(color: car.color, length: car.length, seats: car.seats, cell: cell, direction: car.direction)
                        .matchedGeometryEffect(id: car.id, in: namespace)
                        .overlay {
                            if car.id == hintCar || car.id == guideCar {
                                RoundedRectangle(cornerRadius: cell * 0.3)
                                    .strokeBorder(Gold.bright, lineWidth: 3)
                                    .shadow(color: Gold.bright, radius: 6)
                                    .padding(-4)
                            }
                        }
                        .modifier(YarnShake(amount: car.id == shakingCar && !reduceMotion ? CGFloat(shakeID) : 0))
                        .position(x: frame.midX, y: frame.midY)
                        .onTapGesture { onTap(car) }
                        .accessibilityElement()
                        .accessibilityLabel(Text("Car with \(car.seats) seats"))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("taxi.car.\(car.id)")
                }
                if let guideCar, let car = game.lot.first(where: { $0.id == guideCar }) {
                    let frame = frame(of: car, cell: cell)
                    PawPointer()
                        .position(x: frame.midX + 16, y: frame.midY + 26)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func frame(of car: YarnCar, cell: CGFloat) -> CGRect {
        let columns = car.direction.isHorizontal ? CGFloat(car.length) : 1
        let rows = car.direction.isHorizontal ? 1 : CGFloat(car.length)
        return CGRect(x: CGFloat(car.column) * cell, y: CGFloat(car.row) * cell, width: columns * cell, height: rows * cell)
    }

    private func lines(cell: CGFloat) -> some View {
        Canvas { context, size in
            var path = Path()
            for column in 1..<game.columns {
                let x = CGFloat(column) * cell
                path.move(to: CGPoint(x: x, y: 6))
                path.addLine(to: CGPoint(x: x, y: size.height - 6))
            }
            for row in 1..<game.rows {
                let y = CGFloat(row) * cell
                path.move(to: CGPoint(x: 6, y: y))
                path.addLine(to: CGPoint(x: size.width - 6, y: y))
            }
            context.stroke(path, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
        }
    }
}

/// Önü kapalı araba sallanır.
struct YarnShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(amount * .pi * 4), y: 0))
    }
}

/// Durak: yan yana yerler; gelen araba ve bindirdiği yumak sayısı.
struct YarnStationView: View {
    let game: YarnTaxiGame
    let namespace: Namespace.ID

    var body: some View {
        GeometryReader { proxy in
            let count = max(game.station.count, 1)
            let slot = min(proxy.size.width / CGFloat(count), proxy.size.height * 0.7)
            HStack(spacing: 0) {
                ForEach(Array(game.station.enumerated()), id: \.offset) { _, entry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .frame(width: slot * 0.82, height: proxy.size.height * 0.92)
                        if let entry {
                            YarnCarView(color: entry.car.color, length: min(entry.car.length, 2), seats: entry.car.seats,
                                        cell: slot * 0.62, riders: entry.riders)
                                .matchedGeometryEffect(id: entry.car.id, in: namespace)
                                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                    .frame(width: proxy.size.width / CGFloat(count), height: proxy.size.height)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Station: \(game.freeSlots) free places"))
    }
}

/// Yumak sırası: öndeki yumak büyük, arkadakiler küçülerek dizilir.
struct YarnQueueView: View {
    let game: YarnTaxiGame

    var body: some View {
        HStack(spacing: 4) {
            let upcoming = Array(game.queue[game.head...].prefix(12))
            ForEach(Array(upcoming.enumerated()), id: \.offset) { index, color in
                YarnBallView(color: color, size: index == 0 ? 34 : max(18, 28 - CGFloat(index)))
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
            Text(verbatim: "\(game.remainingYarns)")
                .font(.headline.weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.3)))
        }
        .animation(.spring(response: 0.35), value: game.head)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(game.remainingYarns) yarn balls waiting"))
    }
}

/// Ana sayfa kartının çizimi: yola çıkan kedi arabası ve arkasında yumaklar; araba hafifçe sallanır.
struct YarnTaxiCardArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.height * 0.62, proxy.size.width * 0.3)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    YarnBallView(color: [3, 2, 1][index], size: cell * 0.42)
                        .offset(y: bounce && index == 1 ? -3 : 0)
                }
                YarnCarView(color: 0, length: 2, seats: 4, cell: cell, direction: .right)
                    .offset(y: bounce ? -2 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
        }
        .accessibilityHidden(true)
    }
}
