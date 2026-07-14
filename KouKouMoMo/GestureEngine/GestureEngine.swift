import SwiftUI

enum GestureKind {
    case rotation
    case verticalSlide
    case horizontalSlide
    case tap
    case continuousMotion
}

struct GestureProgressEvent {
    let progress: Double
    let velocity: Double
    /// Direction hint used by some doodles (e.g. earlobe up/down, finger left/right).
    let axis: Double
}

/// Turns raw touch input into a normalized progress value (0…1) plus velocity/direction hints.
/// Every doodle consumes the same interface: it never listens to raw drag events itself.
final class GestureEngine {
    var onFingerDown: (() -> Void)?
    var onProgress: ((GestureProgressEvent) -> Void)?

    private let kind: GestureKind
    private var lastPoint: CGPoint?
    private var lastAngle: CGFloat?
    private var accumulated: CGFloat = 0
    private var hasStarted = false

    init(kind: GestureKind) {
        self.kind = kind
    }

    func reset() {
        lastPoint = nil
        lastAngle = nil
        accumulated = 0
        hasStarted = false
    }

    /// Reset only the accumulated-progress counter (used by infinite-loop toys so they
    /// can restart the cycle without dropping the finger-down state).
    func resetAccumulator() {
        accumulated = 0
    }

    func handleTap() {
        beginIfNeeded()
        guard kind == .tap else { return }
        accumulated += 0.14
        emit(velocity: 1, axis: 0)
    }

    func handleDrag(_ value: DragGesture.Value, in size: CGSize) {
        beginIfNeeded()
        let location = value.location

        switch kind {
        case .rotation:
            handleRotation(location, size: size)
        case .verticalSlide:
            handleAxis(current: location.y, previous: lastPoint?.y, requiredDistance: 560, invertAxis: false)
        case .horizontalSlide:
            handleAxis(current: location.x, previous: lastPoint?.x, requiredDistance: 580, invertAxis: false)
        case .tap:
            break
        case .continuousMotion:
            handleContinuous(location, size: size)
        }

        lastPoint = location
    }

    func handleEnded() {
        lastPoint = nil
        lastAngle = nil
        hasStarted = false
    }

    private func beginIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        onFingerDown?()
    }

    private func handleRotation(_ point: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let angle = atan2(point.y - center.y, point.x - center.x)
        defer { lastAngle = angle }
        guard let previous = lastAngle else { return }
        let delta = normalizedAngleDelta(angle - previous)
        guard abs(delta) > 0.014 else { return }
        accumulated += abs(delta) / (CGFloat.pi * 5.2)
        emit(velocity: min(1, Double(abs(delta) * 8)), axis: Double(delta))
    }

    private func handleAxis(current: CGFloat, previous: CGFloat?, requiredDistance: CGFloat, invertAxis: Bool) {
        guard let previous else { return }
        let delta = current - previous
        guard abs(delta) > 0.6 else { return }
        accumulated += abs(delta) / requiredDistance
        let axis = Double(invertAxis ? -delta : delta) / 20
        emit(velocity: min(1, Double(abs(delta) / 18)), axis: axis)
    }

    private func handleContinuous(_ point: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let angle = atan2(point.y - center.y, point.x - center.x)
        let horizontalDelta = abs(point.x - (lastPoint?.x ?? point.x))
        var rotationContribution: CGFloat = 0
        if let previousAngle = lastAngle {
            rotationContribution = abs(normalizedAngleDelta(angle - previousAngle)) / (CGFloat.pi * 6.5)
        }
        accumulated += rotationContribution + horizontalDelta / 720
        lastAngle = angle
        emit(velocity: min(1, Double(horizontalDelta / 22 + rotationContribution * 3)), axis: Double(point.x - (lastPoint?.x ?? point.x)) / 12)
    }

    private func emit(velocity: Double, axis: Double) {
        let clamped = Double(min(1.05, max(0, accumulated)))
        onProgress?(GestureProgressEvent(progress: clamped, velocity: velocity.clamped(to: 0...1), axis: axis))
    }

    private func normalizedAngleDelta(_ value: CGFloat) -> CGFloat {
        var delta = value
        while delta > .pi { delta -= .pi * 2 }
        while delta < -.pi { delta += .pi * 2 }
        return delta
    }
}
