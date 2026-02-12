import Foundation
import SwiftUI
import AuthenticationServices

/// AuthViewModel manages authentication state and coordinates between
/// AppleAuthService (identity) and GoogleAuthService (Gmail access).
///
/// Supports two auth flows:
/// - **Google Sign-In**: Identity + Gmail access in one step (existing behavior).
/// - **Apple Sign-In**: Identity only → then prompt user to connect Gmail separately.
///
/// Provides a reactive interface for views to observe authentication status.
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Auth State

    /// Represents the three possible authentication states during app lifecycle.
    /// .unknown is the transient state during credential validation at launch —
    /// it prevents the onboarding flash by showing a splash screen instead.
    enum AuthState: Equatable {
        case unknown         // Checking stored credentials at launch
        case authenticated   // User is signed in and validated
        case unauthenticated // User needs to sign in
    }

    // MARK: - Published State

    /// Current authentication state. Starts as .unknown to prevent
    /// the onboarding view from flashing before validation completes.
    @Published var authState: AuthState = .unknown

    /// Convenience computed property for backward compatibility with views
    /// that check a simple boolean.
    var isAuthenticated: Bool {
        authState == .authenticated
    }

    /// Whether an authentication operation is in progress
    @Published var isLoading = false

    /// Error message from the last authentication attempt
    @Published var errorMessage: String?

    /// User's email address (if authenticated)
    @Published var userEmail: String?

    /// User's display name (if authenticated)
    @Published var userName: String?

    /// Which auth provider was used for sign-in (nil before first auth)
    @Published var authProvider: AuthProvider?

    /// Whether the user needs to connect Gmail (Apple Sign-In users only).
    /// When true, RootView shows ConnectGmailView instead of MainTabView.
    @Published var needsGmailConnection: Bool = false

    // MARK: - Computed Properties

    /// Whether Gmail is currently connected and available for API calls.
    /// Google users always have Gmail; Apple users may or may not.
    var isGmailConnected: Bool {
        return keychain.hasGmailCredentials()
    }

    // MARK: - Private Properties

    /// Google auth service for OAuth operations and Gmail access
    private let googleAuthService: GoogleAuthService

    /// Apple auth service for Sign in with Apple
    private let appleAuthService: AppleAuthService

    /// Keychain service for credential storage
    private let keychain: KeychainService

    // MARK: - Initialization

    /// Creates a new AuthViewModel.
    /// - Parameters:
    ///   - googleAuthService: Google auth service (injectable for testing)
    ///   - appleAuthService: Apple auth service (injectable for testing)
    init(
        googleAuthService: GoogleAuthService = .shared,
        appleAuthService: AppleAuthService = .shared
    ) {
        self.googleAuthService = googleAuthService
        self.appleAuthService = appleAuthService
        self.keychain = KeychainService.shared

        // Check for existing credentials on init
        checkExistingCredentials()
    }

    // MARK: - Google Sign-In

    /// Initiates the Google sign-in flow. Provides both identity and Gmail access
    /// in a single step. Sets the auth provider to .google and marks Gmail as connected.
    /// - Parameter window: The window to present the auth sheet from
    func signInWithGoogle(from window: UIWindow?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            guard let anchor = window else {
                errorMessage = "Unable to present sign in"
                return
            }

            let success = try await googleAuthService.signIn(presentationAnchor: anchor)

            if success {
                // Mark as Google auth provider — both identity and Gmail in one step
                keychain.setAuthProvider(.google)
                authProvider = .google
                needsGmailConnection = false

                updateUserInfo()
                authState = .authenticated
            }

        } catch let error as GoogleAuthError {
            switch error {
            case .userCancelled:
                break // User cancelled, don't show error
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }

    /// Backward-compatible wrapper for views that still call the old signIn(from:) method.
    /// Routes to signInWithGoogle for existing Google-only sign-in flows.
    func signIn(from window: UIWindow?) async {
        await signInWithGoogle(from: window)
    }

    // MARK: - Apple Sign-In

    /// Initiates Apple Sign-In. Provides identity only — Gmail must be connected
    /// separately via connectGmail(). Sets needsGmailConnection to true.
    func signInWithApple() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let success = try await appleAuthService.signIn()

            if success {
                // Mark as Apple auth provider — Gmail still needs to be connected
                authProvider = .apple
                needsGmailConnection = !keychain.hasGmailCredentials()

                updateUserInfo()
                authState = .authenticated
            }

        } catch let error as AppleAuthError {
            switch error {
            case .userCancelled:
                break // User cancelled, don't show error
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Gmail Connection (Two-Step Flow)

    /// Connects Gmail for an Apple Sign-In user (step 2 of the two-step flow).
    /// Opens the Google OAuth flow for Gmail-only access, then clears needsGmailConnection.
    /// - Parameter window: The window to present the auth sheet from
    func connectGmail(from window: UIWindow?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            guard let anchor = window else {
                errorMessage = "Unable to present Gmail connection"
                return
            }

            let success = try await googleAuthService.connectGmailOnly(presentationAnchor: anchor)

            if success {
                needsGmailConnection = false
            }

        } catch let error as GoogleAuthError {
            switch error {
            case .userCancelled:
                break // User cancelled, don't show error
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Gmail connection failed: \(error.localizedDescription)"
        }
    }

    /// Allows the user to skip Gmail connection and enter the app without it.
    /// The Swipe tab will show a "Connect Gmail" prompt instead of email cards.
    func skipGmailConnection() {
        needsGmailConnection = false
    }

    // MARK: - Sign Out

    /// Signs the user out, clearing all credentials for both providers.
    func signOut() async {
        isLoading = true

        defer {
            isLoading = false
        }

        // Sign out from the appropriate service based on provider
        if authProvider == .apple || keychain.getAuthProvider() == .apple {
            await appleAuthService.signOut()
        } else {
            await googleAuthService.signOut()
        }

        // Clear local state
        authState = .unauthenticated
        authProvider = nil
        needsGmailConnection = false
        userEmail = nil
        userName = nil
        errorMessage = nil
    }

    // MARK: - Session Validation

    /// Validates stored credentials and refreshes token if needed.
    /// Called on app launch to verify session validity.
    /// Handles both Apple and Google auth providers.
    ///
    /// On network errors, falls back to offline-first: if we have
    /// a stored token, assume authenticated rather than forcing re-auth.
    func validateSession() async {
        guard keychain.hasStoredCredentials() else {
            authState = .unauthenticated
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        // Determine the provider from stored credentials
        let storedProvider = keychain.getAuthProvider()
        authProvider = storedProvider

        if storedProvider == .apple {
            await validateAppleSession()
        } else {
            await validateGoogleSession()
        }
    }

    /// Validates an Apple Sign-In session.
    /// Checks Apple credential state (local check) and Gmail connection status.
    private func validateAppleSession() async {
        // Check if the Apple credential is still valid (can be revoked in Settings)
        let isAppleValid = await appleAuthService.validateAppleCredential()

        if !isAppleValid {
            // Apple credential was revoked — sign out
            await signOut()
            return
        }

        // Apple credential is valid — user is authenticated
        updateUserInfo()
        authState = .authenticated

        // Check if Gmail is connected for this Apple user
        needsGmailConnection = !keychain.hasGmailCredentials()
    }

    /// Validates a Google Sign-In session (existing behavior).
    private func validateGoogleSession() async {
        do {
            let isValid = try await googleAuthService.validateStoredCredentials()

            if isValid {
                updateUserInfo()
                authState = .authenticated
                needsGmailConnection = false
            } else {
                await signOut()
            }
        } catch {
            // Validation failed (likely network error) — don't auto-sign out.
            // User might just be offline.
            print("Session validation failed: \(error)")

            if keychain.hasStoredCredentials() {
                updateUserInfo()
                authState = .authenticated
                needsGmailConnection = false
            } else {
                authState = .unauthenticated
            }
        }
    }

    /// Clears any displayed error message.
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Checks for existing stored credentials on app launch.
    /// If credentials exist, keeps authState as .unknown (showing splash)
    /// while async validation runs. If no credentials, immediately
    /// sets .unauthenticated so onboarding shows without delay.
    private func checkExistingCredentials() {
        if keychain.hasStoredCredentials() {
            // Credentials exist — keep .unknown state (splash screen shows)
            // while we validate in the background
            updateUserInfo()
            authProvider = keychain.getAuthProvider()
            Task {
                // Safety timeout: if validation takes more than 3 seconds
                // and we have local credentials, assume authenticated.
                // The actual validation continues — if it fails, signOut() fires.
                let validationTask = Task {
                    await validateSession()
                }

                // Race against a 3-second timeout
                let timeoutTask = Task {
                    try await Task.sleep(for: .seconds(3))
                    // If still .unknown after 3 seconds, optimistically authenticate
                    if authState == .unknown {
                        updateUserInfo()
                        authState = .authenticated
                        // Set Gmail connection status based on stored state
                        if keychain.getAuthProvider() == .apple {
                            needsGmailConnection = !keychain.hasGmailCredentials()
                        }
                    }
                }

                // Wait for validation to finish, then cancel the timeout
                await validationTask.value
                timeoutTask.cancel()
            }
        } else {
            // No credentials at all — show onboarding immediately
            authState = .unauthenticated
        }
    }

    /// Updates user info from keychain storage.
    private func updateUserInfo() {
        userEmail = keychain.getUserEmail()
        userName = keychain.getUserName()
    }
}

// MARK: - Window Helper

extension AuthViewModel {

    /// Gets the key window from the current scene.
    /// - Returns: The key window, or nil if not available
    var keyWindow: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return scene.windows.first { $0.isKeyWindow }
    }
}

// MARK: - View Helpers

extension AuthViewModel {

    /// Formatted display name or email for UI display.
    var displayName: String {
        if let name = userName, !name.isEmpty {
            return name
        }
        if let email = userEmail {
            // Extract name from email (before @)
            return email.components(separatedBy: "@").first ?? email
        }
        return "User"
    }

    /// First initial of the user's name for avatar display.
    var userInitial: String {
        return String(displayName.prefix(1)).uppercased()
    }
}
