import SwiftUI

/// Standard animation tokens. All durations < 0.3s, no bouncy effects.
enum MakLockAnimations {

    /// Overlay appears — quick ease out
    static let overlayAppear = Animation.easeOut(duration: 0.2)

    /// Overlay disappears — quick ease in
    static let overlayDisappear = Animation.easeIn(duration: 0.15)

    /// Button press feedback
    static let buttonPress = Animation.easeInOut(duration: 0.1)

    /// Error shake on wrong password
    static let errorShake = Animation.default

    /// Generic transition for UI elements
    static let standard = Animation.easeInOut(duration: 0.2)
}
