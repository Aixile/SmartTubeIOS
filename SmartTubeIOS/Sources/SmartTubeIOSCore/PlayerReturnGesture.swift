import Foundation

/// Navigation gestures never choose a different video. A deliberate rightward
/// swipe returns to browsing; native playback also supports downward dismissal.
public enum PlayerReturnGesture {
    public static let minimumDistance: CGFloat = 50

    public static func matches(horizontal: CGFloat, vertical: CGFloat, allowsSwipeDown: Bool = false) -> Bool {
        if horizontal > minimumDistance && horizontal > abs(vertical) { return true }
        return allowsSwipeDown && vertical > minimumDistance && vertical > abs(horizontal)
    }
}
