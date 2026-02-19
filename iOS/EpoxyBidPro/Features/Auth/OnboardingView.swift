import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authStore: AuthStore

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
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(EBPAnimation.bouncy.delay(0.1), value: appeared)

                    Text("EpoxyBidPro")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)
                        .animation(EBPAnimation.smooth.delay(0.2), value: appeared)

                    Text("Measure. Bid. Win.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(1.5)
                        .opacity(appeared ? 1 : 0)
                        .animation(EBPAnimation.smooth.delay(0.3), value: appeared)
                }

                Spacer(minLength: EBPSpacing.xl)

                // ── Feature Pager ──────────────────────────────────────────
                TabView(selection: $currentPage) {
                    ForEach(features.indices, id: \.self) { i in
                        featureCard(features[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 260)
                .opacity(appeared ? 1 : 0)
                .animation(EBPAnimation.smooth.delay(0.4), value: appeared)

                // ── Page dots ──────────────────────────────────────────────
                HStack(spacing: EBPSpacing.sm) {
                    ForEach(features.indices, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(currentPage == i ? 0.9 : 0.30))
                            .frame(width: currentPage == i ? 20 : 6, height: 6)
                            .animation(EBPAnimation.snappy, value: currentPage)
                    }
                }
                .padding(.top, EBPSpacing.md)

                Spacer(minLength: EBPSpacing.xl)

                // ── CTA ────────────────────────────────────────────────────
                VStack(spacing: EBPSpacing.md) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        authStore.signInWithApple()
                    } label: {
                        HStack(spacing: EBPSpacing.sm) {
                            Image(systemName: "applelogo")
                                .font(.body.weight(.semibold))
                            Text("Sign in with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        authStore.signInWithApple() // same flow, just labelled differently
                    } label: {
                        Text("Continue with Email")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.80))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: EBPRadius.md)
                                    .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                            )
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
                    .foregroundStyle(feature.color.mix(with: .white, by: 0.3))
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

// ─── Color mix helper (iOS 17+, with fallback) ────────────────────────────────
private extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        // Simple approximation: blend toward white
        let opacity = 1.0 - amount * 0.5
        return self.opacity(opacity)
    }
}

