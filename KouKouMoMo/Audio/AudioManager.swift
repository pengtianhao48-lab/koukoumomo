import AVFoundation
import AudioToolbox
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
    private var players: [AVAudioPlayer] = []

    private let soundPaths: [SystemSoundID: [String]] = [
        1104: ["/System/Library/Audio/UISounds/Tock.caf", "/System/Library/Audio/UISounds/tock.caf"],
        1105: ["/System/Library/Audio/UISounds/Tock.caf", "/System/Library/Audio/UISounds/tock.caf"],
        1106: ["/System/Library/Audio/UISounds/ReceivedMessage.caf"],
        1155: ["/System/Library/Audio/UISounds/Swish.caf", "/System/Library/Audio/UISounds/sms-received1.caf"],
        1156: ["/System/Library/Audio/UISounds/Pop.caf", "/System/Library/Audio/UISounds/sms-received2.caf"],
        1157: ["/System/Library/Audio/UISounds/Swish.caf", "/System/Library/Audio/UISounds/sms-received3.caf"],
        1306: ["/System/Library/Audio/UISounds/Modern/sms-received1.caf", "/System/Library/Audio/UISounds/sms-received1.caf"]
    ]

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
        if playSystemFile(for: id) { return }
        AudioServicesPlaySystemSound(id)
    }

    private func playSystemFile(for id: SystemSoundID) -> Bool {
        guard let paths = soundPaths[id] else { return false }
        players.removeAll { !$0.isPlaying }
        for path in paths where FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = 0.55
            player.prepareToPlay()
            player.play()
            players.append(player)
            return true
        }
        return false
    }
}
