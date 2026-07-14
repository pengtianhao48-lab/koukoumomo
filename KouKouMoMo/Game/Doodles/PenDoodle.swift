import SwiftUI

/// ⑥「转笔」— segmented hand-drawn pen (cap / body / tip). Slow drags rotate it 1:1 with the
/// finger; a quick flick imparts real angular momentum that decays via friction, so the pen
/// spins for several turns and then coasts to a stop. It stays quiet: no completion sound, haptic, or glow.
struct PenDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    @State private var angle: Double = 0            // current visual angle (degrees, cumulative)
    @State private var angularVelocity: Double = 0  // deg/sec
    @State private var lastFrame: TimeInterval = 0
    @State private var lastAxisSeen: Double = 0
    @State private var lastVelocitySeen: Double = 0
    @State private var trailSamples: [Double] = []
    // Tunables
    private let momentumGain: Double = 420       // how much angular momentum each unit of axis contributes
    private let friction: Double = 1.9           // exponential friction: av *= exp(-friction * dt)
    private let flickThreshold: Double = 0.35    // velocity above which we count as a flick
    private let maxAV: Double = 2600             // deg/sec cap

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                PenDoodleRenderer.draw(context: ctx, size: size,
                                       angle: angle,
                                       trail: trailSamples,
                                       velocity: abs(angularVelocity) / 900,
                                       time: time)
            }
            .onChange(of: time) { _, newTime in step(now: newTime) }
        }
    }

    private func step(now: TimeInterval) {
        if lastFrame == 0 { lastFrame = now; return }
        let dt = min(1.0/30, now - lastFrame)
        lastFrame = now

        let axis = viewModel.axis
        let velocity = viewModel.velocity

        // Add momentum when there's fresh finger movement. NOTE: user reported the previous
        // implementation rotated in the OPPOSITE direction of the finger — inverted here so a
        // rightward drag rotates the pen clockwise (visually same-direction as the finger tip).
        if axis != lastAxisSeen || velocity > 0.01 {
            let dAxis = axis - lastAxisSeen
            // Prefer the raw delta if it's meaningful, otherwise use axis directly.
            let contrib = abs(dAxis) > 0.001 ? dAxis : axis * velocity * 3.0
            angularVelocity += -contrib * momentumGain

            // Flick detection — a big burst of velocity → extra push. No haptic/sound for this toy.
            if velocity > flickThreshold && velocity - lastVelocitySeen > 0.15 {
                angularVelocity += -sign(axis) * velocity * 800
            }
            lastAxisSeen = axis
            lastVelocitySeen = velocity
        }

        // Friction is ALWAYS applied — that's what makes the pen coast to a stop naturally.
        angularVelocity *= exp(-friction * dt)
        if angularVelocity > maxAV { angularVelocity = maxAV }
        if angularVelocity < -maxAV { angularVelocity = -maxAV }
        // Snap tiny residuals to zero so the pen truly stops.
        if abs(angularVelocity) < 3 { angularVelocity = 0 }

        // Integrate angle
        let newAngle = angle + angularVelocity * dt
        angle = newAngle

        // Dedicated subtle spin-wind sound. Faster spin = denser/brighter system sound ticks;
        // when friction slows the pen below threshold it naturally fades out.
        AudioManager.shared.penSpinWind(speed: abs(angularVelocity) / maxAV)

        // Trail sampling (only while moving fast enough to look nice)
        if abs(angularVelocity) > 180 {
            if trailSamples.isEmpty || abs(newAngle - (trailSamples.last ?? newAngle)) > 12 {
                var updated = trailSamples
                updated.append(newAngle)
                if updated.count > 4 { updated.removeFirst(updated.count - 4) }
                trailSamples = updated
            }
        } else if !trailSamples.isEmpty {
            trailSamples = []
        }
    }

    private func sign(_ v: Double) -> Double { v >= 0 ? 1 : -1 }
}

struct PenDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            PenDoodleRenderer.draw(context: ctx, size: size, angle: -30, trail: [],
                                   velocity: 0, time: 0)
        }
    }
}

enum PenDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     angle: Double, trail: [Double], velocity: Double,
                     time: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height / 2

        // Pivot circle
        let pivot = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
        context.fill(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700),
                     with: .color(DoodleStyle.paperShadow.opacity(0.55)))
        context.stroke(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700),
                       with: .color(DoodleStyle.inkFaint), style: .doodleThin)

        // Ghost trails
        for (i, ta) in trail.enumerated() {
            let alpha = Double(i + 1) / Double(trail.count + 1) * 0.30 * min(1.0, velocity * 2.0)
            if alpha < 0.02 { continue }
            drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: ta,
                    length: penLength(size), alpha: alpha, ghost: true)
        }

        // Main pen
        drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: angle,
                length: penLength(size), alpha: 1.0, ghost: false)

        _ = time
    }

    private static func penLength(_ size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.7
    }

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

        // Cap
        let capRect = CGRect(x: halfLen - capLen, y: -thick/2, width: capLen, height: thick)
        let capPath = Rough.roundedRect(capRect, corner: thick/2, wobble: 0.5, seed: 740)
        pen.fill(capPath, with: .color(capFill))
        pen.stroke(capPath, with: .color(inkColor), style: .doodle)
        let clipX = halfLen - capLen
        var clipPath = Path()
        clipPath.move(to: CGPoint(x: clipX, y: -thick/2 - 2))
        clipPath.addLine(to: CGPoint(x: clipX, y: thick/2 + 2))
        pen.stroke(clipPath, with: .color(inkColor), style: .doodle)

        // Body
        let bodyRect = CGRect(x: -halfLen + tipLen, y: -thick/2, width: bodyLen, height: thick)
        let bodyPath = Rough.roundedRect(bodyRect, corner: 3, wobble: 0.4, seed: 741)
        pen.fill(bodyPath, with: .color(bodyFill))
        pen.stroke(bodyPath, with: .color(inkColor), style: .doodle)
        for i in 0..<4 {
            let sx = -halfLen + tipLen + 6 + CGFloat(i) * 6
            var stripe = Path()
            stripe.move(to: CGPoint(x: sx, y: -thick/2 + 2))
            stripe.addLine(to: CGPoint(x: sx, y: thick/2 - 2))
            pen.stroke(stripe, with: .color(inkColor.opacity(alpha * 0.7)), style: .doodleThin)
        }

        // Tip
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
