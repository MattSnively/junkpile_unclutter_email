import SwiftUI

/// Centralized semantic color definitions for dark mode support.
/// Most colors use built-in adaptive system colors. This enum provides
/// compile-time-safe constants for the ~10% of cases that don't map
/// directly to a single system color (e.g., inverted fills, custom
/// opacities that differ between light and dark).
enum Theme {

    // MARK: - Custom Adaptive Colors

    /// Solid fill for level badges, progress bars, and primary action buttons.
    /// Light: black. Dark: white.
    static let solidFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    })

    /// Foreground text/icons placed on top of solidFill backgrounds.
    /// Light: white. Dark: black.
    static let solidFillForeground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })

    /// Border color for card strokes and outlined buttons.
    /// Light: black. Dark: systemGray3 (softer edge in dark mode).
    static let cardBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGray3 : .black
    })

    /// Peak highlight in the shimmer gradient animation.
    /// Light: white @ 40%. Dark: white @ 15% (subtler on dark backgrounds).
    static let shimmerHighlight = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.15)
            : UIColor.white.withAlphaComponent(0.4)
    })

    /// Decorative circle behind hero card illustrations.
    /// Light: black @ 5%. Dark: white @ 8%.
    static let illustrationCircle = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.05)
    })

    /// Google brand border color — same in both modes per brand guidelines.
    static let googleBorder = Color(red: 0.455, green: 0.467, blue: 0.475)

    // MARK: - System Color Aliases (convenience wrappers)

    /// Card and section backgrounds — adapts automatically.
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    /// Page-level background — already used in some views via UIColor.systemGroupedBackground.
    static let pageBackground = Color(UIColor.systemGroupedBackground)

    /// Light fill for icon backgrounds and stat items.
    static let subtleFill = Color(UIColor.systemGray6)

    /// Slightly stronger fill for progress bar tracks.
    static let subtleFillStrong = Color(UIColor.systemGray5)

    /// Dividers, handle bars, and thin separators.
    static let separator = Color(UIColor.separator)

    // MARK: - Convenience Methods

    /// Adaptive shadow color that works in both light and dark mode.
    /// Uses sRGBLinear black (no color shift) so shadows remain visible
    /// on dark backgrounds without looking muddy.
    /// - Parameter opacity: The shadow opacity (0.0–1.0).
    /// - Returns: A color suitable for shadow modifiers.
    static func shadow(opacity: Double) -> Color {
        Color(.sRGBLinear, white: 0, opacity: opacity)
    }
}
