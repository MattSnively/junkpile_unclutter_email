import SwiftUI

/// GoogleSignInView presents the Google sign-in button and handles the OAuth flow.
/// Displayed as a sheet from the onboarding flow.
struct GoogleSignInView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                headerSection

                // Sign-in button
                signInButton

                // Privacy note
                privacyNote

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
            .alert("Sign In Error", isPresented: showingError) {
                Button("OK") {
                    authViewModel.clearError()
                }
            } message: {
                Text(authViewModel.errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
                // Dismiss when authenticated
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Components

    /// Header with icon and title
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Gmail icon
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundColor(.black)

            Text("Connect Your Gmail")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            Text("Sign in with Google to start cleaning your inbox")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    /// Google sign-in button
    private var signInButton: some View {
        Button {
            Task {
                await authViewModel.signIn(from: authViewModel.keyWindow)
            }
        } label: {
            HStack(spacing: 12) {
                // Google "G" logo placeholder (use actual asset in production)
                Image(systemName: "g.circle.fill")
                    .font(.title2)

                Text(authViewModel.isLoading ? "Signing in..." : "Sign in with Google")
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .disabled(authViewModel.isLoading)
        .opacity(authViewModel.isLoading ? 0.6 : 1.0)
    }

    /// Privacy and permissions note
    private var privacyNote: some View {
        VStack(spacing: 12) {
            Text("What we access:")
                .font(.subheadline.bold())
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 8) {
                permissionRow(icon: "envelope", text: "Read email metadata")
                permissionRow(icon: "eye.slash", text: "Mark emails as read")
            }

            Text("We never store your email content or share your data.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    /// Permission row with icon and text
    private func permissionRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.black)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    /// Binding for showing error alert
    private var showingError: Binding<Bool> {
        Binding(
            get: { authViewModel.errorMessage != nil },
            set: { if !$0 { authViewModel.clearError() } }
        )
    }
}

// MARK: - Permissions View

/// Standalone permissions view that can be shown after initial sign-in if needed
struct PermissionsView: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Permissions Granted")
                        .font(.title.bold())

                    Text("Junkpile can now help you manage your email subscriptions.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Continue button
                Button {
                    dismiss()
                } label: {
                    Text("Start Cleaning")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Previews

#Preview("Sign In View") {
    GoogleSignInView()
        .environmentObject(AuthViewModel())
}

#Preview("Sign In View - Loading") {
    let authVM = AuthViewModel()
    authVM.isLoading = true

    return GoogleSignInView()
        .environmentObject(authVM)
}

#Preview("Permissions View") {
    PermissionsView()
}
