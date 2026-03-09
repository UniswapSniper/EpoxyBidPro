import SwiftUI
import StoreKit

// ─── PaywallView ──────────────────────────────────────────────────────────────
// Full-screen subscription paywall shown when a user hits a gated feature
// or taps "Upgrade" from settings.

struct PaywallView: View {

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: SubscriptionTier = .pro
    @State private var isAnnual = false
    @State private var isPurchasing = false

    // Tier presented in locked-feature context (pre-selects the right card)
    var requiredTier: SubscriptionTier = .solo

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.04),
                        Color(red: 0.05, green: 0.05, blue: 0.08),
                        Color(red: 0.00, green: 0.10, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        billingToggle
                        tierCards
                        ctaButton
                        footnotes
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .alert("Purchase Error", isPresented: .constant(subscriptionManager.purchaseError != nil)) {
                Button("OK") { subscriptionManager.purchaseError = nil }
            } message: {
                Text(subscriptionManager.purchaseError ?? "")
            }
        }
        .onAppear { selectedTier = max(requiredTier, .solo) }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: EBPSpacing.sm) {
            // Logo mark
            ZStack {
                Circle()
                    .fill(EBPColor.accent.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(EBPColor.accent)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EBPColor.gold)
                    .offset(x: 4, y: 4)
            }
            .padding(.top, EBPSpacing.xl)

            Text("EpoxyBidPro")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)

            Text("Run your epoxy business\nlike a pro.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, EBPSpacing.lg)
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingPill(label: "Monthly", isSelected: !isAnnual) {
                withAnimation(.easeInOut(duration: 0.2)) { isAnnual = false }
            }
            billingPill(label: "Annual", badge: "Save 20%", isSelected: isAnnual) {
                withAnimation(.easeInOut(duration: 0.2)) { isAnnual = true }
            }
        }
        .background(Color.white.opacity(0.08), in: Capsule())
        .padding(.horizontal, EBPSpacing.xl)
        .padding(.bottom, EBPSpacing.lg)
    }

    private func billingPill(label: String, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? EBPColor.primary : .white.opacity(0.6))
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? EBPColor.primary : EBPColor.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? EBPColor.gold : EBPColor.gold.opacity(0.25), in: Capsule())
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: EBPSpacing.sm) {
            ForEach([SubscriptionTier.solo, .pro, .team], id: \.rawValue) { tier in
                TierCard(
                    tier: tier,
                    isSelected: selectedTier == tier,
                    isAnnual: isAnnual,
                    storeProduct: isAnnual ? subscriptionManager.annualProduct(for: tier)
                                           : subscriptionManager.monthlyProduct(for: tier)
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTier = tier
                    }
                }
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.md)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        VStack(spacing: EBPSpacing.sm) {
            let product = isAnnual
                ? subscriptionManager.annualProduct(for: selectedTier)
                : subscriptionManager.monthlyProduct(for: selectedTier)

            Button {
                Task { await purchase(product) }
            } label: {
                Group {
                    if subscriptionManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.body.weight(.semibold))
                            Text(ctaLabel(product: product))
                                .font(.headline)
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedTier.accentColor, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowStrong()
            }
            .disabled(subscriptionManager.isLoading || product == nil)
            .padding(.horizontal, EBPSpacing.md)

            if isAnnual {
                Text("Billed \(selectedTier.annualPrice)/year · \(selectedTier.annualMonthlyEquivalent) equivalent")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func ctaLabel(product: Product?) -> String {
        guard let product else { return "Start \(selectedTier.displayName)" }
        return "Start \(selectedTier.displayName) · \(product.displayPrice)/\(isAnnual ? "yr" : "mo")"
    }

    private func purchase(_ product: Product?) async {
        guard let product else { return }
        await subscriptionManager.purchase(product)
    }

    // MARK: - Footnotes

    private var footnotes: some View {
        VStack(spacing: EBPSpacing.sm) {
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .underline()
            }

            Text("Cancel anytime. Subscriptions auto-renew unless cancelled\nat least 24 hours before the renewal date.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, EBPSpacing.xl)

            HStack(spacing: EBPSpacing.md) {
                Link("Privacy Policy", destination: URL(string: "https://www.epoxybidpro.com/privacy")!)
                Text("·").foregroundStyle(.white.opacity(0.3))
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, EBPSpacing.md)
    }
}

// MARK: - TierCard

private struct TierCard: View {

    let tier: SubscriptionTier
    let isSelected: Bool
    let isAnnual: Bool
    let storeProduct: Product?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                // Header row
                HStack(alignment: .top) {
                    // Icon + name
                    HStack(spacing: EBPSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(tier.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: tier.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(tier.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(tier.displayName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                if tier == .pro {
                                    Text("POPULAR")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(EBPColor.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(EBPColor.gold, in: Capsule())
                                }
                            }
                            Text(tier.tagline)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    // Price
                    VStack(alignment: .trailing, spacing: 1) {
                        if let product = storeProduct {
                            Text(product.displayPrice)
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)
                            Text(isAnnual ? "/yr" : "/mo")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            Text(isAnnual ? tier.annualPrice : tier.monthlyPrice)
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)
                            Text(isAnnual ? "/yr" : "/mo")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                Divider()
                    .background(.white.opacity(0.1))

                // Features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tier.features) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.isHighlight ? "checkmark.seal.fill" : "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(feature.isHighlight ? tier.accentColor : .white.opacity(0.5))
                            Text(feature.label)
                                .font(.footnote.weight(feature.isHighlight ? .semibold : .regular))
                                .foregroundStyle(feature.isHighlight ? .white : .white.opacity(0.75))
                        }
                    }
                }
            }
            .padding(EBPSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: EBPRadius.lg)
                    .fill(isSelected
                          ? tier.accentColor.opacity(0.12)
                          : Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: EBPRadius.lg)
                            .strokeBorder(
                                isSelected ? tier.accentColor : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
