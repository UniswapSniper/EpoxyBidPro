import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var currentPage = 0
    @State private var appeared = false

    private let features: [OnboardingFeature] = [
        OnboardingFeature(
            icon: "ruler.fill",
            color: Color.indigo,
            title: "Measure in Seconds",
            body: "LiDAR scanning turns your iPhone into a precision floor-measurement tool. Capture sq footage instantly — no tape measure needed."
        ),
        OnboardingFeature(
            icon: "doc.text.fill",
            color: EBPColor.primary,
            title: "Beautiful Proposals",
            body: "Generate professional, branded bid proposals from your scan data in one tap. Send by email or SMS and collect e-signatures on-device."
        ),
        OnboardingFeature(
            icon: "chart.line.uptrend.xyaxis",
            color: EBPColor.success,
            title: "Grow Your Revenue",
            body: "Real-time analytics, CRM pipeline tracking, and AI-powered pricing insights help you win more jobs and maximise margins."
        ),
    ]

    var body: some View {
        ZStack {
            // ── Background gradient ────────────────────────────────────────
            EBPColor.onboardingGradient
                .ignoresSafeArea()

            // ── Decorative circles ─────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 380)
                    .offset(x: 140, y: -180)
                Circle()
                    .fill(.white.opacity(0.03))
                    .frame(width: 280)
                    .offset(x: -130, y: 200)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Logo / Wordmark ────────────────────────────────────────
                Spacer(minLength: EBPSpacing.xxxl)

                VStack(spacing: EBPSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(EBPAnimation.bouncy.delay(0.1), value: appeared)

                    Text("EpoxyBidPro")
                        .font(EBPFont.hero)
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)
                        .animation(EBPAnimation.smooth.delay(0.2), value: appeared)
                }

                Spacer(minLength: EBPSpacing.lg)

                // ── Feature pager ──────────────────────────────────────────
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { i in
                        featureCard(features[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)

                // Dots
                HStack(spacing: 6) {
                    ForEach(0..<features.count, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(currentPage == i ? 0.90 : 0.30))
                            .frame(width: currentPage == i ? 20 : 6, height: 6)
                            .animation(EBPAnimation.snappy, value: currentPage)
                    }
                }
                .padding(.top, EBPSpacing.md)

                Spacer(minLength: EBPSpacing.xl)

                // ── CTA ────────────────────────────────────────────────────
                VStack(spacing: EBPSpacing.md) {

                    // Real Sign in with Apple button
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authManager.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))

                    // Error message
                    if let error = authManager.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Loading
                    if authManager.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.40))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EBPSpacing.xl)
                }
                .padding(.horizontal, EBPSpacing.md)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(EBPAnimation.smooth.delay(0.5), value: appeared)

                Spacer(minLength: EBPSpacing.xl)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Feature Card

    private func featureCard(_ feature: OnboardingFeature) -> some View {
        VStack(spacing: EBPSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .fill(feature.color.opacity(0.20))
                    .frame(width: 72, height: 72)
                Image(systemName: feature.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(feature.color.opacity(0.8))
            }

            VStack(spacing: EBPSpacing.sm) {
                Text(feature.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(feature.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, EBPSpacing.xl)
    }
}

// ─── Model ────────────────────────────────────────────────────────────────────

private struct OnboardingFeature {
    let icon: String
    let color: Color
    let title: String
    let body: String
}


