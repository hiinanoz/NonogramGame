import NonogramKit
import SwiftUI

// MARK: - Bölüm başı

/// Bölüm başında hedefler; ilk oyunda kısa "nasıl oynanır".
@MainActor
struct CrushIntroOverlay: View {
    @Environment(\.appTheme) private var theme
    let level: CrushLevel
    let number: Int
    let showsHowTo: Bool
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Level \(number)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(ModeStyle.crush.ink(theme))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(level.goals.enumerated()), id: \.offset) { _, goal in
                        HStack(spacing: 12) {
                            CrushGoalIcon(goal: goal)
                                .frame(width: 36, height: 36)
                            goal.sentence
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "hand.draw.fill")
                            .font(.title2)
                            .foregroundStyle(ModeStyle.crush.tint(theme))
                            .frame(width: 36, height: 36)
                        Text("in \(level.moves) moves")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsHowTo {
                    CrushHowTo()
                }
                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("crush.intro.play")
            }
            .padding(22)
            .frame(maxWidth: 420)
            .card()
            .padding(20)
        }
    }
}

/// Kısa kurallar: kaydır, 3'lü eşleştir; 4'lü, T/L ve 5'li özel eşyalar.
struct CrushHowTo: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swipe an item to swap it with a neighbor. Line up 3 or more of the same item!")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            row(CrushPiece(id: 0, color: .yarn, special: .stripedRow), "4 in a row: Striped Yarn clears a whole line")
            row(CrushPiece(id: 0, color: .treat, special: .wrapped), "T or L shape: Rattle Box explodes twice")
            row(CrushPiece(id: 0, color: nil, special: .colorBomb), "5 in a row: Golden Cat Eye clears one color")
            Text("Swap two special items together for a giant combo!")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ModeStyle.crush.tint(theme))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surfaceMuted))
    }

    private func row(_ piece: CrushPiece, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            CrushPieceView(piece: piece)
                .frame(width: 32, height: 32)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Kazanınca

@MainActor
struct CrushResultOverlay: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: CrushResult
    let level: CrushLevel
    let number: Int
    let next: CrushLevel?
    let onNext: (CrushLevel) -> Void
    let onReplay: () -> Void
    let onMap: () -> Void
    @State private var shownStars = 0
    @State private var appeared = false

    private var outcome: CrushLevelOutcome { result.outcome }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            RaysView()
                .opacity(appeared ? 0.5 : 0)
                .frame(width: 520, height: 520)
                .offset(y: -150)
                .allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 14) {
                    title
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#FFE27A"), Color(hex: "#FF8A3D")], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
                        .scaleEffect(appeared ? 1 : 0.4)
                    bigStars
                    VStack(spacing: 2) {
                        Text(result.score, format: .number)
                            .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        if outcome.isNewBest && !outcome.isFirstWin {
                            Text("New best score!")
                                .font(.subheadline.bold())
                                .foregroundStyle(Gold.bright)
                        }
                    }
                    rewards
                    VStack(spacing: 10) {
                        if let next {
                            Button {
                                onNext(next)
                            } label: {
                                Text("Level \(number + 1)")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("crush.result.next")
                        }
                        HStack(spacing: 10) {
                            Button(action: onReplay) {
                                Label("Replay", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button(action: onMap) {
                                Label("Map", systemImage: "map.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("crush.result.map")
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay(alignment: .topTrailing) {
            ShareResultButton(
                headline: Text("Meow Crush") + Text(verbatim: " · ") + Text("Level \(number)")
                    + Text(verbatim: " · " + String(repeating: "★", count: result.stars) + " ") + Text(result.score, format: .number),
                style: .dark,
                message: String(localized: "I beat this Meow Crush level in Catgrid Collection! Can you? 🐾")
            ) {
                CrushShareArt(level: level, stars: result.stars)
            }
            .padding(.trailing, 18)
            .padding(.top, 8)
        }
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
            for star in 1...max(1, result.stars) {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.05 : 0.35))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { shownStars = star }
                Haptics.selection()
            }
        }
    }

    @ViewBuilder
    private var title: some View {
        switch result.stars {
        case 3: Text("Purrfect!")
        case 2: Text("Great!")
        default: Text("Level Clear!")
        }
    }

    private var bigStars: some View {
        HStack(spacing: 10) {
            ForEach(1...3, id: \.self) { index in
                let isEarned = index <= shownStars
                Image(systemName: "star.fill")
                    .font(.system(size: index == 2 ? 60 : 46, weight: .bold))
                    .foregroundStyle(isEarned ? AnyShapeStyle(LinearGradient(colors: [Gold.light, Gold.bright, Gold.mid], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.2)))
                    .shadow(color: isEarned ? Gold.bright.opacity(0.7) : .clear, radius: 10)
                    .scaleEffect(isEarned ? 1 : 0.8)
                    .offset(y: index == 2 ? -10 : 0)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(result.stars) of 3 stars"))
    }

    @ViewBuilder
    private var rewards: some View {
        let reward = outcome.totalReward
        if !reward.isEmpty || !outcome.newBadges.isEmpty {
            VStack(spacing: 10) {
                if !outcome.chests.isEmpty {
                    Label("Star chest opened!", systemImage: "shippingbox.fill")
                        .font(.headline)
                        .foregroundStyle(Gold.bright)
                }
                if outcome.episodeReward != nil {
                    Label("Adventure complete!", systemImage: "flag.checkered")
                        .font(.headline)
                        .foregroundStyle(Gold.bright)
                }
                if !reward.isEmpty {
                    CrushRewardRow(reward: reward)
                }
                ForEach(outcome.newBadges, id: \.self) { badge in
                    Label {
                        Text("New badge: \(Text(badge.title))")
                    } icon: {
                        Image(systemName: badge.icon)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.12)))
        }
    }
}

/// Ödül satırı: güçlendirici simgeleri ve adetleri.
struct CrushRewardRow: View {
    let reward: CrushReward

    var body: some View {
        HStack(spacing: 14) {
            ForEach(CrushBooster.allCases, id: \.self) { booster in
                if let count = reward.boosters[booster], count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: booster.icon)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(booster.tint))
                        Text(verbatim: "×\(count)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(booster.title))
                    .accessibilityValue(Text(verbatim: "\(count)"))
                }
            }
        }
    }
}

/// Paylaşılan görsel: bölüm numarası, eşyalar ve yıldızlar.
struct CrushShareArt: View {
    let level: CrushLevel
    let stars: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(CrushColor.allCases.prefix(3)), id: \.self) { color in
                    CrushPieceView(piece: CrushPiece(id: 0, color: color)).frame(width: 52, height: 52)
                }
            }
            HStack(spacing: 6) {
                CrushPieceView(piece: CrushPiece(id: 0, color: .mouse, special: .stripedRow)).frame(width: 52, height: 52)
                CrushPieceView(piece: CrushPiece(id: 0, color: nil, special: .colorBomb)).frame(width: 52, height: 52)
                CrushPieceView(piece: CrushPiece(id: 0, color: .paw, special: .wrapped)).frame(width: 52, height: 52)
            }
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(index <= stars ? Gold.mid : Color.gray.opacity(0.3))
                }
            }
        }
    }
}

// MARK: - Hamle bitince

@MainActor
struct CrushFailedOverlay: View {
    @Environment(\.appTheme) private var theme
    let session: CrushSession
    let extraMoves: Int
    let canWatchAd: Bool
    let isPremiumFree: Bool
    let onContinue: () -> Void
    let onRetry: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            theme.background.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "hourglass")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(ModeStyle.crush.tint(theme))
                Text("Out of moves!")
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                Text("So close! Still to go:")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Array(session.goals.enumerated()), id: \.offset) { _, goal in
                        CrushGoalChip(goal: goal)
                    }
                }
                VStack(spacing: 10) {
                    if isPremiumFree || extraMoves > 0 || canWatchAd {
                        Button(action: onContinue) {
                            continueLabel
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("crush.failed.continue")
                    }
                    HStack(spacing: 10) {
                        Button(action: onRetry) {
                            Label("Try Again", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("crush.failed.retry")
                        Button(action: onMap) {
                            Label("Map", systemImage: "map.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .card()
            .padding(20)
        }
    }

    @ViewBuilder
    private var continueLabel: some View {
        if isPremiumFree {
            Label("Continue (+5 Moves)", systemImage: "crown.fill")
        } else if extraMoves > 0 {
            Label("Use +5 Moves (\(extraMoves) left)", systemImage: "plus.circle.fill")
        } else {
            Label("Watch Video (+5 Moves)", systemImage: "play.rectangle.fill")
        }
    }
}

// MARK: - Rozetler

extension CrushBadge {
    var title: LocalizedStringResource {
        switch self {
        case .firstWin: "First Crush"
        case .episodeCleared(let episode): "\(String(localized: CrushEpisode(index: episode).title)) Cleared"
        case .episodePerfect(let episode): "\(String(localized: CrushEpisode(index: episode).title)): All Stars"
        case .starCollector(let stars): "\(stars) Stars"
        case .chainMaster: "Chain Master"
        case .catFrenzy: "Cat Frenzy"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .firstWin: "Win your first level."
        case .episodeCleared: "Win every level in this adventure."
        case .episodePerfect: "Get 3 stars on every level in this adventure."
        case .starCollector(let stars): "Collect \(stars) stars."
        case .chainMaster: "Make a chain of 5 or more in one move."
        case .catFrenzy: "Turn 10 or more moves into a Cat Frenzy."
        }
    }

    var icon: String {
        switch self {
        case .firstWin: "sparkles"
        case .episodeCleared: "flag.checkered"
        case .episodePerfect: "crown.fill"
        case .starCollector: "star.circle.fill"
        case .chainMaster: "link"
        case .catFrenzy: "flame.fill"
        }
    }

    /// Hub'da gösterilecek bütün rozetler (kazanılmamışlar soluk).
    static func all(episodes: Int) -> [CrushBadge] {
        [.firstWin, .chainMaster, .catFrenzy]
            + CrushBadge.starMilestones.map { .starCollector($0) }
            + (0..<episodes).map { .episodeCleared($0) }
            + (0..<episodes).map { .episodePerfect($0) }
    }
}
