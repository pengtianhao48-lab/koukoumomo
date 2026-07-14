import SwiftUI

/// A hand-drawn X in the top-right corner. Nothing else appears on-screen.
struct DoodleCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Canvas { context, size in
                let inset: CGFloat = 6
                let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
                context.stroke(Rough.ellipse(in: rect, wobble: 1.4, points: 26, seed: 33),
                               with: .color(DoodleStyle.ink),
                               style: .doodleThin)
                context.stroke(Rough.line(from: CGPoint(x: rect.minX + 8, y: rect.minY + 8),
                                          to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 8),
                                          steps: 5, amp: 1.0, seed: 44),
                               with: .color(DoodleStyle.ink), style: .doodle)
                context.stroke(Rough.line(from: CGPoint(x: rect.maxX - 8, y: rect.minY + 8),
                                          to: CGPoint(x: rect.minX + 8, y: rect.maxY - 8),
                                          steps: 5, amp: 1.0, seed: 55),
                               with: .color(DoodleStyle.ink), style: .doodle)
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("action.close"))
    }
}

/// A hand-drawn speaker / speaker-with-slash toggle. Sits next to the close button.
struct DoodleMuteButton: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Button {
            prefs.isMuted.toggle()
            if !prefs.isMuted {
                HapticManager.shared.progress(intensity: 0.4)
            }
        } label: {
            Canvas { ctx, size in
                let inset: CGFloat = 6
                let rect = CGRect(x: inset, y: inset,
                                  width: size.width - inset * 2,
                                  height: size.height - inset * 2)
                // rim
                ctx.stroke(Rough.ellipse(in: rect, wobble: 1.4, points: 26, seed: 66),
                           with: .color(DoodleStyle.ink), style: .doodleThin)

                // Speaker body — small trapezoid on the left + cone on the right
                let cx = rect.midX - 4
                let cy = rect.midY
                var body = Path()
                body.move(to: CGPoint(x: cx - 8, y: cy - 4))
                body.addLine(to: CGPoint(x: cx - 3, y: cy - 4))
                body.addLine(to: CGPoint(x: cx + 3, y: cy - 9))
                body.addLine(to: CGPoint(x: cx + 3, y: cy + 9))
                body.addLine(to: CGPoint(x: cx - 3, y: cy + 4))
                body.addLine(to: CGPoint(x: cx - 8, y: cy + 4))
                body.closeSubpath()
                ctx.fill(body, with: .color(DoodleStyle.ink.opacity(0.85)))
                ctx.stroke(body, with: .color(DoodleStyle.ink), style: .doodleThin)

                if prefs.isMuted {
                    // Slash across
                    ctx.stroke(Rough.line(from: CGPoint(x: rect.minX + 8, y: rect.minY + 8),
                                          to: CGPoint(x: rect.maxX - 8, y: rect.maxY - 8),
                                          steps: 5, amp: 0.8, seed: 78),
                               with: .color(DoodleStyle.ink), style: .doodle)
                } else {
                    // Two small sound-wave arcs to the right of the cone
                    for i in 0..<2 {
                        let r: CGFloat = 6 + CGFloat(i) * 5
                        let cx2 = cx + 6
                        let a = CGPoint(x: cx2, y: cy - r * 0.7)
                        let b = CGPoint(x: cx2, y: cy + r * 0.7)
                        ctx.stroke(Rough.arc(from: a, to: b, bulge: r * 0.6, seed: 80 &+ i),
                                   with: .color(DoodleStyle.ink.opacity(0.75)),
                                   style: .doodleThin)
                    }
                }
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(prefs.isMuted ? "action.unmute" : "action.mute"))
    }
}

#Preview {
    HStack { DoodleMuteButton(); DoodleCloseButton() }
        .padding().background(DoodleStyle.paper)
}
