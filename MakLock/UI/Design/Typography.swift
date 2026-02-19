import SwiftUI

/// System font definitions for MakLock.
enum MakLockTypography {

    /// Large title — overlay "Safari is Locked"
    static let largeTitle = Font.system(size: 28, weight: .bold)

    /// Section headers
    static let title = Font.system(size: 20, weight: .semibold)

    /// App names in lists
    static let headline = Font.system(size: 15, weight: .semibold)

    /// Body text, descriptions
    static let body = Font.system(size: 13, weight: .regular)

    /// Button labels
    static let button = Font.system(size: 14, weight: .medium)

    /// Helper text, captions
    static let caption = Font.system(size: 11, weight: .regular)
}
