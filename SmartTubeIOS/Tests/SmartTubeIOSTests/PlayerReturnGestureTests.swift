import Foundation
import Testing

@testable import SmartTubeIOSCore

@Suite("Player return gestures")
struct PlayerReturnGestureTests {
    @Test("A clear right swipe returns; a left swipe never changes or dismisses the video")
    func horizontalNavigation() {
        #expect(PlayerReturnGesture.matches(horizontal: 120, vertical: 12))
        #expect(!PlayerReturnGesture.matches(horizontal: -120, vertical: 12))
        #expect(!PlayerReturnGesture.matches(horizontal: -120, vertical: 12, allowsSwipeDown: true))
    }

    @Test("Small and diagonal movements do not accidentally return")
    func accidentalMovement() {
        #expect(!PlayerReturnGesture.matches(horizontal: 20, vertical: 0))
        #expect(!PlayerReturnGesture.matches(horizontal: PlayerReturnGesture.minimumDistance, vertical: 0))
        #expect(!PlayerReturnGesture.matches(horizontal: 80, vertical: 80))
        #expect(!PlayerReturnGesture.matches(horizontal: 80, vertical: -120))
    }

    @Test("Native swipe-down still returns; web vertical adjustments remain independent")
    func verticalNavigation() {
        #expect(PlayerReturnGesture.matches(horizontal: 12, vertical: 120, allowsSwipeDown: true))
        #expect(!PlayerReturnGesture.matches(horizontal: 12, vertical: 120))
        #expect(!PlayerReturnGesture.matches(horizontal: 12, vertical: -120, allowsSwipeDown: true))
    }
}
