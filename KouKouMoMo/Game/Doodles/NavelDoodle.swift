import SwiftUI

struct NavelDoodle: View {
    @ObservedObject var viewModel: ToyViewModel
    @State private var fingerPoint: CGPoint?
    @State private var lastDragPoint: CGPoint?
    @State private var lastDragTime: Date?
    @State private var lastTranslation: CGSize?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    NavelDoodleRenderer.draw(context: ctx, size: size,
                                             progress: viewModel.progress,
                                             axis: viewModel.axis,
                                             velocity: viewModel.velocity,
                                             time: time,
                                             fingerPoint: fingerPoint,
                                             isDragging: isDragging)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in handleDrag(value, size: proxy.size) }
                        .onEnded { _ in
                            lastDragPoint = nil
                            lastDragTime = nil
                            lastTranslation = nil
                            isDragging = false
                            withAnimation(.easeOut(duration: 0.3)) {
                                viewModel.progress = 0
                            }
                        }
                )
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value, size: CGSize) {
        isDragging = true
        let now = value.time
        defer {
            lastDragPoint = value.location
            lastDragTime = now
            lastTranslation = value.translation
        }
        guard let previous = lastDragPoint, let previousTime = lastDragTime else {
            fingerPoint = value.location
            return
        }
        let dt = max(0.001, now.timeIntervalSince(previousTime))
        let distance = hypot(value.location.x - previous.x, value.location.y - previous.y)
        let previousTranslation = lastTranslation ?? value.translation
        let translationDelta = hypot(value.translation.width - previousTranslation.width,
                                     value.translation.height - previousTranslation.height)
        if translationDelta > 0.7 {
            viewModel.progress = min(1.0, viewModel.progress + Double(translationDelta) / 800.0)
        }
        let speed = distance / dt
        fingerPoint = value.location
        guard distance > 0.7 else { return }
        let interval = max(0.028, 0.075 - min(1, Double(speed / 900)) * 0.035)
        HapticManager.shared.frictionTick(intensity: min(1, Double(speed / 850)), minimumInterval: interval)
    }
}

struct NavelDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            NavelDoodleRenderer.draw(context: ctx, size: size, progress: 0, axis: 0, velocity: 0, time: 0, fingerPoint: nil, isDragging: false)
        }
    }
}

private enum NavelDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     progress: Double, axis: Double, velocity: Double,
                     time: TimeInterval, fingerPoint: CGPoint?, isDragging: Bool) {
        let W = size.width
        let H = size.height
        let compression = 1 - CGFloat(progress) * 0.10
        let sink = CGFloat(progress) * 8
        let baseBellyRect = CGRect(x: W * 0.08, y: H * 0.20 + sink, width: W * 0.84, height: H * 0.70 * compression)
        var bellyRect = baseBellyRect
        if progress >= 0.99 && isDragging {
            bellyRect.origin.x += CGFloat(sin(time * 25)) * 2.2
            bellyRect.origin.y += CGFloat(cos(time * 21)) * 2.2
            bellyRect.size.width += CGFloat(sin(time * 18)) * 3.0
            bellyRect.size.height += CGFloat(cos(time * 20)) * 3.0
        }
        context.stroke(Rough.ellipse(in: bellyRect, wobble: 2.4, points: 46, seed: 210),
                       with: .color(DoodleStyle.ink), style: .doodleBold)

        // All non-shaking elements use baseBellyRect coordinates or static center
        let hlA = CGPoint(x: baseBellyRect.minX + baseBellyRect.width * 0.18, y: baseBellyRect.minY + baseBellyRect.height * 0.35)
        let hlB = CGPoint(x: baseBellyRect.minX + baseBellyRect.width * 0.32, y: baseBellyRect.minY + baseBellyRect.height * 0.18)
        context.stroke(Rough.arc(from: hlA, to: hlB, bulge: -6, seed: 211),
                       with: .color(DoodleStyle.inkFaint.opacity(0.35)), style: .doodle)
        let shA = CGPoint(x: baseBellyRect.maxX - baseBellyRect.width * 0.14, y: baseBellyRect.midY + baseBellyRect.height * 0.05)
        let shB = CGPoint(x: baseBellyRect.maxX - baseBellyRect.width * 0.32, y: baseBellyRect.maxY - baseBellyRect.height * 0.14)
        context.stroke(Rough.arc(from: shA, to: shB, bulge: 22, seed: 212),
                       with: .color(DoodleStyle.inkSoft.opacity(0.45)), style: .doodle)
        let sh2A = CGPoint(x: baseBellyRect.maxX - baseBellyRect.width * 0.08, y: baseBellyRect.midY - baseBellyRect.height * 0.03)
        let sh2B = CGPoint(x: baseBellyRect.maxX - baseBellyRect.width * 0.20, y: baseBellyRect.maxY - baseBellyRect.height * 0.06)
        context.stroke(Rough.arc(from: sh2A, to: sh2B, bulge: 14, seed: 213),
                       with: .color(DoodleStyle.inkSoft.opacity(0.3)), style: .doodleThin)

        var center = CGPoint(x: baseBellyRect.midX, y: baseBellyRect.midY + baseBellyRect.height * 0.04)
        if progress >= 0.99 && isDragging {
            center.x += CGFloat(cos(time * 23)) * 1.5
            center.y += CGFloat(sin(time * 26)) * 1.5
        }
        let navelW: CGFloat = 60
        let navelH: CGFloat = 44
        let rimRect = CGRect(x: center.x - navelW/2, y: center.y - navelH/2, width: navelW, height: navelH)
        context.stroke(Rough.ellipse(in: rimRect, wobble: 1.6, points: 36, seed: 214),
                       with: .color(DoodleStyle.ink), style: .doodleBold)
        let holeRect = rimRect.insetBy(dx: 4, dy: 3)
        context.fill(Rough.ellipse(in: holeRect, wobble: 1.4, points: 32, seed: 215),
                     with: .color(DoodleStyle.ink.opacity(0.15 + progress * 0.20)))

        var coreCtx = context
        coreCtx.translateBy(x: center.x, y: center.y + 1)
        coreCtx.rotate(by: .degrees(progress * 620 + sin(time * 2.4) * 8))
        var beanPath = Path()
        beanPath.move(to: CGPoint(x: 0, y: -14))
        beanPath.addCurve(to: CGPoint(x: 6, y: 0), control1: CGPoint(x: 6, y: -12), control2: CGPoint(x: 7, y: -6))
        beanPath.addCurve(to: CGPoint(x: 0, y: 14), control1: CGPoint(x: 5, y: 6), control2: CGPoint(x: 6, y: 12))
        beanPath.addCurve(to: CGPoint(x: -6, y: 0), control1: CGPoint(x: -6, y: 12), control2: CGPoint(x: -5, y: 6))
        beanPath.addCurve(to: CGPoint(x: 0, y: -14), control1: CGPoint(x: -7, y: -6), control2: CGPoint(x: -6, y: -12))
        coreCtx.fill(beanPath, with: .color(DoodleStyle.ink))

        for i in 0..<3 {
            let stretch = 1.0 + CGFloat(progress) * 0.18
            let angBase = -CGFloat.pi * 0.9 + CGFloat(i) * 0.35
            let r1: CGFloat = (navelW/2 + 8) * stretch
            let r2: CGFloat = (navelW/2 + 16) * stretch
            let a = CGPoint(x: center.x + cos(angBase) * r1, y: center.y + sin(angBase) * r1 * 0.72)
            let b = CGPoint(x: center.x + cos(angBase - 0.55) * r2, y: center.y + sin(angBase - 0.55) * r2 * 0.72)
            context.stroke(Rough.arc(from: a, to: b, bulge: 3, seed: 220 &+ i),
                           with: .color(DoodleStyle.inkSoft.opacity(0.5 + progress * 0.2)), style: .doodleThin)
        }
        for i in 0..<3 {
            let stretch = 1.0 + CGFloat(progress) * 0.18
            let angBase = -CGFloat.pi * 0.1 - CGFloat(i) * 0.35
            let r1: CGFloat = (navelW/2 + 8) * stretch
            let r2: CGFloat = (navelW/2 + 16) * stretch
            let a = CGPoint(x: center.x + cos(angBase) * r1, y: center.y + sin(angBase) * r1 * 0.72)
            let b = CGPoint(x: center.x + cos(angBase + 0.55) * r2, y: center.y + sin(angBase + 0.55) * r2 * 0.72)
            context.stroke(Rough.arc(from: a, to: b, bulge: -3, seed: 223 &+ i),
                           with: .color(DoodleStyle.inkSoft.opacity(0.5 + progress * 0.2)), style: .doodleThin)
        }

        let orbitR: CGFloat = navelW * 0.42
        let spin = time * 3.2 + axis * 6
        let defaultTip = CGPoint(x: center.x + cos(spin) * orbitR, y: center.y + sin(spin) * orbitR * 0.72)
        let tipCenter = clamped(fingerPoint ?? defaultTip,
                                to: center,
                                radiusX: navelW * 0.46,
                                radiusY: navelH * 0.42)

        let baseX = bellyRect.maxX - 30
        let baseY = H * 0.98
        let fingerW: CGFloat = 30
        var trunk = Path()
        let control = CGPoint(x: baseX - 20, y: (baseY + tipCenter.y) / 2 + 20)
        trunk.move(to: CGPoint(x: baseX, y: baseY))
        trunk.addQuadCurve(to: tipCenter, control: control)
        context.stroke(trunk, with: .color(DoodleStyle.ink), style: StrokeStyle(lineWidth: fingerW + 3, lineCap: .round, lineJoin: .round))
        context.stroke(trunk, with: .color(DoodleStyle.paper), style: StrokeStyle(lineWidth: fingerW, lineCap: .round, lineJoin: .round))
        let knuckleT: CGFloat = 0.55
        let kx = (1-knuckleT)*(1-knuckleT)*baseX + 2*(1-knuckleT)*knuckleT*control.x + knuckleT*knuckleT*tipCenter.x
        let ky = (1-knuckleT)*(1-knuckleT)*baseY + 2*(1-knuckleT)*knuckleT*control.y + knuckleT*knuckleT*tipCenter.y
        context.stroke(Rough.arc(from: CGPoint(x: kx - 10, y: ky), to: CGPoint(x: kx + 10, y: ky), bulge: 3, seed: 260),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)
        let nailRect = CGRect(x: tipCenter.x - 7, y: tipCenter.y - 4, width: 14, height: 8)
        context.stroke(Rough.arc(from: CGPoint(x: nailRect.minX, y: nailRect.midY), to: CGPoint(x: nailRect.maxX, y: nailRect.midY), bulge: -4, seed: 261),
                       with: .color(DoodleStyle.ink.opacity(0.55)), style: .doodleThin)
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
    NavelDoodle(viewModel: ToyViewModel(mode: .navelPoke))
        .frame(width: 320, height: 380).background(DoodleStyle.paper)
}
