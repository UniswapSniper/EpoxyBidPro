import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if authStore.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}
