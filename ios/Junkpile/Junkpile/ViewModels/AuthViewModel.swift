import Foundation
import SwiftUI
import AuthenticationServices

/// AuthViewModel manages authentication state and coordinates with GoogleAuthService.
/// Provides a reactive interface for views to observe authentication status.
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published State

    /// Whether the user is currently authenticated
    @Published var isAuthenticated = false

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
                isAuthenticated = true
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
        isAuthenticated = false
        userEmail = nil
        userName = nil
        errorMessage = nil
    }

    /// Validates stored credentials and refreshes token if needed.
    /// Called on app launch to verify session validity.
    func validateSession() async {
        guard keychain.hasStoredCredentials() else {
            isAuthenticated = false
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
                isAuthenticated = true
            } else {
                // Credentials invalid, sign out
                await signOut()
            }
        } catch {
            // Validation failed, but don't auto-sign out
            // User might just be offline
            print("Session validation failed: \(error)")

            // If we have stored credentials, assume authenticated but mark for refresh
            if keychain.hasStoredCredentials() {
                updateUserInfo()
                isAuthenticated = true
            }
        }
    }

    /// Clears any displayed error message.
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Checks for existing stored credentials on app launch.
    private func checkExistingCredentials() {
        if keychain.hasStoredCredentials() {
            updateUserInfo()
            // Don't set isAuthenticated until validated
            // But start a validation task
            Task {
                await validateSession()
            }
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
