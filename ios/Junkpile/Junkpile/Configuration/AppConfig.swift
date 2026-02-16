import Foundation

/// AppConfig provides centralized, environment-aware configuration for the app.
///
/// All sensitive credentials and environment-specific values live here,
/// making it easy to audit and update them in one place. Debug builds
/// point at the local development server; Release builds point at production.
///
/// IMPORTANT: Before submitting to the App Store, verify that `productionBaseURL`
/// is set to your real production server URL.
enum AppConfig {

    // MARK: - Google OAuth

    /// Google OAuth client ID from Google Cloud Console.
    /// Must match the iOS client configured at https://console.cloud.google.com/apis/credentials
    static let googleClientID = "758350179240-rlbdcla4brd4ffus0ln3nvfma5pn9j5r.apps.googleusercontent.com"

    /// Reversed Google client ID used as the OAuth callback URL scheme.
    /// This is the client ID with the segments reversed and periods replaced,
    /// following Google's standard pattern for iOS deep links.
    /// Must match one of the URL schemes in Info.plist.
    static let googleReversedClientID = "com.googleusercontent.apps.758350179240-rlbdcla4brd4ffus0ln3nvfma5pn9j5r"

    // MARK: - OAuth Redirect

    /// Custom URL scheme for the OAuth redirect callback.
    /// Must match the CFBundleURLSchemes entry in Info.plist.
    static let oauthRedirectScheme = "com.junkpile.app"

    /// Full OAuth redirect URI sent to Google during the authorization flow.
    static let oauthRedirectURI = "\(oauthRedirectScheme):/oauth2callback"

    // MARK: - API Base URL

    /// Production API base URL.
    /// TODO: Update this to your real production server URL before App Store submission.
    private static let productionBaseURL = "https://api.junkpile.app"

    /// Development API base URL (local server for simulator testing).
    private static let developmentBaseURL = "http://localhost:3000"

    /// The API base URL to use, determined by build configuration.
    /// - Debug builds: uses localhost for simulator development
    /// - Release builds: uses the production HTTPS endpoint
    ///
    /// Can be overridden at runtime via the `API_BASE_URL` environment variable
    /// (useful for testing against staging servers in debug builds).
    static var apiBaseURL: String {
        // Allow environment variable override (e.g., for staging/QA builds)
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }

        #if DEBUG
        return developmentBaseURL
        #else
        return productionBaseURL
        #endif
    }

    // MARK: - Apple Sign-In

    /// The app's bundle identifier, used as the audience when verifying Apple identity tokens.
    static let appleBundleID = "com.junkpile.app"
}
