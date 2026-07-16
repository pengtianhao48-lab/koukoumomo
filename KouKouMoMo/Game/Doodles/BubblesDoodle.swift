import SwiftUI

/// ⑤「压泡泡纸」— full-screen sheet of bubbles. Tap anywhere → nearest bubble pops. The
/// entire canvas then springs so the next-nearest bubble slides right under the finger,
/// so you can keep popping without moving your hand.
struct BubblesDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    private static let cols = 35
    private static let rows = 55
    private static let spacing: CGFloat = 60
    private static let bubbleRadius: CGFloat = 26

    @State private var popped: Set<Int> = []
    @State private var poppedAt: Int? = nil
    @State private var burstStart: TimeInterval = 0
    @State private var offset: CGSize = .zero
    @State private var lastTap: CGPoint? = nil
    @State private var pendingOffset: CGSize? = nil
    @State private var pendingMoveStart: TimeInterval = 0
    @State private var recentTapIntervals: [TimeInterval] = []
    @State private var lastAcceptedTapTime: TimeInterval?
    @State private var burstDuration: TimeInterval = 0.35
    @State private var isTouching = false
    @State private var lastTimelineStep: TimeInterval = 0

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawGrid(ctx: ctx, size: size, time: time)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard !isTouching else { return }
                            isTouching = true
                            handleTap(at: value.location, viewSize: proxy.size, time: time)
                        }
                        .onEnded { _ in
                            isTouching = false
                        }
                )
                .onChange(of: time) { _, newTime in
                    handleTimelineChange(newTime)
                }
            }
        }
    }

    private func cellIndex(row: Int, col: Int) -> Int { row * Self.cols + col }
    private func rowCol(of index: Int) -> (row: Int, col: Int) { (index / Self.cols, index % Self.cols) }

    private func handleTimelineChange(_ newTime: TimeInterval) {
        guard newTime - lastTimelineStep > 0.001 else { return }
        lastTimelineStep = newTime
        moveCanvasIfBurstFinished(now: newTime)
    }

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

    private func handleTap(at p: CGPoint, viewSize: CGSize, time: TimeInterval) {
        // Aggressive responsiveness: if tapping very fast (< 150ms since last accepted),
        // skip the animation lock and respond immediately.
        let interval = lastAcceptedTapTime == nil ? 9.0 : (time - lastAcceptedTapTime!)
        let isVeryFast = interval < 0.15

        if !isVeryFast {
            // While a burst is still playing and before the canvas has moved, ignore taps to avoid
            // overlapping pending moves and wrong-position bursts.
            if pendingOffset != nil { return }
            if let poppedAt, time - burstStart < burstDuration { return }
        }
        // Nearest unpopped bubble to tap point.
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
        guard bestIdx >= 0, bestD < 140 else { return }

        updateBurstDuration(forTapAt: time)
        popped.insert(bestIdx)
        poppedAt = bestIdx
        burstStart = time
        HapticManager.shared.bubblePop()
        viewModel.engine.handleTap()

        // Move the whole canvas AFTER the pop animation finishes so the burst stays at the
        // original tap location for its full 300–350ms lifecycle. The pending target is applied
        // from TimelineView.onChange once the burst has disappeared.
        var nextIdx = -1
        var nextD: CGFloat = .greatestFiniteMagnitude
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let idx = cellIndex(row: r, col: c)
                if popped.contains(idx) { continue }
                let sp = screenPos(row: r, col: c, viewSize: viewSize)
                let d = hypot(sp.x - p.x, sp.y - p.y)
                if d < nextD { nextD = d; nextIdx = idx }
            }
        }
        if nextIdx >= 0 {
            let (nr, nc) = rowCol(of: nextIdx)
            let nw = worldPos(row: nr, col: nc)
            // We want screenPos(nr,nc) == p, i.e.
            //   viewSize.width/2 + nw.x + newOffset.x = p.x  →  newOffset.x = p.x - viewSize.width/2 - nw.x
            let target = CGSize(width: p.x - viewSize.width/2 - nw.x,
                                height: p.y - viewSize.height/2 - nw.y)
            pendingOffset = target
            pendingMoveStart = time
        }
        lastTap = p
    }

    private func updateBurstDuration(forTapAt time: TimeInterval) {
        defer { lastAcceptedTapTime = time }
        guard let lastAcceptedTapTime else {
            burstDuration = 0.35
            return
        }
        let interval = max(0.04, time - lastAcceptedTapTime)
        recentTapIntervals.append(interval)
        if recentTapIntervals.count > 3 {
            recentTapIntervals.removeFirst(recentTapIntervals.count - 3)
        }
        let average = recentTapIntervals.reduce(0, +) / Double(recentTapIntervals.count)
        let target: TimeInterval
        if average < 0.15 {
            target = 0.08
        } else if average < 0.30 {
            target = 0.175
        } else {
            target = 0.35
        }
        burstDuration = burstDuration * 0.40 + target * 0.60
    }

    private func moveCanvasIfBurstFinished(now: TimeInterval) {
        guard let target = pendingOffset else { return }
        guard now - pendingMoveStart >= burstDuration else { return }
        pendingOffset = nil
        // Use a duration-based animation as requested to ensure dynamic speed is respected.
        withAnimation(.easeInOut(duration: burstDuration * 1.2)) {
            offset = target
        }
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                let idx = cellIndex(row: r, col: c)
                let sp = screenPos(row: r, col: c, viewSize: size)
                if sp.x < -80 || sp.x > size.width + 80 || sp.y < -80 || sp.y > size.height + 80 { continue }

                if popped.contains(idx) {
                    if idx == poppedAt {
                        let dt = time - burstStart
                        if dt < burstDuration {
                            let t = CGFloat(dt / burstDuration)
                            let rr = Self.bubbleRadius * (0.4 + t * 1.6)
                            let alpha = 1 - t
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
                    continue
                }

                // Breathing
                let breathe = 0.95 + 0.05 * sin(time * 1.6 + Double(idx) * 0.37)
                let r0 = Self.bubbleRadius * CGFloat(breathe)
                let bRect = CGRect(x: sp.x - r0, y: sp.y - r0, width: r0 * 2, height: r0 * 2)
                let bubblePath = Rough.ellipse(in: bRect, wobble: 0.9, points: 26, seed: idx &+ 1)
                ctx.fill(bubblePath, with: .color(DoodleStyle.sky.opacity(0.28)))
                ctx.stroke(bubblePath, with: .color(DoodleStyle.ink), style: .doodle)

                // Highlight
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
