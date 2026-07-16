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
                        .onChanged { value in handleDrag(value) }
                        .onEnded { _ in
                            lastDragPoint = nil
                            lastDragTime = nil
                        }
                )
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value) {
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
                                    progress: 0.28, velocity: 0, axis: 0,
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
        let expression = CGFloat(progress.clamped(to: 0...1))
        let face = CGRect(x: W * 0.13, y: H * 0.08, width: W * 0.74, height: H * 0.78)

        var facePath = Path()
        facePath.move(to: CGPoint(x: face.midX - face.width * 0.10, y: face.minY + face.height * 0.01))
        facePath.addCurve(to: CGPoint(x: face.maxX - face.width * 0.07, y: face.minY + face.height * 0.26),
                          control1: CGPoint(x: face.midX + face.width * 0.20, y: face.minY - face.height * 0.03),
                          control2: CGPoint(x: face.maxX - face.width * 0.14, y: face.minY + face.height * 0.10))
        facePath.addCurve(to: CGPoint(x: face.maxX - face.width * 0.05, y: face.minY + face.height * 0.74),
                          control1: CGPoint(x: face.maxX + face.width * 0.08, y: face.minY + face.height * 0.45),
                          control2: CGPoint(x: face.maxX + face.width * 0.04, y: face.minY + face.height * 0.62))
        facePath.addCurve(to: CGPoint(x: face.midX, y: face.maxY),
                          control1: CGPoint(x: face.maxX - face.width * 0.15, y: face.minY + face.height * 0.92),
                          control2: CGPoint(x: face.midX + face.width * 0.18, y: face.maxY + face.height * 0.02))
        facePath.addCurve(to: CGPoint(x: face.minX + face.width * 0.08, y: face.minY + face.height * 0.75),
                          control1: CGPoint(x: face.midX - face.width * 0.25, y: face.maxY - face.height * 0.02),
                          control2: CGPoint(x: face.minX + face.width * 0.09, y: face.minY + face.height * 0.92))
        facePath.addCurve(to: CGPoint(x: face.minX + face.width * 0.13, y: face.minY + face.height * 0.28),
                          control1: CGPoint(x: face.minX - face.width * 0.03, y: face.minY + face.height * 0.57),
                          control2: CGPoint(x: face.minX + face.width * 0.02, y: face.minY + face.height * 0.41))
        facePath.addCurve(to: CGPoint(x: face.midX - face.width * 0.10, y: face.minY + face.height * 0.01),
                          control1: CGPoint(x: face.minX + face.width * 0.18, y: face.minY + face.height * 0.13),
                          control2: CGPoint(x: face.midX - face.width * 0.27, y: face.minY + face.height * 0.08))
        context.stroke(facePath, with: .color(DoodleStyle.ink), style: StrokeStyle(lineWidth: DoodleStyle.strokeBold + 0.5, lineCap: .round, lineJoin: .round))

        let cheekOpacity = 0.22 + Double(expression) * 0.48
        let cheekScale = 1 + expression * 0.32
        let leftCheek = CGRect(x: face.minX + face.width * 0.11, y: face.midY + face.height * 0.10,
                               width: face.width * 0.18 * cheekScale, height: face.width * 0.105 * cheekScale)
        let rightCheek = CGRect(x: face.maxX - face.width * (0.29 + expression * 0.02), y: face.midY + face.height * 0.10,
                                width: face.width * 0.18 * cheekScale, height: face.width * 0.105 * cheekScale)
        context.fill(Rough.ellipse(in: leftCheek, wobble: 2.2, points: 24, seed: 21), with: .color(DoodleStyle.blush.opacity(cheekOpacity)))
        context.fill(Rough.ellipse(in: rightCheek, wobble: 2.2, points: 24, seed: 22), with: .color(DoodleStyle.blush.opacity(cheekOpacity)))

        let eyeY = face.minY + face.height * (0.35 + expression * 0.015)
        let leftEyeA = CGPoint(x: face.midX - face.width * 0.23, y: eyeY)
        let leftEyeB = CGPoint(x: face.midX - face.width * 0.10, y: eyeY - 4 - expression * 3)
        let rightEyeA = CGPoint(x: face.midX + face.width * 0.10, y: eyeY - 4 - expression * 3)
        let rightEyeB = CGPoint(x: face.midX + face.width * 0.23, y: eyeY)
        context.stroke(Rough.arc(from: leftEyeA, to: leftEyeB, bulge: -5 - expression * 4, seed: 31), with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.arc(from: rightEyeA, to: rightEyeB, bulge: 5 + expression * 4, seed: 32), with: .color(DoodleStyle.ink), style: .doodleBold)
        context.stroke(Rough.line(from: CGPoint(x: leftEyeA.x + 10, y: eyeY + 16), to: CGPoint(x: leftEyeA.x + 24, y: eyeY + 16), steps: 4, amp: 0.7, seed: 33), with: .color(DoodleStyle.ink), style: .doodleThin)
        context.stroke(Rough.line(from: CGPoint(x: rightEyeB.x - 24, y: eyeY + 16), to: CGPoint(x: rightEyeB.x - 10, y: eyeY + 16), steps: 4, amp: 0.7, seed: 34), with: .color(DoodleStyle.ink), style: .doodleThin)

        let noseTop = CGPoint(x: face.midX, y: face.minY + face.height * 0.47)
        let noseLeft = CGPoint(x: face.midX - face.width * 0.16, y: face.minY + face.height * 0.63)
        let noseRight = CGPoint(x: face.midX + face.width * 0.16, y: face.minY + face.height * 0.63)
        var nose = Path()
        nose.move(to: noseTop)
        nose.addLine(to: noseLeft)
        nose.addQuadCurve(to: noseRight, control: CGPoint(x: face.midX, y: face.minY + face.height * (0.67 + expression * 0.015)))
        nose.closeSubpath()
        context.stroke(nose, with: .color(DoodleStyle.ink), style: StrokeStyle(lineWidth: DoodleStyle.strokeBold + 0.2, lineCap: .round, lineJoin: .round))

        let leftNostril = CGRect(x: noseLeft.x + face.width * 0.045, y: noseLeft.y - face.height * 0.035, width: face.width * 0.075, height: face.height * 0.033)
        let rightNostril = CGRect(x: noseRight.x - face.width * 0.115, y: noseRight.y - face.height * 0.034, width: face.width * 0.076, height: face.height * 0.034)
        context.fill(Rough.ellipse(in: leftNostril, wobble: 1.0, seed: 111), with: .color(DoodleStyle.ink))
        context.fill(Rough.ellipse(in: rightNostril, wobble: 1.0, seed: 112), with: .color(DoodleStyle.ink))

        let nostrilCenter = CGPoint(x: rightNostril.midX, y: rightNostril.midY)
        let defaultR: CGFloat = 4 + expression * 6
        let spin = time * (2.2 + Double(expression) * 3.2) + axis * 5
        let defaultTip = CGPoint(x: nostrilCenter.x + CGFloat(cos(spin)) * defaultR,
                                 y: nostrilCenter.y + CGFloat(sin(spin)) * defaultR * 0.45)
        let tipCenter = clamped(fingerPoint ?? defaultTip,
                                to: nostrilCenter,
                                radiusX: rightNostril.width * 0.34,
                                radiusY: rightNostril.height * 0.36)

        let baseX = face.midX + face.width * 0.18
        let baseY = H * 0.98
        let fingerW: CGFloat = max(18, min(W, H) * 0.075)
        var trunk = Path()
        trunk.move(to: CGPoint(x: baseX, y: baseY))
        trunk.addLine(to: tipCenter)
        context.stroke(trunk, with: .color(DoodleStyle.ink), style: StrokeStyle(lineWidth: fingerW + 3, lineCap: .round, lineJoin: .round))
        context.stroke(trunk, with: .color(DoodleStyle.paper), style: StrokeStyle(lineWidth: fingerW, lineCap: .round, lineJoin: .round))

        let nailY = tipCenter.y + fingerW * 0.35
        context.stroke(Rough.arc(from: CGPoint(x: tipCenter.x - fingerW * 0.25, y: nailY),
                                 to: CGPoint(x: tipCenter.x + fingerW * 0.25, y: nailY),
                                 bulge: 4, seed: 211),
                       with: .color(DoodleStyle.ink.opacity(0.58)), style: .doodleThin)
        context.fill(Rough.ellipse(in: rightNostril, wobble: 1.0, seed: 112), with: .color(DoodleStyle.ink))
        context.fill(Rough.ellipse(in: CGRect(x: tipCenter.x - fingerW * 0.18, y: tipCenter.y - fingerW * 0.10, width: fingerW * 0.36, height: fingerW * 0.22), wobble: 0.5, seed: 210),
                     with: .color(DoodleStyle.paper.opacity(0.96)))

        let boogerSize = 3 + expression * 7
        if progress > 0.02 || isCompleting {
            let boogerRect = CGRect(x: tipCenter.x - boogerSize / 2, y: tipCenter.y - boogerSize / 2, width: boogerSize, height: boogerSize)
            context.fill(Rough.ellipse(in: boogerRect, wobble: 0.8, seed: 121), with: .color(DoodleStyle.sunshine.opacity(0.85)))
            context.stroke(Rough.ellipse(in: boogerRect, wobble: 0.8, seed: 121), with: .color(DoodleStyle.ink), style: .doodleThin)
        }

        let mouthY = face.minY + face.height * (0.82 + expression * 0.02)
        let mouthW = face.width * (0.25 + expression * 0.12)
        let mouthBulge = 8 + expression * 20
        context.stroke(Rough.arc(from: CGPoint(x: face.midX - mouthW, y: mouthY),
                                 to: CGPoint(x: face.midX + mouthW, y: mouthY - expression * 6),
                                 bulge: mouthBulge, seed: 131),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        if expression > 0.65 || isCompleting {
            for i in 0..<3 {
                let x = face.midX + CGFloat(i - 1) * face.width * 0.18
                context.stroke(Rough.arc(from: CGPoint(x: x - 8, y: mouthY + 18 + CGFloat(i % 2) * 4),
                                         to: CGPoint(x: x + 8, y: mouthY + 18 + CGFloat(i % 2) * 4),
                                         bulge: 4, seed: 151 &+ i),
                               with: .color(DoodleStyle.inkFaint), style: .doodleThin)
            }
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
