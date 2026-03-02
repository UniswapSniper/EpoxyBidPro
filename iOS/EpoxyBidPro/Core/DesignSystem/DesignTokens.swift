import SwiftUI

// ─── EBPColor ─────────────────────────────────────────────────────────────────
// Centralised semantic colour tokens for EpoxyBidPro.
// All colours are dark-mode aware unless otherwise noted.

enum EBPColor {

    // ── Brand ──────────────────────────────────────────────────────────────────
    /// Obsidian-black primary (Deep dark background).
    static let primary      = Color(red: 0.05, green: 0.05, blue: 0.06)
    /// Charcoal-slate secondary.
    static let secondary    = Color(red: 0.12, green: 0.12, blue: 0.15)
    /// Electric Cyan accent (LiDAR, highlights).
    static let accent       = Color(red: 0.00, green: 1.00, blue: 0.95)
    /// Metallic Silver (Flakes, secondary highlights).
    static let silver       = Color(red: 0.75, green: 0.75, blue: 0.80)

    // ── Semantic ───────────────────────────────────────────────────────────────
    static let success      = Color(red: 0.00, green: 0.85, blue: 0.45)
    static let warning      = Color(red: 1.00, green: 0.70, blue: 0.00)
    static let danger       = Color(red: 1.00, green: 0.30, blue: 0.30)
    static let info         = Color(red: 0.00, green: 1.00, blue: 0.95)

    // ── Premium / Tier ─────────────────────────────────────────────────────────
    /// Gold tone used for BEST-tier bids.
    static let gold         = Color(red: 0.82, green: 0.62, blue: 0.10)

    // ── Backgrounds & Surfaces ─────────────────────────────────────────────────
    static let surface      = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let surfaceRaised = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let canvas       = Color(red: 0.05, green: 0.05, blue: 0.06)

    // ── Gradients ─────────────────────────────────────────────────────────────
    /// Deep obsidian to charcoal gradient.
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.12, green: 0.12, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Cyan scanning gradient for headers and CTAs.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.00, green: 0.80, blue: 0.75), Color(red: 0.00, green: 1.00, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.00, green: 0.70, blue: 0.40), Color(red: 0.00, green: 0.90, blue: 0.50)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Dark obsidian to cyan glow (for onboarding screens).
    static var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.03),
                Color(red: 0.05, green: 0.05, blue: 0.06),
                Color(red: 0.00, green: 0.30, blue: 0.30),
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
    func ebpShadowSubtle() -> some View  { shadow(color: .black.opacity(0.3), radius: 6,  x: 0, y: 3) }
    func ebpShadowMedium()  -> some View { shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6) }
    func ebpShadowStrong()  -> some View { shadow(color: .black.opacity(0.7), radius: 24, x: 0, y: 12) }

    /// A premium glassmorphic background effect
    func ebpGlassmorphism(cornerRadius: CGFloat = EBPRadius.md) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.2)) // Slightly darkens the blur
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear, Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
    }

    /// Adds a cyan neon glow
    func ebpNeonGlow(radius: CGFloat = 8, intensity: Double = 0.3) -> some View {
        self.shadow(color: EBPColor.accent.opacity(intensity), radius: radius, x: 0, y: 0)
    }
}

// ─── EBPAnimation ─────────────────────────────────────────────────────────────

enum EBPAnimation {
    static let snappy   = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let bouncy   = Animation.spring(response: 0.4,  dampingFraction: 0.65)
    static let smooth   = Animation.easeInOut(duration: 0.25)
    static let fast     = Animation.easeInOut(duration: 0.15)
    static let sectionSwitch = Animation.easeInOut(duration: 0.22)
    static let handoff  = Animation.spring(response: 0.38, dampingFraction: 0.8)
    static let ambient  = Animation.easeInOut(duration: 7.0)
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
    static let statLg:  Font = .system(size: 40, weight: .bold,  design: .rounded)
    static let stat:    Font = .system(size: 32, weight: .bold,  design: .rounded)
    static let statSm:  Font = .system(size: 22, weight: .bold,  design: .rounded)
    static let mono:    Font = .system(size: 15, weight: .medium, design: .monospaced)
}

