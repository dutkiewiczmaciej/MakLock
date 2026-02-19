import SwiftUI

/// MakLock Gold color palette (colours.cafe #02)
enum MakLockColors {

    // MARK: - Brand

    /// Primary background — pure black
    static let background = Color(hex: 0x000000)

    /// Signature accent — MakLock Gold
    static let gold = Color(hex: 0xFFD213)

    /// Primary text — white
    static let textPrimary = Color.white

    /// Secondary text — muted gray
    static let textSecondary = Color(hex: 0x8E8E93)

    // MARK: - Surfaces

    /// Surface/card background — light gray
    static let surface = Color(hex: 0xF2F2F2)

    /// Card background for dark context
    static let cardDark = Color(hex: 0x2C2C2E)

    /// Separator line
    static let separator = Color(hex: 0x48484A)

    // MARK: - Semantic

    /// Secondary accent — light blue (info states)
    static let info = Color(hex: 0xB5E0F7)

    /// Error state — system red
    static let error = Color(hex: 0xFF3B30)

    /// Success state — system green
    static let success = Color(hex: 0x34C759)

    /// Locked state — system orange
    static let locked = Color(hex: 0xFF9500)
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
