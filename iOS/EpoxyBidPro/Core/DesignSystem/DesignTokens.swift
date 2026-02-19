import SwiftUI

// ─── EBPColor ─────────────────────────────────────────────────────────────────
// Centralised semantic colour tokens for EpoxyBidPro.
// All colours are dark-mode aware unless otherwise noted.

enum EBPColor {

    // ── Brand ──────────────────────────────────────────────────────────────────
    /// Royal-blue primary brand colour.
    static let primary      = Color(red: 0.05, green: 0.33, blue: 0.64)
    /// Midnight-slate secondary.
    static let secondary    = Color(red: 0.20, green: 0.24, blue: 0.30)
    /// Bright azure accent (highlights, links).
    static let accent       = Color(red: 0.10, green: 0.55, blue: 0.95)

    // ── Semantic ───────────────────────────────────────────────────────────────
    static let success      = Color(red: 0.18, green: 0.72, blue: 0.42)
    static let warning      = Color(red: 1.00, green: 0.62, blue: 0.04)
    static let danger       = Color(red: 0.94, green: 0.22, blue: 0.22)
    static let info         = Color(red: 0.10, green: 0.55, blue: 0.95)

    // ── Premium / Tier ─────────────────────────────────────────────────────────
    /// Gold tone used for BEST-tier bids.
    static let gold         = Color(red: 0.82, green: 0.62, blue: 0.10)

    // ── Backgrounds & Surfaces ─────────────────────────────────────────────────
    static let surface      = Color(.secondarySystemBackground)
    static let surfaceRaised = Color(.tertiarySystemBackground)
    static let canvas       = Color(.systemBackground)

    // ── Gradients ─────────────────────────────────────────────────────────────
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.33, blue: 0.64), Color(red: 0.10, green: 0.52, blue: 0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.26, blue: 0.54), Color(red: 0.08, green: 0.45, blue: 0.80)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.62, blue: 0.36), Color(red: 0.24, green: 0.78, blue: 0.50)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.18, blue: 0.40),
                Color(red: 0.05, green: 0.33, blue: 0.64),
                Color(red: 0.10, green: 0.50, blue: 0.90),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// ─── EBPSpacing ───────────────────────────────────────────────────────────────

enum EBPSpacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// ─── EBPRadius ────────────────────────────────────────────────────────────────

enum EBPRadius {
    static let xs:  CGFloat = 6
    static let sm:  CGFloat = 10
    static let md:  CGFloat = 14
    static let lg:  CGFloat = 18
    static let xl:  CGFloat = 24
    static let pill: CGFloat = 999
}

// ─── EBPShadow ────────────────────────────────────────────────────────────────

enum EBPShadow {
    static func subtle(radius: CGFloat = 4, y: CGFloat = 2) -> some ViewModifier {
        _ShadowModifier(color: .black.opacity(0.06), radius: radius, x: 0, y: y)
    }
    static func medium(radius: CGFloat = 10, y: CGFloat = 4) -> some ViewModifier {
        _ShadowModifier(color: .black.opacity(0.10), radius: radius, x: 0, y: y)
    }
    static func strong(radius: CGFloat = 20, y: CGFloat = 8) -> some ViewModifier {
        _ShadowModifier(color: .black.opacity(0.18), radius: radius, x: 0, y: y)
    }
}

struct _ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension View {
    func ebpShadowSubtle() -> some View  { shadow(color: .black.opacity(0.06), radius: 4,  x: 0, y: 2) }
    func ebpShadowMedium()  -> some View { shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4) }
    func ebpShadowStrong()  -> some View { shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8) }
}

// ─── EBPAnimation ─────────────────────────────────────────────────────────────

enum EBPAnimation {
    static let snappy   = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let bouncy   = Animation.spring(response: 0.4,  dampingFraction: 0.65)
    static let smooth   = Animation.easeInOut(duration: 0.25)
    static let fast     = Animation.easeInOut(duration: 0.15)
}

// ─── EBPFont ──────────────────────────────────────────────────────────────────

enum EBPFont {
    // Display
    static let hero:    Font = .system(size: 36, weight: .black, design: .rounded)
    static let title:   Font = .system(size: 28, weight: .bold,  design: .default)
    static let heading: Font = .system(size: 20, weight: .bold,  design: .default)
    // Body
    static let body:    Font = .system(size: 16, weight: .regular)
    static let callout: Font = .system(size: 15, weight: .medium)
    // Labels
    static let label:   Font = .system(size: 13, weight: .semibold)
    static let caption: Font = .system(size: 12, weight: .regular)
    static let micro:   Font = .system(size: 10, weight: .semibold)
    // Numeric
    static let stat:    Font = .system(size: 32, weight: .bold,  design: .rounded)
    static let statSm:  Font = .system(size: 22, weight: .bold,  design: .rounded)
    static let mono:    Font = .system(size: 15, weight: .medium, design: .monospaced)
}

