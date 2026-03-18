import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                OnboardingView()
            } else if !authManager.hasCompletedBusinessSetup {
                BusinessSetupView()
            } else {
                MainTabView()
            }
        }
        .animation(EBPAnimation.smooth, value: authManager.isAuthenticated)
        .animation(EBPAnimation.smooth, value: authManager.hasCompletedBusinessSetup)
    }
}
