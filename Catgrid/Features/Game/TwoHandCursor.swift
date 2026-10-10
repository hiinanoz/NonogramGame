import NonogramKit
import SwiftUI

/// Büyük bulmacalarda imleç türü.
enum CursorStyle: String, CaseIterable, Identifiable {
    /// Solda Doldur/X, sağ tarafta dokununca beliren joystick (varsayılan).
    case twoHands
    /// İmlecin yanındaki panel: Doldur, X ve taşıma.
    case oneHand

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .twoHands: "Two-Hand Cursor"
        case .oneHand: "One-Hand Cursor"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .twoHands: "Fill and X on the left. Touch anywhere on the right side to steer the cursor with a joystick."
        case .oneHand: "A small panel next to the cursor: Fill, X and a move button."
        }
    }
}

/// Çift el imleç: sol eldeki Doldur ve X. Basılı tuttukça araç kilitli kalır; joystick
/// imleci gezdirdikçe geçtiği kareler işaretlenir. Kısa dokunuş tek kareyi işaretler.
@MainActor
struct TwoHandControls: View {
    @Environment(\.appTheme) private var theme
    let lockedTool: MarkTool?
    let canUndo: Bool
    let onPress: (MarkTool) -> Void
    let onRelease: () -> Void
    let undo: () -> Void

    @State private var pressed: MarkTool?

    var body: some View {
        HStack(spacing: 12) {
            holdButton(.fill, systemImage: "square.fill", label: "Fill")
            holdButton(.cross, systemImage: "xmark", label: "Cross")
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3.weight(.semibold))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(theme.surface))
                    .overlay(Circle().strokeBorder(theme.separator, lineWidth: 1))
                    .foregroundStyle(canUndo ? theme.textPrimary : theme.textSecondary.opacity(0.4))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canUndo)
            .accessibilityLabel(Text("Undo"))
            Spacer(minLength: 0)
        }
    }

    private func holdButton(_ tool: MarkTool, systemImage: String, label: LocalizedStringKey) -> some View {
        let isActive = lockedTool == tool || pressed == tool
        return Image(systemName: systemImage)
            .font(.system(size: 24, weight: .bold))
            .frame(width: 64, height: 64)
            .background(Circle().fill(isActive ? theme.accent : theme.surface))
            .overlay(Circle().strokeBorder(isActive ? .clear : theme.separator, lineWidth: 1))
            .shadow(color: isActive ? theme.accent.opacity(0.3) : theme.cardShadow, radius: 6, y: 3)
            .foregroundStyle(isActive ? theme.onAccent : theme.textPrimary)
            .scaleEffect(isActive ? 1.08 : 1)
            .animation(.snappy(duration: 0.15), value: isActive)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard pressed != tool else { return }
                        if pressed != nil { onRelease() }
                        pressed = tool
                        Haptics.selection()
                        onPress(tool)
                    }
                    .onEnded { _ in
                        pressed = nil
                        onRelease()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onPress(tool)
                onRelease()
            }
    }
}

/// Ekranın sağ tarafı: dokunulan yerde silik bir joystick belirir; parmağın yönüne göre
/// imleç kare kare ilerler (uzaklaştıkça hızlanır). Hep hiyerarşide durur.
@MainActor
struct JoystickPad: View {
    @Environment(\.appTheme) private var theme
    /// Satır ve sütun değişimi (-1, 0, 1).
    let onStep: (Int, Int) -> Void
    /// Kaydırmadan kısa dokunuş (joystick alanının koordinatlarında): alttaki kedi gibi
    /// öğelere ulaşmak için.
    var onTap: ((CGPoint) -> Void)?

    @State private var origin: CGPoint?
    @State private var touchStart: Date?
    @State private var offset: CGSize = .zero
    @State private var repeatTask: Task<Void, Never>?

    static let radius: CGFloat = 48
    private static let deadZone: CGFloat = 12

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
            joystick
                .position(origin ?? .zero)
                .opacity(origin == nil ? 0 : 1)
                .allowsHitTesting(false)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if origin == nil {
                        origin = value.startLocation
                        touchStart = .now
                        startRepeating()
                    }
                    offset = Self.clamp(value.translation)
                }
                .onEnded { value in
                    repeatTask?.cancel()
                    repeatTask = nil
                    let isTap = hypot(value.translation.width, value.translation.height) < Self.deadZone
                        && Date.now.timeIntervalSince(touchStart ?? .now) < 0.3
                    origin = nil
                    offset = .zero
                    touchStart = nil
                    if isTap { onTap?(value.location) }
                }
        )
        .accessibilityHidden(true)
    }

    private var joystick: some View {
        ZStack {
            Circle()
                .fill(theme.textPrimary.opacity(0.08))
                .overlay(Circle().stroke(theme.textPrimary.opacity(0.18), lineWidth: 2))
                .frame(width: Self.radius * 2, height: Self.radius * 2)
            Circle()
                .fill(theme.accent.opacity(0.55))
                .frame(width: 44, height: 44)
                .offset(offset)
        }
    }

    private static func clamp(_ translation: CGSize) -> CGSize {
        let length = hypot(translation.width, translation.height)
        guard length > radius else { return translation }
        return CGSize(width: translation.width / length * radius, height: translation.height / length * radius)
    }

    /// Parmak merkezden uzaklaştıkça adımlar sıklaşır; çapraz da gidilebilir.
    private func startRepeating() {
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            while !Task.isCancelled {
                let length = hypot(offset.width, offset.height)
                if length > Self.deadZone {
                    let dx = abs(offset.width) > length * 0.38 ? (offset.width > 0 ? 1 : -1) : 0
                    let dy = abs(offset.height) > length * 0.38 ? (offset.height > 0 ? 1 : -1) : 0
                    onStep(dy, dx)
                    let strength = min(length / Self.radius, 1)
                    try? await Task.sleep(for: .seconds(0.34 - 0.24 * strength))
                } else {
                    try? await Task.sleep(for: .seconds(0.03))
                }
            }
        }
    }
}
