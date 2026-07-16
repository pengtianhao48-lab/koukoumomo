import AudioToolbox
import AVFoundation
import Combine
import Foundation

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "koukoumomo.isMuted") }
    }

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "koukoumomo.isMuted")
    }
}

final class AudioManager {
    static let shared = AudioManager()

    private var lastContinuousAt = Date.distantPast
    private var lastPenWindAt = Date.distantPast

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func start(for mode: PlayMode) {
        switch mode {
        case .penSpin: return
        case .navelPoke: play(1104)
        case .nosePick:  play(1156)
        case .bubbleWrap: play(1104)
        default: play(1156)
        }
    }

    func continuous(for mode: PlayMode, progress: Double) {
        let interval = max(0.11, 0.34 - progress * 0.20)
        guard Date().timeIntervalSince(lastContinuousAt) > interval else { return }
        lastContinuousAt = Date()

        switch mode {
        case .nosePick:             play(1105)
        case .navelPoke:            play(1104)
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

    func penSpinWind(speed: Double) {
        guard speed > 0.02 else { return }
        let clamped = min(1, max(0, speed))
        let interval = 0.30 - clamped * (0.30 - 0.07)
        guard Date().timeIntervalSince(lastPenWindAt) > interval else { return }
        lastPenWindAt = Date()
        play(clamped > 0.55 ? 1157 : 1104)
    }

    private func play(_ id: SystemSoundID) {
        if Preferences.shared.isMuted { return }
        AudioServicesPlaySystemSound(id)
    }
}
