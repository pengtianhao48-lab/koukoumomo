import SwiftUI

/// ④「咬手指」— cartoon mouth with rows of teeth chomping onto a finger.
///   • Teeth open & close in sync with the horizontal axis (chomp rhythm).
///   • On completion a tiny "spat-out" object flies off with a squiggle.
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

        // Mouth: a big oval opening centered horizontally
        let mouth = CGRect(x: W * 0.16, y: H * 0.32, width: W * 0.68, height: H * 0.30)
        // Lip outline
        context.stroke(Rough.ellipse(in: mouth, wobble: 2.0, points: 44, seed: 411),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Inner mouth cavity fill (darker)
        context.fill(Rough.ellipse(in: mouth.insetBy(dx: 4, dy: 4), wobble: 1.4, seed: 412),
                     with: .color(DoodleStyle.ink.opacity(0.85)))

        // Chomp rhythm
        let chomp = CGFloat(sin(time * 8 + axis * 2)) * CGFloat(0.3 + velocity * 0.7)
        let gap = 10 + (1 - abs(chomp)) * 22 // 10~32
        let toothW: CGFloat = 14
        let toothH: CGFloat = 22
        let toothCount = 6
        let toothSpacing = (mouth.width * 0.72) / CGFloat(toothCount - 1)

        // Upper teeth (top edge of mouth, tips pointing down)
        for i in 0..<toothCount {
            let cx = mouth.midX - (mouth.width * 0.36) + toothSpacing * CGFloat(i)
            let jitter = Rough.noise(430, i) * 1.4
            let topY = mouth.midY - gap - toothH + jitter
            var path = Path()
            path.move(to: CGPoint(x: cx - toothW / 2, y: topY))
            path.addLine(to: CGPoint(x: cx + toothW / 2, y: topY))
            path.addLine(to: CGPoint(x: cx, y: topY + toothH))
            path.closeSubpath()
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }
        // Lower teeth (bottom, tips pointing up)
        for i in 0..<toothCount {
            let cx = mouth.midX - (mouth.width * 0.36) + toothSpacing * CGFloat(i)
            let jitter = Rough.noise(431, i) * 1.4
            let botY = mouth.midY + gap + toothH + jitter
            var path = Path()
            path.move(to: CGPoint(x: cx - toothW / 2, y: botY))
            path.addLine(to: CGPoint(x: cx + toothW / 2, y: botY))
            path.addLine(to: CGPoint(x: cx, y: botY - toothH))
            path.closeSubpath()
            context.fill(path, with: .color(DoodleStyle.paper))
            context.stroke(path, with: .color(DoodleStyle.ink), style: .doodle)
        }

        // Finger entering from bottom
        let fingerBottom: CGFloat = H * 0.94
        let fingerWidth: CGFloat = 42
        let fingerCX = mouth.midX + CGFloat(axis) * 5 + CGFloat(sin(time * 6)) * CGFloat(velocity) * 1.5
        let fingerTop = mouth.midY + 4 // pushes into the mouth
        let fingerRect = CGRect(x: fingerCX - fingerWidth / 2, y: fingerTop,
                                 width: fingerWidth, height: fingerBottom - fingerTop)
        // Rounded top
        var finger = Path()
        finger.addRoundedRect(in: fingerRect, cornerSize: CGSize(width: fingerWidth / 2, height: fingerWidth / 2))
        context.fill(finger, with: .color(DoodleStyle.paper))
        context.stroke(finger, with: .color(DoodleStyle.ink), style: .doodleBold)
        // Knuckle line
        let knuckleY = fingerTop + fingerWidth * 1.4
        context.stroke(Rough.arc(from: CGPoint(x: fingerCX - fingerWidth / 2 + 6, y: knuckleY),
                                 to: CGPoint(x: fingerCX + fingerWidth / 2 - 6, y: knuckleY),
                                 bulge: 4, seed: 471),
                       with: .color(DoodleStyle.ink), style: .doodle)
        // Nail hint (a small arc at the top)
        let nailRect = CGRect(x: fingerCX - 12, y: fingerTop + 6, width: 24, height: 12)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY),
                                 to: CGPoint(x: nailRect.maxX, y: nailRect.midY),
                                 bulge: -6, seed: 481),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)

        // Corners of the mouth (lip lines)
        let leftCorner = CGPoint(x: mouth.minX + 6, y: mouth.midY)
        let rightCorner = CGPoint(x: mouth.maxX - 6, y: mouth.midY)
        context.stroke(Rough.arc(from: leftCorner,
                                 to: CGPoint(x: leftCorner.x - 14, y: leftCorner.y - 6),
                                 bulge: -4, seed: 491),
                       with: .color(DoodleStyle.ink), style: .doodleThin)
        context.stroke(Rough.arc(from: rightCorner,
                                 to: CGPoint(x: rightCorner.x + 14, y: rightCorner.y - 6),
                                 bulge: 4, seed: 492),
                       with: .color(DoodleStyle.ink), style: .doodleThin)

        // Completion: spit out a little object flying upward
        if isCompleting {
            let phase = min(1, max(0, time - Double(completionTick)))
            let x = mouth.midX + 90
            let y = mouth.minY - 30 - CGFloat(phase) * 60
            let objRect = CGRect(x: x - 12, y: y - 10, width: 24, height: 18)
            // Draw a candy-wrapper-ish twist shape
            context.fill(Rough.ellipse(in: objRect, wobble: 1.0, seed: 501),
                         with: .color(DoodleStyle.sunshine))
            context.stroke(Rough.ellipse(in: objRect, wobble: 1.0, seed: 501),
                           with: .color(DoodleStyle.ink), style: .doodle)
            // twist ends
            let twistL = CGPoint(x: x - 18, y: y - 4)
            let twistR = CGPoint(x: x + 18, y: y + 4)
            context.stroke(Rough.line(from: CGPoint(x: x - 12, y: y), to: twistL, steps: 3, amp: 0.4, seed: 511),
                           with: .color(DoodleStyle.ink), style: .doodle)
            context.stroke(Rough.line(from: CGPoint(x: x + 12, y: y), to: twistR, steps: 3, amp: 0.4, seed: 512),
                           with: .color(DoodleStyle.ink), style: .doodle)
            // motion squiggle
            var squiggle = Path()
            squiggle.move(to: CGPoint(x: x, y: y + 20))
            squiggle.addQuadCurve(to: CGPoint(x: x + 6, y: y + 34),
                                  control: CGPoint(x: x - 6, y: y + 28))
            squiggle.addQuadCurve(to: CGPoint(x: x - 4, y: y + 48),
                                  control: CGPoint(x: x + 12, y: y + 42))
            context.stroke(squiggle, with: .color(DoodleStyle.ink), style: .doodle)
        }
    }
}

#Preview {
    FingerDoodle(viewModel: ToyViewModel(mode: .fingerNibble))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
