import SwiftUI

// ─── EBPColor ─────────────────────────────────────────────────────────────────
// Industrial Precision design system colour tokens.
// Surface hierarchy follows Material Design 3 tonal layering.
// "No-Line Rule" — separation via background shifts, not borders.

enum EBPColor {

    // ── Surface Hierarchy (The "Material Stack") ────────────────────────────
    /// Darkest possible — deep backgrounds, canvas.
    static let surfaceContainerLowest = Color(hex: "#0c0e11")
    /// Base "floor" layer.
    static let surface                = Color(hex: "#111316")
    /// Headers, sidebars, subtle separation.
    static let surfaceContainerLow    = Color(hex: "#1a1c1f")
    /// Large content blocks.
    static let surfaceContainer       = Color(hex: "#1e2023")
    /// Interactive cards, elevated content.
    static let surfaceContainerHigh   = Color(hex: "#282a2d")
    /// Highest elevation — modals, overlays.
    static let surfaceContainerHighest = Color(hex: "#333538")
    /// Glassmorphism base (60% opacity + blur).
    static let surfaceBright          = Color(hex: "#37393d")

    // ── Primary (Cyan System) ───────────────────────────────────────────────
    /// Cyan highlight text, section titles.
    static let primary          = Color(hex: "#c3f5ff")
    /// Electric cyan — gradients, active indicators, CTAs.
    static let primaryContainer = Color(hex: "#00e5ff")
    /// Text on primary-gradient backgrounds.
    static let onPrimary        = Color(hex: "#00363d")
    /// "Lit from within" icon glow.
    static let primaryFixedDim  = Color(hex: "#00daf3")

    // ── On-Surface (Text) ───────────────────────────────────────────────────
    /// Primary text on dark surfaces.
    static let onSurface        = Color(hex: "#e2e2e6")
    /// Secondary / metadata text.
    static let onSurfaceVariant = Color(hex: "#bac9cc")

    // ── Secondary (Industrial Orange) ───────────────────────────────────────
    /// Warm orange text — "In Progress", active states.
    static let secondary          = Color(hex: "#ffb692")
    /// Bold industrial orange — high-priority CTAs.
    static let secondaryContainer = Color(hex: "#fd6c00")

    // ── Tertiary (Gold System) ──────────────────────────────────────────────
    /// Soft gold tint.
    static let tertiary          = Color(hex: "#ffeac0")
    /// Bold gold — premium tiers, BEST bids.
    static let tertiaryContainer = Color(hex: "#fec931")

    // ── Outline ─────────────────────────────────────────────────────────────
    /// Muted outlines for disabled / low-contrast edges.
    static let outline        = Color(hex: "#849396")
    /// Ghost borders — 15% opacity shimmer edges.
    static let outlineVariant = Color(hex: "#3b494c")

    // ── Semantic ────────────────────────────────────────────────────────────
    static let error   = Color(hex: "#ffb4ab")
    static let success = Color(red: 0.00, green: 0.85, blue: 0.45)
    static let danger  = Color(hex: "#ffb4ab")

    // ── Backward-Compatible Aliases ─────────────────────────────────────────
    /// Electric cyan accent (maps to primaryContainer).
    static let accent       = primaryContainer
    /// Deepest canvas (maps to surfaceContainerLowest).
    static let canvas       = surfaceContainerLowest
    /// Gold tier (maps to tertiaryContainer).
    static let gold         = tertiaryContainer
    /// Metallic silver for secondary highlights.
    static let silver       = Color(red: 0.75, green: 0.75, blue: 0.80)
    /// Raised surface (maps to surfaceContainerHigh).
    static let surfaceRaised = surfaceContainerHigh
    /// Warning orange (maps to secondary).
    static let warning      = secondary
    /// Info cyan (maps to primaryContainer).
    static let info         = primaryContainer

    // ── Gradients ───────────────────────────────────────────────────────────

    /// Primary CTA gradient — backlit electric glow (135 degrees).
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#c3f5ff"), Color(hex: "#00e5ff")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Hero gradient for headers and feature sections.
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#00daf3"), Color(hex: "#00e5ff")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Success gradient.
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.00, green: 0.70, blue: 0.40), Color(red: 0.00, green: 0.90, blue: 0.50)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Onboarding gradient — deep surface to cyan glow.
    static var onboardingGradient: LinearGradient {
        LinearGradient(
            colors: [
                surfaceContainerLowest,
                surface,
                Color(hex: "#00363d"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// ─── Color hex initialiser ──────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// ─── EBPSpacing ───────────────────────────────────────────────────────────────

enum EBPSpacing {
    static let xxs:  CGFloat = 2
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let xl:   CGFloat = 32
    static let xxl:  CGFloat = 48
    static let xxxl: CGFloat = 64
    /// Generous page margins (Industrial Precision spacing.20).
    static let page:    CGFloat = 20
    /// Section-level spacing (Industrial Precision spacing.16).
    static let section: CGFloat = 16
}

// ─── EBPRadius ────────────────────────────────────────────────────────────────

enum EBPRadius {
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 10
    static let md:   CGFloat = 14
    static let lg:   CGFloat = 18
    static let xl:   CGFloat = 24
    static let pill:  CGFloat = 999
    /// Default card radius (xl).
    static let card: CGFloat = 24
}

// ─── EBPShadow ────────────────────────────────────────────────────────────────
// Industrial Precision: No drop shadows. Use neon glow with primaryFixedDim.

enum EBPShadow {
    static func subtle(radius: CGFloat = 10, y: CGFloat = 0) -> some ViewModifier {
        _ShadowModifier(color: EBPColor.primaryFixedDim.opacity(0.03), radius: radius, x: 0, y: y)
    }
    static func medium(radius: CGFloat = 20, y: CGFloat = 0) -> some ViewModifier {
        _ShadowModifier(color: EBPColor.primaryFixedDim.opacity(0.05), radius: radius, x: 0, y: y)
    }
    static func strong(radius: CGFloat = 40, y: CGFloat = 0) -> some ViewModifier {
        _ShadowModifier(color: EBPColor.primaryFixedDim.opacity(0.08), radius: radius, x: 0, y: y)
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
    /// Subtle neon glow (replaces old black drop shadow).
    func ebpShadowSubtle() -> some View {
        shadow(color: EBPColor.primaryFixedDim.opacity(0.03), radius: 10, x: 0, y: 0)
    }
    /// Medium neon glow.
    func ebpShadowMedium() -> some View {
        shadow(color: EBPColor.primaryFixedDim.opacity(0.05), radius: 20, x: 0, y: 0)
    }
    /// Strong neon glow.
    func ebpShadowStrong() -> some View {
        shadow(color: EBPColor.primaryFixedDim.opacity(0.08), radius: 40, x: 0, y: 0)
    }

    /// Ghost border — shimmer edge at 15% opacity (the "light catching glass" effect).
    func ebpGhostBorder(radius: CGFloat = EBPRadius.xl) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(EBPColor.outlineVariant.opacity(0.15), lineWidth: 0.5)
        )
    }

    /// Industrial Precision glassmorphism — surfaceBright at 60% + backdrop blur.
    func ebpGlassmorphism(cornerRadius: CGFloat = EBPRadius.xl) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(EBPColor.surfaceBright.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .ebpGhostBorder(radius: cornerRadius)
    }

    /// Cyan neon glow — "backlit from the floor" effect.
    func ebpNeonGlow(radius: CGFloat = 12, intensity: Double = 0.15) -> some View {
        self.shadow(color: EBPColor.primaryFixedDim.opacity(intensity), radius: radius, x: 0, y: 0)
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
// Typography: "Authority through Scale." Dense, industrial, tracked-tight display.

enum EBPFont {
    // Display — tracked-tight, dense
    static let hero:    Font = .system(size: 36, weight: .black,  design: .default)
    static let title:   Font = .system(size: 28, weight: .bold,   design: .default)
    static let heading: Font = .system(size: 20, weight: .bold,   design: .default)
    // Body
    static let body:    Font = .system(size: 16, weight: .regular)
    static let callout: Font = .system(size: 15, weight: .medium)
    // Labels
    static let label:   Font = .system(size: 13, weight: .semibold)
    static let labelSm: Font = .system(size: 11, weight: .semibold)
    static let caption: Font = .system(size: 12, weight: .regular)
    static let micro:   Font = .system(size: 10, weight: .semibold)
    // Numeric — keep rounded for instrument-panel feel
    static let statLg:  Font = .system(size: 40, weight: .bold,   design: .rounded)
    static let stat:    Font = .system(size: 32, weight: .bold,   design: .rounded)
    static let statSm:  Font = .system(size: 22, weight: .bold,   design: .rounded)
    static let mono:    Font = .system(size: 15, weight: .medium,  design: .monospaced)
}

// ─── Typography View Modifiers ──────────────────────────────────────────────

extension View {
    /// Display-scale tracked-tight text (-2% tracking).
    func ebpTrackedTight() -> some View {
        self.tracking(-0.4)
    }

    /// Industrial uppercase label styling (all-caps + letter spacing).
    func ebpUppercaseLabel() -> some View {
        self.textCase(.uppercase)
            .tracking(0.8)
    }
}
