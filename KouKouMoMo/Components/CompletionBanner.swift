import SwiftUI

/// Floating hand-lettered banner that appears whenever a toy hits its completion moment.
/// Small, warm, off-center so it never distracts from the doodle itself.
struct CompletionBanner: View {
    let text: String
    let accent: Color
    let visible: Bool

    var body: some View {
        Text(text)
            .font(DoodleStyle.mono(24, .heavy))
            .foregroundStyle(DoodleStyle.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Canvas { context, size in
                        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                        context.fill(Rough.roundedRect(rect, corner: 16, wobble: 1.5, seed: 12),
                                     with: .color(DoodleStyle.paper))
                        context.stroke(Rough.roundedRect(rect, corner: 16, wobble: 1.5, seed: 12),
                                       with: .color(DoodleStyle.ink), style: .doodle)
                        // Little tag squiggle
                        for i in 0..<3 {
                            let y = rect.maxY - 4 + CGFloat(i) * 2
                            context.stroke(Rough.line(
                                from: CGPoint(x: rect.midX - 22, y: y),
                                to: CGPoint(x: rect.midX + 22, y: y),
                                steps: 6, amp: 0.8, seed: 55 &+ i),
                                           with: .color(accent.opacity(0.55)), style: .doodleThin)
                        }
                    }
                }
            )
            .rotationEffect(.degrees(-2.4))
            .scaleEffect(visible ? 1 : 0.6)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? -8 : 6)
            .animation(DoodleStyle.bouncySpring, value: visible)
            .accessibilityHidden(true)
    }
}
