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

    var message: LocalizedStringResource {
        switch self {
        case .first:
            "Every color hides one cat. Each row and column has one cat too, and cats never touch, not even diagonally. This color is a single square, so its cat is there. Double-tap it quickly to place the cat!"
        case .useHint:
            "You found a cat! No other cat can be in its row, column or color, or right next to it. Tap ? below and I'll cross those squares out for you."
        case .second:
            "Now this color has only one free square left. Find its cat!"
        case .finder:
            "Stuck? The cat button below shows where a cat is hiding. You get 6 Cat Finders and 6 hints; watch a short video for more."
        case .freePlay:
            "You've got it! Tap once for X, tap an X again to clear it, double-tap for a cat, and swipe to place many X's. Find the rest of the cats!"
        }
    }
}

@MainActor
struct CatTutorialBanner: View {
    @Environment(\.appTheme) private var theme
    let step: CatTutorialStep
    @State private var speech = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MuffinView(pose: step == .freePlay ? .cheer : .point, speechID: speech)
                .frame(width: 64, height: 96)
            Text(step.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SpeechBubble().fill(theme.surface).shadow(color: theme.cardShadow, radius: 8, y: 2))
        }
        .onChange(of: step) { _, _ in speech += 1 }
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
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
        }
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
