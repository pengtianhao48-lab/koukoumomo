import SwiftUI

/// ①「抠鼻孔」— a face reacts as you draw tiny circles. A finger reaches up from below
/// and rotates inside the right nostril along with the user's motion.
struct NoseDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                NoseDoodleRenderer.draw(context: ctx, size: size,
                                        progress: viewModel.progress,
                                        velocity: viewModel.velocity,
                                        axis: viewModel.axis,
                                        isCompleting: viewModel.isCompleting,
                                        completionTick: viewModel.completionTick,
                                        time: now)
            }
        }
    }
}

struct NoseDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            NoseDoodleRenderer.draw(context: ctx, size: size,
                                    progress: 0, velocity: 0, axis: 0,
                                    isCompleting: false, completionTick: 0, time: 0)
        }
    }
}

private enum NoseDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, velocity: Double, axis: Double,
                     isCompleting: Bool, completionTick: Int, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Face outline
        let face = CGRect(x: W * 0.14, y: H * 0.16, width: W * 0.72, height: H * 0.68)
        context.stroke(Rough.ellipse(in: face, wobble: 2.2, points: 42, seed: 11),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Cheeks blush
        let cheekOpacity = 0.35 + progress * 0.35
        context.fill(Rough.ellipse(in: CGRect(x: face.minX + face.width * 0.10, y: face.midY + face.height * 0.06,
                                              width: face.width * 0.18, height: face.width * 0.10),
                                    wobble: 1.4, seed: 21),
                     with: .color(DoodleStyle.blush.opacity(cheekOpacity)))
        context.fill(Rough.ellipse(in: CGRect(x: face.maxX - face.width * 0.28, y: face.midY + face.height * 0.06,
                                              width: face.width * 0.18, height: face.width * 0.10),
                                    wobble: 1.4, seed: 22),
                     with: .color(DoodleStyle.blush.opacity(cheekOpacity)))

        // Eyes — squint as progress rises
        let eyeY = face.midY - face.height * 0.14
        let leftEyeC = CGPoint(x: face.midX - face.width * 0.19, y: eyeY)
        let rightEyeC = CGPoint(x: face.midX + face.width * 0.19, y: eyeY)
        let eyeHeight: CGFloat = 8 + 3 * CGFloat(sin(time * 0.6)) - CGFloat(progress) * 5
        for (idx, c) in [leftEyeC, rightEyeC].enumerated() {
            let squint = max(2.5, eyeHeight)
            let rect = CGRect(x: c.x - 7, y: c.y - squint / 2, width: 14, height: squint)
            context.fill(Rough.ellipse(in: rect, wobble: 0.6, seed: 33 &+ idx),
                         with: .color(DoodleStyle.ink))
        }
        // Eyebrows: normal → furrow inward
        let browTilt = CGFloat(progress) * 12
        for (i, cx) in [face.midX - face.width * 0.19, face.midX + face.width * 0.19].enumerated() {
            let sign: CGFloat = i == 0 ? 1 : -1
            let start = CGPoint(x: cx - 14, y: eyeY - 18 + browTilt * sign)
            let end = CGPoint(x: cx + 14, y: eyeY - 18 - browTilt * sign)
            context.stroke(Rough.line(from: start, to: end, steps: 6, amp: 1.0, seed: 71 &+ i),
                           with: .color(DoodleStyle.ink), style: .doodleBold)
        }

        // Nose: bulbous triangle
        let noseTop = CGPoint(x: face.midX, y: face.midY - face.height * 0.02)
        let noseLeft = CGPoint(x: face.midX - face.width * 0.16, y: face.midY + face.height * 0.14)
        let noseRight = CGPoint(x: face.midX + face.width * 0.16, y: face.midY + face.height * 0.14)
        context.stroke(Rough.line(from: noseTop, to: noseLeft, steps: 8, amp: 1.3, seed: 101),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.line(from: noseTop, to: noseRight, steps: 8, amp: 1.3, seed: 102),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.arc(from: noseLeft, to: noseRight, bulge: 26, seed: 103),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Two nostrils
        let leftNostril = CGRect(x: noseLeft.x + 6, y: noseLeft.y - 12, width: 22, height: 14)
        let rightNostril = CGRect(x: noseRight.x - 28, y: noseRight.y - 12, width: 22, height: 14)
        context.fill(Rough.ellipse(in: leftNostril, wobble: 0.9, seed: 111), with: .color(DoodleStyle.ink))
        context.fill(Rough.ellipse(in: rightNostril, wobble: 0.9, seed: 112), with: .color(DoodleStyle.ink))

        // ============ NEW: A finger reaches into the right nostril ============
        // Finger enters from below the face and its tip orbits inside the right nostril.
        let orbitR: CGFloat = 2.4 + CGFloat(progress) * 2.2
        let spin = time * 3.4 + axis * 6
        let nostrilCenter = CGPoint(x: rightNostril.midX, y: rightNostril.midY)
        let tipCenter = CGPoint(x: nostrilCenter.x + cos(spin) * orbitR,
                                y: nostrilCenter.y + sin(spin) * orbitR * 0.45)

        // Finger geometry: knuckle at bottom-right, curves up to the nostril tip.
        // Draw as a wobbly capsule from (baseX, bottom) to tipCenter.
        let baseX = face.midX + face.width * 0.20 + CGFloat(sin(time * 1.6)) * 4
        let baseY = face.maxY + 18
        let fingerW: CGFloat = 26

        // Trunk of the finger — draw ink outline first (wider), then paper inside (thinner).
        var trunk = Path()
        let control = CGPoint(x: baseX - 12, y: (baseY + tipCenter.y) / 2 + 24)
        trunk.move(to: CGPoint(x: baseX, y: baseY))
        trunk.addQuadCurve(to: tipCenter, control: control)
        context.stroke(trunk, with: .color(DoodleStyle.ink),
                       style: StrokeStyle(lineWidth: fingerW + 3, lineCap: .round, lineJoin: .round))
        context.stroke(trunk, with: .color(DoodleStyle.paper),
                       style: StrokeStyle(lineWidth: fingerW, lineCap: .round, lineJoin: .round))
        // Knuckle line hint
        let knuckleT: CGFloat = 0.65
        let kx = (1-knuckleT)*(1-knuckleT)*baseX + 2*(1-knuckleT)*knuckleT*control.x + knuckleT*knuckleT*tipCenter.x
        let ky = (1-knuckleT)*(1-knuckleT)*baseY + 2*(1-knuckleT)*knuckleT*control.y + knuckleT*knuckleT*tipCenter.y
        context.stroke(Rough.arc(from: CGPoint(x: kx - 8, y: ky), to: CGPoint(x: kx + 8, y: ky),
                                 bulge: 3, seed: 210),
                       with: .color(DoodleStyle.ink.opacity(0.6)), style: .doodleThin)

        // Repaint the nostril over the finger stem so the stem appears to enter the cavity,
        // then draw only the fingertip inside the black nostril.
        context.fill(Rough.ellipse(in: rightNostril, wobble: 0.9, seed: 112), with: .color(DoodleStyle.ink))
        let fingertipRect = CGRect(x: tipCenter.x - 6, y: tipCenter.y - 4, width: 12, height: 8)
        context.fill(Rough.ellipse(in: fingertipRect, wobble: 0.5, seed: 210),
                     with: .color(DoodleStyle.paper))
        context.stroke(Rough.ellipse(in: fingertipRect, wobble: 0.5, seed: 210),
                       with: .color(DoodleStyle.ink), style: .doodleThin)

        // Nail hint inside the nostril
        let nailRect = CGRect(x: tipCenter.x - 6, y: tipCenter.y - 3, width: 12, height: 6)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY),
                                 to: CGPoint(x: nailRect.maxX, y: nailRect.midY),
                                 bulge: -3, seed: 211),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)

        // Booger blob follows the finger tip
        let boogerSize = 3 + CGFloat(progress) * 6
        if progress > 0.02 || isCompleting {
            let boogerRect = CGRect(x: tipCenter.x - boogerSize / 2, y: tipCenter.y - boogerSize / 2,
                                    width: boogerSize, height: boogerSize)
            context.fill(Rough.ellipse(in: boogerRect, wobble: 0.7, seed: 121),
                         with: .color(DoodleStyle.sunshine.opacity(0.85)))
            context.stroke(Rough.ellipse(in: boogerRect, wobble: 0.7, seed: 121),
                           with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        // Mouth
        let mouthCenter = CGPoint(x: face.midX, y: face.maxY - face.height * 0.14)
        let mouthWidth: CGFloat = 60 + (isCompleting ? 28 : CGFloat(progress) * 8)
        let mouthBulge: CGFloat = isCompleting ? 32 : 14 + CGFloat(progress) * 8
        context.stroke(Rough.arc(
            from: CGPoint(x: mouthCenter.x - mouthWidth, y: mouthCenter.y),
            to: CGPoint(x: mouthCenter.x + mouthWidth, y: mouthCenter.y),
            bulge: mouthBulge, seed: 131),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Completion: blob flies up + squiggles (unchanged)
        if isCompleting {
            let liftPhase = CGFloat(sin(min(1, (time - Double(completionTick)) * 4)))
            let blobRect = CGRect(x: rightNostril.midX - 20, y: rightNostril.midY - 90 - liftPhase * 20,
                                   width: 40, height: 30)
            context.fill(Rough.ellipse(in: blobRect, wobble: 1.6, seed: 141),
                         with: .color(DoodleStyle.sunshine))
            context.stroke(Rough.ellipse(in: blobRect, wobble: 1.6, seed: 141),
                           with: .color(DoodleStyle.ink), style: .doodle)
            for i in 0..<3 {
                let ang = CGFloat(i) * .pi / 3 - .pi
                let baseX2 = rightNostril.midX + cos(ang) * 24
                let baseY2 = rightNostril.midY - 32 + sin(ang) * 24
                let tipX = baseX2 + cos(ang) * 14
                let tipY = baseY2 + sin(ang) * 14 - 6
                context.stroke(Rough.line(from: CGPoint(x: baseX2, y: baseY2),
                                          to: CGPoint(x: tipX, y: tipY),
                                          steps: 3, amp: 0.6, seed: 150 &+ i),
                               with: .color(DoodleStyle.ink), style: .doodle)
            }
        }
    }
}

#Preview {
    NoseDoodle(viewModel: ToyViewModel(mode: .nosePick))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
