import SwiftUI
import SwiftData

/// Main entry point for the Junkpile iOS app.
/// Configures the app environment, persistence, and root navigation.
@main
struct JunkpileApp: App {

    // MARK: - State Objects

    /// Authentication view model, shared across the app
    @StateObject private var authViewModel = AuthViewModel()

    /// Gamification view model for tracking achievements and progress
    @StateObject private var gamificationViewModel = GamificationViewModel()

    // MARK: - Persistence

    /// SwiftData model container for persistence
    let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        // Initialize the persistence controller
        modelContainer = PersistenceController.shared.container
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(gamificationViewModel)
        }
        .modelContainer(modelContainer)
    }
}

/// RootView handles the top-level navigation between onboarding, Gmail connection, and main app.
/// Navigation flow:
/// - .unknown → SplashView (validating credentials)
/// - .unauthenticated → OnboardingView (sign in with Apple or Google)
/// - .authenticated + needsGmailConnection → ConnectGmailView (Apple users, step 2)
/// - .authenticated + Gmail connected → MainTabView (full app)
struct RootView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                // Credentials are being validated — show branded splash
                // to prevent the onboarding view from flashing briefly
                SplashView()
            case .authenticated:
                if authViewModel.needsGmailConnection {
                    // Apple Sign-In users who haven't connected Gmail yet
                    // see the Gmail connection interstitial before the main app
                    ConnectGmailView()
                } else {
                    // User is fully set up — show main app
                    MainTabView()
                }
            case .unauthenticated:
                // User needs to authenticate
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: authViewModel.authState)
    }
}

// MARK: - Tab Definition

/// Available tabs in the app. Defined at file scope so child views
/// (e.g. SessionCompleteView) can accept a Binding<Tab> to navigate
/// the user to other tabs after completing a session.
enum Tab: String, CaseIterable {
    case home = "Home"
    case swipe = "Swipe"
    case stats = "Stats"
    case settings = "Settings"

    /// SF Symbol icon for each tab
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .swipe: return "hand.draw.fill"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// MainTabView provides the primary navigation for authenticated users.
/// Contains tabs for Home, Swipe, Stats, and Settings.
struct MainTabView: View {

    // MARK: - State

    /// Currently selected tab — persisted via @SceneStorage so the tab
    /// survives backgrounding and scene recreation without resetting to .home
    @SceneStorage("selectedTab") private var selectedTab: Tab = .home

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab - Dashboard with stats and quick actions
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.iconName)
                }
                .tag(Tab.home)

            // Swipe tab - Main email swiping interface
            SwipeContainerView(selectedTab: $selectedTab)
                .tabItem {
                    Label(Tab.swipe.rawValue, systemImage: Tab.swipe.iconName)
                }
                .tag(Tab.swipe)

            // Stats tab - Statistics and history
            StatsView()
                .tabItem {
                    Label(Tab.stats.rawValue, systemImage: Tab.stats.iconName)
                }
                .tag(Tab.stats)

            // Settings tab - Account and preferences
            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.iconName)
                }
                .tag(Tab.settings)
        }
        .tint(.primary) // Use black/white for tab icons
    }
}

// MARK: - Previews

#Preview("Root View - Authenticated") {
    let authVM = AuthViewModel()
    authVM.authState = .authenticated

    return RootView()
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Root View - Not Authenticated") {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Main Tab View") {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}
