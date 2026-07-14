import Foundation

/// State machine used by every doodle. The transitions are strictly ordered:
/// idle → fingerDown → continuousGesture → progress → completionFeedback → reset → idle
enum ToyState: String {
    case idle
    case fingerDown
    case continuousGesture
    case progress
    case completionFeedback
    case reset
}
