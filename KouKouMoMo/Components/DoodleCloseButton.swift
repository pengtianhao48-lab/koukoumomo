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

#Preview {
    DoodleCloseButton()
        .padding().background(DoodleStyle.paper)
}
