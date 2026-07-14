import SwiftUI

/// ②「抠肚脐」— soft belly outline with a navel that gets deeper as you spin.
///   • Concentric arcs grow inside the navel with progress (越抠越深).
///   • Completion: sparkles fan out + "Clean!" glow around the navel.
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
        // Torso: soft bump crossing full width
        let torso = CGRect(x: W * 0.06, y: H * 0.22, width: W * 0.88, height: H * 0.66)
        context.stroke(Rough.ellipse(in: torso, wobble: 2.2, points: 42, seed: 210),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Optional torso details – two soft dots at the top (hint of chest) + a hip curve at bottom
        let dotY = torso.minY + torso.height * 0.14
        for (i, cx) in [torso.midX - torso.width * 0.22, torso.midX + torso.width * 0.22].enumerated() {
            context.stroke(Rough.ellipse(in: CGRect(x: cx - 6, y: dotY - 4, width: 12, height: 8),
                                          wobble: 0.6, seed: 220 &+ i),
                           with: .color(DoodleStyle.inkSoft), style: .doodleThin)
        }

        // Central navel area
        let center = CGPoint(x: torso.midX, y: torso.midY + H * 0.02)
        let navelRadius: CGFloat = 24

        // Halo of soft rings around navel intensifies with progress
        for i in 0..<3 {
            let r = navelRadius + CGFloat(i) * (10 + CGFloat(progress) * 6)
            let ringRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.stroke(Rough.ellipse(in: ringRect, wobble: 1.0 + CGFloat(progress) * 1.4, points: 34, seed: 231 &+ i),
                           with: .color(DoodleStyle.ink.opacity(0.14 + Double(i) * 0.05 + progress * 0.10)),
                           style: .doodleThin)
        }

        // Navel: outer soft "hole"
        let navelOuter = CGRect(x: center.x - navelRadius, y: center.y - navelRadius,
                                 width: navelRadius * 2, height: navelRadius * 2)
        context.stroke(Rough.ellipse(in: navelOuter, wobble: 1.4, seed: 241),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // Inner concentric arcs → the "digging deeper" illusion
        let arcCount = 1 + Int(progress * 4)
        for i in 0..<arcCount {
            let inset = CGFloat(i) * 4 + 4
            let r = navelRadius - inset
            guard r > 3 else { break }
            let rect = CGRect(x: center.x - r, y: center.y - r + inset * 0.4,
                              width: r * 2, height: r * 2 - inset * 0.6)
            // Only the upper arc to feel like a crescent depression
            var arc = Path()
            arc.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                       radius: r,
                       startAngle: .degrees(200),
                       endAngle: .degrees(340),
                       clockwise: false)
            let jitter = Path { p in
                let steps = 12
                for j in 0...steps {
                    let a = (200.0 + Double(j) / Double(steps) * 140.0) * .pi / 180.0
                    let x = CGFloat(cos(a)) * r + rect.midX + Rough.noise(261 &+ i, j) * 0.9
                    let y = CGFloat(sin(a)) * r + rect.midY + Rough.noise(261 &+ i, j + 30) * 0.9
                    if j == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            context.stroke(jitter,
                           with: .color(DoodleStyle.ink.opacity(0.7 - Double(i) * 0.1)),
                           style: .doodle)
        }

        // Rotating "picking finger" hint - a small orbiting dot around navel
        let orbitAngle = time * 3.2
        let orbitRadius: CGFloat = navelRadius + 6 + CGFloat(progress) * 4
        let orbitPoint = CGPoint(x: center.x + CGFloat(cos(orbitAngle)) * orbitRadius,
                                 y: center.y + CGFloat(sin(orbitAngle)) * orbitRadius)
        let orbitRect = CGRect(x: orbitPoint.x - 3, y: orbitPoint.y - 3, width: 6, height: 6)
        context.fill(Rough.ellipse(in: orbitRect, wobble: 0.4, seed: 271),
                     with: .color(DoodleStyle.ink.opacity(0.35 + progress * 0.35)))

        // Completion: sparkles + halo of light around navel
        if isCompleting {
            let phase = min(1, (time - Double(completionTick)) * 3)
            let scale = 1 + CGFloat(phase) * 0.3
            let haloR: CGFloat = navelRadius * 2.6 * scale
            context.stroke(Rough.ellipse(in: CGRect(x: center.x - haloR, y: center.y - haloR,
                                                    width: haloR * 2, height: haloR * 2),
                                          wobble: 3, points: 44, seed: 281),
                           with: .color(DoodleStyle.sunshine.opacity(0.7 - Double(phase) * 0.5)),
                           style: .doodleBold)

            for i in 0..<8 {
                let ang = CGFloat(i) * .pi / 4 + CGFloat(phase) * 0.4
                let base = CGPoint(x: center.x + cos(ang) * (navelRadius + 26),
                                   y: center.y + sin(ang) * (navelRadius + 26))
                let tip = CGPoint(x: center.x + cos(ang) * (navelRadius + 42 + CGFloat(phase) * 6),
                                  y: center.y + sin(ang) * (navelRadius + 42 + CGFloat(phase) * 6))
                context.stroke(Rough.line(from: base, to: tip, steps: 3, amp: 0.4, seed: 291 &+ i),
                               with: .color(DoodleStyle.ink), style: .doodle)
            }
        }
    }
}

#Preview {
    NavelDoodle(viewModel: ToyViewModel(mode: .navelPoke))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
