import UIKit

/// Central haptic feedback. Different toys expose different textures — orbit taps, chomp beats,
/// bubble pops, spin ticks — so the phone feel matches the on-screen action.
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

    private init() {
        [light, soft, medium, heavy, rigid].forEach { $0.prepare() }
        success.prepare()
    }

    // Legacy — kept so existing callers keep working.
    func start() {
        soft.impactOccurred(intensity: 0.35)
        soft.prepare()
    }
    func progress(intensity: Double) {
        guard Date().timeIntervalSince(lastProgressAt) > 0.12 else { return }
        lastProgressAt = Date()
        light.impactOccurred(intensity: CGFloat(0.22 + intensity * 0.38))
        light.prepare()
    }
    func completion() {
        success.notificationOccurred(.success)
        success.prepare()
    }

    // MARK: - Mode-specific textures

    /// A quick low-intensity beat used for continuous orbits (nose/navel).
    func orbitTick(intensity: Double) {
        guard Date().timeIntervalSince(lastProgressAt) > 0.14 else { return }
        lastProgressAt = Date()
        light.impactOccurred(intensity: CGFloat(0.28 + intensity * 0.35))
        light.prepare()
    }

    /// Ear-lobe pull-down beat (medium impact when it bottoms out).
    func earPullBeat(strength: Double) {
        guard Date().timeIntervalSince(lastBeatAt) > 0.18 else { return }
        lastBeatAt = Date()
        medium.impactOccurred(intensity: CGFloat(0.55 + strength * 0.45))
        medium.prepare()
    }

    /// A tiny "spring back" flick when the lobe rebounds after release.
    func earSpringBack() {
        light.impactOccurred(intensity: 0.35)
        light.prepare()
    }

    /// One chomp beat — medium impact, rate-limited so it's rhythmic.
    func chompBeat(intensity: Double) {
        guard Date().timeIntervalSince(lastBeatAt) > 0.11 else { return }
        lastBeatAt = Date()
        medium.impactOccurred(intensity: CGFloat(0.50 + intensity * 0.50))
        medium.prepare()
    }

    /// The satisfying bubble pop. Heavy + tiny rigid tail for the "snap".
    func bubblePop() {
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.rigid.impactOccurred(intensity: 0.45)
            self?.rigid.prepare()
        }
    }

    func frictionTick(intensity: Double, minimumInterval: TimeInterval = 0.06) {
        guard Date().timeIntervalSince(lastProgressAt) > minimumInterval else { return }
        lastProgressAt = Date()
        light.impactOccurred(intensity: CGFloat((0.25 + intensity * 0.65).clamped(to: 0.25...1.0)))
        light.prepare()
    }

    func penHalfTurnTick(intensity: Double) {
        medium.impactOccurred(intensity: CGFloat((0.55 + intensity * 0.35).clamped(to: 0.55...1.0)))
        medium.prepare()
    }

    func penInertiaStart() {
        rigid.impactOccurred(intensity: 0.95)
        rigid.prepare()
    }

    func penCaught() {
        medium.impactOccurred(intensity: 0.85)
        medium.prepare()
    }

    func penStopped() {
        heavy.impactOccurred(intensity: 0.9)
        heavy.prepare()
    }

    /// A single 360° pen-spin tick.
    func spinLoop() {
        medium.impactOccurred(intensity: 0.6)
        medium.prepare()
    }

    /// A quick "flick" tap while actively spinning the pen.
    func spinFlick() {
        light.impactOccurred(intensity: 0.4)
        light.prepare()
    }

    /// Completion — reserved for nose (which still finishes with a booger).
    func heavyCompletion() {
        heavy.impactOccurred(intensity: 1.0)
        heavy.prepare()
    }
}
