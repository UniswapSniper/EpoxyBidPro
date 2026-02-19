import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                Text("Welcome to EpoxyBidPro")
                    .font(.largeTitle.bold())

                Text("Measure, bid, schedule, and invoice from one field-ready app.")
                    .foregroundStyle(.secondary)

                EBPCard {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        Text("Business Profile Setup")
                            .font(.headline)
                        Text("Company name, license, contact details, and first crew member.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                EBPButton(title: "Sign in with Apple", style: .primary) {
                    authStore.signInWithApple()
                }
            }
            .padding(EBPSpacing.md)
            .navigationTitle("Get Started")
        }
    }
}
