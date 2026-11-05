import NonogramKit
import SwiftUI

/// Yumak Taksi haritası: üstte mahalleler, ortada mahallenin 75 bölümü kıvrımlı bir yol üstünde
/// (1. bölüm en altta), altta "Oyna". Açılışta kalınan bölüm ortalanır.
@MainActor
struct YarnTaxiHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var district = 0

    private var taxi: YarnTaxiModel { model.taxi }

    var body: some View {
        VStack(spacing: 0) {
            districtPicker
                .padding(.top, 6)
            GeometryReader { proxy in
                path(width: proxy.size.width, viewport: proxy.size.height)
            }
            .id(district)
            footer
        }
        .background(LinearGradient(colors: ModeStyle.taxi.backgroundColors(theme), startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BirdSortRoundButton(symbol: "chevron.left") { router.pop() }
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("taxi.hub.back")
            }
            ToolbarItem(placement: .principal) {
                BirdSortTitleCapsule(title: Text("Yarn Taxi"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Gold.mid)
                    Text(verbatim: "\(taxi.totalStars)")
                }
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(theme.surface.opacity(0.95)))
            }
        }
        .onAppear { district = taxi.selectedDistrict ?? taxi.currentDistrict }
        .onChange(of: district) { _, new in taxi.selectedDistrict = new }
    }

    private var districtPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(YarnTaxiDistrict.all) { item in
                    let unlocked = taxi.isDistrictUnlocked(item.index)
                    Button {
                        guard unlocked else { return }
                        Haptics.selection()
                        district = item.index
                    } label: {
                        HStack(spacing: 5) {
                            if !unlocked { Image(systemName: "lock.fill") }
                            Text(item.title)
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(district == item.index ? .white : theme.textPrimary.opacity(unlocked ? 1 : 0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(district == item.index ? ModeStyle.taxi.tint(theme) : theme.surface.opacity(0.9)))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("taxi.district.\(item.index + 1)")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Bölümler yukarı doğru zikzak çizer; aralarında yol.
    private func path(width: CGFloat, viewport: CGFloat) -> some View {
        let range = taxi.districtRange(district)
        let spacing: CGFloat = 92
        let content = spacing * CGFloat(range.count) + 80
        let points: [CGPoint] = range.map { number in
            let index = number - range.lowerBound
            let x = width * (0.5 + 0.28 * sin(Double(index) * 0.9))
            return CGPoint(x: x, y: content - 60 - CGFloat(index) * spacing)
        }
        let current = taxi.currentLevel
        let reached = current > range.upperBound ? points.count - 1 : (range.contains(current) ? current - range.lowerBound : 0)
        let target = range.contains(current) ? current - range.lowerBound : 0
        let anchorY = content > viewport ? min(max((points[target].y - viewport / 2) / (content - viewport), 0), 1) : 1
        return ScrollView(showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                BirdSortRoad(points: points, reached: reached)
                ForEach(Array(range), id: \.self) { number in
                    BirdSortLevelNode(number: number, stars: taxi.stars(for: number), isUnlocked: taxi.isUnlocked(number),
                                      isCurrent: number == current, tint: ModeStyle.taxi.tint(theme)) {
                        router.push(.taxiGame(level: number))
                    }
                    .position(points[number - range.lowerBound])
                    .accessibilityIdentifier("taxi.level.\(number)")
                }
            }
            .frame(width: width, height: content, alignment: .topLeading)
        }
        .defaultScrollAnchor(UnitPoint(x: 0.5, y: anchorY))
    }

    private var footer: some View {
        Button {
            router.push(.taxiGame(level: taxi.currentLevel))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Play Level \(taxi.currentLevel)")
            }
            .font(.title3.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFB347"), Color(hex: "#F07A3C")], startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 2))
            .shadow(color: Color(hex: "#C25A1E").opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .accessibilityIdentifier("taxi.hub.play")
    }
}
