import Foundation

/// Identifies which authentication provider was used for the user's identity/login.
/// Stored in Keychain to determine the correct auth flow on app relaunch.
///
/// - `apple`: User signed in with Apple. Gmail access is a separate connection step.
/// - `google`: User signed in with Google. Identity and Gmail access are bundled together.
enum AuthProvider: String, Codable {
    case apple = "apple"
    case google = "google"
}
