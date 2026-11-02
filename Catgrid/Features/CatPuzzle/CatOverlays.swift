import NonogramKit
import SwiftUI

/// 1. bölümde Muffin'in adımları.
enum CatTutorialStep: Equatable {
    /// İlk kedi: tek kareli renk.
    case first(GridPosition)
    /// "?" ipucuyla ilk kedinin etki alanını X'le.
    case useHint
    /// İkinci kedi: X'lerden sonra tek seçeneğe inen renk.
    case second(GridPosition)
    /// Kedi bulucuyu tanıt.
    case finder
    case freePlay

    var pointer: GridPosition? {
        switch self {
        case .first(let position), .second(let position): position
        case .useHint, .finder, .freePlay: nil
        }
    }

    /// Muffin'in kısa cümlesi. `catToolReady`: Kedi aracı seçili mi (değilse önce onu seçtirir).
    func message(catToolReady: Bool) -> LocalizedStringResource {
        switch self {
        case .first:
            catToolReady
                ? "Now tap the glowing square!"
                : "This color is just one square, so its cat is here. Pick the Cat tool below!"
        case .useHint:
            "You found a cat! Tap ? and I'll cross out the squares where no cat can be."
        case .second:
            catToolReady
                ? "This color has one free square left. Tap it!"
                : "Pick the Cat tool and tap the glowing square."
        case .finder:
            "Stuck? The cat button shows where a cat is hiding."
        case .freePlay:
            "Your turn! Shortcut: double-tap a square to place a cat."
        }
    }

    /// Bu adımda Kedi aracıyla bir kareye dokunulmalı mı?
    var needsCatTool: Bool {
        switch self {
        case .first, .second: true
        default: false
        }
    }
}

@MainActor
struct CatTutorialBanner: View {
    @Environment(\.appTheme) private var theme
    let step: CatTutorialStep
    var catToolReady = false
    @State private var speech = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MuffinView(pose: step == .freePlay ? .cheer : .point, speechID: speech)
                .frame(width: 64, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(step.message(catToolReady: catToolReady))
                if step == .freePlay {
                    DoubleTapDemo()
                }
            }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SpeechBubble().fill(theme.surface).shadow(color: theme.cardShadow, radius: 8, y: 2))
        }
        .onChange(of: step) { _, _ in speech += 1 }
        .onChange(of: catToolReady) { _, _ in speech += 1 }
        .animation(.snappy, value: step)
    }
}

/// Bölüm bitince: Muffin kutlar, başlık sonuca göre değişir.
@MainActor
struct CatResultOverlay: View {
    @Environment(\.appTheme) private var theme
    let result: CatResult
    let next: CatLevel?
    let onNext: (CatLevel) -> Void
    let onLevels: () -> Void
    @State private var appeared = false

    private var completion: CatPuzzleModel.Completion { result.completion }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            // Arkada dönen ışık hüzmeleri
            RaysView()
                .opacity(appeared ? 0.55 : 0)
                .frame(width: 520, height: 520)
                .offset(y: -90)
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                title
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 1, green: 0.5, blue: 0.15)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
                    .scaleEffect(appeared ? 1 : 0.4)
                MuffinView(pose: .cheer, speechID: 1)
                    .frame(height: 200)
                message
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                HStack(spacing: 18) {
                    Label {
                        Text(completion.score, format: .number)
                    } icon: {
                        Image(systemName: "star.fill")
                    }
                    Label {
                        Text(Duration.seconds(completion.elapsed), format: .time(pattern: .minuteSecond))
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                if !result.newBadges.isEmpty {
                    Label {
                        Text("New badge: \(result.newBadges.map { String(localized: $0.title) }.joined(separator: ", "))")
                    } icon: {
                        Image(systemName: "rosette")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(Gold.bright)
                }
                VStack(spacing: 10) {
                    if let next {
                        Button {
                            onNext(next)
                        } label: {
                            Text("Level \(nextNumber)")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("cat.result.next")
                    }
                    Button("All Levels", action: onLevels)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 440)
        }
        // Sonucu paylaş: bölümün renkli tahtası, numarası ve puanı
        .overlay(alignment: .topTrailing) {
            ShareResultButton(
                headline: Text(BadgeMode.cats.title) + Text(verbatim: " · ") + Text("Level \(levelNumber)")
                    + Text(verbatim: " · ★ ") + Text(completion.score, format: .number),
                style: .dark
            ) {
                CatLevelPreview(level: completion.level)
            }
            .padding(.trailing, 18)
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
    }

    /// Bu bölümün numarası (bölümler `cat-001` biçiminde).
    private var levelNumber: Int {
        Int(completion.level.id.split(separator: "-").last ?? "") ?? 0
    }

    /// Bir sonraki bölümün numarası (bölümler `cat-001` biçiminde).
    private var nextNumber: Int {
        next.flatMap { Int($0.id.split(separator: "-").last ?? "") } ?? 0
    }

    @ViewBuilder
    private var title: some View {
        if completion.mistakes == 0 && !completion.usedHints {
            Text("Flawless!")
        } else if completion.mistakes == 0 {
            Text("Clever!")
        } else if completion.mistakes == 1 {
            Text("Great!")
        } else {
            Text("Solved!")
        }
    }

    @ViewBuilder
    private var message: some View {
        if completion.mistakes == 0 && !completion.usedHints {
            Text("0 mistakes! Every cat is right where it belongs!")
        } else if completion.mistakes == 0 {
            Text("Outstanding logic!")
        } else if completion.mistakes == 1 {
            Text("Just one slip. Well done!")
        } else {
            Text("You found every cat!")
        }
    }
}

/// Dönen ışık hüzmeleri (kutlama arka planı).
struct RaysView: View {
    @State private var angle: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height)
            for i in 0..<12 {
                let start = Angle.degrees(Double(i) * 30 + angle)
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .degrees(12), clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .radialGradient(
                    Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.4).opacity(0.7), .clear]),
                    center: center, startRadius: 0, endRadius: radius / 2
                ))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}

/// Canlar bitince: reklamla bir can ya da baştan başla.
@MainActor
struct CatFailedOverlay: View {
    @Environment(\.appTheme) private var theme
    let canRevive: Bool
    let isPremium: Bool
    let onRevive: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            theme.background.opacity(0.94)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                MuffinView(pose: .oops)
                    .frame(height: 150)
                Text("Out of paws!")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("A cat slipped through your paws. Keep going with one more paw, or start this level over.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                VStack(spacing: 10) {
                    if canRevive {
                        Button(action: onRevive) {
                            Label(isPremium ? "Continue (+1 Paw)" : "Watch Video (+1 Paw)", systemImage: isPremium ? "pawprint.fill" : "play.rectangle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    Button(action: onRetry) {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .card()
            .padding(20)
        }
    }
}

/// Çift dokunuşu gösteren küçük animasyon: el iki kez dokunur, her dokunuşta halka yayılır,
/// sonra karede kedi belirir.
@MainActor
struct DoubleTapDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 1.6 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4)
            let tap1 = t > 0.3 && t < 0.55
            let tap2 = t > 0.7 && t < 0.95
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.18)).frame(width: 36, height: 36)
                    if t > 0.95 {
                        Image(systemName: "cat.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.orange)
                            .transition(.scale)
                    }
                    ForEach([0.3, 0.7], id: \.self) { start in
                        let age = t - start
                        if age > 0, age < 0.45 {
                            Circle().stroke(Color.orange.opacity(1 - age / 0.45), lineWidth: 2)
                                .frame(width: 10 + 50 * age, height: 10 + 50 * age)
                        }
                    }
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                        .offset(x: 12, y: (tap1 || tap2) ? 12 : 20)
                }
                .frame(width: 44, height: 44)
                Text(verbatim: "× 2")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityHidden(true)
    }
}
