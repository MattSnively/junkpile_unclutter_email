import Foundation

/// Extension providing locale-aware number formatting for display in stat views.
/// Uses NumberFormatter with `.decimal` style so thousands separators respect
/// the device locale (e.g., English "1,234", German "1.234", French "1 234").
extension Int {

    /// Returns a locale-formatted string representation of the integer.
    /// Uses the device's current locale for thousands separators.
    /// Falls back to raw string interpolation if formatting fails.
    var localized: String {
        return NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }
}
