import SwiftUI

// ─── SubscriptionGate ─────────────────────────────────────────────────────────
// Wraps any view with a paywall lock overlay when the user lacks the required tier.
//
// Usage:
//   SomeProView()
//       .subscriptionGated(.pro)
//
// Or inline with the GatedSection view:
//   GatedSection(requiredTier: .pro, label: "AI Insights") {
//       AIInsightsContent()
//   }

// MARK: - ViewModifier

struct SubscriptionGateModifier: ViewModifier {

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let requiredTier: SubscriptionTier

    func body(content: Content) -> some View {
        content
            .overlay {
                if !subscriptionManager.isEntitled(to: requiredTier) {
                    lockedOverlay
                }
            }
            .allowsHitTesting(subscriptionManager.isEntitled(to: requiredTier))
    }

    private var lockedOverlay: some View {
        ZStack {
            // Blur the content behind
            Rectangle()
                .fill(.ultraThinMaterial)

            VStack(spacing: EBPSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(requiredTier.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(requiredTier.accentColor)
                }

                Text("\(requiredTier.displayName) Feature")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Upgrade to \(requiredTier.displayName) to unlock this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    subscriptionManager.showPaywall = true
                } label: {
                    Text("Upgrade Now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, EBPSpacing.lg)
                        .padding(.vertical, 10)
                        .background(requiredTier.accentColor, in: Capsule())
                }
                .padding(.top, 4)
            }
            .padding(EBPSpacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.lg))
    }
}

// MARK: - View Extension

extension View {
    /// Applies a paywall gate overlay if the user's subscription is below the required tier.
    func subscriptionGated(_ tier: SubscriptionTier) -> some View {
        modifier(SubscriptionGateModifier(requiredTier: tier))
    }
}

// MARK: - GatedSection

/// A card-style section that shows a lock badge in the header and taps to upgrade
/// without completely obscuring content (useful for list rows or settings cells).
struct GatedSection<Content: View>: View {

    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let requiredTier: SubscriptionTier
    let label: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var isUnlocked: Bool { subscriptionManager.isEntitled(to: requiredTier) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if !isUnlocked {
                    tierBadge
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, EBPSpacing.sm)

            // Content (blurred + locked or fully visible)
            content()
                .subscriptionGated(requiredTier)
        }
    }

    private var tierBadge: some View {
        Button {
            subscriptionManager.showPaywall = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(requiredTier.displayName)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(requiredTier.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PaywallSheetPresenter

/// Attach to the root of any tab/view to handle showPaywall changes from SubscriptionManager.
struct PaywallSheetPresenter: ViewModifier {

    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $subscriptionManager.showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
    }
}

extension View {
    /// Attach to root views to enable paywall presentation from anywhere in the tree.
    func paywallSheetPresenter() -> some View {
        modifier(PaywallSheetPresenter())
    }
}
