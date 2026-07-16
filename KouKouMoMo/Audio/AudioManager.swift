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
    private var urls: [Int: URL] = [:]
    private var players: [AVAudioPlayer] = []

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        prepareSounds()
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

    private func play(_ id: Int) {
        if Preferences.shared.isMuted { return }
        guard let url = urls[id] else { return }
        players.removeAll { !$0.isPlaying }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.45
        player.prepareToPlay()
        player.play()
        players.append(player)
    }

    private func prepareSounds() {
        let specs: [Int: (Double, Double)] = [
            1104: (190, 0.030),
            1105: (260, 0.022),
            1106: (320, 0.040),
            1155: (520, 0.026),
            1156: (420, 0.030),
            1157: (720, 0.022),
            1306: (980, 0.018)
        ]
        for (id, spec) in specs {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("koukoumomo_\(id).wav")
            if !FileManager.default.fileExists(atPath: url.path) {
                writeTone(url: url, frequency: spec.0, duration: spec.1)
            }
            urls[id] = url
        }
    }

    private func writeTone(url: URL, frequency: Double, duration: Double) {
        let sampleRate = 44_100
        let samples = Int(Double(sampleRate) * duration)
        var data = Data()
        for i in 0..<samples {
            let t = Double(i) / Double(sampleRate)
            let fade = min(1, Double(i) / 80) * min(1, Double(samples - i) / 120)
            let wave = sin(2 * Double.pi * frequency * t) * 0.30 * fade
            var value = Int16(max(-1, min(1, wave)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        var file = Data()
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(data.count)
        let chunkSize = 36 + subchunk2Size

        file.append("RIFF".data(using: .ascii)!)
        appendLE(UInt32(chunkSize), to: &file)
        file.append("WAVEfmt ".data(using: .ascii)!)
        appendLE(UInt32(16), to: &file)
        appendLE(UInt16(1), to: &file)
        appendLE(UInt16(1), to: &file)
        appendLE(UInt32(sampleRate), to: &file)
        appendLE(UInt32(byteRate), to: &file)
        appendLE(blockAlign, to: &file)
        appendLE(bitsPerSample, to: &file)
        file.append("data".data(using: .ascii)!)
        appendLE(subchunk2Size, to: &file)
        file.append(data)
        try? file.write(to: url, options: .atomic)
    }

    private func appendLE(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private func appendLE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}
