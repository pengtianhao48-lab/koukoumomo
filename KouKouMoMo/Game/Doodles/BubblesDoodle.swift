import SwiftUI

/// ⑤「压泡泡纸」— full-screen sheet of bubbles. Tap anywhere → nearest bubble pops with a
///   "line-burst" animation. All remaining bubbles slide toward the popped spot with a
///   soft spring, so the next candidate is always near the finger. Grid is deep enough to
///   feel infinite for a normal session.
struct BubblesDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    // Fixed world grid centered at (0,0). Large enough for a long session.
    private static let cols = 15
    private static let rows = 25
    private static let spacing: CGFloat = 56
    private static let bubbleRadius: CGFloat = 24

    // Per-cell live state
    @State private var popped: Set<Int> = []
    @State private var poppedAt: Int? = nil   // index of latest pop (for burst)
    @State private var burstStart: TimeInterval = 0
    @State private var offset: CGSize = .zero
    @State private var lastTap: CGPoint = .zero

    private var totalCells: Int { Self.cols * Self.rows }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawGrid(ctx: ctx, size: size, time: time)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { evt in handleTap(at: evt.location, viewSize: proxy.size, time: time) }
                )
            }
        }
    }

    // MARK: layout helpers

    private func cellIndex(row: Int, col: Int) -> Int { row * Self.cols + col }
    private func rowCol(of index: Int) -> (row: Int, col: Int) { (index / Self.cols, index % Self.cols) }

    /// World position of a cell relative to grid center (0,0), with staggered rows for a honeycomb feel.
    private func worldPos(row: Int, col: Int) -> CGPoint {
        let cx = CGFloat(col) - CGFloat(Self.cols - 1) / 2
        let cy = CGFloat(row) - CGFloat(Self.rows - 1) / 2
        let stagger: CGFloat = (row % 2 == 0) ? 0 : Self.spacing * 0.5
        return CGPoint(x: cx * Self.spacing + stagger, y: cy * Self.spacing * 0.86)
    }

    private func screenPos(row: Int, col: Int, viewSize: CGSize) -> CGPoint {
        let w = worldPos(row: row, col: col)
        return CGPoint(x: viewSize.width/2 + w.x + offset.width,
                       y: viewSize.height/2 + w.y + offset.height)
    }

    // MARK: interaction

    private func handleTap(at p: CGPoint, viewSize: CGSize, time: TimeInterval) {
        // find nearest alive bubble in screen space
        var bestIdx = -1
        var bestD: CGFloat = .greatestFiniteMagnitude
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let idx = cellIndex(row: r, col: c)
                if popped.contains(idx) { continue }
                let sp = screenPos(row: r, col: c, viewSize: viewSize)
                let d = hypot(sp.x - p.x, sp.y - p.y)
                if d < bestD { bestD = d; bestIdx = idx }
            }
        }
        guard bestIdx >= 0, bestD < 120 else { return }
        popped.insert(bestIdx)
        poppedAt = bestIdx
        burstStart = time
        lastTap = p

        // After popping, animate offset so next-closest bubble to CENTER is at CENTER.
        let center = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
        var nextIdx = -1
        var nextD: CGFloat = .greatestFiniteMagnitude
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let idx = cellIndex(row: r, col: c)
                if popped.contains(idx) { continue }
                let sp = screenPos(row: r, col: c, viewSize: viewSize)
                let d = hypot(sp.x - center.x, sp.y - center.y)
                if d < nextD { nextD = d; nextIdx = idx }
            }
        }
        if nextIdx >= 0 {
            let (nr, nc) = rowCol(of: nextIdx)
            let nw = worldPos(row: nr, col: nc)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                offset = CGSize(width: -nw.x, height: -nw.y)
            }
        }

        // Bump progress via engine's tap so audio/haptic + completion count fires.
        viewModel.engine.handleTap()
    }

    // MARK: drawing

    private func drawGrid(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let idx = cellIndex(row: r, col: c)
                let sp = screenPos(row: r, col: c, viewSize: size)
                // culling
                if sp.x < -80 || sp.x > size.width + 80 || sp.y < -80 || sp.y > size.height + 80 { continue }

                if popped.contains(idx) {
                    // If this is the freshly popped one, draw a short burst animation
                    if idx == poppedAt {
                        let dt = time - burstStart
                        if dt < 0.35 {
                            let t = CGFloat(dt / 0.35)
                            let rr = Self.bubbleRadius * (0.4 + t * 1.6)
                            let alpha = 1 - t
                            // radiating dashes
                            for k in 0..<8 {
                                let ang = CGFloat(k) * .pi / 4 + CGFloat(idx)
                                let a = CGPoint(x: sp.x + cos(ang) * rr * 0.4,
                                                y: sp.y + sin(ang) * rr * 0.4)
                                let b = CGPoint(x: sp.x + cos(ang) * rr,
                                                y: sp.y + sin(ang) * rr)
                                ctx.stroke(Rough.line(from: a, to: b, steps: 2, amp: 0.6, seed: idx &+ k),
                                           with: .color(DoodleStyle.ink.opacity(Double(alpha))),
                                           style: .doodleThin)
                            }
                            continue
                        }
                    }
                    // leave popped cells blank
                    continue
                }

                // Breathing scale — staggered by index
                let breathe = 0.95 + 0.05 * sin(time * 1.6 + Double(idx) * 0.37)
                let r0 = Self.bubbleRadius * CGFloat(breathe)
                let bRect = CGRect(x: sp.x - r0, y: sp.y - r0, width: r0 * 2, height: r0 * 2)

                // bubble body
                let bubblePath = Rough.ellipse(in: bRect, wobble: 0.9, points: 26, seed: idx &+ 1)
                ctx.fill(bubblePath, with: .color(DoodleStyle.sky.opacity(0.28)))
                ctx.stroke(bubblePath, with: .color(DoodleStyle.ink), style: .doodle)

                // highlight arc top-left
                let hlA = CGPoint(x: sp.x - r0 * 0.55, y: sp.y - r0 * 0.15)
                let hlB = CGPoint(x: sp.x - r0 * 0.15, y: sp.y - r0 * 0.55)
                ctx.stroke(Rough.arc(from: hlA, to: hlB, bulge: -3, seed: idx &+ 2),
                           with: .color(DoodleStyle.paper.opacity(0.9)), style: .doodleThin)
            }
        }
    }
}

struct BubblesDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            let radius: CGFloat = 12
            for r in 0..<4 {
                for c in 0..<4 {
                    let x = size.width * (0.18 + CGFloat(c) * 0.22) + (r % 2 == 0 ? 0 : 6)
                    let y = size.height * (0.18 + CGFloat(r) * 0.22)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let path = Rough.ellipse(in: rect, wobble: 0.6, points: 20, seed: r * 4 + c)
                    ctx.fill(path, with: .color(DoodleStyle.sky.opacity(0.28)))
                    ctx.stroke(path, with: .color(DoodleStyle.ink), style: .doodleThin)
                }
            }
        }
    }
}

#Preview {
    BubblesDoodle(viewModel: ToyViewModel(mode: .bubbleWrap))
        .frame(width: 360, height: 640).background(DoodleStyle.paper)
}
