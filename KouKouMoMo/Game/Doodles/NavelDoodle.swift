import SwiftUI

/// ②「抠肚脐」— refined: soft belly bulge with shading, realistic navel that has an inner bean core.
///   • Belly compresses slightly with progress (pressed in feel).
///   • Inner core rotates with progress; wrinkle arcs stretch outward.
///   • Completion: core pops upward, warm glow around navel.
struct NavelDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                NavelDoodleRenderer.draw(context: ctx, size: size,
                                         progress: viewModel.progress,
                                         isCompleting: viewModel.isCompleting,
                                         completionTick: viewModel.completionTick,
                                         time: time)
            }
        }
    }
}

struct NavelDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            NavelDoodleRenderer.draw(context: ctx, size: size, progress: 0,
                                     isCompleting: false, completionTick: 0, time: 0)
        }
    }
}

private enum NavelDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, isCompleting: Bool,
                     completionTick: Int, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Belly bulge: a big rounded oval that slightly compresses (scaleY) with progress
        let compression = 1 - CGFloat(progress) * 0.06
        let bellyRect = CGRect(
            x: W * 0.08,
            y: H * 0.20 + CGFloat(progress) * 6,
            width: W * 0.84,
            height: H * 0.70 * compression
        )
        // Outer belly outline
        context.stroke(Rough.ellipse(in: bellyRect, wobble: 2.4, points: 46, seed: 210),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Shading arcs on the belly for 3D feel
        // Highlight arc top-left
        let hlA = CGPoint(x: bellyRect.minX + bellyRect.width * 0.18, y: bellyRect.minY + bellyRect.height * 0.35)
        let hlB = CGPoint(x: bellyRect.minX + bellyRect.width * 0.32, y: bellyRect.minY + bellyRect.height * 0.18)
        context.stroke(Rough.arc(from: hlA, to: hlB, bulge: -6, seed: 211),
                       with: .color(DoodleStyle.inkFaint.opacity(0.35)), style: .doodle)
        // Shadow arc bottom-right (thicker)
        let shA = CGPoint(x: bellyRect.maxX - bellyRect.width * 0.14, y: bellyRect.midY + bellyRect.height * 0.05)
        let shB = CGPoint(x: bellyRect.maxX - bellyRect.width * 0.32, y: bellyRect.maxY - bellyRect.height * 0.14)
        context.stroke(Rough.arc(from: shA, to: shB, bulge: 22, seed: 212),
                       with: .color(DoodleStyle.inkSoft.opacity(0.45)), style: .doodle)
        // Second shadow arc, more curved
        let sh2A = CGPoint(x: bellyRect.maxX - bellyRect.width * 0.08, y: bellyRect.midY - bellyRect.height * 0.03)
        let sh2B = CGPoint(x: bellyRect.maxX - bellyRect.width * 0.20, y: bellyRect.maxY - bellyRect.height * 0.06)
        context.stroke(Rough.arc(from: sh2A, to: sh2B, bulge: 14, seed: 213),
                       with: .color(DoodleStyle.inkSoft.opacity(0.3)), style: .doodleThin)

        // Navel area — centered slightly below belly midline
        let center = CGPoint(x: bellyRect.midX, y: bellyRect.midY + bellyRect.height * 0.04)
        let navelW: CGFloat = 60
        let navelH: CGFloat = 44
        // Outer ellipse (rim, drawn as a subtle darker outline)
        let rimRect = CGRect(x: center.x - navelW/2, y: center.y - navelH/2, width: navelW, height: navelH)
        context.stroke(Rough.ellipse(in: rimRect, wobble: 1.6, points: 36, seed: 214),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        // Deeper shadow ellipse just inside — the "depression"
        let holeRect = rimRect.insetBy(dx: 4, dy: 3)
        context.fill(Rough.ellipse(in: holeRect, wobble: 1.4, points: 32, seed: 215),
                     with: .color(DoodleStyle.ink.opacity(0.14 + progress * 0.14)))

        // Wrinkle arcs around navel — stretch outward with progress
        for i in 0..<3 {
            let stretch = 1.0 + CGFloat(progress) * 0.18
            let angBase = -CGFloat.pi * 0.9 + CGFloat(i) * 0.35
            let r1: CGFloat = (navelW/2 + 8) * stretch
            let r2: CGFloat = (navelW/2 + 16) * stretch
            let a = CGPoint(x: center.x + cos(angBase) * r1, y: center.y + sin(angBase) * r1 * 0.72)
            let b = CGPoint(x: center.x + cos(angBase - 0.55) * r2,
                            y: center.y + sin(angBase - 0.55) * r2 * 0.72)
            context.stroke(Rough.arc(from: a, to: b, bulge: 3, seed: 220 &+ i),
                           with: .color(DoodleStyle.inkSoft.opacity(0.5 + progress * 0.2)),
                           style: .doodleThin)
        }
        // Symmetric on the right
        for i in 0..<3 {
            let stretch = 1.0 + CGFloat(progress) * 0.18
            let angBase = -CGFloat.pi * 0.1 - CGFloat(i) * 0.35
            let r1: CGFloat = (navelW/2 + 8) * stretch
            let r2: CGFloat = (navelW/2 + 16) * stretch
            let a = CGPoint(x: center.x + cos(angBase) * r1, y: center.y + sin(angBase) * r1 * 0.72)
            let b = CGPoint(x: center.x + cos(angBase + 0.55) * r2,
                            y: center.y + sin(angBase + 0.55) * r2 * 0.72)
            context.stroke(Rough.arc(from: a, to: b, bulge: -3, seed: 223 &+ i),
                           with: .color(DoodleStyle.inkSoft.opacity(0.5 + progress * 0.2)),
                           style: .doodleThin)
        }

        // Inner bean core (vertical bean-shape) — rotates with progress
        var coreCtx = context
        coreCtx.translateBy(x: center.x, y: center.y + 1)
        coreCtx.rotate(by: .degrees(progress * 620 + sin(time * 2.4) * 8))
        let coreRect = CGRect(x: -6, y: -14, width: 12, height: 26)
        // Two bulges to make it look like a bean
        var beanPath = Path()
        beanPath.move(to: CGPoint(x: 0, y: -14))
        beanPath.addCurve(to: CGPoint(x: 6, y: 0),
                          control1: CGPoint(x: 6, y: -12),
                          control2: CGPoint(x: 7, y: -6))
        beanPath.addCurve(to: CGPoint(x: 0, y: 14),
                          control1: CGPoint(x: 5, y: 6),
                          control2: CGPoint(x: 6, y: 12))
        beanPath.addCurve(to: CGPoint(x: -6, y: 0),
                          control1: CGPoint(x: -6, y: 12),
                          control2: CGPoint(x: -5, y: 6))
        beanPath.addCurve(to: CGPoint(x: 0, y: -14),
                          control1: CGPoint(x: -7, y: -6),
                          control2: CGPoint(x: -6, y: -12))
        coreCtx.fill(beanPath, with: .color(DoodleStyle.ink))
        // small notch line inside the bean (highlights the "seam")
        var seam = Path()
        seam.move(to: CGPoint(x: -1, y: -8))
        seam.addQuadCurve(to: CGPoint(x: 1, y: 8), control: CGPoint(x: -3, y: 0))
        coreCtx.stroke(seam, with: .color(DoodleStyle.paper.opacity(0.7)), style: .doodleThin)
        _ = coreRect

        // Completion: core lifts out + warm glow + radial sparkles
        if isCompleting {
            let phase = min(1, max(0, (time.truncatingRemainder(dividingBy: 4)) * 0.6))
            let lift = CGFloat(phase) * 40
            // Lifted core (drawn again above navel)
            var liftCtx = context
            liftCtx.translateBy(x: center.x, y: center.y - lift - 24)
            liftCtx.rotate(by: .degrees(sin(time * 5) * 20))
            var beanPath2 = Path()
            beanPath2.move(to: CGPoint(x: 0, y: -14))
            beanPath2.addCurve(to: CGPoint(x: 6, y: 0),
                               control1: CGPoint(x: 6, y: -12), control2: CGPoint(x: 7, y: -6))
            beanPath2.addCurve(to: CGPoint(x: 0, y: 14),
                               control1: CGPoint(x: 5, y: 6), control2: CGPoint(x: 6, y: 12))
            beanPath2.addCurve(to: CGPoint(x: -6, y: 0),
                               control1: CGPoint(x: -6, y: 12), control2: CGPoint(x: -5, y: 6))
            beanPath2.addCurve(to: CGPoint(x: 0, y: -14),
                               control1: CGPoint(x: -7, y: -6), control2: CGPoint(x: -6, y: -12))
            liftCtx.fill(beanPath2, with: .color(DoodleStyle.sunshine))
            liftCtx.stroke(beanPath2, with: .color(DoodleStyle.ink), style: .doodleThin)
            // Warm halo
            let haloR: CGFloat = navelW * 1.4
            context.stroke(Rough.ellipse(in: CGRect(x: center.x - haloR, y: center.y - haloR * 0.72,
                                                    width: haloR * 2, height: haloR * 2 * 0.72),
                                          wobble: 2.4, points: 42, seed: 291),
                           with: .color(DoodleStyle.sunshine.opacity(0.6)),
                           style: .doodleBold)
            // Sparkle spokes
            for i in 0..<8 {
                let ang = CGFloat(i) * .pi / 4
                let base = CGPoint(x: center.x + cos(ang) * (navelW/2 + 22),
                                   y: center.y + sin(ang) * (navelW/2 + 16))
                let tip = CGPoint(x: base.x + cos(ang) * 12, y: base.y + sin(ang) * 12)
                context.stroke(Rough.line(from: base, to: tip, steps: 2, amp: 0.4, seed: 300 &+ i),
                               with: .color(DoodleStyle.ink), style: .doodle)
            }
        }
    }
}

#Preview {
    NavelDoodle(viewModel: ToyViewModel(mode: .navelPoke))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
