import SwiftUI

/// All six toys and everything that varies between them.
enum PlayMode: String, CaseIterable, Identifiable {
    case nosePick
    case navelPoke
    case earLobe
    case fingerNibble
    case bubbleWrap
    case penSpin

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .nosePick:     "play.nose.title"
        case .navelPoke:    "play.navel.title"
        case .earLobe:      "play.ear.title"
        case .fingerNibble: "play.finger.title"
        case .bubbleWrap:   "play.bubble.title"
        case .penSpin:      "play.pen.title"
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .nosePick:     "play.nose.subtitle"
        case .navelPoke:    "play.navel.subtitle"
        case .earLobe:      "play.ear.subtitle"
        case .fingerNibble: "play.finger.subtitle"
        case .bubbleWrap:   "play.bubble.subtitle"
        case .penSpin:      "play.pen.subtitle"
        }
    }

    var gesture: GestureKind {
        switch self {
        case .nosePick, .navelPoke: .rotation
        case .earLobe:              .verticalSlide
        case .fingerNibble:         .horizontalSlide
        case .bubbleWrap:           .tap
        case .penSpin:              .continuousMotion
        }
    }

    var gestureHintKey: LocalizedStringKey {
        switch gesture {
        case .rotation:         "hint.rotation"
        case .verticalSlide:    "hint.vertical"
        case .horizontalSlide:  "hint.horizontal"
        case .tap:              "hint.tap"
        case .continuousMotion: "hint.continuous"
        }
    }

    /// One tiny accent color per toy so they feel distinct without breaking the paper look.
    var accent: Color {
        switch self {
        case .nosePick:     DoodleStyle.blush
        case .navelPoke:    DoodleStyle.sunshine
        case .earLobe:      DoodleStyle.blush
        case .fingerNibble: DoodleStyle.sunshine
        case .bubbleWrap:   DoodleStyle.sky
        case .penSpin:      DoodleStyle.mint
        }
    }

    /// The completion phrase (randomized for some modes) is resolved on-demand so localization stays live.
    func completionCopy() -> String {
        switch self {
        case .nosePick:     String(localized: "completion.pop")
        case .navelPoke:    Bool.random() ? String(localized: "completion.clean") : String(localized: "completion.comfy")
        case .earLobe:      String(localized: "completion.comfy")
        case .fingerNibble: [String(localized: "completion.seed_shell"),
                             String(localized: "completion.paper_ball"),
                             String(localized: "completion.candy_wrapper")].randomElement() ?? String(localized: "completion.paper_ball")
        case .bubbleWrap:   String(localized: "completion.snap")
        case .penSpin:      String(localized: "completion.pretty")
        }
    }
}
