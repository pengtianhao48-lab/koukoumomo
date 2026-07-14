import SwiftUI

/// Full-screen container for a single doodle. Cream paper background, one small × in the corner,
/// and a completion banner that appears/disappears with the state machine.
struct GameContainerView: View {
    let mode: PlayMode
    @StateObject private var viewModel: ToyViewModel
    @State private var lastGestureAt: TimeInterval? = nil

    init(mode: PlayMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: ToyViewModel(mode: mode))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DoodleStyle.paper.ignoresSafeArea()

            // Faint paper grain: a few super-light deterministic wobble marks so it never flickers.
            Canvas { ctx, size in
                for i in 0..<14 {
                    let nx = (Rough.noise(mode.hashValue & 0xFF, i) + 1) / 2
                    let ny = (Rough.noise(mode.hashValue & 0xFF, i &+ 500) + 1) / 2
                    let rect = CGRect(x: nx * size.width, y: ny * size.height, width: 6, height: 6)
                    ctx.fill(Rough.ellipse(in: rect, wobble: 0.4, seed: i),
                             with: .color(DoodleStyle.inkFaint.opacity(0.08)))
                }
            }
            .allowsHitTesting(false)

            // The doodle itself in a centered fixed area so proportions stay stable across devices.
            // BubbleWrap is a special case: it fills the entire screen so the bubble grid has no margins.
            if mode == .bubbleWrap {
                doodle
                    .ignoresSafeArea()
            } else {
                GeometryReader { proxy in
                    doodle
                        .frame(width: proxy.size.width * 0.86,
                               height: min(proxy.size.height * 0.72, 560))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }

            CompletionBanner(text: viewModel.completionText,
                             accent: mode.accent,
                             visible: viewModel.isCompleting)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .allowsHitTesting(false)

            HStack(spacing: 6) {
                DoodleMuteButton()
                DoodleCloseButton()
            }
            .padding(.top, 12)
            .padding(.trailing, 14)

            // Very subtle gesture hint. Non-bubble toys sit higher (about 100pt above bottom safe area)
            // so the text doesn't hide under the finger. It disappears immediately after a valid
            // gesture and fades back in after 5 seconds of inactivity.
            TimelineView(.animation(minimumInterval: 0.25, paused: false)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                let visible = hintVisible(at: now)
                VStack {
                    Spacer()
                    Text(mode.gestureHintKey)
                        .font(DoodleStyle.mono(13, .semibold))
                        .foregroundStyle(DoodleStyle.inkSoft)
                        .padding(.bottom, mode == .bubbleWrap ? 34 : 100)
                        .opacity(visible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.35), value: visible)
                        .accessibilityHidden(true)
                }
            }
            .allowsHitTesting(false)
        }
        .doodleGesture(engine: viewModel.engine, kind: mode.gesture)
        .onChange(of: viewModel.progress) { _, newValue in
            if newValue > 0.01 { markGestureActivity() }
        }
        .onChange(of: viewModel.velocity) { _, newValue in
            if newValue > 0.01 { markGestureActivity() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(mode.titleKey))
        .accessibilityHint(Text(mode.gestureHintKey))
    }

    private func markGestureActivity() {
        lastGestureAt = Date().timeIntervalSinceReferenceDate
    }

    private func hintVisible(at now: TimeInterval) -> Bool {
        guard let lastGestureAt else { return true }
        return now - lastGestureAt >= 5
    }

    @ViewBuilder
    private var doodle: some View {
        switch mode {
        case .nosePick:     NoseDoodle(viewModel: viewModel)
        case .navelPoke:    NavelDoodle(viewModel: viewModel)
        case .earLobe:      EarDoodle(viewModel: viewModel)
        case .fingerNibble: FingerDoodle(viewModel: viewModel)
        case .bubbleWrap:   BubblesDoodle(viewModel: viewModel)
        case .penSpin:      PenDoodle(viewModel: viewModel)
        }
    }
}

#Preview("Nose")     { GameContainerView(mode: .nosePick) }
#Preview("Navel")    { GameContainerView(mode: .navelPoke) }
#Preview("Ear")      { GameContainerView(mode: .earLobe) }
#Preview("Finger")   { GameContainerView(mode: .fingerNibble) }
#Preview("Bubbles")  { GameContainerView(mode: .bubbleWrap) }
#Preview("Pen")      { GameContainerView(mode: .penSpin) }
