import SwiftUI

/// ③「摸耳垂」— a big hand-drawn ear whose lobe wobbles vertically & blushes pink.
///   • Lobe stretches with axis direction; blush intensifies with progress.
///   • Completion: little "boing" waves around the lobe.
struct EarDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                EarDoodleRenderer.draw(context: ctx, size: size,
                                       progress: viewModel.progress,
                                       axis: viewModel.axis,
                                       velocity: viewModel.velocity,
                                       isCompleting: viewModel.isCompleting,
                                       time: time)
            }
        }
    }
}

struct EarDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            EarDoodleRenderer.draw(context: ctx, size: size, progress: 0, axis: 0, velocity: 0,
                                   isCompleting: false, time: 0)
        }
    }
}

private enum EarDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, axis: Double, velocity: Double,
                     isCompleting: Bool, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Side profile silhouette (subtle jaw + neck hint), placed left of center
        let jawStart = CGPoint(x: W * 0.24, y: H * 0.18)
        let jawEnd = CGPoint(x: W * 0.28, y: H * 0.86)
        context.stroke(Rough.arc(from: jawStart, to: jawEnd, bulge: -50, seed: 310),
                       with: .color(DoodleStyle.inkSoft), style: .doodle)

        // Ear – shell shape
        let earRect = CGRect(x: W * 0.32, y: H * 0.22, width: W * 0.42, height: H * 0.52)
        // Outer curl (an oval that leans toward the head)
        context.stroke(Rough.ellipse(in: earRect, wobble: 2.4, points: 40, seed: 321),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        // Inner curl
        let innerRect = earRect.insetBy(dx: earRect.width * 0.18, dy: earRect.height * 0.16)
        context.stroke(Rough.ellipse(in: innerRect, wobble: 1.8, points: 34, seed: 322),
                       with: .color(DoodleStyle.ink), style: .doodle)
        // Small curl inside (tragus hint)
        var tragus = Path()
        let t1 = CGPoint(x: earRect.midX - 6, y: earRect.maxY - 68)
        let t2 = CGPoint(x: earRect.midX + 6, y: earRect.maxY - 50)
        tragus.move(to: t1)
        tragus.addQuadCurve(to: t2,
                            control: CGPoint(x: earRect.midX + 20, y: earRect.maxY - 62))
        context.stroke(tragus, with: .color(DoodleStyle.ink), style: .doodle)

        // Lobe – hangs below the ear rect, its offset & scale react to gesture axis
        let lobeCenter = CGPoint(x: earRect.midX - earRect.width * 0.06,
                                  y: earRect.maxY + 10 + CGFloat(sin(time * 5)) * CGFloat(velocity) * 3)
        let baseW: CGFloat = 60
        let baseH: CGFloat = 64
        // Axis pushes the lobe up/down; also a little bounce right after each stroke
        let axisPush = CGFloat(max(-1, min(1, axis * 0.7)))
        let bounce = CGFloat(sin(time * 12)) * CGFloat(velocity) * 4
        let stretch = 1 + CGFloat(velocity) * 0.35
        let lobeRect = CGRect(x: lobeCenter.x - baseW / 2,
                              y: lobeCenter.y - baseH / 2 + axisPush * 8 + bounce,
                              width: baseW,
                              height: baseH * stretch)
        // Blush fill grows with progress; pinkish tint on the lobe
        let blushAlpha = 0.15 + progress * 0.65
        context.fill(Rough.ellipse(in: lobeRect, wobble: 1.6, seed: 341),
                     with: .color(DoodleStyle.blush.opacity(blushAlpha)))
        context.stroke(Rough.ellipse(in: lobeRect, wobble: 1.6, seed: 341),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        // Little earring dot
        context.fill(Rough.ellipse(in: CGRect(x: lobeCenter.x - 3, y: lobeRect.maxY - 6, width: 6, height: 6),
                                    wobble: 0.4, seed: 351),
                     with: .color(DoodleStyle.ink))

        // Boing waves when velocity is high or during completion
        let showBoing = velocity > 0.15 || isCompleting
        if showBoing {
            let intensity = isCompleting ? 1.0 : min(1.0, velocity * 1.4)
            for i in 0..<3 {
                let angBase = CGFloat.pi + CGFloat(i - 1) * 0.35
                let start = CGPoint(
                    x: lobeCenter.x + cos(angBase) * (baseW / 2 + 8),
                    y: lobeCenter.y + sin(angBase) * (baseH / 2 + 8)
                )
                let end = CGPoint(
                    x: start.x + cos(angBase) * (14 + CGFloat(intensity) * 12),
                    y: start.y + sin(angBase) * (14 + CGFloat(intensity) * 12)
                )
                context.stroke(Rough.line(from: start, to: end, steps: 3, amp: 0.5, seed: 361 &+ i),
                               with: .color(DoodleStyle.ink.opacity(0.35 + intensity * 0.4)),
                               style: .doodle)
            }
        }
    }
}

#Preview {
    EarDoodle(viewModel: ToyViewModel(mode: .earLobe))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
