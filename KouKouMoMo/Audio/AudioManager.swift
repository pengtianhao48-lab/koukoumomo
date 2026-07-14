import AudioToolbox
import Foundation

/// Very small wrapper around AudioServices system sounds so we ship without any bundled audio
/// yet keep the ASMR feedback loop: a soft "start" tap, throttled continuous ticks, and a warm completion tone.
final class AudioManager {
    static let shared = AudioManager()

    private var lastContinuousAt = Date.distantPast
    private init() {}

    func start(for mode: PlayMode) {
        play(mode == .bubbleWrap ? 1104 : 1156)
    }

    func continuous(for mode: PlayMode, progress: Double) {
        let interval = max(0.11, 0.34 - progress * 0.20)
        guard Date().timeIntervalSince(lastContinuousAt) > interval else { return }
        lastContinuousAt = Date()

        switch mode {
        case .nosePick, .navelPoke: play(progress > 0.65 ? 1157 : 1105)
        case .earLobe:              play(1104)
        case .fingerNibble:         play(1155)
        case .bubbleWrap:           play(1306)
        case .penSpin:              play(progress > 0.7 ? 1157 : 1104)
        }
    }

    func completion(for mode: PlayMode) {
        switch mode {
        case .nosePick:     play(1306)
        case .navelPoke, .earLobe: play(1022)
        case .fingerNibble: play(1106)
        case .bubbleWrap:   play(1306)
        case .penSpin:      play(1025)
        }
    }

    private func play(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
}
