import AudioToolbox
import Foundation
import Combine

/// Global preferences (currently just the audio mute toggle). Persists to UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "koukoumomo.isMuted") }
    }

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "koukoumomo.isMuted")
    }
}

/// Very small wrapper around AudioServices system sounds so we ship without any bundled audio
/// yet keep the ASMR feedback loop: a soft "start" tap, throttled continuous ticks, and a warm completion tone.
final class AudioManager {
    static let shared = AudioManager()

    private var lastContinuousAt = Date.distantPast
    private init() {}

    func start(for mode: PlayMode) {
        switch mode {
        case .penSpin: return
        case .navelPoke: play(1104) // soft low tap before gentle skin-rub loop
        case .nosePick:  play(1156) // small close-contact start, not a success sound
        case .bubbleWrap: play(1104)
        default: play(1156)
        }
    }

    func continuous(for mode: PlayMode, progress: Double) {
        let interval = max(0.11, 0.34 - progress * 0.20)
        guard Date().timeIntervalSince(lastContinuousAt) > interval else { return }
        lastContinuousAt = Date()

        switch mode {
        case .nosePick:             play(1105) // subtle damp friction
        case .navelPoke:            play(1104) // soft low skin-rub / ASMR-like tick
        case .earLobe:              play(1104)
        case .fingerNibble:         play(1155)
        case .bubbleWrap:           play(1306)
        case .penSpin:              return
        }
    }

    func completion(for mode: PlayMode) {
        switch mode {
        case .nosePick:     play(1105)
        case .bubbleWrap:   play(1306)
        case .fingerNibble: play(1106)
        case .navelPoke, .earLobe, .penSpin: return
        }
    }

    private func play(_ id: SystemSoundID) {
        if Preferences.shared.isMuted { return }
        AudioServicesPlaySystemSound(id)
    }
}
