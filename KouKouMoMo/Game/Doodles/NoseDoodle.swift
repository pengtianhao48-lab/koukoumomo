import SwiftUI

struct NoseDoodle: View {
    @ObservedObject var viewModel: ToyViewModel
    @State private var fingerPoint: CGPoint?
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragTime: Date?

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    NoseDoodleRenderer.draw(context: ctx, size: size,
                                            progress: viewModel.progress,
                                            velocity: viewModel.velocity,
                                            axis: viewModel.axis,
                                            isCompleting: viewModel.isCompleting,
                                            completionTick: viewModel.completionTick,
                                            time: now,
                                            fingerPoint: fingerPoint)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in handleDrag(value, size: proxy.size) }
                        .onEnded { _ in
                            lastDragPoint = nil
                            lastDragTime = nil
                        }
                )
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value, size: CGSize) {
        let now = value.time
        defer {
            lastDragPoint = value.location
            lastDragTime = now
        }
        guard let previous = lastDragPoint, let previousTime = lastDragTime else {
            fingerPoint = value.location
            return
        }
        let dt = max(0.001, now.timeIntervalSince(previousTime))
        let distance = hypot(value.location.x - previous.x, value.location.y - previous.y)
        let speed = distance / dt
        fingerPoint = value.location
        guard distance > 0.7 else { return }
        let interval = max(0.028, 0.075 - min(1, Double(speed / 900)) * 0.035)
        HapticManager.shared.frictionTick(intensity: min(1, Double(speed / 850)), minimumInterval: interval)
    }
}

struct NoseDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            NoseDoodleRenderer.draw(context: ctx, size: size,
                                    progress: 0, velocity: 0, axis: 0,
                                    isCompleting: false, completionTick: 0, time: 0,
                                    fingerPoint: nil)
        }
    }
}

private enum NoseDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, velocity: Double, axis: Double,
                     isCompleting: Bool, completionTick: Int, time: TimeInterval,
                     fingerPoint: CGPoint?) {
        let W = size.width
        let H = size.height
        let face = CGRect(x: W * 0.14, y: H * 0.16, width: W * 0.72, height: H * 0.68)
        context.stroke(Rough.ellipse(in: face, wobble: 2.2, points: 42, seed: 11),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        let expression = CGFloat(progress.clamped(to: 0...1))
        let cheekOpacity = 0.32 + Double(expression) * 0.48
        context.fill(Rough.ellipse(in: CGRect(x: face.minX + face.width * 0.10, y: face.midY + face.height * 0.06,
                                              width: face.width * (0.17 + expression * 0.04), height: face.width * (0.10 + expression * 0.04)),
                                    wobble: 1.4, seed: 21),
                     with: .color(DoodleStyle.blush.opacity(cheekOpacity)))
        context.fill(Rough.ellipse(in: CGRect(x: face.maxX - face.width * (0.28 + expression * 0.02), y: face.midY + face.height * 0.06,
                                              width: face.width * (0.17 + expression * 0.04), height: face.width * (0.10 + expression * 0.04)),
                                    wobble: 1.4, seed: 22),
                     with: .color(DoodleStyle.blush.opacity(cheekOpacity)))

        let eyeY = face.midY - face.height * 0.14
        let eyeHeight: CGFloat = max(2.0, 10 + 3 * CGFloat(sin(time * 0.6)) - expression * 8)
        for (idx, c) in [CGPoint(x: face.midX - face.width * 0.19, y: eyeY), CGPoint(x: face.midX + face.width * 0.19, y: eyeY)].enumerated() {
            if expression < 0.55 {
                let rect = CGRect(x: c.x - 7, y: c.y - eyeHeight / 2, width: 14, height: eyeHeight)
                context.fill(Rough.ellipse(in: rect, wobble: 0.6, seed: 33 &+ idx), with: .color(DoodleStyle.ink))
            } else {
                let w: CGFloat = 22 + expression * 8
                let bulge: CGFloat = idx == 0 ? -8 - expression * 7 : 8 + expression * 7
                context.stroke(Rough.arc(from: CGPoint(x: c.x - w / 2, y: c.y),
                                         to: CGPoint(x: c.x + w / 2, y: c.y),
                                         bulge: bulge, seed: 33 &+ idx),
                               with: .color(DoodleStyle.ink), style: .doodleBold)
            }
        }
        let browTilt = 8 + expression * 20
        for (i, cx) in [face.midX - face.width * 0.19, face.midX + face.width * 0.19].enumerated() {
            let inward: CGFloat = i == 0 ? 1 : -1
            context.stroke(Rough.line(from: CGPoint(x: cx - 15, y: eyeY - 20 + browTilt * inward * 0.45),
                                      to: CGPoint(x: cx + 15, y: eyeY - 20 - browTilt * inward * 0.45),
                                      steps: 6, amp: 1.0 + expression * 0.6, seed: 71 &+ i),
                           with: .color(DoodleStyle.ink), style: .doodleBold)
        }

        let noseTop = CGPoint(x: face.midX, y: face.midY - face.height * 0.02)
        let noseLeft = CGPoint(x: face.midX - face.width * 0.16, y: face.midY + face.height * 0.14)
        let noseRight = CGPoint(x: face.midX + face.width * 0.16, y: face.midY + face.height * 0.14)
        context.stroke(Rough.line(from: noseTop, to: noseLeft, steps: 8, amp: 1.3, seed: 101), with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.line(from: noseTop, to: noseRight, steps: 8, amp: 1.3, seed: 102), with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.arc(from: noseLeft, to: noseRight, bulge: 26, seed: 103), with: .color(DoodleStyle.ink), style: .doodleBold)

        let leftNostril = CGRect(x: noseLeft.x + 6, y: noseLeft.y - 12, width: 22, height: 14)
        let rightNostril = CGRect(x: noseRight.x - 28, y: noseRight.y - 12, width: 22, height: 14)
        context.fill(Rough.ellipse(in: leftNostril, wobble: 0.9, seed: 111), with: .color(DoodleStyle.ink))
        context.fill(Rough.ellipse(in: rightNostril, wobble: 0.9, seed: 112), with: .color(DoodleStyle.ink))

        let nostrilCenter = CGPoint(x: rightNostril.midX, y: rightNostril.midY)
        let defaultR: CGFloat = 2.4 + CGFloat(progress) * 2.2
        let spin = time * 3.4 + axis * 6
        let defaultTip = CGPoint(x: nostrilCenter.x + cos(spin) * defaultR,
                                 y: nostrilCenter.y + sin(spin) * defaultR * 0.45)
        let tipCenter = clamped(fingerPoint ?? defaultTip,
                                to: nostrilCenter,
                                radiusX: rightNostril.width * 0.34,
                                radiusY: rightNostril.height * 0.34)

        let baseX = face.midX + face.width * 0.20 + CGFloat(sin(time * 1.6)) * 4
        let baseY = face.maxY + 18
        let fingerW: CGFloat = 26
        var trunk = Path()
        let control = CGPoint(x: baseX - 12, y: (baseY + tipCenter.y) / 2 + 24)
        trunk.move(to: CGPoint(x: baseX, y: baseY))
        trunk.addQuadCurve(to: tipCenter, control: control)
        context.stroke(trunk, with: .color(DoodleStyle.ink), style: StrokeStyle(lineWidth: fingerW + 3, lineCap: .round, lineJoin: .round))
        context.stroke(trunk, with: .color(DoodleStyle.paper), style: StrokeStyle(lineWidth: fingerW, lineCap: .round, lineJoin: .round))

        let knuckleT: CGFloat = 0.65
        let kx = (1-knuckleT)*(1-knuckleT)*baseX + 2*(1-knuckleT)*knuckleT*control.x + knuckleT*knuckleT*tipCenter.x
        let ky = (1-knuckleT)*(1-knuckleT)*baseY + 2*(1-knuckleT)*knuckleT*control.y + knuckleT*knuckleT*tipCenter.y
        context.stroke(Rough.arc(from: CGPoint(x: kx - 8, y: ky), to: CGPoint(x: kx + 8, y: ky), bulge: 3, seed: 210),
                       with: .color(DoodleStyle.ink.opacity(0.6)), style: .doodleThin)

        context.fill(Rough.ellipse(in: rightNostril, wobble: 0.9, seed: 112), with: .color(DoodleStyle.ink))
        let fingertipRect = CGRect(x: tipCenter.x - 6, y: tipCenter.y - 4, width: 12, height: 8)
        context.fill(Rough.ellipse(in: fingertipRect, wobble: 0.5, seed: 210), with: .color(DoodleStyle.paper))
        context.stroke(Rough.ellipse(in: fingertipRect, wobble: 0.5, seed: 210), with: .color(DoodleStyle.ink), style: .doodleThin)
        let nailRect = CGRect(x: tipCenter.x - 6, y: tipCenter.y - 3, width: 12, height: 6)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY), to: CGPoint(x: nailRect.maxX, y: nailRect.midY), bulge: -3, seed: 211),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)

        let boogerSize = 3 + CGFloat(progress) * 6
        if progress > 0.02 || isCompleting {
            let boogerRect = CGRect(x: tipCenter.x - boogerSize / 2, y: tipCenter.y - boogerSize / 2, width: boogerSize, height: boogerSize)
            context.fill(Rough.ellipse(in: boogerRect, wobble: 0.7, seed: 121), with: .color(DoodleStyle.sunshine.opacity(0.85)))
            context.stroke(Rough.ellipse(in: boogerRect, wobble: 0.7, seed: 121), with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        let mouthCenter = CGPoint(x: face.midX, y: face.maxY - face.height * 0.14 + expression * 10)
        let mouthWidth: CGFloat = 42 + expression * 42 + (isCompleting ? 18 : 0)
        if expression < 0.35 {
            context.stroke(Rough.arc(from: CGPoint(x: mouthCenter.x - mouthWidth, y: mouthCenter.y + expression * 5),
                                     to: CGPoint(x: mouthCenter.x + mouthWidth, y: mouthCenter.y + expression * 5),
                                     bulge: -8 + expression * 30, seed: 131),
                           with: .color(DoodleStyle.ink), style: .doodleBold)
        } else {
            let grinHeight: CGFloat = 14 + expression * 24 + (isCompleting ? 10 : 0)
            var grin = Path()
            grin.move(to: CGPoint(x: mouthCenter.x - mouthWidth, y: mouthCenter.y))
            grin.addCurve(to: CGPoint(x: mouthCenter.x + mouthWidth, y: mouthCenter.y),
                          control1: CGPoint(x: mouthCenter.x - mouthWidth * 0.45, y: mouthCenter.y + grinHeight),
                          control2: CGPoint(x: mouthCenter.x + mouthWidth * 0.45, y: mouthCenter.y + grinHeight))
            context.stroke(grin, with: .color(DoodleStyle.ink), style: .doodleBold)
            if expression > 0.72 || isCompleting {
                context.stroke(Rough.arc(from: CGPoint(x: mouthCenter.x - mouthWidth * 0.35, y: mouthCenter.y + grinHeight * 0.45),
                                         to: CGPoint(x: mouthCenter.x + mouthWidth * 0.35, y: mouthCenter.y + grinHeight * 0.45),
                                         bulge: 5, seed: 132),
                               with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)
            }
        }

        if isCompleting {
            let liftPhase = CGFloat(sin(min(1, (time - Double(completionTick)) * 4)))
            let blobRect = CGRect(x: rightNostril.midX - 20, y: rightNostril.midY - 90 - liftPhase * 20, width: 40, height: 30)
            context.fill(Rough.ellipse(in: blobRect, wobble: 1.6, seed: 141), with: .color(DoodleStyle.sunshine))
            context.stroke(Rough.ellipse(in: blobRect, wobble: 1.6, seed: 141), with: .color(DoodleStyle.ink), style: .doodle)
        }
    }

    private static func clamped(_ point: CGPoint, to center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let normalized = (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY)
        guard normalized > 1 else { return point }
        let scale = 1 / sqrt(normalized)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

#Preview {
    NoseDoodle(viewModel: ToyViewModel(mode: .nosePick))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
