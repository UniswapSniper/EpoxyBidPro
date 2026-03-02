import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if !authStore.isAuthenticated {
                OnboardingView()
            } else if !authStore.hasCompletedBusinessSetup {
                BusinessSetupView()
            } else {
                MainTabView()
            }
        }
        .animation(EBPAnimation.smooth, value: authStore.isAuthenticated)
        .animation(EBPAnimation.smooth, value: authStore.hasCompletedBusinessSetup)
    }
}
