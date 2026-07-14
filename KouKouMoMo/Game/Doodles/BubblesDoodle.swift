import SwiftUI

/// ⑤「压泡泡纸」— a full-screen grid of hand-drawn bubbles.
///   • One bubble at the center is the active target; taps squish it flat then a new one grows in place.
///   • Grid stays visible so users can loop endlessly, always tapping at the center.
struct BubblesDoodle: View {
    @ObservedObject var viewModel: ToyViewModel

    /// A stable "which bubble was popped last" hint so the visual jumps around subtly.
    @State private var popAge: Double = 1 // seconds since last pop
    @State private var popStamp: TimeInterval = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let sincePop = time - popStamp
            Canvas { ctx, size in
                BubblesDoodleRenderer.draw(context: ctx, size: size,
                                           tapTick: viewModel.tapTick,
                                           sincePop: sincePop,
                                           time: time)
            }
            .onChange(of: viewModel.tapTick) { _, _ in
                popStamp = time
            }
        }
    }
}

struct BubblesDoodleThumbnail: View {
    var body: some View {
        Canvas { ctx, size in
            BubblesDoodleRenderer.draw(context: ctx, size: size, tapTick: 0, sincePop: 1.5, time: 0)
        }
    }
}

private enum BubblesDoodleRenderer {
    static func draw(context: GraphicsContext, size: CGSize,
                     tapTick: Int, sincePop: TimeInterval, time: TimeInterval) {
        let W = size.width
        let H = size.height

        // Grid of bubbles filling the doodle rect
        let cols = 5
        let rows = 6
        let padding: CGFloat = 22
        let gridW = W - padding * 2
        let gridH = H - padding * 2
        let bubbleW = gridW / CGFloat(cols)
        let bubbleH = gridH / CGFloat(rows)
        let radius = min(bubbleW, bubbleH) * 0.38

        let centerCol = cols / 2
        let centerRow = rows / 2

        for row in 0..<rows {
            for col in 0..<cols {
                let cx = padding + bubbleW * (CGFloat(col) + 0.5)
                let cy = padding + bubbleH * (CGFloat(row) + 0.5)
                let seed = row * 100 + col
                let wobble: CGFloat = 0.9 + Rough.noise(seed, 1) * 0.4

                let isActive = (row == centerRow && col == centerCol)
                let scale: CGFloat
                let opacity: Double
                if isActive {
                    // Pop-and-regrow curve based on sincePop
                    let t = min(1.0, sincePop / 0.42)
                    if t < 0.35 {
                        // Squish flat then vanish
                        let s = 1 - CGFloat(t / 0.35)
                        scale = s
                        opacity = Double(s)
                    } else {
                        // Regrow with bounce
                        let g = (t - 0.35) / 0.65
                        scale = CGFloat(min(1.0, g)) * (1 + 0.15 * CGFloat(sin(g * .pi * 2)))
                        opacity = min(1.0, g * 1.4)
                    }
                } else {
                    // Idle bubbles: gentle breathing
                    let phase = sin(time * 1.4 + Double(seed) * 0.7)
                    scale = 1 + CGFloat(phase) * 0.03
                    opacity = 0.65 + phase * 0.10
                }

                let rW = bubbleW * 0.62 * scale
                let rH = bubbleH * 0.62 * scale
                let rect = CGRect(x: cx - rW / 2, y: cy - rH / 2, width: rW, height: rH)

                if scale > 0.05 {
                    context.stroke(Rough.ellipse(in: rect, wobble: wobble, points: 22, seed: 100 &+ seed),
                                   with: .color(DoodleStyle.ink.opacity(isActive ? 0.9 : 0.55 * opacity)),
                                   style: isActive ? .doodleBold : .doodleThin)
                    if isActive {
                        // Highlight inside
                        let inner = rect.insetBy(dx: rW * 0.18, dy: rH * 0.18)
                        context.fill(Rough.ellipse(in: inner, wobble: 0.6, seed: 400 &+ seed),
                                     with: .color(DoodleStyle.sky.opacity(0.35)))
                        // Sparkle dot
                        let dotRect = CGRect(x: rect.minX + rW * 0.22, y: rect.minY + rH * 0.22, width: 5, height: 5)
                        context.fill(Rough.ellipse(in: dotRect, wobble: 0.2, seed: 500 &+ seed),
                                     with: .color(DoodleStyle.paper))
                    }
                }

                // Pop lines right after a tap
                if isActive && sincePop < 0.30 {
                    let intensity = 1 - sincePop / 0.30
                    for i in 0..<6 {
                        let ang = CGFloat(i) * .pi / 3
                        let inner = CGPoint(x: cx + cos(ang) * (radius + 4),
                                            y: cy + sin(ang) * (radius + 4))
                        let outer = CGPoint(x: cx + cos(ang) * (radius + 14 + CGFloat(intensity) * 8),
                                            y: cy + sin(ang) * (radius + 14 + CGFloat(intensity) * 8))
                        context.stroke(Rough.line(from: inner, to: outer, steps: 2, amp: 0.4, seed: 610 &+ i),
                                       with: .color(DoodleStyle.ink.opacity(intensity)),
                                       style: .doodle)
                    }
                }
            }
        }
    }
}

#Preview {
    BubblesDoodle(viewModel: ToyViewModel(mode: .bubbleWrap))
        .frame(width: 320, height: 480).background(DoodleStyle.paper)
}
