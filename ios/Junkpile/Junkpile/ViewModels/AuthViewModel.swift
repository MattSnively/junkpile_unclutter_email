import Foundation
import SwiftUI
import AuthenticationServices

/// AuthViewModel manages authentication state and coordinates with GoogleAuthService.
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

    // MARK: - Private Properties

    /// Google auth service for OAuth operations
    private let authService: GoogleAuthService

    /// Keychain service for credential storage
    private let keychain: KeychainService

    // MARK: - Initialization

    /// Creates a new AuthViewModel.
    /// - Parameter authService: Optional auth service for dependency injection (testing)
    init(authService: GoogleAuthService = .shared) {
        self.authService = authService
        self.keychain = KeychainService.shared

        // Check for existing credentials on init
        checkExistingCredentials()
    }

    // MARK: - Public Methods

    /// Initiates the Google sign-in flow.
    /// - Parameter window: The window to present the auth sheet from
    func signIn(from window: UIWindow?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            // Get presentation anchor
            guard let anchor = window else {
                errorMessage = "Unable to present sign in"
                return
            }

            // Perform sign in
            let success = try await authService.signIn(presentationAnchor: anchor)

            if success {
                // Update state with stored credentials
                updateUserInfo()
                authState = .authenticated
            }

        } catch let error as GoogleAuthError {
            // Handle specific auth errors
            switch error {
            case .userCancelled:
                // User cancelled, don't show error
                break
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }

    /// Signs the user out.
    func signOut() async {
        isLoading = true

        defer {
            isLoading = false
        }

        await authService.signOut()

        // Clear local state
        authState = .unauthenticated
        userEmail = nil
        userName = nil
        errorMessage = nil
    }

    /// Validates stored credentials and refreshes token if needed.
    /// Called on app launch to verify session validity.
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

        do {
            let isValid = try await authService.validateStoredCredentials()

            if isValid {
                updateUserInfo()
                authState = .authenticated
            } else {
                // Credentials explicitly invalid — sign out
                await signOut()
            }
        } catch {
            // Validation failed (likely network error) — don't auto-sign out.
            // User might just be offline. If we have stored credentials,
            // assume authenticated and let the next API call handle refresh.
            print("Session validation failed: \(error)")

            if keychain.hasStoredCredentials() {
                updateUserInfo()
                authState = .authenticated
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
