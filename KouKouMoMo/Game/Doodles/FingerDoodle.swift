import SwiftUI

/// ④「咬手指」— front-view mouth: full lips, two rows of small rounded-square teeth,
/// a finger inserted between them. Left/right slide drives a real chomp cycle.
/// Tiny nail-clipping shards spray from the corners of the mouth on every bite.
/// Infinite loop — no completion state.
struct FingerDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    // A small pool of active debris particles.
    @State private var debris: [Debris] = []
    @State private var lastEmit: TimeInterval = 0
    @State private var lastBiteSign: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                FingerDoodleRenderer.draw(context: ctx, size: size,
                                          axis: viewModel.axis,
                                          velocity: viewModel.velocity,
                                          debris: debris,
                                          time: time)
            }
            .onChange(of: time) { _, newTime in step(now: newTime) }
        }
    }

    private func step(now: TimeInterval) {
        // Prune dead debris.
        debris = debris.filter { now - $0.birth < $0.life }

        // Emit new debris on each bite half-cycle when velocity is high enough.
        let phase = sin(now * 7.0 + viewModel.axis * 2)
        let curSign = phase >= 0 ? 1.0 : -1.0
        if curSign != lastBiteSign && viewModel.velocity > 0.30 && (now - lastEmit) > 0.09 {
            lastEmit = now
            let n = Int.random(in: 2...4)
            for _ in 0..<n {
                let fromLeft = Bool.random()
                debris.append(Debris.random(fromLeft: fromLeft, now: now))
            }
        }
        lastBiteSign = curSign
    }
}

/// A small crescent-like nail chip. Position is computed analytically from birth+velocity+gravity
/// in `draw`, so we don't need to know the view size while stepping.
struct Debris {
    var originX: CGFloat  // fraction of view width  (0…1)
    var originY: CGFloat  // fraction of view height (0…1)
    var vx: CGFloat       // pixels / second
    var vy: CGFloat       // pixels / second (negative = up)
    var rot: CGFloat
    var rotSpeed: CGFloat
    var length: CGFloat
    var birth: TimeInterval
    var life: TimeInterval

    static func random(fromLeft: Bool, now: TimeInterval) -> Debris {
        let cornerX: CGFloat = fromLeft ? 0.18 : 0.82
        let cornerY: CGFloat = 0.50
        let vx: CGFloat = (fromLeft ? -1 : 1) * CGFloat.random(in: 80...220)
        let vy: CGFloat = CGFloat.random(in: -260 ... -80)
        return Debris(originX: cornerX, originY: cornerY, vx: vx, vy: vy,
                      rot: CGFloat.random(in: -0.6...0.6),
                      rotSpeed: CGFloat.random(in: -6...6),
                      length: CGFloat.random(in: 6...11),
                      birth: now,
                      life: TimeInterval.random(in: 0.7...1.2))
    }
}

struct FingerDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            FingerDoodleRenderer.draw(context: ctx, size: size, axis: 0, velocity: 0, debris: [], time: 0)
        }
    }
}

private enum FingerDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     axis: Double, velocity: Double, debris: [Debris], time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Chomp rhythm
        let chompPhase = sin(time * 7.0 + axis * 2)
        let chompStrength = CGFloat(0.35 + velocity * 0.65)
        let bite = CGFloat(chompPhase) * chompStrength
        let topOffset = bite * 5
        let botOffset = -bite * 5
        let mouthCornerContract = abs(bite) * 3

        let mouthCenterX = W * 0.5
        let mouthCenterY = H * 0.48
        let mouthWidth: CGFloat = W * 0.68

        // Upper lip
        let ulLeft = CGPoint(x: mouthCenterX - mouthWidth/2 + mouthCornerContract, y: mouthCenterY - 4)
        let ulRight = CGPoint(x: mouthCenterX + mouthWidth/2 - mouthCornerContract, y: mouthCenterY - 4)
        var upperLip = Path()
        upperLip.move(to: ulLeft)
        upperLip.addCurve(to: CGPoint(x: mouthCenterX - 12, y: mouthCenterY - 22),
                          control1: CGPoint(x: mouthCenterX - mouthWidth * 0.34, y: mouthCenterY - 28),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.22, y: mouthCenterY - 24))
        upperLip.addQuadCurve(to: CGPoint(x: mouthCenterX + 12, y: mouthCenterY - 22),
                              control: CGPoint(x: mouthCenterX, y: mouthCenterY - 12))
        upperLip.addCurve(to: ulRight,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.22, y: mouthCenterY - 24),
                          control2: CGPoint(x: mouthCenterX + mouthWidth * 0.34, y: mouthCenterY - 28))
        upperLip.addCurve(to: ulLeft,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.28, y: mouthCenterY - 2),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.28, y: mouthCenterY - 2))
        context.fill(upperLip, with: .color(DoodleStyle.blush.opacity(0.42)))
        context.stroke(upperLip, with: .color(DoodleStyle.ink), style: .doodleBold)

        // Lower lip
        let llLeft = CGPoint(x: mouthCenterX - mouthWidth/2 + mouthCornerContract, y: mouthCenterY + 4)
        let llRight = CGPoint(x: mouthCenterX + mouthWidth/2 - mouthCornerContract, y: mouthCenterY + 4)
        var lowerLip = Path()
        lowerLip.move(to: llLeft)
        lowerLip.addCurve(to: llRight,
                          control1: CGPoint(x: mouthCenterX - mouthWidth * 0.30, y: mouthCenterY + 32),
                          control2: CGPoint(x: mouthCenterX + mouthWidth * 0.30, y: mouthCenterY + 32))
        lowerLip.addCurve(to: llLeft,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.28, y: mouthCenterY + 6),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.28, y: mouthCenterY + 6))
        context.fill(lowerLip, with: .color(DoodleStyle.blush.opacity(0.42)))
        context.stroke(lowerLip, with: .color(DoodleStyle.ink), style: .doodleBold)

        // Corners
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let corner = CGPoint(x: mouthCenterX + s * (mouthWidth/2 - mouthCornerContract),
                                 y: mouthCenterY)
            let tail = CGPoint(x: corner.x + s * 12, y: corner.y - 4)
            context.stroke(Rough.arc(from: corner, to: tail, bulge: -s * 3, seed: 480),
                           with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        // Inside cavity
        let cavityRect = CGRect(x: mouthCenterX - mouthWidth/2 + 14,
                                y: mouthCenterY - 8,
                                width: mouthWidth - 28,
                                height: 16)
        context.fill(Rough.ellipse(in: cavityRect, wobble: 1.0, seed: 471),
                     with: .color(DoodleStyle.ink.opacity(0.78)))

        // Teeth
        let toothCount = 5
        let toothW: CGFloat = 20
        let toothH: CGFloat = 20
        let toothGap: CGFloat = 4
        let toothRowW = CGFloat(toothCount) * toothW + CGFloat(toothCount - 1) * toothGap
        let toothStartX = mouthCenterX - toothRowW / 2

        for i in 0..<toothCount {
            let x = toothStartX + CGFloat(i) * (toothW + toothGap)
            let baseY = mouthCenterY - 4 - toothH + topOffset
            let rect = CGRect(x: x, y: baseY, width: toothW, height: toothH)
            let path = Rough.roundedRect(rect, corner: 5, wobble: 0.6, seed: 500 &+ i)
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }
        for i in 0..<toothCount {
            let x = toothStartX + CGFloat(i) * (toothW + toothGap)
            let baseY = mouthCenterY + 4 + botOffset
            let rect = CGRect(x: x, y: baseY, width: toothW, height: toothH)
            let path = Rough.roundedRect(rect, corner: 5, wobble: 0.6, seed: 520 &+ i)
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }

        // Finger
        let fingerCx = mouthCenterX + CGFloat(axis).clamped(to: -1...1) * 8
        let fingerW: CGFloat = 34
        let fingerBottom = H * 0.96
        let fingerTopY = mouthCenterY - 2
        let fingerRect = CGRect(x: fingerCx - fingerW/2, y: fingerTopY,
                                width: fingerW, height: fingerBottom - fingerTopY)
        var finger = Path()
        finger.addRoundedRect(in: fingerRect, cornerSize: CGSize(width: fingerW/2, height: fingerW/2))
        context.fill(finger, with: .color(DoodleStyle.paper))
        context.stroke(finger, with: .color(DoodleStyle.ink), style: .doodleBold)
        let knuckleY = fingerTopY + fingerW * 1.5
        context.stroke(Rough.arc(from: CGPoint(x: fingerCx - fingerW/2 + 5, y: knuckleY),
                                 to: CGPoint(x: fingerCx + fingerW/2 - 5, y: knuckleY),
                                 bulge: 3, seed: 540),
                       with: .color(DoodleStyle.ink), style: .doodle)
        let nailRect = CGRect(x: fingerCx - 10, y: fingerTopY + 4, width: 20, height: 10)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY),
                                 to: CGPoint(x: nailRect.maxX, y: nailRect.midY),
                                 bulge: -5, seed: 541),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)

        if abs(bite) > 0.6 {
            let markY = mouthCenterY
            context.stroke(Rough.arc(from: CGPoint(x: fingerCx - 8, y: markY),
                                     to: CGPoint(x: fingerCx + 8, y: markY),
                                     bulge: 2, seed: 555),
                           with: .color(DoodleStyle.ink.opacity(0.6)), style: .doodleThin)
        }

        // ============ Nail-clipping debris ============
        // Compute each particle's current pixel position analytically from birth + initial velocity + gravity.
        let gravity: CGFloat = 900
        for d in debris {
            let age = CGFloat(time - d.birth)
            let alpha = max(0, 1 - Double(age) / d.life)
            let px = d.originX * W + d.vx * age
            let py = d.originY * H + d.vy * age + 0.5 * gravity * age * age
            var dCtx = context
            dCtx.translateBy(x: px, y: py)
            dCtx.rotate(by: .radians(Double(d.rot + d.rotSpeed * age)))
            let a = CGPoint(x: -d.length/2, y: 0)
            let b = CGPoint(x: d.length/2, y: 0)
            dCtx.stroke(Rough.arc(from: a, to: b, bulge: -3, seed: 700),
                        with: .color(DoodleStyle.ink.opacity(alpha * 0.85)),
                        style: .doodle)
        }
    }
}

#Preview {
    FingerDoodle(viewModel: ToyViewModel(mode: .fingerNibble))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
