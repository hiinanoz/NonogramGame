import NonogramKit
import SwiftUI

/// Günlük bulmaca takvimi. Bugün ve önceki 10 gün oynanabilir (kaçırılan günler sonradan
/// çözülebilir); daha eski ve gelecek günler kilitli. Altında seçili günün kartı ve haftalık rozet.
@MainActor
struct DailyHubView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appTheme) private var theme
    @State private var selected: DayKey?
    /// Gösterilen ay (yıl * 12 + ay - 1).
    @State private var month: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var style: ModeStyle { .daily }

    var body: some View {
        let today = model.today
        let day = selected ?? today
        let shownMonth = month ?? Self.monthIndex(of: today)
        ScrollView {
            VStack(spacing: 16) {
                streakRow
                VStack(spacing: 12) {
                    monthHeader(shownMonth)
                    weekdayHeader
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(Self.cells(forMonth: shownMonth).enumerated()), id: \.offset) { _, cell in
                            if let cell {
                                dayCell(cell, isSelected: cell == day)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                }
                .padding(14)
                .card(cornerRadius: 24)

                selectedDayCard(day)

                WeeklyBadgeCard()

                HubRow(
                    icon: "medal.fill",
                    title: "My Badges",
                    detail: Text(verbatim: "\(Badge.all(in: .daily).filter { model.badges.isEarned($0) }.count)/\(Badge.all(in: .daily).count)"),
                    tint: Gold.deep
                ) { router.push(.badges(.daily)) }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle(BadgeMode.daily.title)
    }

    // MARK: - Seri

    private var streakRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: "#F06A5A"))
            Text("\(model.dailyStreak)-day streak")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Label {
                Text(verbatim: "\(model.badgeProgress.dailySolved)")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(style.tint(theme))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Solved"))
            .accessibilityValue(Text(verbatim: "\(model.badgeProgress.dailySolved)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(style.background(theme)))
    }

    // MARK: - Takvim

    private func monthHeader(_ shownMonth: Int) -> some View {
        let range = monthRange
        return HStack {
            Button {
                withAnimation(.snappy) { month = shownMonth - 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .disabled(shownMonth <= range.lowerBound)
            .accessibilityLabel(Text("Previous month"))
            Spacer()
            Text(Self.date(ofMonth: shownMonth), format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button {
                withAnimation(.snappy) { month = shownMonth + 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .disabled(shownMonth >= range.upperBound)
            .accessibilityLabel(Text("Next month"))
        }
        .foregroundStyle(theme.accent)
    }

    private var weekdayHeader: some View {
        // Pazartesiden başlar (haftalık rozetle aynı)
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[1...]) + [symbols[0]]
        return HStack(spacing: 6) {
            ForEach(ordered.indices, id: \.self) { index in
                Text(verbatim: ordered[index])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Takvimde gezilebilecek aylar: oynanabilir ya da çözülmüş en eski günün ayından bu aya.
    private var monthRange: ClosedRange<Int> {
        let current = Self.monthIndex(of: model.today)
        let solved = model.progress.completedIDs.compactMap(DayKey.init(puzzleID:))
        let oldest = (solved + model.recentDays).min() ?? model.today
        return min(Self.monthIndex(of: oldest), current)...current
    }

    private func dayCell(_ day: DayKey, isSelected: Bool) -> some View {
        let today = model.today
        let isToday = day == today
        let isFuture = day > today
        let isSolved = model.isDailySolved(day)
        let isPlayable = model.isDailyPlayable(day)
        let fill: Color = if isToday {
            theme.accent
        } else if isSolved {
            style.tint(theme).opacity(theme.isDark ? 0.35 : 0.22)
        } else if isPlayable {
            theme.surface
        } else {
            theme.surfaceMuted.opacity(isFuture ? 0.4 : 0.8)
        }
        return Button {
            withAnimation(.snappy) { selected = day }
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: "\(day.day)")
                    .font(.subheadline.weight(isToday ? .bold : .semibold).monospacedDigit())
                Group {
                    if isSolved {
                        Image(systemName: "checkmark")
                    } else if isToday {
                        Image(systemName: "star.fill")
                    } else if !isPlayable && !isFuture {
                        Image(systemName: "lock.fill")
                    } else {
                        Image(systemName: "circle.fill").hidden()
                    }
                }
                .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(isToday ? theme.onAccent : (isFuture || !isPlayable ? theme.textSecondary.opacity(0.55) : (isSolved ? style.ink(theme) : theme.textPrimary)))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected && !isToday ? style.tint(theme) : (isPlayable && !isSolved && !isToday ? theme.separator : .clear), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: isToday ? theme.accent.opacity(0.3) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isPlayable)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(isSolved ? Text("Solved") : (isPlayable ? Text(verbatim: "") : Text("Locked")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Seçili gün

    private func selectedDayCard(_ day: DayKey) -> some View {
        let puzzle = model.daily.puzzle(for: day)
        let isSolved = model.isDailySolved(day)
        let isResuming = model.progress.hasSavedGame(for: day.puzzleID)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(style.background(theme))
                    if isSolved, let puzzle {
                        ArtworkThumbnail(artwork: puzzle.artwork)
                            .padding(6)
                    } else {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(style.tint(theme))
                    }
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if day == model.today {
                            Text("Today's Puzzle")
                        } else {
                            Text(day.date, format: .dateTime.weekday(.wide))
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    Text(day.date, format: .dateTime.day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    if let puzzle {
                        Text("Expert · \(puzzle.columns)×\(puzzle.rows)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if LoopingCatAnimation.isAvailable(LoopingCatAnimation.sleepyCat) {
                    // Uyuyan kedi (sevince mırlar); çözülmüşse köşesinde onay rozeti
                    LoopingCatView(name: LoopingCatAnimation.sleepyCat, tapToPet: true)
                        .frame(maxWidth: 124, maxHeight: 76)
                        .overlay(alignment: .topTrailing) {
                            if isSolved {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(theme.success)
                                    .background(Circle().fill(theme.surface).padding(2))
                            }
                        }
                } else if isSolved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(theme.success)
                } else {
                    IllustrationView(name: "daily-cat")
                        .frame(maxWidth: 84, maxHeight: 84)
                }
            }
            Button {
                router.push(.game(puzzleID: day.puzzleID))
            } label: {
                Label(
                    isSolved ? "Play Again" : (isResuming ? "Resume" : "Play"),
                    systemImage: isSolved ? "arrow.counterclockwise" : (isResuming ? "arrow.clockwise" : "play.fill")
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(puzzle == nil || !model.isDailyPlayable(day))
            .accessibilityIdentifier("daily.play")
            if day != model.today, !isSolved {
                Text("Missed a day? You can solve the puzzles of the last 10 days.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(16)
        .card()
    }

    // MARK: - Tarih yardımcıları

    static func monthIndex(of day: DayKey) -> Int { day.year * 12 + day.month - 1 }

    static func date(ofMonth index: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: index / 12, month: index % 12 + 1, day: 1)) ?? Date()
    }

    /// Ayın takvim hücreleri: pazartesiden başlayan haftalar, ay dışı hücreler `nil`.
    static func cells(forMonth index: Int) -> [DayKey?] {
        let year = index / 12
        let month = index % 12 + 1
        let first = DayKey(year: year, month: month, day: 1)
        let calendar = Calendar(identifier: .gregorian)
        let count = calendar.range(of: .day, in: .month, for: first.date)?.count ?? 30
        let leading = AppModel.weekdayIndex(of: first)
        return Array(repeating: nil, count: leading) + (1...count).map { DayKey(year: year, month: month, day: $0) }
    }
}

/// Haftalık rozet: bu haftanın (pazartesi–pazar) günlük bulmacaları. 7 gün de çözülünce
/// "Haftalık Rozet" kazanılır.
@MainActor
struct WeeklyBadgeCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appTheme) private var theme

    var body: some View {
        let week = model.week(containing: model.today)
        let solved = week.filter { model.isDailySolved($0) }.count
        let tint = ModeStyle.daily.tint(theme)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Badge")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: solved == 7 ? "gift.fill" : "gift")
                    .font(.title3)
                    .foregroundStyle(solved == 7 ? Gold.deep : theme.accent)
            }
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    let isSolved = model.isDailySolved(day)
                    let isLast = index == week.count - 1
                    VStack(spacing: 6) {
                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(day == model.today ? theme.textPrimary : theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        ZStack {
                            Circle()
                                .fill(isSolved ? tint : (isLast ? Gold.light.opacity(theme.isDark ? 0.25 : 1) : theme.surfaceMuted))
                            Image(systemName: isSolved ? "checkmark" : (isLast ? "gift.fill" : "checkmark"))
                                .font(.system(size: isLast && !isSolved ? 14 : 12, weight: .bold))
                                .foregroundStyle(isSolved ? .white : (isLast ? Gold.deep : theme.textSecondary.opacity(0.35)))
                        }
                        .frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(isSolved ? Text("Solved") : Text(verbatim: ""))
                }
            }
            Text("This week: \(solved)/7 days")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .card()
    }
}
