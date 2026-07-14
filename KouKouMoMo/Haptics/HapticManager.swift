import UIKit

/// Central haptic feedback. Progress events are throttled to avoid the phone shaking non-stop.
final class HapticManager {
    static let shared = HapticManager()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft  = UIImpactFeedbackGenerator(style: .soft)
    private let success = UINotificationFeedbackGenerator()
    private var lastProgressAt = Date.distantPast

    private init() {
        light.prepare(); soft.prepare(); success.prepare()
    }

    func start() {
        soft.impactOccurred(intensity: 0.32)
        soft.prepare()
    }

    func progress(intensity: Double) {
        guard Date().timeIntervalSince(lastProgressAt) > 0.16 else { return }
        lastProgressAt = Date()
        light.impactOccurred(intensity: CGFloat(0.22 + intensity * 0.38))
        light.prepare()
    }

    func completion() {
        success.notificationOccurred(.success)
        success.prepare()
    }
}
