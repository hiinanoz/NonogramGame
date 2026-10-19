import NonogramKit
import SwiftUI

/// Miyav Crush tahtası: hücre zemini, eşyalar, efektler ve dokunma/kaydırma.
/// Kaydırma bir eşyayı komşusuyla takas eder; dokunarak da (önce biri, sonra komşusu) takas
/// edilebilir. `pawMode` açıkken dokunulan eşya Kedi Patisi'yle patlatılır.
@MainActor
struct CrushBoardView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: CrushGameViewModel
    var pawMode = false
    var onPaw: (GridPosition) -> Void = { _ in }

    @State private var dragStart: GridPosition?
    @State private var didSwapInDrag = false

    var body: some View {
        let board = viewModel.board
        GeometryReader { proxy in
            let cell = min(proxy.size.width / CGFloat(board.columns), proxy.size.height / CGFloat(board.rows))
            let size = CGSize(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
            ZStack(alignment: .topLeading) {
                CrushBoardBackground(board: board, cell: cell)
                pieces(cell: cell)
                    .mask(CrushBoardMask(board: board, cell: cell))
                selection(cell: cell)
                CrushEffectsLayer(viewModel: viewModel, cell: cell)
                    .frame(width: size.width, height: size.height)
                popups(cell: cell)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(cell: cell, board: board))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(viewModel.board.columns) / CGFloat(viewModel.board.rows), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Game board"))
        .accessibilityIdentifier("crush.board")
    }

    private func pieces(cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(viewModel.tiles.values)) { tile in
                let isHinted = viewModel.hint.map { tile.isAt($0.from) || tile.isAt($0.to) } ?? false
                CrushPieceView(piece: tile.piece)
                    .frame(width: cell, height: cell)
                    .scaleEffect(tile.isClearing ? 0.1 : (tile.isSpawning ? 0.2 : 1))
                    .opacity(tile.isClearing ? 0 : 1)
                    .modifier(HintWiggle(isOn: isHinted && !reduceMotion))
                    .position(x: (tile.column + 0.5) * cell, y: (tile.row + 0.5) * cell)
            }
        }
        // Yalnızca ekran konumu değişir; her eşya ayrı kimlikle takip edilir
        .drawingGroup(opaque: false)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func selection(cell: CGFloat) -> some View {
        if let selected = viewModel.selected {
            RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)
                .shadow(color: .white.opacity(0.8), radius: 6)
                .frame(width: cell, height: cell)
                .position(x: (CGFloat(selected.column) + 0.5) * cell, y: (CGFloat(selected.row) + 0.5) * cell)
                .allowsHitTesting(false)
        }
    }

    private func popups(cell: CGFloat) -> some View {
        ForEach(viewModel.popups) { popup in
            ScorePopupView(score: popup.score, cell: cell)
                .position(x: (popup.column + 0.5) * cell, y: (popup.row + 0.5) * cell)
        }
        .allowsHitTesting(false)
    }

    private func dragGesture(cell: CGFloat, board: CrushBoard) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = position(of: value.startLocation, cell: cell)
                if dragStart == nil {
                    dragStart = start
                    didSwapInDrag = false
                }
                guard !pawMode, !didSwapInDrag, let from = dragStart else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                let threshold = cell * 0.35
                guard max(abs(dx), abs(dy)) > threshold else { return }
                let to = abs(dx) > abs(dy)
                    ? GridPosition(row: from.row, column: from.column + (dx > 0 ? 1 : -1))
                    : GridPosition(row: from.row + (dy > 0 ? 1 : -1), column: from.column)
                didSwapInDrag = true
                viewModel.swap(from: from, to: to)
            }
            .onEnded { value in
                defer {
                    dragStart = nil
                    didSwapInDrag = false
                }
                guard !didSwapInDrag else { return }
                let tapped = position(of: value.location, cell: cell)
                guard max(abs(value.translation.width), abs(value.translation.height)) < cell * 0.35 else { return }
                if pawMode {
                    if board.isPlayable(tapped) { onPaw(tapped) }
                } else {
                    viewModel.tap(tapped)
                }
            }
    }

    private func position(of point: CGPoint, cell: CGFloat) -> GridPosition {
        GridPosition(row: Int(floor(point.y / cell)), column: Int(floor(point.x / cell)))
    }
}

extension CrushTile {
    func isAt(_ position: GridPosition) -> Bool {
        Int(row.rounded()) == position.row && Int(column.rounded()) == position.column
    }
}

/// İpucu: iki eşya hafifçe sallanır.
private struct HintWiggle: ViewModifier {
    let isOn: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isOn && phase ? 1.12 : 1)
            .rotationEffect(.degrees(isOn && phase ? 6 : 0))
            .onChange(of: isOn, initial: true) { _, on in
                if on {
                    withAnimation(.easeInOut(duration: 0.4).repeatForever()) { phase = true }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { phase = false }
                }
            }
    }
}

/// Oynanabilir hücreler: krem ve açık kahve dama; delikler boş.
struct CrushBoardBackground: View {
    @Environment(\.appTheme) private var theme
    let board: CrushBoard
    let cell: CGFloat

    var body: some View {
        Canvas { context, _ in
            let light = theme.isDark ? Color(hex: "#3B3346") : Color(hex: "#FFF7EC")
            let dark = theme.isDark ? Color(hex: "#332C3D") : Color(hex: "#F6E6D3")
            let outline = theme.isDark ? Color.white.opacity(0.08) : Color(hex: "#E7CFB4")
            // Kenar çizgisi: her oynanabilir hücrenin biraz büyüğü
            for position in board.playablePositions {
                let rect = rect(position).insetBy(dx: -cell * 0.06, dy: -cell * 0.06)
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.24), with: .color(outline))
            }
            for position in board.playablePositions {
                let isLight = (position.row + position.column).isMultiple(of: 2)
                context.fill(Path(roundedRect: rect(position), cornerRadius: cell * 0.14), with: .color(isLight ? light : dark))
            }
        }
        .frame(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
        .allowsHitTesting(false)
    }

    private func rect(_ position: GridPosition) -> CGRect {
        CGRect(x: CGFloat(position.column) * cell, y: CGFloat(position.row) * cell, width: cell, height: cell)
    }
}

/// Eşyalar yalnızca tahtanın içinde görünür (yukarıdan düşen yeniler tahtaya girince belirir).
struct CrushBoardMask: View {
    let board: CrushBoard
    let cell: CGFloat

    var body: some View {
        Rectangle()
            .frame(width: cell * CGFloat(board.columns), height: cell * CGFloat(board.rows))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "+120" puan balonu: yükselip kaybolur.
private struct ScorePopupView: View {
    let score: Int
    let cell: CGFloat
    @State private var isRising = false

    var body: some View {
        Text(verbatim: "+\(score)")
            .font(.system(size: max(14, cell * 0.42), weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .offset(y: isRising ? -cell * 0.9 : 0)
            .opacity(isRising ? 0 : 1)
            .scaleEffect(isRising ? 1.15 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { isRising = true }
            }
    }
}

/// Efekt katmanı: iplik ışınları, kutu patlaması, altın göz lazerleri ve tüy/pati parçacıkları.
/// Yalnızca çizilecek bir şey varken akar.
struct CrushEffectsLayer: View {
    let viewModel: CrushGameViewModel
    let cell: CGFloat

    var body: some View {
        let isActive = !viewModel.effects.isEmpty || !viewModel.particles.isEmpty
        TimelineView(.animation(paused: !isActive)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                for effect in viewModel.effects {
                    draw(effect, at: now, in: &context, size: size)
                }
                for particle in viewModel.particles {
                    draw(particle, at: now, in: &context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func center(_ position: GridPosition) -> CGPoint {
        CGPoint(x: (CGFloat(position.column) + 0.5) * cell, y: (CGFloat(position.row) + 0.5) * cell)
    }

    private func draw(_ effect: CrushEffect, at now: Date, in context: inout GraphicsContext, size: CGSize) {
        let t = now.timeIntervalSince(effect.start) / effect.duration
        guard t >= 0, t < 1 else { return }
        let fade = 1 - t
        switch effect.kind {
        case .beam(let isRow, let index, let color):
            // Ortadan iki yana açılan parlak iplik
            let origin = center(effect.origin)
            let reach: CGFloat = min(1, CGFloat(t) * 2.5)
            let thickness: CGFloat = cell * (0.55 - 0.35 * CGFloat(t))
            let line: CGFloat = (CGFloat(index) + 0.5) * cell - thickness / 2
            let rect: CGRect
            if isRow {
                rect = CGRect(x: origin.x - size.width * reach, y: line, width: size.width * reach * 2, height: thickness)
            } else {
                rect = CGRect(x: line, y: origin.y - size.height * reach, width: thickness, height: size.height * reach * 2)
            }
            context.fill(Path(roundedRect: rect, cornerRadius: thickness / 2), with: .color(color.opacity(0.55 * fade)))
            let core = isRow ? rect.insetBy(dx: 0, dy: thickness * 0.32) : rect.insetBy(dx: thickness * 0.32, dy: 0)
            context.fill(Path(roundedRect: core, cornerRadius: thickness / 4), with: .color(.white.opacity(0.9 * fade)))
        case .blast(let radius, let color):
            let origin = center(effect.origin)
            let growth: CGFloat = 0.4 + 0.9 * CGFloat(t)
            let r: CGFloat = cell * (CGFloat(radius) + 0.5) * growth
            let ring = Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: 2 * r, height: 2 * r))
            context.fill(ring, with: .color(color.opacity(0.25 * fade)))
            context.stroke(ring, with: .color(.white.opacity(0.9 * fade)), lineWidth: cell * 0.18 * CGFloat(fade))
        case .laser(let targets):
            let origin = center(effect.origin)
            let reach: CGFloat = min(1, CGFloat(t) * 3)
            for target in targets {
                let end = center(target)
                let tip = CGPoint(x: origin.x + (end.x - origin.x) * reach, y: origin.y + (end.y - origin.y) * reach)
                var path = Path()
                path.move(to: origin)
                path.addLine(to: tip)
                context.stroke(path, with: .color(Gold.bright.opacity(0.85 * fade)), lineWidth: cell * 0.12)
                context.stroke(path, with: .color(.white.opacity(fade)), lineWidth: cell * 0.04)
            }
        case .flash:
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.7 * fade)))
        }
    }

    private func draw(_ particle: CrushParticle, at now: Date, in context: inout GraphicsContext) {
        let age = now.timeIntervalSince(particle.start)
        guard age >= 0, age < 0.9 else { return }
        let t = CGFloat(age)
        let gravity: CGFloat = 3.2 * t * t
        let x: CGFloat = (particle.origin.x + particle.velocity.dx * t) * cell
        let y: CGFloat = (particle.origin.y + particle.velocity.dy * t + gravity) * cell
        let size: CGFloat = particle.size * cell * (1 - t * 0.6)
        var piece = context
        piece.opacity = 1 - age / 0.9
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(particle.spin * age))
        if particle.isPaw {
            // Küçük pati: taban ve dört parmak
            let pad = Path(ellipseIn: CGRect(x: -size * 0.6, y: -size * 0.2, width: size * 1.2, height: size))
            piece.fill(pad, with: .color(particle.color))
            let toes: [(CGFloat, CGFloat)] = [(-0.75, -0.55), (-0.25, -0.9), (0.25, -0.9), (0.75, -0.55)]
            for (dx, dy) in toes {
                let toeSize: CGFloat = size * 0.44
                let toe = Path(ellipseIn: CGRect(x: size * dx - toeSize / 2, y: size * dy - toeSize / 2, width: toeSize, height: toeSize))
                piece.fill(toe, with: .color(particle.color))
            }
        } else {
            // Pofuduk tüy: yumuşak daire
            piece.fill(Path(ellipseIn: CGRect(x: -size / 2, y: -size / 2, width: size, height: size)), with: .color(particle.color))
        }
    }
}
