import SwiftUI

/// Central design tokens for the hand-drawn doodle look.
/// Palette: warm paper + charcoal ink + tiny accents.
enum DoodleStyle {
    static let paper = Color(red: 0.980, green: 0.965, blue: 0.933)
    static let paperShadow = Color(red: 0.932, green: 0.910, blue: 0.860)
    static let ink = Color(red: 0.102, green: 0.098, blue: 0.094)
    static let inkSoft = Color(red: 0.102, green: 0.098, blue: 0.094).opacity(0.55)
    static let inkFaint = Color(red: 0.102, green: 0.098, blue: 0.094).opacity(0.22)

    static let blush = Color(red: 0.956, green: 0.706, blue: 0.678)
    static let sunshine = Color(red: 0.972, green: 0.828, blue: 0.416)
    static let sky = Color(red: 0.658, green: 0.784, blue: 0.856)
    static let mint = Color(red: 0.706, green: 0.850, blue: 0.750)

    static let strokeThin: CGFloat = 1.6
    static let strokeBase: CGFloat = 2.1
    static let strokeBold: CGFloat = 2.8

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let quickSpring: Animation = .spring(response: 0.24, dampingFraction: 0.72, blendDuration: 0.05)
    static let softSpring: Animation = .spring(response: 0.36, dampingFraction: 0.80, blendDuration: 0.08)
    static let bouncySpring: Animation = .spring(response: 0.32, dampingFraction: 0.58, blendDuration: 0.06)
}

/// Common stroke style presets so every doodle keeps the same pencil feel.
extension StrokeStyle {
    static let doodleThin = StrokeStyle(lineWidth: DoodleStyle.strokeThin, lineCap: .round, lineJoin: .round)
    static let doodle = StrokeStyle(lineWidth: DoodleStyle.strokeBase, lineCap: .round, lineJoin: .round)
    static let doodleBold = StrokeStyle(lineWidth: DoodleStyle.strokeBold, lineCap: .round, lineJoin: .round)
}
