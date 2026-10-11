import StoreKit
import SwiftUI
import UIKit

enum SettingsKeys {
    static let haptics = "settings.haptics"
    /// "Zor": tamamlanan satırlara otomatik X konmaz.
    static let hardMode = "settings.hardMode"
    /// Rahat ya da Dopamin modu.
    static let playMode = "settings.playMode"
    /// 10x10'dan büyük bulmacalarda imleçle oynama.
    static let largeBoardCursor = "settings.largeBoardCursor"
    /// Çift el (joystick) ya da tek el (panel) imleç.
    static let cursorStyle = "settings.cursorStyle"
    /// Yardımlı kaydırma (düz çizgi) ya da serbest kaydırma.
    static let assistedDrag = "settings.assistedDrag"
}

/// Sakin: sade oyun. Enerjik (varsayılan): satır parıltıları, kutlamalar, hareketli müzik.
/// Kayıtlı değerler (relax/dopamine) eski sürümlerle uyum için değişmedi.
enum PlayMode: String, CaseIterable, Identifiable {
    case relax
    case dopamine

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .relax: "Calm"
        case .dopamine: "Energetic"
        }
    }

    /// Sakin: iki sakin parça 5'er dakika sırayla (her biri kendi içinde döner).
    /// Enerjik: iki hareketli parça arka arkaya, sonsuz döngü.
    var playlist: MusicPlaylist {
        switch self {
        case .relax:
            MusicPlaylist(
                tracks: [
                    MusicTrack(name: "music_cozy", fileExtension: "m4a", gain: 1.5),
                    MusicTrack(name: "music_upbeat", fileExtension: "m4a", gain: 1.6),
                ],
                segmentDuration: 5 * 60
            )
        case .dopamine:
            MusicPlaylist(
                tracks: [
                    MusicTrack(name: "music_quest_1", fileExtension: "mp3", gain: 0.75),
                    MusicTrack(name: "music_quest_2", fileExtension: "mp3", gain: 0.75),
                ],
                segmentDuration: nil
            )
        }
    }
}

@MainActor
struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppModel.self) private var model
    @Environment(AudioManager.self) private var audio
    @Environment(AdCoordinator.self) private var ads
    @Environment(StoreManager.self) private var store
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @AppStorage(SettingsKeys.haptics) private var hapticsEnabled = true
    @AppStorage(SettingsKeys.largeBoardCursor) private var usesLargeBoardCursor = true
    @AppStorage(SettingsKeys.cursorStyle) private var cursorStyle = CursorStyle.twoHands
    @AppStorage(SettingsKeys.assistedDrag) private var assistedDrag = true
    @AppStorage(SettingsKeys.playMode) private var playMode = PlayMode.dopamine
    @State private var isConfirmingReset = false
    @State private var isShowingPaywall = false
    @State private var isManagingSubscription = false
    @State private var restoreResult: StoreManager.RestoreResult?
    @State private var isRestoring = false
    @Environment(ReminderManager.self) private var reminders
    @State private var isShowingNotificationsOff = false

    private let paletteColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var themeManager = themeManager
        @Bindable var audio = audio
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Color Palette") {
                    LazyVGrid(columns: paletteColumns, spacing: 12) {
                        ForEach(ThemePalette.allCases) { palette in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { themeManager.palette = palette }
                            } label: {
                                PaletteCard(
                                    palette: palette,
                                    isDark: colorScheme == .dark,
                                    isSelected: themeManager.palette == palette
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                section("Play Style") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Play Style", selection: $playMode) {
                            ForEach(PlayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.playMode")
                        Text(playMode == .relax
                             ? LocalizedStringKey("Calm and simple: soft music, no distractions.")
                             : LocalizedStringKey("Sparkles for every line, celebrations for every puzzle and upbeat music."))
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                section("Appearance") {
                    Picker("Appearance", selection: $themeManager.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                section("Premium") {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.isPremium {
                            Label("You're Premium. Thank you for supporting Catgrid!", systemImage: "crown.fill")
                                .foregroundStyle(theme.success)
                            subscriptionDetail
                            Button("Manage Subscription") { isManagingSubscription = true }
                                .buttonStyle(SecondaryButtonStyle())
                        } else {
                            Text("No ads, 9 golden puzzles for every breed and Golden Cards. Monthly or yearly subscription.")
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                            Button {
                                isShowingPaywall = true
                            } label: {
                                Label("Go Premium", systemImage: "crown.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("settings.premium")
                        }
                        Button {
                            Task {
                                isRestoring = true
                                restoreResult = await store.restorePurchases()
                                isRestoring = false
                            }
                        } label: {
                            if isRestoring {
                                ProgressView()
                            } else {
                                Text("Restore Purchases")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isRestoring)
                        .alert(
                            "Restore Purchases",
                            isPresented: Binding(get: { restoreResult != nil }, set: { if !$0 { restoreResult = nil } })
                        ) {
                        } message: {
                            switch restoreResult {
                            case .restored: Text("Purchases restored. Welcome back to Premium!")
                            case .nothingToRestore: Text("No active subscription was found for this Apple Account.")
                            case .failed, nil: Text("Couldn't reach the App Store. Please try again.")
                            }
                        }
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
                }

                section("Sound") {
                    VStack(spacing: 18) {
                        volumeRow(
                            title: "Music",
                            icon: "music.note",
                            isOn: $audio.musicEnabled,
                            volume: $audio.musicVolume
                        )
                        Divider()
                        volumeRow(
                            title: "Sound Effects",
                            icon: "speaker.wave.2.fill",
                            isOn: $audio.effectsEnabled,
                            volume: $audio.effectsVolume,
                            preview: .fill
                        )
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
                }

                section("Gameplay") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(theme.textPrimary)
                        }
                        Divider()
                        Picker(selection: $assistedDrag) {
                            Text("Assisted Drag").tag(true)
                            Text("Free Drag").tag(false)
                        } label: {
                            Text("Drag Mode")
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.dragMode")
                        Text(assistedDrag
                             ? LocalizedStringKey("Hold a square and slide: only that row or column is marked, in a straight line.")
                             : LocalizedStringKey("Hold a square and slide in any direction, even diagonally: every square you pass is marked."))
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Toggle(isOn: $usesLargeBoardCursor) {
                            Label("Cursor on Large Puzzles", systemImage: "scope")
                                .foregroundStyle(theme.textPrimary)
                        }
                        Text("Puzzles bigger than 10×10 are played with a cursor: pick a square, then Fill or X.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                        if usesLargeBoardCursor {
                            Picker(selection: $cursorStyle) {
                                ForEach(CursorStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            } label: {
                                Text("Cursor Type")
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("settings.cursorStyle")
                            Text(cursorStyle.detail)
                                .font(.footnote)
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .card(cornerRadius: 16)
                }

                section("Reminders") {
                    reminderSettings
                        .padding(16)
                        .card(cornerRadius: 16)
                }

                section("Progress") {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Label("Reset Progress", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(theme.mistake)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(8)
                    .card(cornerRadius: 16)
                    .confirmationDialog("Reset all progress?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                        Button("Reset Progress", role: .destructive) { model.resetProgress() }
                    } message: {
                        Text("All solved puzzles, best times and saved games will be deleted. This cannot be undone.")
                    }
                }

                section("Language") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The game follows your device language. You can choose a different language just for this app in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                        Button("Change Language") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                section("About") {
                    VStack(spacing: 0) {
                        linkRow("Rate Catgrid", icon: "star.fill") {
                            if let url = AppLinks.writeReview { openURL(url) } else { requestReview() }
                        }
                        Divider()
                        linkRow("Support", icon: "questionmark.circle.fill") { openURL(AppLinks.support) }
                        Divider()
                        linkRow("Privacy Policy", icon: "hand.raised.fill") { openURL(AppLinks.privacyPolicy) }
                        Divider()
                        linkRow("Terms of Use", icon: "doc.text.fill") { openURL(AppLinks.termsOfUse) }
                        if ads.isPrivacyOptionsRequired {
                            Divider()
                            linkRow("Ad Privacy Choices", icon: "slider.horizontal.3") {
                                Task { await ads.presentPrivacyOptions() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .card(cornerRadius: 16)
                }

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                    (Text("Version \(version)") + Text(verbatim: " (\(build))"))
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .themedScreen()
        .screenTitle("Settings")
        .sheet(isPresented: $isShowingPaywall) {
            PremiumPaywall()
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
    }

    private var reminderSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { reminders.isEnabled },
                set: { isOn in
                    if isOn {
                        Task {
                            if await reminders.enable() {
                                await reschedule()
                            } else {
                                isShowingNotificationsOff = true
                            }
                        }
                    } else {
                        reminders.disable()
                    }
                }
            )) {
                Label("Daily Reminder", systemImage: "bell.fill")
                    .foregroundStyle(theme.textPrimary)
            }
            .accessibilityIdentifier("settings.reminder")
            if reminders.isEnabled {
                DatePicker(selection: Binding(
                    get: { Calendar.current.date(bySettingHour: reminders.hour, minute: reminders.minute, second: 0, of: Date()) ?? Date() },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        reminders.hour = parts.hour ?? 19
                        reminders.minute = parts.minute ?? 0
                        Task { await reschedule() }
                    }
                ), displayedComponents: .hourAndMinute) {
                    Label("Time", systemImage: "clock.fill")
                        .foregroundStyle(theme.textPrimary)
                }
            }
            Text("Only on days you haven't played.")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .alert("Notifications are off", isPresented: $isShowingNotificationsOff) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("To get reminders, allow notifications for Catgrid in Settings.")
        }
    }

    private func reschedule() async {
        await reminders.reschedule(lastPlayedAt: model.lastPlayedAt, streak: model.dailyStreak)
    }

    @ViewBuilder
    private var subscriptionDetail: some View {
        let plan: LocalizedStringKey? = switch store.activeProductID ?? "" {
        case StoreManager.yearlyProductID: "Yearly plan"
        case StoreManager.monthlyProductID: "Monthly plan"
        default: nil
        }
        if let plan {
            Text(plan)
                .font(.subheadline.bold())
                .foregroundStyle(theme.textPrimary)
        }
        if !store.willAutoRenew, let end = store.expirationDate {
            Text("Ends on \(end.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func linkRow(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(theme.accent)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func volumeRow(
        title: LocalizedStringKey,
        icon: String,
        isOn: Binding<Bool>,
        volume: Binding<Double>,
        preview: SoundEffect? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: icon)
                    .foregroundStyle(theme.textPrimary)
            }
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Slider(value: volume, in: 0...1) {
                    Text(title)
                } onEditingChanged: { editing in
                    // Efekt seviyesini ayarlarken örnek ses çal
                    if !editing, let preview { audio.play(preview) }
                }
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .disabled(!isOn.wrappedValue)
            .opacity(isOn.wrappedValue ? 1 : 0.4)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(theme.textPrimary)
            content()
        }
    }
}

/// Paletin kendi renkleriyle çizilmiş küçük bir tahta önizlemesi.
@MainActor
struct PaletteCard: View {
    let palette: ThemePalette
    let isDark: Bool
    let isSelected: Bool

    /// Minik kedi kafası
    private static let pattern = ["#...#", "##.##", "#####", "#.#.#", ".###."]

    var body: some View {
        let preview = AppTheme(palette: palette, isDark: isDark)
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(Array(Self.pattern.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, symbol in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(symbol == "#" ? preview.cellFilled : preview.surfaceMuted)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            Text(palette.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(preview.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(preview.background))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? preview.accent : preview.separator, lineWidth: isSelected ? 3 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(preview.accent)
                    .padding(8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
