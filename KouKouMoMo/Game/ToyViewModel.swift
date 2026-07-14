import SwiftUI

@MainActor
final class ToyViewModel: ObservableObject {
    let mode: PlayMode
    let engine: GestureEngine

    @Published var state: ToyState = .idle
    @Published var progress: Double = 0
    @Published var velocity: Double = 0
    @Published var axis: Double = 0
    @Published var isCompleting = false
    @Published var completionText: String = ""
    /// Bumped once each time a completion loop starts. Doodles use it to trigger one-shot effects.
    @Published var completionTick: Int = 0
    /// Bumped each time a `.tap` gesture registers, so the bubble doodle can pop the current bubble
    /// even if the accumulated progress stays low.
    @Published var tapTick: Int = 0

    private let audio = AudioManager.shared
    private let haptics = HapticManager.shared
    private var isLocked = false

    init(mode: PlayMode) {
        self.mode = mode
        self.engine = GestureEngine(kind: mode.gesture)

        engine.onFingerDown = { [weak self] in
            Task { @MainActor in self?.startPlaying() }
        }
        engine.onProgress = { [weak self] event in
            Task { @MainActor in self?.consume(event) }
        }
    }

    private func startPlaying() {
        guard !isLocked, state == .idle else { return }
        state = .fingerDown
        audio.start(for: mode)
        haptics.start()
    }

    private func consume(_ event: GestureProgressEvent) {
        guard !isLocked else { return }
        if state == .fingerDown || state == .idle {
            state = .continuousGesture
        } else if state == .continuousGesture {
            state = .progress
        }

        withAnimation(DoodleStyle.quickSpring) {
            progress = event.progress.clamped(to: 0...1)
            velocity = event.velocity
            axis = event.axis
        }

        if mode == .bubbleWrap, event.velocity > 0 {
            tapTick &+= 1
        }

        audio.continuous(for: mode, progress: progress)
        // Per-mode haptic textures — orbit tick for the rotating toys, chomp beats for the finger,
        // gentle pull beats for the ear. Nose is the only mode that still terminates with a banner.
        switch mode {
        case .nosePick, .navelPoke:
            haptics.orbitTick(intensity: max(progress * 0.4, event.velocity))
        case .earLobe:
            if event.velocity > 0.25 {
                haptics.earPullBeat(strength: min(1, event.velocity))
            }
        case .fingerNibble:
            if event.velocity > 0.30 {
                haptics.chompBeat(intensity: min(1, event.velocity))
            }
        case .bubbleWrap:
            break // bubble pops fire heavy haptic from BubblesDoodle itself
        case .penSpin:
            break // PenDoodle fires haptics from its own physics loop
        }

        if event.progress >= 1 {
            if mode.isInfinite {
                // Silent loop reset — no banner, no lock, keeps the toy running forever.
                engine.resetAccumulator()
                progress = 0
            } else {
                complete()
            }
        }
    }

    private func complete() {
        guard !isLocked else { return }
        isLocked = true
        state = .completionFeedback
        completionText = mode.completionCopy()
        completionTick &+= 1
        isCompleting = true
        progress = 1

        audio.completion(for: mode)
        haptics.completion()

        Task { [weak self] in
            guard let self else { return }
            let delay: Duration = self.mode == .bubbleWrap ? .milliseconds(240) : .milliseconds(700)
            try? await Task.sleep(for: delay)
            await self.resetLoop()
        }
    }

    private func resetLoop() async {
        state = .reset
        withAnimation(DoodleStyle.softSpring) {
            progress = 0
            velocity = 0
            axis = 0
            isCompleting = false
        }
        engine.reset()
        try? await Task.sleep(for: .milliseconds(200))
        state = .idle
        isLocked = false
    }
}
