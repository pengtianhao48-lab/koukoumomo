import SwiftUI

/// ③「摸耳垂」— side profile with an ear whose lobe follows the finger 1:1 vertically.
/// Slide down → lobe stretches down with the finger, release → lobe springs back.
/// Infinite loop — no completion state.
struct EarDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    // Local integration so the lobe truly 1:1 follows the finger.
    @State private var lobeOffset: CGFloat = 0
    @State private var lastFrame: TimeInterval = 0
    @State private var wasPulling = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                EarDoodleRenderer.draw(context: ctx, size: size,
                                       lobeOffset: lobeOffset,
                                       velocity: viewModel.velocity,
                                       progress: viewModel.progress,
                                       time: time)
            }
            .onChange(of: time) { _, newTime in step(now: newTime) }
        }
    }

    private func step(now: TimeInterval) {
        if lastFrame == 0 { lastFrame = now; return }
        let dt = min(1.0/30, now - lastFrame)
        lastFrame = now
        let v = viewModel.velocity

        if v > 0.05 {
            // Actively pulling — apply axis as a positional delta (axis = drag delta / 20)
            let delta = CGFloat(viewModel.axis) * 20
            lobeOffset += delta
            // Clamp so lobe doesn't fly off-screen
            if lobeOffset > 140 { lobeOffset = 140 }
            if lobeOffset < -40 { lobeOffset = -40 }
            wasPulling = true
        } else {
            // Not pulling — spring back to 0 with critically-damped exponential decay
            if wasPulling && lobeOffset > 30 {
                HapticManager.shared.earSpringBack()
                wasPulling = false
            } else if wasPulling && lobeOffset <= 30 {
                wasPulling = false
            }
            let k: Double = 8.0  // stiffness
            lobeOffset = lobeOffset * CGFloat(exp(-k * dt))
            if abs(lobeOffset) < 0.4 { lobeOffset = 0 }
        }
    }
}

struct EarDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            EarDoodleRenderer.draw(context: ctx, size: size,
                                   lobeOffset: 0, velocity: 0, progress: 0, time: 0)
        }
    }
}

private enum EarDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     lobeOffset: CGFloat, velocity: Double, progress: Double, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Side profile: a big head silhouette. Occupy left side; ear sits on the right cheek.
        let headRect = CGRect(x: W * 0.10, y: H * 0.14, width: W * 0.60, height: H * 0.72)
        context.stroke(Rough.ellipse(in: headRect, wobble: 2.2, points: 44, seed: 300),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Hair squiggles on top
        for i in 0..<5 {
            let x = headRect.minX + headRect.width * (0.20 + Double(i) * 0.13)
            context.stroke(Rough.line(from: CGPoint(x: x, y: headRect.minY + 4),
                                      to: CGPoint(x: x + 4, y: headRect.minY - 12),
                                      steps: 3, amp: 0.5, seed: 305 &+ i),
                           with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        // Simple side-view face features (facing left)
        let eyeY = headRect.midY - headRect.height * 0.10
        let eye = CGRect(x: headRect.minX + headRect.width * 0.24, y: eyeY, width: 8, height: 5)
        context.fill(Rough.ellipse(in: eye, wobble: 0.4, seed: 312), with: .color(DoodleStyle.ink))
        // Small nose bump on the left silhouette
        context.stroke(Rough.arc(from: CGPoint(x: headRect.minX + 4, y: headRect.midY - 6),
                                 to: CGPoint(x: headRect.minX + 4, y: headRect.midY + 14),
                                 bulge: -10, seed: 313),
                       with: .color(DoodleStyle.ink), style: .doodle)
        // Little mouth
        context.stroke(Rough.arc(from: CGPoint(x: headRect.minX + 10, y: headRect.midY + 40),
                                 to: CGPoint(x: headRect.minX + 34, y: headRect.midY + 40),
                                 bulge: 6, seed: 314),
                       with: .color(DoodleStyle.ink), style: .doodleThin)

        // Ear sits on the right side of the head
        let earCenterX = headRect.maxX - 26
        let earCenterY = headRect.midY - 8
        let earRect = CGRect(x: earCenterX - 32, y: earCenterY - 42, width: 64, height: 84)
        // outer shell
        context.stroke(Rough.ellipse(in: earRect, wobble: 1.8, points: 34, seed: 320),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        // inner curl
        context.stroke(Rough.ellipse(in: earRect.insetBy(dx: 12, dy: 18), wobble: 1.2, points: 28, seed: 321),
                       with: .color(DoodleStyle.ink), style: .doodle)
        // tragus
        var tragus = Path()
        tragus.move(to: CGPoint(x: earRect.midX - 6, y: earRect.maxY - 30))
        tragus.addQuadCurve(to: CGPoint(x: earRect.midX + 4, y: earRect.maxY - 14),
                            control: CGPoint(x: earRect.midX + 12, y: earRect.maxY - 22))
        context.stroke(tragus, with: .color(DoodleStyle.ink), style: .doodle)

        // Lobe — hangs below the ear, stretches vertically 1:1 with the finger's slide offset.
        let baseLobeCenter = CGPoint(x: earRect.midX - 4, y: earRect.maxY + 14)
        // The stretch: lobeOffset > 0 stretches down; height grows, center shifts down half of offset.
        let stretchAmount = max(0, lobeOffset)  // negative offsets don't push the lobe up
        let lobeH: CGFloat = 44 + stretchAmount * 0.9
        let lobeW: CGFloat = 46 - min(12, stretchAmount * 0.12)
        let lobeRect = CGRect(x: baseLobeCenter.x - lobeW / 2,
                              y: baseLobeCenter.y - 22 + stretchAmount * 0.5,
                              width: lobeW,
                              height: lobeH)
        let blushAlpha = 0.20 + Double(stretchAmount / 140) * 0.55
        context.fill(Rough.ellipse(in: lobeRect, wobble: 1.4, seed: 341),
                     with: .color(DoodleStyle.blush.opacity(blushAlpha)))
        context.stroke(Rough.ellipse(in: lobeRect, wobble: 1.4, seed: 341),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        // Earring dot at the bottom of the lobe
        let dot = CGRect(x: baseLobeCenter.x - 3, y: lobeRect.maxY - 6, width: 6, height: 6)
        context.fill(Rough.ellipse(in: dot, wobble: 0.4, seed: 351),
                     with: .color(DoodleStyle.ink))

        // A finger pinching the lobe from the right — moves along with lobeOffset.
        let pinchY = lobeRect.maxY - 4
        let fingerBaseX = W - 12
        let fingerBaseY = pinchY + 30
        var fingerTrunk = Path()
        fingerTrunk.move(to: CGPoint(x: fingerBaseX, y: fingerBaseY))
        fingerTrunk.addQuadCurve(to: CGPoint(x: baseLobeCenter.x + 8, y: pinchY),
                                 control: CGPoint(x: fingerBaseX - 20, y: pinchY - 4))
        context.stroke(fingerTrunk, with: .color(DoodleStyle.ink),
                       style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
        context.stroke(fingerTrunk, with: .color(DoodleStyle.paper),
                       style: StrokeStyle(lineWidth: 27, lineCap: .round, lineJoin: .round))

        // Motion lines while pulling
        if velocity > 0.10 {
            for i in 0..<3 {
                let y = lobeRect.midY - 14 + CGFloat(i) * 6
                context.stroke(Rough.line(from: CGPoint(x: lobeRect.maxX + 6, y: y),
                                          to: CGPoint(x: lobeRect.maxX + 18, y: y),
                                          steps: 3, amp: 0.4, seed: 361 &+ i),
                               with: .color(DoodleStyle.ink.opacity(0.4)),
                               style: .doodleThin)
            }
        }
        _ = progress
        _ = time
    }
}

#Preview {
    EarDoodle(viewModel: ToyViewModel(mode: .earLobe))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
