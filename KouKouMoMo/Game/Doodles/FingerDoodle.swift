import SwiftUI

/// ④「咬手指」— front-view mouth: full lips, two rows of small rounded-square teeth,
///   a finger inserted between them. Left/right slide drives a real chomp cycle.
struct FingerDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                FingerDoodleRenderer.draw(context: ctx, size: size,
                                          progress: viewModel.progress,
                                          axis: viewModel.axis,
                                          velocity: viewModel.velocity,
                                          isCompleting: viewModel.isCompleting,
                                          completionTick: viewModel.completionTick,
                                          time: time)
            }
        }
    }
}

struct FingerDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            FingerDoodleRenderer.draw(context: ctx, size: size, progress: 0, axis: 0, velocity: 0,
                                      isCompleting: false, completionTick: 0, time: 0)
        }
    }
}

private enum FingerDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, axis: Double, velocity: Double,
                     isCompleting: Bool, completionTick: Int, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Chomp rhythm
        let chompPhase = sin(time * 7.0 + axis * 2)
        let chompStrength = CGFloat(0.35 + velocity * 0.65)
        let bite = CGFloat(chompPhase) * chompStrength   // -bite..+bite
        let topOffset = bite * 5    // upper teeth push DOWN when positive
        let botOffset = -bite * 5   // lower teeth push UP when positive
        let mouthCornerContract = abs(bite) * 3  // corners pinch slightly during bite

        // Lip geometry
        let mouthCenterX = W * 0.5
        let mouthCenterY = H * 0.48
        let mouthWidth: CGFloat = W * 0.68
        let lipThickness: CGFloat = 20

        // Upper lip - Cupid's bow style curve
        let ulLeft = CGPoint(x: mouthCenterX - mouthWidth/2 + mouthCornerContract, y: mouthCenterY - 4)
        let ulRight = CGPoint(x: mouthCenterX + mouthWidth/2 - mouthCornerContract, y: mouthCenterY - 4)
        var upperLip = Path()
        upperLip.move(to: ulLeft)
        // left half up
        upperLip.addCurve(to: CGPoint(x: mouthCenterX - 12, y: mouthCenterY - 22),
                          control1: CGPoint(x: mouthCenterX - mouthWidth * 0.34, y: mouthCenterY - 28),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.22, y: mouthCenterY - 24))
        // cupid's bow dip
        upperLip.addQuadCurve(to: CGPoint(x: mouthCenterX + 12, y: mouthCenterY - 22),
                              control: CGPoint(x: mouthCenterX, y: mouthCenterY - 12))
        // right half up
        upperLip.addCurve(to: ulRight,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.22, y: mouthCenterY - 24),
                          control2: CGPoint(x: mouthCenterX + mouthWidth * 0.34, y: mouthCenterY - 28))
        // close going along lip bottom (thickness)
        upperLip.addCurve(to: ulLeft,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.28, y: mouthCenterY - 2),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.28, y: mouthCenterY - 2))
        context.fill(upperLip, with: .color(DoodleStyle.blush.opacity(0.42)))
        context.stroke(upperLip, with: .color(DoodleStyle.ink), style: .doodleBold)

        // Lower lip - fuller pillow
        let llLeft = CGPoint(x: mouthCenterX - mouthWidth/2 + mouthCornerContract, y: mouthCenterY + 4)
        let llRight = CGPoint(x: mouthCenterX + mouthWidth/2 - mouthCornerContract, y: mouthCenterY + 4)
        var lowerLip = Path()
        lowerLip.move(to: llLeft)
        lowerLip.addCurve(to: llRight,
                          control1: CGPoint(x: mouthCenterX - mouthWidth * 0.30, y: mouthCenterY + 32),
                          control2: CGPoint(x: mouthCenterX + mouthWidth * 0.30, y: mouthCenterY + 32))
        // close along top
        lowerLip.addCurve(to: llLeft,
                          control1: CGPoint(x: mouthCenterX + mouthWidth * 0.28, y: mouthCenterY + 6),
                          control2: CGPoint(x: mouthCenterX - mouthWidth * 0.28, y: mouthCenterY + 6))
        context.fill(lowerLip, with: .color(DoodleStyle.blush.opacity(0.42)))
        context.stroke(lowerLip, with: .color(DoodleStyle.ink), style: .doodleBold)

        // Mouth corners thin lines
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let corner = CGPoint(x: mouthCenterX + s * (mouthWidth/2 - mouthCornerContract),
                                 y: mouthCenterY)
            let tail = CGPoint(x: corner.x + s * 12, y: corner.y - 4)
            context.stroke(Rough.arc(from: corner, to: tail, bulge: -s * 3, seed: 480),
                           with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        _ = lipThickness

        // Inside mouth cavity (darker) — clipped roughly between the two lips
        let cavityRect = CGRect(x: mouthCenterX - mouthWidth/2 + 14,
                                y: mouthCenterY - 8,
                                width: mouthWidth - 28,
                                height: 16)
        context.fill(Rough.ellipse(in: cavityRect, wobble: 1.0, seed: 471),
                     with: .color(DoodleStyle.ink.opacity(0.78)))

        // Teeth — rounded squares
        let toothCount = 5
        let toothW: CGFloat = 20
        let toothH: CGFloat = 20
        let toothGap: CGFloat = 4
        let toothRowW = CGFloat(toothCount) * toothW + CGFloat(toothCount - 1) * toothGap
        let toothStartX = mouthCenterX - toothRowW / 2

        // Upper teeth
        for i in 0..<toothCount {
            let x = toothStartX + CGFloat(i) * (toothW + toothGap)
            let baseY = mouthCenterY - 4 - toothH + topOffset
            let rect = CGRect(x: x, y: baseY, width: toothW, height: toothH)
            let path = Rough.roundedRect(rect, corner: 5, wobble: 0.6, seed: 500 &+ i)
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }
        // Lower teeth
        for i in 0..<toothCount {
            let x = toothStartX + CGFloat(i) * (toothW + toothGap)
            let baseY = mouthCenterY + 4 + botOffset
            let rect = CGRect(x: x, y: baseY, width: toothW, height: toothH)
            let path = Rough.roundedRect(rect, corner: 5, wobble: 0.6, seed: 520 &+ i)
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }

        // Finger from below — enters between the tooth rows, moves ±8pt with axis
        let fingerCx = mouthCenterX + CGFloat(axis).clamped(to: -1...1) * 8
        let fingerW: CGFloat = 34
        let fingerBottom = H * 0.96
        let fingerTopY = mouthCenterY - 2  // between the rows
        let fingerRect = CGRect(x: fingerCx - fingerW/2, y: fingerTopY,
                                width: fingerW, height: fingerBottom - fingerTopY)
        var finger = Path()
        finger.addRoundedRect(in: fingerRect, cornerSize: CGSize(width: fingerW/2, height: fingerW/2))
        context.fill(finger, with: .color(DoodleStyle.paper))
        context.stroke(finger, with: .color(DoodleStyle.ink), style: .doodleBold)
        // Knuckle line
        let knuckleY = fingerTopY + fingerW * 1.5
        context.stroke(Rough.arc(from: CGPoint(x: fingerCx - fingerW/2 + 5, y: knuckleY),
                                 to: CGPoint(x: fingerCx + fingerW/2 - 5, y: knuckleY),
                                 bulge: 3, seed: 540),
                       with: .color(DoodleStyle.ink), style: .doodle)
        // Nail hint
        let nailRect = CGRect(x: fingerCx - 10, y: fingerTopY + 4, width: 20, height: 10)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY),
                                 to: CGPoint(x: nailRect.maxX, y: nailRect.midY),
                                 bulge: -5, seed: 541),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)

        // Bite mark on finger where teeth touch it (only when |bite| high)
        if abs(bite) > 0.6 {
            let markY = mouthCenterY
            context.stroke(Rough.arc(from: CGPoint(x: fingerCx - 8, y: markY),
                                     to: CGPoint(x: fingerCx + 8, y: markY),
                                     bulge: 2, seed: 555),
                           with: .color(DoodleStyle.ink.opacity(0.6)), style: .doodleThin)
        }

        // Completion: finger flies down out of the mouth + small object flies from a corner
        if isCompleting {
            // Rising object from right corner
            let obj = ["candy", "seed", "paper"].randomElement() ?? "candy"
            _ = obj
            let phase = min(1.0, max(0.0, sin((time.truncatingRemainder(dividingBy: 2)) * .pi)))
            let ox = mouthCenterX + mouthWidth * 0.4
            let oy = mouthCenterY - 30 - CGFloat(phase) * 40
            let objRect = CGRect(x: ox - 12, y: oy - 8, width: 24, height: 16)
            context.fill(Rough.ellipse(in: objRect, wobble: 1.0, seed: 601),
                         with: .color(DoodleStyle.sunshine))
            context.stroke(Rough.ellipse(in: objRect, wobble: 1.0, seed: 601),
                           with: .color(DoodleStyle.ink), style: .doodle)
            // twist ends
            context.stroke(Rough.line(from: CGPoint(x: ox - 12, y: oy),
                                      to: CGPoint(x: ox - 20, y: oy - 4),
                                      steps: 3, amp: 0.4, seed: 611),
                           with: .color(DoodleStyle.ink), style: .doodle)
            context.stroke(Rough.line(from: CGPoint(x: ox + 12, y: oy),
                                      to: CGPoint(x: ox + 20, y: oy + 3),
                                      steps: 3, amp: 0.4, seed: 612),
                           with: .color(DoodleStyle.ink), style: .doodle)
        }
    }
}

#Preview {
    FingerDoodle(viewModel: ToyViewModel(mode: .fingerNibble))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
