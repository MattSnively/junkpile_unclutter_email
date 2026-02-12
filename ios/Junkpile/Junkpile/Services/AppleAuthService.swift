import Foundation
import AuthenticationServices

/// AppleAuthService handles Sign in with Apple authentication.
/// Uses ASAuthorizationController to present the system Apple Sign-In UI.
///
/// Unlike GoogleAuthService (which provides both identity + Gmail access),
/// AppleAuthService ONLY handles identity. Gmail access requires a separate
/// Google OAuth step via GoogleAuthService.connectGmailOnly().
///
/// CRITICAL: Apple only provides the user's email and full name on the FIRST sign-in.
/// On subsequent sign-ins, these fields are nil. We must store them immediately
/// in Keychain on the first successful authentication.
@MainActor
final class AppleAuthService: NSObject, ObservableObject {

    // MARK: - Singleton

    /// Shared instance of the AppleAuthService
    static let shared = AppleAuthService()

    // MARK: - Published State

    /// Whether authentication is currently in progress
    @Published var isAuthenticating = false

    /// Error message from the last authentication attempt
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// API service for backend communication
    private let apiService = APIService.shared

    /// Keychain service for credential storage
    private let keychain = KeychainService.shared

    /// Continuation for bridging the delegate-based API to async/await
    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern.
    /// Registers for Apple credential revocation notifications so we can
    /// sign the user out if they revoke access from iOS Settings.
    private override init() {
        super.init()
        registerForRevocationNotification()
    }

    // MARK: - Authentication

    /// Performs Sign in with Apple and exchanges the identity token with our backend.
    ///
    /// Flow:
    /// 1. Present Apple Sign-In UI via ASAuthorizationController
    /// 2. User authenticates with Face ID / Touch ID / password
    /// 3. Apple returns an identity token (JWT) and optionally email/name
    /// 4. Send the identity token to our backend for verification
    /// 5. Backend returns a server session token for subsequent API calls
    /// 6. Store session token, user info, and Apple user ID in Keychain
    ///
    /// - Returns: True if authentication was successful
    func signIn() async throws -> Bool {
        // Prevent concurrent authentication attempts
        guard !isAuthenticating else {
            throw AppleAuthError.authenticationInProgress
        }

        isAuthenticating = true
        errorMessage = nil

        defer {
            isAuthenticating = false
        }

        do {
            // Step 1: Perform Apple Sign-In via ASAuthorizationController
            let authorization = try await performAppleSignIn()

            // Step 2: Extract credentials from the authorization result
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppleAuthError.invalidCredential
            }

            // Step 3: Extract the identity token (JWT) — required for backend verification
            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                throw AppleAuthError.identityTokenMissing
            }

            // Extract the authorization code (used for server-to-server verification)
            let authorizationCode: String?
            if let codeData = credential.authorizationCode {
                authorizationCode = String(data: codeData, encoding: .utf8)
            } else {
                authorizationCode = nil
            }

            // Extract email and name — ONLY available on first sign-in!
            let email = credential.email
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let nameToSend = fullName.isEmpty ? nil : fullName

            // Step 4: Exchange the identity token with our backend
            let response = try await apiService.exchangeAppleToken(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                email: email,
                fullName: nameToSend
            )

            guard response.success, let sessionToken = response.sessionToken else {
                let error = response.error ?? "Unknown error during Apple Sign-In verification"
                errorMessage = error
                throw AppleAuthError.tokenVerificationFailed(error)
            }

            // Step 5: Store everything in Keychain
            // Store the auth provider so we know this is an Apple user on relaunch
            keychain.setAuthProvider(.apple)

            // Store the Apple user identifier for credential state checks
            keychain.setAppleUserIdentifier(credential.user)

            // Store the server session token (used as Bearer token for API calls)
            keychain.setServerSessionToken(sessionToken)

            // Store user info — use response values (which come from our backend/store)
            // because Apple only provides email/name on first sign-in
            if let userEmail = response.email {
                keychain.setUserEmail(userEmail)
            }
            if let userName = response.name, !userName.isEmpty {
                keychain.setUserName(userName)
            }

            return true

        } catch let error as AppleAuthError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw AppleAuthError.networkError(error.localizedDescription)
        }
    }

    /// Performs the Apple Sign-In using ASAuthorizationController.
    /// Bridges the delegate-based API to async/await using a continuation.
    /// - Returns: The ASAuthorization result containing credentials
    private func performAppleSignIn() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            // Create the Apple ID authorization request
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            // Request email and full name scopes
            request.requestedScopes = [.email, .fullName]

            // Create and configure the authorization controller
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Sign Out

    /// Signs the user out, clearing all Apple-related credentials from Keychain.
    func signOut() async {
        // Clear all auth data (both Apple and any connected Gmail tokens)
        keychain.clearAllAuthData()

        // Notify the backend to clean up server-side state
        do {
            try await apiService.logout()
        } catch {
            // Log but don't fail — local sign-out is what matters
            print("Backend logout failed: \(error)")
        }
    }

    // MARK: - Credential Validation

    /// Checks if the Apple credential is still valid using ASAuthorizationAppleIDProvider.
    /// This is a local check that doesn't require network access.
    ///
    /// Users can revoke Sign in with Apple from iOS Settings → Apple ID →
    /// Password & Security → Apps Using Apple ID. If revoked, we must sign out.
    ///
    /// - Returns: True if the credential is still authorized
    func validateAppleCredential() async -> Bool {
        guard let appleUserId = keychain.getAppleUserIdentifier() else {
            return false
        }

        let provider = ASAuthorizationAppleIDProvider()

        return await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: appleUserId) { state, _ in
                switch state {
                case .authorized:
                    continuation.resume(returning: true)
                case .revoked, .notFound, .transferred:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Revocation Notification

    /// Registers for Apple credential revocation notifications.
    /// If the user revokes Sign in with Apple from iOS Settings,
    /// we'll be notified and can sign them out.
    private func registerForRevocationNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCredentialRevocation),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )
    }

    /// Handles the Apple credential revocation notification.
    /// Signs the user out when they revoke access from iOS Settings.
    @objc private func handleCredentialRevocation() {
        Task { @MainActor in
            print("Apple credential revoked — signing out")
            await signOut()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    /// Called when Apple Sign-In completes successfully.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            signInContinuation?.resume(returning: authorization)
            signInContinuation = nil
        }
    }

    /// Called when Apple Sign-In fails or is cancelled.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            // Check if the user cancelled the sign-in
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                signInContinuation?.resume(throwing: AppleAuthError.userCancelled)
            } else {
                signInContinuation?.resume(throwing: AppleAuthError.invalidCredential)
            }
            signInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {

    /// Provides the window to present the Apple Sign-In UI in.
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Error Types

/// Errors that can occur during Apple Sign-In authentication
enum AppleAuthError: Error, LocalizedError {
    case authenticationInProgress
    case userCancelled
    case invalidCredential
    case identityTokenMissing
    case tokenVerificationFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationInProgress:
            return "Authentication is already in progress"
        case .userCancelled:
            return "Sign in was cancelled"
        case .invalidCredential:
            return "Invalid Apple credential received"
        case .identityTokenMissing:
            return "Apple identity token was not provided"
        case .tokenVerificationFailed(let message):
            return "Failed to verify Apple Sign-In: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
