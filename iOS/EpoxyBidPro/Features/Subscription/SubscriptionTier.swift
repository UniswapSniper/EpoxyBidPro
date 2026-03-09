import SwiftUI

// ─── SubscriptionTier ─────────────────────────────────────────────────────────
// Represents the user's active subscription level.
// Feature gates are derived directly from the tier — no separate flags needed.

enum SubscriptionTier: Int, Comparable, Equatable {
    case none = 0   // No active subscription
    case solo = 1   // $49/mo
    case pro  = 2   // $79/mo
    case team = 3   // $149/mo

    // MARK: - Init from Product ID

    init?(productID: String) {
        if productID.contains(".solo.") { self = .solo }
        else if productID.contains(".pro.") { self = .pro }
        else if productID.contains(".team.") { self = .team }
        else { return nil }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .none: return "Free"
        case .solo: return "Solo"
        case .pro:  return "Pro"
        case .team: return "Team"
        }
    }

    var tagline: String {
        switch self {
        case .none: return "Limited access"
        case .solo: return "For independent contractors"
        case .pro:  return "For growing businesses"
        case .team: return "For multi-crew operations"
        }
    }

    var icon: String {
        switch self {
        case .none: return "person"
        case .solo: return "person.fill"
        case .pro:  return "star.fill"
        case .team: return "person.3.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return .secondary
        case .solo: return EBPColor.accent
        case .pro:  return EBPColor.gold
        case .team: return Color(red: 0.60, green: 0.40, blue: 1.00) // purple
        }
    }

    var monthlyPrice: String {
        switch self {
        case .none: return "Free"
        case .solo: return "$49"
        case .pro:  return "$79"
        case .team: return "$149"
        }
    }

    var annualPrice: String {
        switch self {
        case .none: return "Free"
        case .solo: return "$470"   // $49 × 12 × 0.80
        case .pro:  return "$758"   // $79 × 12 × 0.80
        case .team: return "$1,430" // $149 × 12 × 0.80
        }
    }

    var annualMonthlyEquivalent: String {
        switch self {
        case .none: return "Free"
        case .solo: return "$39/mo"
        case .pro:  return "$63/mo"
        case .team: return "$119/mo"
        }
    }

    /// Feature list shown in the paywall card (top items only, not "everything in X").
    var features: [SubscriptionFeature] {
        switch self {
        case .none:
            return []
        case .solo:
            return [
                .init(icon: "person.fill",              label: "1 user"),
                .init(icon: "doc.text.fill",            label: "Unlimited bids"),
                .init(icon: "lidar.sensor",             label: "LiDAR measurement"),
                .init(icon: "arrow.down.doc.fill",      label: "PDF export"),
                .init(icon: "person.2.fill",            label: "Basic CRM"),
            ]
        case .pro:
            return [
                .init(icon: "chevron.up.square.fill",   label: "Everything in Solo", isHighlight: true),
                .init(icon: "brain",                    label: "AI pricing insights"),
                .init(icon: "sparkles",                 label: "AI follow-up queue"),
                .init(icon: "paintpalette.fill",        label: "Custom branded PDFs"),
                .init(icon: "chart.bar.fill",           label: "Analytics dashboard"),
                .init(icon: "creditcard.fill",          label: "Payment processing"),
            ]
        case .team:
            return [
                .init(icon: "chevron.up.square.fill",   label: "Everything in Pro", isHighlight: true),
                .init(icon: "person.3.fill",            label: "Up to 10 users"),
                .init(icon: "key.fill",                 label: "Role permissions"),
                .init(icon: "calendar.badge.plus",      label: "Multi-crew scheduling"),
                .init(icon: "headphones.circle.fill",   label: "Priority support"),
            ]
        }
    }

    // MARK: - Feature Gates

    /// PDF export is included in all paid tiers.
    var hasPDFExport: Bool { self >= .solo }

    /// AI-powered pricing insights and suggestions.
    var hasAIInsights: Bool { self >= .pro }

    /// AI follow-up queue for CRM leads.
    var hasAIFollowUp: Bool { self >= .pro }

    /// Custom logo/branding on exported PDFs.
    var hasCustomBranding: Bool { self >= .pro }

    /// Analytics dashboard and revenue reporting.
    var hasAnalytics: Bool { self >= .pro }

    /// Stripe payment processing integration.
    var hasPaymentProcessing: Bool { self >= .pro }

    /// Multi-user seats and role-based permissions.
    var hasMultiUser: Bool { self >= .team }

    var maxUsers: Int {
        switch self {
        case .none, .solo, .pro: return 1
        case .team: return 10
        }
    }
}

// MARK: - SubscriptionFeature

struct SubscriptionFeature: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    var isHighlight: Bool = false
}
