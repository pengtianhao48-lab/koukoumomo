import SwiftUI

/// ⑥「转笔」— a hand-drawn pen that rotates as you slide.
///   • Tracks angular velocity smoothly via a small state object so the pen never freezes between events.
///   • Motion arcs intensify with progress; completion adds a fast 360° flourish.
struct PenDoodle: View {
    @ObservedObject var viewModel: ToyViewModel
    @StateObject private var state = PenSpinState()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let angle = state.tick(
                time: time,
                axis: viewModel.axis,
                progress: viewModel.progress,
                velocity: viewModel.velocity,
                completionTick: viewModel.completionTick
            )
            Canvas { ctx, size in
                PenDoodleRenderer.draw(context: ctx, size: size,
                                       progress: viewModel.progress,
                                       velocity: viewModel.velocity,
                                       angle: angle)
            }
        }
    }
}

struct PenDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            PenDoodleRenderer.draw(context: ctx, size: size, progress: 0, velocity: 0, angle: 25)
        }
    }
}

/// State machine that integrates pen rotation over time so it feels alive between gesture events.
private final class PenSpinState: ObservableObject {
    private var angle: Double = 12
    private var lastTime: TimeInterval = 0
    private var lastCompletion: Int = -1
    private var flourishRemaining: Double = 0

    func tick(time: TimeInterval, axis: Double, progress: Double, velocity: Double, completionTick: Int) -> Double {
        if lastTime == 0 { lastTime = time }
        let dt = min(0.05, max(0, time - lastTime))
        lastTime = time

        // Drift: rotation velocity in degrees per second driven by axis + progress.
        let axisDeg = axis * 40 // fast angular kick from live drag
        let ambientDeg = progress * 260 // keeps pen visibly spinning while you play
        angle += (axisDeg + ambientDeg) * dt * 3

        if completionTick != lastCompletion {
            lastCompletion = completionTick
            flourishRemaining = 720
        }
        if flourishRemaining > 0 {
            let step = 1400 * dt
            let take = min(flourishRemaining, step)
            angle += take
            flourishRemaining -= take
        }
        return angle
    }
}

private enum PenDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, velocity: Double, angle: Double) {
        let W = size.width
        let H = size.height
        let center = CGPoint(x: W / 2, y: H / 2)

        // Trailing motion arcs (only when there's activity or progress > 0.05)
        let showTrail = velocity > 0.05 || progress > 0.05
        if showTrail {
            for i in 0..<4 {
                let radius = 92 + CGFloat(i) * 12
                let start = angle - 40 - Double(i) * 6
                let end = angle - 10 - Double(i) * 3
                var arcPath = Path()
                let steps = 14
                for j in 0...steps {
                    let t = Double(j) / Double(steps)
                    let a = (start + (end - start) * t) * .pi / 180
                    let x = center.x + CGFloat(cos(a)) * (radius + Rough.noise(701, i * 20 + j) * 1.2)
                    let y = center.y + CGFloat(sin(a)) * (radius + Rough.noise(702, i * 20 + j) * 1.2)
                    if j == 0 { arcPath.move(to: CGPoint(x: x, y: y)) } else { arcPath.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(arcPath,
                               with: .color(DoodleStyle.ink.opacity(0.10 + Double(velocity) * 0.35 + progress * 0.15 - Double(i) * 0.03)),
                               style: .doodle)
            }
        }

        // The pen itself. Draw horizontally centered on origin, then apply rotation transform.
        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .degrees(angle))

        let bodyLen: CGFloat = 210
        let bodyThickness: CGFloat = 22

        // Body (long rounded rectangle)
        let bodyRect = CGRect(x: -bodyLen / 2, y: -bodyThickness / 2, width: bodyLen, height: bodyThickness)
        ctx.fill(Rough.roundedRect(bodyRect, corner: bodyThickness / 2, wobble: 0.7, seed: 731),
                 with: .color(DoodleStyle.paper))
        ctx.stroke(Rough.roundedRect(bodyRect, corner: bodyThickness / 2, wobble: 0.7, seed: 731),
                   with: .color(DoodleStyle.ink), style: .doodleBold)
        // Cap (darker section at the right end)
        let capRect = CGRect(x: bodyLen / 2 - 46, y: -bodyThickness / 2, width: 46, height: bodyThickness)
        ctx.fill(Rough.roundedRect(capRect, corner: bodyThickness / 2, wobble: 0.6, seed: 741),
                 with: .color(DoodleStyle.ink))
        // Clip line on cap (little metallic clip)
        var clipPath = Path()
        clipPath.move(to: CGPoint(x: bodyLen / 2 - 34, y: -bodyThickness / 2 - 3))
        clipPath.addLine(to: CGPoint(x: bodyLen / 2 - 14, y: -bodyThickness / 2 - 12))
        clipPath.addLine(to: CGPoint(x: bodyLen / 2 - 8, y: -bodyThickness / 2 - 4))
        ctx.stroke(clipPath, with: .color(DoodleStyle.ink), style: .doodle)

        // Nib (triangle at the left end)
        var nib = Path()
        let nibBaseX: CGFloat = -bodyLen / 2
        nib.move(to: CGPoint(x: nibBaseX, y: -bodyThickness / 2 + 3))
        nib.addLine(to: CGPoint(x: nibBaseX, y: bodyThickness / 2 - 3))
        nib.addLine(to: CGPoint(x: nibBaseX - 26, y: 0))
        nib.closeSubpath()
        ctx.fill(nib, with: .color(DoodleStyle.ink))
        // Nib highlight line
        var nibLine = Path()
        nibLine.move(to: CGPoint(x: nibBaseX - 20, y: 0))
        nibLine.addLine(to: CGPoint(x: nibBaseX - 4, y: 0))
        ctx.stroke(nibLine, with: .color(DoodleStyle.paper.opacity(0.9)), style: .doodleThin)

        // Body accent stripe (mint band)
        let bandRect = CGRect(x: -bodyLen / 2 + 44, y: -bodyThickness / 2 + 1,
                              width: 18, height: bodyThickness - 2)
        ctx.fill(Rough.roundedRect(bandRect, corner: 4, wobble: 0.4, seed: 761),
                 with: .color(DoodleStyle.mint))
        ctx.stroke(Rough.roundedRect(bandRect, corner: 4, wobble: 0.4, seed: 761),
                   with: .color(DoodleStyle.ink), style: .doodleThin)

        // Small pivot dot in the center (rendered in un-rotated space)
        var pivot = context
        pivot.translateBy(x: center.x, y: center.y)
        pivot.fill(Rough.ellipse(in: CGRect(x: -4, y: -4, width: 8, height: 8), wobble: 0.2, seed: 771),
                   with: .color(DoodleStyle.ink))
    }
}

#Preview {
    PenDoodle(viewModel: ToyViewModel(mode: .penSpin))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
