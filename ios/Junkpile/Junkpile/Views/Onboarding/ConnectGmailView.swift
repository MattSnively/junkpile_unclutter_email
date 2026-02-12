import SwiftUI

/// ConnectGmailView is the "step 2" interstitial for Apple Sign-In users.
/// Shown after Apple authentication succeeds, prompting the user to connect
/// their Gmail account for inbox access (the app's core functionality).
///
/// Users can either:
/// - "Connect Gmail" → triggers Google OAuth for Gmail-only access
/// - "Skip for Now" → enters the app without Gmail (Swipe tab shows a connect prompt)
///
/// This view is also accessible from Settings for users who skipped.
struct ConnectGmailView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header illustration and text
            headerSection

            // Permission explanation
            permissionSection

            Spacer()

            // Action buttons
            actionButtons

            Spacer()
                .frame(height: 20)
        }
        .padding(.horizontal, 24)
        .background(Theme.cardBackground.ignoresSafeArea())
        .alert("Connection Error", isPresented: showingError) {
            Button("OK") {
                authViewModel.clearError()
            }
        } message: {
            Text(authViewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Components

    /// Header with icon and explanation
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Gmail envelope icon
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundColor(.primary)

            Text("Connect Your Gmail")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("Junkpile needs access to your Gmail to find emails with unsubscribe options and help you clean your inbox.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Explains what permissions are requested and why
    private var permissionSection: some View {
        VStack(spacing: 12) {
            Text("What we access:")
                .font(.subheadline.bold())
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                permissionRow(icon: "envelope", text: "Read email metadata (sender, subject)")
                permissionRow(icon: "eye.slash", text: "Mark emails as read")
            }

            Text("We never read your email content, access attachments, or share your data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(16)
        .background(Theme.subtleFill)
        .cornerRadius(12)
    }

    /// Permission row with icon and text
    private func permissionRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    /// Connect and Skip buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary: Connect Gmail
            Button {
                Task {
                    await authViewModel.connectGmail(from: authViewModel.keyWindow)
                }
            } label: {
                HStack(spacing: 8) {
                    Image("GoogleG")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text(authViewModel.isLoading ? "Connecting..." : "Connect Gmail")
                        .font(.headline)
                }
                .foregroundColor(Theme.solidFillForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.solidFill)
                .cornerRadius(12)
            }
            .disabled(authViewModel.isLoading)
            .opacity(authViewModel.isLoading ? 0.6 : 1.0)
            .accessibilityLabel(authViewModel.isLoading ? "Connecting Gmail" : "Connect Gmail")
            .accessibilityHint("Opens Google sign-in to connect your Gmail account")

            // Secondary: Skip for now
            Button {
                authViewModel.skipGmailConnection()
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .disabled(authViewModel.isLoading)
            .accessibilityLabel("Skip Gmail connection")
            .accessibilityHint("Enter the app without connecting Gmail. You can connect later in Settings.")
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

// MARK: - Previews

#Preview("Connect Gmail View") {
    ConnectGmailView()
        .environmentObject(AuthViewModel())
}

#Preview("Connect Gmail View - Dark") {
    ConnectGmailView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
