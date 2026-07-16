import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    private let success = UINotificationFeedbackGenerator()

    private var lastProgressAt = Date.distantPast
    private var lastBeatAt = Date.distantPast
    private var lastPenAt = Date.distantPast
    private var bubbleCombo = 0
    private var lastBubbleAt = Date.distantPast

    private init() {
        [medium, heavy, rigid].forEach { $0.prepare() }
        success.prepare()
    }

    func start() {
        medium.prepare()
        medium.impactOccurred(intensity: 0.55)
        medium.prepare()
    }

    func progress(intensity: Double) {
        guard Date().timeIntervalSince(lastProgressAt) >= 0.04 else { return }
        lastProgressAt = Date()
        medium.prepare()
        medium.impactOccurred(intensity: CGFloat((0.35 + intensity * 0.55).clamped(to: 0.35...0.90)))
        medium.prepare()
    }

    func completion() {
        success.prepare()
        success.notificationOccurred(.success)
        success.prepare()
    }

    func orbitTick(intensity: Double) {
        frictionTick(intensity: intensity, minimumInterval: 0.04)
    }

    func earPullBeat(strength: Double) {
        guard Date().timeIntervalSince(lastBeatAt) >= 0.06 else { return }
        lastBeatAt = Date()
        rigid.prepare()
        rigid.impactOccurred(intensity: CGFloat((0.55 + strength * 0.45).clamped(to: 0.55...1.0)))
        rigid.prepare()
    }

    func earSpringBack() {
        medium.prepare()
        medium.impactOccurred(intensity: 0.65)
        medium.prepare()
    }

    func chompBeat(intensity: Double) {
        guard Date().timeIntervalSince(lastBeatAt) >= 0.06 else { return }
        lastBeatAt = Date()
        heavy.prepare()
        heavy.impactOccurred(intensity: CGFloat((0.65 + intensity * 0.35).clamped(to: 0.65...1.0)))
        heavy.prepare()
    }

    func bubblePop() {
        let now = Date()
        bubbleCombo = now.timeIntervalSince(lastBubbleAt) < 0.35 ? bubbleCombo + 1 : 1
        lastBubbleAt = now
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
        if bubbleCombo >= 5 {
            bubbleCombo = 0
            success.prepare()
            success.notificationOccurred(.success)
            success.prepare()
        }
    }

    func frictionTick(intensity: Double, minimumInterval: TimeInterval = 0.04) {
        guard Date().timeIntervalSince(lastProgressAt) >= max(0.04, minimumInterval) else { return }
        lastProgressAt = Date()
        let clamped = intensity.clamped(to: 0...1)
        let generator: UIImpactFeedbackGenerator = clamped > 0.38 ? heavy : medium
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat((0.35 + clamped * 0.65).clamped(to: 0.35...1.0)))
        generator.prepare()
    }

    func peak() {
        guard Date().timeIntervalSince(lastProgressAt) >= 0.04 else { return }
        lastProgressAt = Date()
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }

    func releaseTail() {
        medium.prepare()
        medium.impactOccurred(intensity: 0.65)
        medium.prepare()
    }

    func penHalfTurnTick(intensity: Double) {
        let interval = 0.12 - intensity.clamped(to: 0...1) * 0.08
        guard Date().timeIntervalSince(lastPenAt) >= max(0.04, interval) else { return }
        lastPenAt = Date()
        heavy.prepare()
        heavy.impactOccurred(intensity: CGFloat((0.55 + intensity * 0.45).clamped(to: 0.55...1.0)))
        heavy.prepare()
    }

    func penInertiaStart() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 0.95)
        rigid.prepare()
    }

    func penCaught() {
        heavy.prepare()
        heavy.impactOccurred(intensity: 0.9)
        heavy.prepare()
    }

    func penStopped() {
        heavy.prepare()
        heavy.impactOccurred(intensity: 0.8)
        heavy.prepare()
    }

    func spinLoop() {
        penHalfTurnTick(intensity: 0.7)
    }

    func spinFlick() {
        guard Date().timeIntervalSince(lastPenAt) >= 0.04 else { return }
        lastPenAt = Date()
        medium.prepare()
        medium.impactOccurred(intensity: 0.55)
        medium.prepare()
    }

    func heavyCompletion() {
        peak()
    }
}
