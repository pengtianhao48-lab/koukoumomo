import SwiftUI

struct PenDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    @State private var angle: Double = 0
    @State private var angularVelocity: Double = 0
    @State private var lastFrame: TimeInterval = 0
    @State private var trailSamples: [Double] = []
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragTime: Date?
    @State private var lastFingerAngle: Double?
    @State private var catchAngle: Double?
    @State private var lastHalfTurnIndex = 0
    @State private var wasSpinning = false
    @State private var lastTimelineStep: TimeInterval = 0

    private let flickThreshold: CGFloat = 300
    private let friction: Double = 1.75
    private let maxAV: Double = 2600

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    PenDoodleRenderer.draw(context: ctx, size: size,
                                           angle: angle,
                                           trail: trailSamples,
                                           velocity: abs(angularVelocity) / 900,
                                           time: time)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in handleDrag(value, size: proxy.size) }
                        .onEnded { value in handleEnded(value, size: proxy.size) }
                )
                .onChange(of: time) { _, newTime in handleTimelineChange(newTime) }
            }
        }
    }

    private func handleTimelineChange(_ newTime: TimeInterval) {
        guard newTime - lastTimelineStep > 0.001 else { return }
        lastTimelineStep = newTime
        step(now: newTime)
    }

    private func handleDrag(_ value: DragGesture.Value, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let point = value.location
        let fingerAngle = Double(atan2(point.y - center.y, point.x - center.x)) * 180 / Double.pi

        if lastDragPoint == nil {
            if abs(angularVelocity) > 30 {
                catchAngle = fingerAngle
            } else {
                angle = fingerAngle
                angularVelocity = 0
            }
            lastDragPoint = point
            lastDragTime = value.time
            lastFingerAngle = fingerAngle
            return
        }

        guard catchAngle == nil else {
            lastDragPoint = point
            lastDragTime = value.time
            lastFingerAngle = fingerAngle
            return
        }

        angle = fingerAngle
        angularVelocity = 0
        lastDragPoint = point
        lastDragTime = value.time
        lastFingerAngle = fingerAngle
    }

    private func handleEnded(_ value: DragGesture.Value, size: CGSize) {
        defer {
            lastDragPoint = nil
            lastDragTime = nil
            lastFingerAngle = nil
            catchAngle = nil
        }
        let speed = dragSpeed(value)
        guard speed >= flickThreshold else {
            angularVelocity = 0
            trailSamples = []
            wasSpinning = false
            return
        }
        let direction = flickDirection(value, size: size)
        let launch = min(maxAV, Double(speed) * 4.2)
        angularVelocity = direction * max(720, launch)
        lastHalfTurnIndex = Int(floor(angle / 180))
        wasSpinning = true
        HapticManager.shared.penInertiaStart()
    }

    private func step(now: TimeInterval) {
        if lastFrame == 0 { lastFrame = now; return }
        let dt = min(1.0 / 30, now - lastFrame)
        lastFrame = now

        if let target = catchAngle, abs(angularVelocity) > 1 {
            let diff = abs(normalizedAngleDelta(normalizedDegrees(angle) - normalizedDegrees(target)))
            if diff < 15 {
                angularVelocity = 0
                catchAngle = nil
                trailSamples = []
                wasSpinning = false
                HapticManager.shared.penCaught()
                return
            }
        }

        guard abs(angularVelocity) > 0 else { return }
        let previousAngle = angle
        angle += angularVelocity * dt
        angularVelocity *= exp(-friction * dt)
        angularVelocity = angularVelocity.clamped(to: -maxAV...maxAV)

        let currentHalfTurn = Int(floor(angle / 180))
        if currentHalfTurn != lastHalfTurnIndex {
            lastHalfTurnIndex = currentHalfTurn
            HapticManager.shared.penHalfTurnTick(intensity: min(1, abs(angularVelocity) / maxAV))
        }

        if abs(angularVelocity) < 28 {
            angularVelocity = 0
            trailSamples = []
            if wasSpinning {
                wasSpinning = false
                HapticManager.shared.penStopped()
            }
            return
        }
        if abs(angularVelocity) > 180, abs(angle - (trailSamples.last ?? previousAngle)) > 12 {
            var updated = trailSamples
            updated.append(angle)
            if updated.count > 4 { updated.removeFirst(updated.count - 4) }
            trailSamples = updated
        } else if abs(angularVelocity) <= 180, !trailSamples.isEmpty {
            trailSamples = []
        }
    }

    private func dragSpeed(_ value: DragGesture.Value) -> CGFloat {
        guard let previous = lastDragPoint, let previousTime = lastDragTime else { return 0 }
        let dt = max(0.001, value.time.timeIntervalSince(previousTime))
        return hypot(value.location.x - previous.x, value.location.y - previous.y) / dt
    }

    private func flickDirection(_ value: DragGesture.Value, size: CGSize) -> Double {
        guard let previous = lastDragPoint else { return angularVelocity >= 0 ? 1 : -1 }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radial = CGVector(dx: previous.x - center.x, dy: previous.y - center.y)
        let motion = CGVector(dx: value.location.x - previous.x, dy: value.location.y - previous.y)
        let cross = radial.dx * motion.dy - radial.dy * motion.dx
        if abs(cross) < 0.001 { return angularVelocity >= 0 ? 1 : -1 }
        return cross >= 0 ? 1 : -1
    }

    private func normalizedAngleDelta(_ value: Double) -> Double {
        var delta = value
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }
}

struct PenDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            PenDoodleRenderer.draw(context: ctx, size: size, angle: -30, trail: [], velocity: 0, time: 0)
        }
    }
}

enum PenDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     angle: Double, trail: [Double], velocity: Double,
                     time: TimeInterval) {
        let cx = size.width / 2
        let cy = size.height / 2
        let pivot = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
        context.fill(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700), with: .color(DoodleStyle.paperShadow.opacity(0.55)))
        context.stroke(Rough.ellipse(in: pivot, wobble: 1.2, points: 24, seed: 700), with: .color(DoodleStyle.inkFaint), style: .doodleThin)

        for (i, ta) in trail.enumerated() {
            let alpha = Double(i + 1) / Double(trail.count + 1) * 0.30 * min(1.0, velocity * 2.0)
            if alpha < 0.02 { continue }
            drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: ta, length: penLength(size), alpha: alpha, ghost: true)
        }
        drawPen(context: context, center: CGPoint(x: cx, y: cy), angle: angle, length: penLength(size), alpha: 1.0, ghost: false)
        _ = time
    }

    private static func penLength(_ size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.7
    }

    private static func drawPen(context: GraphicsContext, center: CGPoint, angle: Double,
                                length: CGFloat, alpha: Double, ghost: Bool) {
        var pen = context
        pen.translateBy(x: center.x, y: center.y)
        pen.rotate(by: .degrees(angle))

        let totalW = length
        let capLen: CGFloat = totalW * 0.20
        let bodyLen: CGFloat = totalW * 0.62
        let tipLen: CGFloat = totalW * 0.18
        let halfLen = totalW / 2
        let thick: CGFloat = 12

        let inkColor = DoodleStyle.ink.opacity(alpha * (ghost ? 0.55 : 1))
        let bodyFill = DoodleStyle.blush.opacity(alpha * (ghost ? 0.25 : 0.7))
        let capFill = DoodleStyle.ink.opacity(alpha * (ghost ? 0.35 : 0.9))

        let capRect = CGRect(x: halfLen - capLen, y: -thick/2, width: capLen, height: thick)
        let capPath = Rough.roundedRect(capRect, corner: thick/2, wobble: 0.5, seed: 740)
        pen.fill(capPath, with: .color(capFill))
        pen.stroke(capPath, with: .color(inkColor), style: .doodle)
        let clipX = halfLen - capLen
        var clipPath = Path()
        clipPath.move(to: CGPoint(x: clipX, y: -thick/2 - 2))
        clipPath.addLine(to: CGPoint(x: clipX, y: thick/2 + 2))
        pen.stroke(clipPath, with: .color(inkColor), style: .doodle)

        let bodyRect = CGRect(x: -halfLen + tipLen, y: -thick/2, width: bodyLen, height: thick)
        let bodyPath = Rough.roundedRect(bodyRect, corner: 3, wobble: 0.4, seed: 741)
        pen.fill(bodyPath, with: .color(bodyFill))
        pen.stroke(bodyPath, with: .color(inkColor), style: .doodle)
        for i in 0..<4 {
            let sx = -halfLen + tipLen + 6 + CGFloat(i) * 6
            var stripe = Path()
            stripe.move(to: CGPoint(x: sx, y: -thick/2 + 2))
            stripe.addLine(to: CGPoint(x: sx, y: thick/2 - 2))
            pen.stroke(stripe, with: .color(inkColor.opacity(alpha * 0.7)), style: .doodleThin)
        }

        var tip = Path()
        tip.move(to: CGPoint(x: -halfLen, y: 0))
        tip.addLine(to: CGPoint(x: -halfLen + tipLen, y: -thick/2))
        tip.addLine(to: CGPoint(x: -halfLen + tipLen, y: thick/2))
        tip.closeSubpath()
        pen.fill(tip, with: .color(DoodleStyle.ink.opacity(alpha * (ghost ? 0.4 : 0.95))))
        pen.stroke(tip, with: .color(inkColor), style: .doodle)
    }
}

#Preview {
    PenDoodle(viewModel: ToyViewModel(mode: .penSpin))
        .frame(width: 360, height: 360).background(DoodleStyle.paper)
}
