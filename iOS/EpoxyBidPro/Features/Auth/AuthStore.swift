import Foundation
import SwiftUI

final class AuthStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding = false

    func signInWithApple() {
        isAuthenticated = true
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func signOut() {
        isAuthenticated = false
        hasCompletedOnboarding = false
    }
}
