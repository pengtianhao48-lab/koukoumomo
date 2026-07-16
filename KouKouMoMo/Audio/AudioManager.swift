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
    private var playerPools: [SystemSoundID: [AVAudioPlayer]] = [:]
    private var nextPlayerIndex: [SystemSoundID: Int] = [:]
    private let queue = DispatchQueue(label: "koukoumomo.audio", qos: .userInitiated)

    private let soundFiles: [SystemSoundID: String] = [
        1104: "key_press_click",
        1105: "key_press_delete",
        1106: "ReceivedMessage",
        1155: "Swish",
        1156: "Pop",
        1157: "Swish",
        1306: "Tock"
    ]

    private init() {}

    func preload() {
        queue.async { [weak self] in
            self?.preloadPlayers()
        }
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
        play(1104)
    }

    private func preloadPlayers() {
        for (id, name) in soundFiles where playerPools[id] == nil {
            guard let url = Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Sounds") else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<3 {
                guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.prepareToPlay()
                pool.append(player)
            }
            if !pool.isEmpty {
                playerPools[id] = pool
                nextPlayerIndex[id] = 0
            }
        }
    }

    private func play(_ id: SystemSoundID) {
        if Preferences.shared.isMuted { return }
        queue.async { [weak self] in
            guard let self else { return }
            guard var pool = self.playerPools[id], !pool.isEmpty else { return }
            let index = self.nextPlayerIndex[id, default: 0] % pool.count
            let player = pool[index]
            self.nextPlayerIndex[id] = (index + 1) % pool.count
            player.stop()
            player.currentTime = 0
            player.prepareToPlay()
            player.play()
            pool[index] = player
            self.playerPools[id] = pool
        }
    }
}
