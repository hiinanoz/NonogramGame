import NonogramKit
import SwiftUI

/// Öğretmen Muffin (Scottish Fold): poz görselleri arasında geçişle basit animasyon.
/// Konuşurken ağız açılıp kapanır, ara sıra göz kırpar, hafifçe nefes alır.
@MainActor
struct MuffinView: View {
    enum Pose: Equatable {
        case hello, point, think, wave, down, oops, cheer

        var image: String {
            switch self {
            case .hello: "muffin-hello"
            case .point: "muffin-point"
            case .think: "muffin-think"
            case .wave: "muffin-wave"
            case .down: "muffin-down"
            case .oops: "muffin-oops"
            case .cheer: "muffin-cheer"
            }
        }

        /// Gözleri kapalı kardeş görsel (varsa).
        var blink: String? {
            switch self {
            case .point: "muffin-point-blink"
            case .think: "muffin-think-blink"
            case .wave: "muffin-wave-blink"
            default: nil
            }
        }

        /// Ağzı açık kardeş görsel (varsa).
        var talk: String? {
            self == .point ? "muffin-point-talk" : nil
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pose: Pose
    /// Değişince Muffin kısa bir süre "konuşur".
    var speechID: Int = 0

    @State private var frame: String?
    @State private var breathe = false
    @State private var hop = false

    var body: some View {
        Image(frame ?? pose.image)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: 1, y: breathe ? 1.012 : 1, anchor: .bottom)
            .offset(y: hop ? -10 : 0)
            .accessibilityHidden(true)
            .task(id: pose) { await live() }
            .task(id: speechID) { await talk() }
            .onChange(of: pose) { _, newPose in
                frame = nil
                guard newPose == .cheer, !reduceMotion else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { hop = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { hop = false }
                }
            }
    }

    /// Göz kırpma ve nefes döngüsü.
    private func live() async {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...4.5)))
            guard let blink = pose.blink, frame == nil else { continue }
            frame = blink
            try? await Task.sleep(for: .milliseconds(140))
            if frame == blink { frame = nil }
        }
    }

    /// Konuşma: ağız birkaç kez açılıp kapanır.
    private func talk() async {
        guard speechID > 0, !reduceMotion, let open = pose.talk else { return }
        for _ in 0..<6 where !Task.isCancelled {
            frame = open
            try? await Task.sleep(for: .milliseconds(180))
            frame = nil
            try? await Task.sleep(for: .milliseconds(160))
        }
    }
}

/// Eğitim bulmacalarının üstünde: Muffin ve konuşma balonu. Büyük yazı, isteğe bağlı ipucu
/// satırı ve eğitimi atlama düğmesi.
@MainActor
struct MuffinLessonBanner: View {
    @Environment(\.appTheme) private var theme
    let lesson: TutorialLesson
    /// Adım adım derslerde o anki adımın metni; yoksa dersin ana metni.
    var message: LocalizedStringResource?
    var pose: MuffinView.Pose
    var speechID: Int
    let onSkip: () -> Void
    @State private var isConfirmingSkip = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MuffinView(pose: pose, speechID: speechID)
                .frame(width: 92, height: 138)
            VStack(alignment: .leading, spacing: 8) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundStyle(theme.accent)
                Text(message ?? lesson.message)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let tip = lesson.tip {
                    Label {
                        Text(tip)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    Button("Skip tutorial") { isConfirmingSkip = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityIdentifier("tutorial.skip")
                }
            }
            .padding(14)
            .background(SpeechBubble().fill(theme.surface).shadow(color: theme.cardShadow, radius: 8, y: 2))
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .confirmationDialog("Skip the tutorial?", isPresented: $isConfirmingSkip, titleVisibility: .visible) {
            Button("Skip tutorial", role: .destructive, action: onSkip)
        } message: {
            Text("The first cat breed opens right away. You can come back to Muffin's School any time from All Levels.")
        }
    }
}

/// Sol alt köşesinde Muffin'e doğru küçük bir kuyruğu olan konuşma balonu.
struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 34))
        tail.addLine(to: CGPoint(x: rect.minX - 10, y: rect.maxY - 18))
        tail.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 20))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

/// Tahtanın üstünde, dokunulacak kareyi gösteren zıplayan pati.
@MainActor
struct PawPointer: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Yerinde zıplasın mı? Kaydırma gösterirken hareketi `GuidePaw` verir.
    var bobs = true
    @State private var isUp = false

    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 40))
            .foregroundStyle(theme.accent)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .offset(y: bobs ? (isUp ? -8 : 6) : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isUp = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension TutorialLesson {
    /// Muffin'in bu derste duruşu.
    var muffinPose: MuffinView.Pose {
        switch self {
        case .firstSquare: .wave
        case .tapToFill, .fullLines, .markWithCross, .edges, .difficulty: .point
        case .emptyLines, .multipleBlocks, .overlap: .think
        case .crossReference: .down
        case .mistakesAndLives: .oops
        case .graduation: .cheer
        }
    }

    /// Kurala ek ipucu satırı: kaldırıldı (eğitimde yazı en aza indirildi).
    var tip: LocalizedStringResource? { nil }
}
