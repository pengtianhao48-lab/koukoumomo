import SwiftUI

/// ⑥「转笔」— segmented hand-drawn pen (cap / body / tip). Spins in response to the engine's
///   rotation gesture, keeps inertia after finger-up, leaves 3–4 fading arc trails when fast,
///   and glows briefly every time it completes a 360°.
struct PenDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    // Local spin state — visualisation only, doesn't touch viewModel.progress semantics.
    @State private var angle: Double = 0            // current visual angle (degrees)
    @State private var angularVelocity: Double = 0  // deg/sec, from engine axis/velocity
    @State private var lastFrame: TimeInterval = 0
    @State private var lastAxis: Double = 0
    @State private var trailSamples: [Double] = []  // recent angles for ghost trails
    @State private var loopsCompleted: Int = 0
    @State private var loopGlowStart: TimeInterval = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                PenDoodleRenderer.draw(context: ctx, size: size,
                                       angle: angle,
                                       trail: trailSamples,
                                       velocity: abs(angularVelocity) / 720,
                                       isCompleting: viewModel.isCompleting,
                                       glowElapsed: time - loopGlowStart,
                                       time: time)
            }
            .onChange(of: time) { _, newTime in
                stepPhysics(now: newTime)
            }
        }
    }

    /// Integrates axis*velocity into an angular velocity + angle. Provides inertia when the user lets go.
    private func stepPhysics(now: TimeInterval) {
        if lastFrame == 0 { lastFrame = now; return }
        let dt = min(1.0/30, now - lastFrame)
        lastFrame = now

        // Drive angular velocity from engine (rotation gesture provides axis = signed delta radians).
        let axis = viewModel.axis
        let velocity = viewModel.velocity
        var av = angularVelocity
        if axis != lastAxis || velocity > 0.02 {
            let target = Double(sign(axis)) * velocity * 900
            av += (target - av) * 0.35
            lastAxis = axis
        }
        // Inertial decay when no user input
        if velocity < 0.05 {
            av *= pow(0.35, dt)
        }
        // Cap
        if av > 1400 { av = 1400 }
        if av < -1400 { av = -1400 }
        angularVelocity = av

        // Integrate angle
        let newAngle = angle + av * dt
        angle = newAngle

        // Full-loop detection
        let loops = Int(abs(newAngle) / 360)
        if loops != loopsCompleted {
            loopsCompleted = loops
            loopGlowStart = now
            HapticManager.shared.progress(intensity: 0.5)
            viewModel.engine.handleTap()
        }

        // Trail sampling
        if trailSamples.isEmpty || abs(newAngle - (trailSamples.last ?? newAngle)) > 10 {
            var updated = trailSamples
            updated.append(newAngle)
            if updated.count > 4 { updated.removeFirst(updated.count - 4) }
            trailSamples = updated
        }
    }

    private func sign(_ v: Double) -> Double { v >= 0 ? 1 : -1 }
}

struct PenDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            PenDoodleRenderer.draw(context: ctx, size: size, angle: -30, trail: [],
                                   velocity: 0, isCompleting: false, glowElapsed: 999, time: 0)
        }
    }
}

enum PenDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     angle: Double, trail: [Double], velocity: Double,
                     isCompleting: Bool, glowElapsed: TimeInterval, time: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height / 2

        // Faint hand hint (the pivot area) — small circle
        let pivot = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
        context.fill(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700),
                     with: .color(DoodleStyle.paperShadow.opacity(0.55)))
        context.stroke(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700),
                       with: .color(DoodleStyle.inkFaint), style: .doodleThin)

        // Ghost trails (older = fainter)
        for (i, ta) in trail.enumerated() {
            let alpha = Double(i + 1) / Double(trail.count + 1) * 0.28 * min(1.0, velocity * 2.0)
            if alpha < 0.02 { continue }
            drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: ta,
                    length: penLength(size), alpha: alpha, ghost: true)
        }

        // The pen itself
        drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: angle,
                length: penLength(size), alpha: 1.0, ghost: false)

        // Loop glow — bright halo the first 0.4s after every full spin
        if glowElapsed < 0.4 {
            let t = CGFloat(1 - glowElapsed / 0.4)
            let r: CGFloat = penLength(size) * 0.55 * (1 + (1 - t) * 0.5)
            let ring = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            context.stroke(Rough.ellipse(in: ring, wobble: 2.0, points: 42, seed: 720),
                           with: .color(DoodleStyle.sunshine.opacity(Double(t) * 0.85)),
                           style: .doodleBold)
        }

        // Completion flourish — starburst
        if isCompleting {
            for k in 0..<12 {
                let ang = Double(k) * .pi / 6 + sin(time) * 0.3
                let r0: CGFloat = penLength(size) * 0.32
                let r1: CGFloat = penLength(size) * 0.48
                let a = CGPoint(x: cx + cos(ang) * r0, y: cy + sin(ang) * r0)
                let b = CGPoint(x: cx + cos(ang) * r1, y: cy + sin(ang) * r1)
                context.stroke(Rough.line(from: a, to: b, steps: 2, amp: 0.5, seed: 730 &+ k),
                               with: .color(DoodleStyle.sunshine.opacity(0.75)),
                               style: .doodle)
            }
        }
    }

    private static func penLength(_ size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.7
    }

    /// Draw a segmented pen: cap (short), body (long, striped), tip (small triangle).
    private static func drawPen(context: GraphicsContext, center: CGPoint, angle: Double,
                                length: CGFloat, alpha: Double, ghost: Bool) {
        var pen = context
        pen.translateBy(x: center.x, y: center.y)
        pen.rotate(by: .degrees(angle))

        let totalW = length
        let capLen: CGFloat = totalW * 0.20
        let bodyLen: CGFloat = totalW * 0.62
        let tipLen: CGFloat = totalW * 0.18
        let halfLen = totalW / 2
        let thick: CGFloat = 12

        let inkColor = DoodleStyle.ink.opacity(alpha * (ghost ? 0.55 : 1))
        let bodyFill = DoodleStyle.blush.opacity(alpha * (ghost ? 0.25 : 0.7))
        let capFill = DoodleStyle.ink.opacity(alpha * (ghost ? 0.35 : 0.9))

        // Cap (right end)
        let capRect = CGRect(x: halfLen - capLen, y: -thick/2, width: capLen, height: thick)
        let capPath = Rough.roundedRect(capRect, corner: thick/2, wobble: 0.5, seed: 740)
        pen.fill(capPath, with: .color(capFill))
        pen.stroke(capPath, with: .color(inkColor), style: .doodle)
        // Clip ring near cap-body join
        let clipX = halfLen - capLen
        var clipPath = Path()
        clipPath.move(to: CGPoint(x: clipX, y: -thick/2 - 2))
        clipPath.addLine(to: CGPoint(x: clipX, y: thick/2 + 2))
        pen.stroke(clipPath, with: .color(inkColor), style: .doodle)

        // Body (middle)
        let bodyRect = CGRect(x: -halfLen + tipLen, y: -thick/2, width: bodyLen, height: thick)
        let bodyPath = Rough.roundedRect(bodyRect, corner: 3, wobble: 0.4, seed: 741)
        pen.fill(bodyPath, with: .color(bodyFill))
        pen.stroke(bodyPath, with: .color(inkColor), style: .doodle)
        // Grip stripes near the tip side
        for i in 0..<4 {
            let sx = -halfLen + tipLen + 6 + CGFloat(i) * 6
            var stripe = Path()
            stripe.move(to: CGPoint(x: sx, y: -thick/2 + 2))
            stripe.addLine(to: CGPoint(x: sx, y: thick/2 - 2))
            pen.stroke(stripe, with: .color(inkColor.opacity(alpha * 0.7)), style: .doodleThin)
        }

        // Tip (left end) - triangle
        var tip = Path()
        tip.move(to: CGPoint(x: -halfLen, y: 0))
        tip.addLine(to: CGPoint(x: -halfLen + tipLen, y: -thick/2))
        tip.addLine(to: CGPoint(x: -halfLen + tipLen, y: thick/2))
        tip.closeSubpath()
        pen.fill(tip, with: .color(DoodleStyle.ink.opacity(alpha * (ghost ? 0.4 : 0.95))))
        pen.stroke(tip, with: .color(inkColor), style: .doodle)
    }
}

#Preview {
    PenDoodle(viewModel: ToyViewModel(mode: .penSpin))
        .frame(width: 360, height: 360).background(DoodleStyle.paper)
}
