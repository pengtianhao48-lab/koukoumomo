import SwiftUI

struct GestureHintView: View {
    let hintText: String
    let isTriggered: Bool

    @State private var isVisible = true
    @State private var isDismissed = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 7) {
            Canvas { ctx, size in
                let ink = DoodleStyle.ink.opacity(0.18)
                let W = size.width
                let H = size.height
                var finger = Path()
                finger.move(to: CGPoint(x: W * 0.47, y: H * 0.82))
                finger.addCurve(to: CGPoint(x: W * 0.46, y: H * 0.30),
                                control1: CGPoint(x: W * 0.40, y: H * 0.66),
                                control2: CGPoint(x: W * 0.41, y: H * 0.42))
                finger.addQuadCurve(to: CGPoint(x: W * 0.58, y: H * 0.30),
                                    control: CGPoint(x: W * 0.52, y: H * 0.20))
                finger.addCurve(to: CGPoint(x: W * 0.62, y: H * 0.82),
                                control1: CGPoint(x: W * 0.66, y: H * 0.44),
                                control2: CGPoint(x: W * 0.66, y: H * 0.66))
                ctx.stroke(finger, with: .color(ink), style: .doodleThin)
                ctx.stroke(Rough.arc(from: CGPoint(x: W * 0.22, y: H * 0.30),
                                     to: CGPoint(x: W * 0.34, y: H * 0.58),
                                     bulge: -W * 0.12,
                                     seed: 401),
                           with: .color(ink), style: .doodleThin)
                ctx.stroke(Rough.arc(from: CGPoint(x: W * 0.76, y: H * 0.30),
                                     to: CGPoint(x: W * 0.66, y: H * 0.58),
                                     bulge: W * 0.12,
                                     seed: 402),
                           with: .color(ink), style: .doodleThin)
            }
            .frame(width: 54, height: 54)
            .scaleEffect(pulse ? 1.06 : 0.94)
            .opacity(pulse ? 0.78 : 0.42)

            Text(hintText)
                .font(DoodleStyle.mono(15, .bold))
                .foregroundStyle(DoodleStyle.ink.opacity(0.18))
        }
        .padding(12)
        .opacity(isVisible && !isDismissed ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isVisible)
        .animation(.easeInOut(duration: 0.35), value: isDismissed)
        .allowsHitTesting(false)
        .task {
            pulse = true
            await runHintSchedule()
        }
        .onChange(of: isTriggered) { _, triggered in
            if triggered {
                isDismissed = true
                isVisible = false
            }
        }
    }

    private func runHintSchedule() async {
        await flash(after: 2.0, visible: false)
        await flash(after: 1.0, visible: true)
        await flash(after: 1.8, visible: false)
        await flash(after: 5.2, visible: true)
        await flash(after: 1.8, visible: false)
    }

    private func flash(after delay: Double, visible: Bool) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard !Task.isCancelled, !isDismissed else { return }
        isVisible = visible
    }
}
