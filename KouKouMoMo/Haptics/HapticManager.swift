import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private let light  = UIImpactFeedbackGenerator(style: .light)
    private let soft   = UIImpactFeedbackGenerator(style: .soft)
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
        [light, soft, medium, heavy, rigid].forEach { $0.prepare() }
        success.prepare()
    }

    func start() {
        soft.prepare()
        soft.impactOccurred(intensity: 0.35)
        soft.prepare()
    }

    func progress(intensity: Double) {
        guard Date().timeIntervalSince(lastProgressAt) >= 0.05 else { return }
        lastProgressAt = Date()
        light.prepare()
        light.impactOccurred(intensity: CGFloat((0.22 + intensity * 0.50).clamped(to: 0.22...0.75)))
        light.prepare()
    }

    func completion() {
        success.prepare()
        success.notificationOccurred(.success)
        success.prepare()
    }

    func orbitTick(intensity: Double) {
        frictionTick(intensity: intensity, minimumInterval: 0.05)
    }

    func earPullBeat(strength: Double) {
        guard Date().timeIntervalSince(lastBeatAt) >= 0.08 else { return }
        lastBeatAt = Date()
        rigid.prepare()
        rigid.impactOccurred(intensity: CGFloat((0.45 + strength * 0.50).clamped(to: 0.45...0.95)))
        rigid.prepare()
    }

    func earSpringBack() {
        soft.prepare()
        soft.impactOccurred(intensity: 0.45)
        soft.prepare()
    }

    func chompBeat(intensity: Double) {
        guard Date().timeIntervalSince(lastBeatAt) >= 0.07 else { return }
        lastBeatAt = Date()
        medium.prepare()
        medium.impactOccurred(intensity: CGFloat((0.55 + intensity * 0.45).clamped(to: 0.55...1.0)))
        medium.prepare()
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

    func frictionTick(intensity: Double, minimumInterval: TimeInterval = 0.05) {
        guard Date().timeIntervalSince(lastProgressAt) >= max(0.05, minimumInterval) else { return }
        lastProgressAt = Date()
        let clamped = intensity.clamped(to: 0...1)
        let generator: UIImpactFeedbackGenerator = clamped > 0.72 ? heavy : (clamped > 0.38 ? medium : light)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat((0.25 + clamped * 0.75).clamped(to: 0.25...1.0)))
        generator.prepare()
    }

    func peak() {
        guard Date().timeIntervalSince(lastProgressAt) >= 0.05 else { return }
        lastProgressAt = Date()
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }

    func releaseTail() {
        soft.prepare()
        soft.impactOccurred(intensity: 0.45)
        soft.prepare()
    }

    func penHalfTurnTick(intensity: Double) {
        let interval = 0.14 - intensity.clamped(to: 0...1) * 0.09
        guard Date().timeIntervalSince(lastPenAt) >= max(0.05, interval) else { return }
        lastPenAt = Date()
        medium.prepare()
        medium.impactOccurred(intensity: CGFloat((0.45 + intensity * 0.50).clamped(to: 0.45...0.95)))
        medium.prepare()
    }

    func penInertiaStart() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 0.95)
        rigid.prepare()
    }

    func penCaught() {
        medium.prepare()
        medium.impactOccurred(intensity: 0.85)
        medium.prepare()
    }

    func penStopped() {
        medium.prepare()
        medium.impactOccurred(intensity: 0.75)
        medium.prepare()
    }

    func spinLoop() {
        penHalfTurnTick(intensity: 0.6)
    }

    func spinFlick() {
        guard Date().timeIntervalSince(lastPenAt) >= 0.05 else { return }
        lastPenAt = Date()
        light.prepare()
        light.impactOccurred(intensity: 0.4)
        light.prepare()
    }

    func heavyCompletion() {
        peak()
    }
}
