import SwiftUI

/// Deterministic pseudo-random helpers used to give every stroke a subtle hand-drawn wobble.
/// Same seed + index → same jitter, so the doodle is stable across renders but never feels mechanical.
enum Rough {
    /// Value in [-1, 1] driven by a hash of `seed` + `index`.
    static func noise(_ seed: Int, _ index: Int) -> CGFloat {
        let v = sin(Double(seed &* 12) + Double(index) * 78.233 + Double(seed &* 7)) * 43758.5453
        return CGFloat(v - floor(v)) * 2 - 1
    }

    /// Perturbs a point by up to `amp` in both axes.
    static func perturb(_ point: CGPoint, seed: Int, index: Int, amp: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x + noise(seed, index) * amp,
            y: point.y + noise(seed, index &+ 731) * amp
        )
    }

    /// Draws a wobbly line between two points using `steps` mid-points that shake sideways.
    static func line(from a: CGPoint, to b: CGPoint, steps: Int = 6, amp: CGFloat = 1.2, seed: Int = 0) -> Path {
        var path = Path()
        path.move(to: a)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let base = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let dx = b.x - a.x
            let dy = b.y - a.y
            let len = max(0.001, sqrt(dx * dx + dy * dy))
            let nx = -dy / len
            let ny = dx / len
            let shake = noise(seed, i) * amp
            path.addLine(to: CGPoint(x: base.x + nx * shake, y: base.y + ny * shake))
        }
        return path
    }

    /// Wobbly ellipse. `wobble` controls radial jitter, `points` controls smoothness.
    static func ellipse(in rect: CGRect, wobble: CGFloat = 1.6, points: Int = 40, seed: Int = 0) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        for i in 0...points {
            let angle = CGFloat(i) / CGFloat(points) * .pi * 2
            let jitter = noise(seed, i) * wobble
            let x = cx + cos(angle) * (rx + jitter)
            let y = cy + sin(angle) * (ry + jitter)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    /// Wobbly rounded rect. Perturbs each straight edge with sideways noise.
    static func roundedRect(_ rect: CGRect, corner: CGFloat, wobble: CGFloat = 1.4, seed: Int = 0) -> Path {
        var path = Path()
        let r = corner
        let steps = 4
        // top edge
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: rect.minX + r + (rect.width - r * 2) * t, y: rect.minY + noise(seed, i) * wobble)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: rect.maxX + noise(seed, i + 20) * wobble, y: rect.minY + r + (rect.height - r * 2) * t)
            path.addLine(to: p)
        }
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: rect.maxX - r - (rect.width - r * 2) * t, y: rect.maxY + noise(seed, i + 40) * wobble)
            path.addLine(to: p)
        }
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: rect.minX + noise(seed, i + 60) * wobble, y: rect.maxY - r - (rect.height - r * 2) * t)
            path.addLine(to: p)
        }
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }

    /// Bulge helper used by mouth/finger/ear – a curve from a→b through a control point offset by `bulge`.
    static func arc(from a: CGPoint, to b: CGPoint, bulge: CGFloat, seed: Int = 0) -> Path {
        var path = Path()
        path.move(to: a)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(0.001, sqrt(dx * dx + dy * dy))
        let nx = -dy / len
        let ny = dx / len
        let control = CGPoint(x: mid.x + nx * bulge + noise(seed, 3) * 1.5,
                              y: mid.y + ny * bulge + noise(seed, 7) * 1.5)
        path.addQuadCurve(to: b, control: control)
        return path
    }
}
