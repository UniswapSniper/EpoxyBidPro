import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// EBPComponents.swift
// Industrial Precision design system components for EpoxyBidPro.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── EBPButton ────────────────────────────────────────────────────────────────

enum EBPButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive
    case tinted(Color)
}

struct EBPButton: View {
    let title: String
    let icon: String?
    let style: EBPButtonStyle
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        style: EBPButtonStyle = .primary,
        isLoading: Bool = false,
        isFullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.action = action
    }

    var body: some View {
        Button {
            triggerTapHaptic()
            action()
        } label: {
            HStack(spacing: EBPSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(labelColor)
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(title)
                        .font(.headline)
                }
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, isFullWidth ? EBPSpacing.md : EBPSpacing.lg)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            .overlay {
                if case .ghost = style {
                    RoundedRectangle(cornerRadius: EBPRadius.md)
                        .stroke(EBPColor.outlineVariant.opacity(0.15), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(EBPAnimation.fast, value: isLoading)
    }

    private func triggerTapHaptic() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
    }

    @ViewBuilder private var backgroundFill: some View {
        switch style {
        case .primary:
            EBPColor.primaryGradient
        case .secondary:
            Color(hex: "#fd6c00") // secondaryContainer — industrial orange
        case .ghost:
            Color.clear
        case .destructive:
            EBPColor.error.opacity(0.12)
        case .tinted(let c):
            c.opacity(0.15)
        }
    }

    private var labelColor: Color {
        switch style {
        case .primary:            return EBPColor.onPrimary
        case .secondary:          return .white
        case .ghost:              return EBPColor.primary
        case .destructive:        return EBPColor.error
        case .tinted(let c):      return c
        }
    }
}

// ─── EBPCard ──────────────────────────────────────────────────────────────────

struct EBPCard<Content: View>: View {
    let radius: CGFloat
    let shadow: Bool
    @ViewBuilder let content: Content

    init(radius: CGFloat = EBPRadius.xl, shadow: Bool = false, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.shadow = shadow
        self.content = content()
    }

    var body: some View {
        content
            .padding(EBPSpacing.md)
            .background(EBPColor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: radius))
            .ebpGhostBorder(radius: radius)
            .if(shadow) { $0.ebpShadowSubtle() }
    }
}

// ─── EBPBadge ─────────────────────────────────────────────────────────────────

struct EBPBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(EBPFont.labelSm)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .padding(.horizontal, EBPSpacing.sm)
        .padding(.vertical, EBPSpacing.xs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// ─── EBPStatCard ──────────────────────────────────────────────────────────────
// Industrial metric card — tonal elevation, ghost border, no drop shadow.

struct EBPStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var trend: TrendDirection? = nil
    var isAlert: Bool = false

    enum TrendDirection { case up, down, neutral }

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: EBPRadius.sm)
                        .fill(tint.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Spacer()

                if let trend {
                    trendBadge(trend)
                }
                if isAlert {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(EBPColor.error)
                }
            }

            Text(value)
                .font(EBPFont.statSm)
                .foregroundStyle(EBPColor.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(EBPFont.caption)
                .foregroundStyle(EBPColor.onSurfaceVariant)
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: EBPRadius.xl))
        .ebpGhostBorder(radius: EBPRadius.xl)
    }

    @ViewBuilder private func trendBadge(_ d: TrendDirection) -> some View {
        let (color, icon): (Color, String) = switch d {
        case .up:      (EBPColor.success, "arrow.up.right")
        case .down:    (EBPColor.error,   "arrow.down.right")
        case .neutral: (EBPColor.outline, "minus")
        }
        Image(systemName: icon)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(4)
            .background(color.opacity(0.12), in: Circle())
    }
}

// ─── EBPSectionHeader ─────────────────────────────────────────────────────────

struct EBPSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (label: String, handler: () -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EBPColor.onSurface)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EBPColor.onSurfaceVariant)
                }
            }
            Spacer()
            if let action {
                Button(action.label, action: action.handler)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EBPColor.primary)
            }
        }
    }
}

// ─── EBPEmptyState ────────────────────────────────────────────────────────────

struct EBPEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (label: String, handler: () -> Void)? = nil

    var body: some View {
        VStack(spacing: EBPSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(EBPColor.primaryFixedDim.opacity(0.35))

            VStack(spacing: EBPSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EBPColor.onSurface)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(EBPColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            if let action {
                EBPButton(title: action.label, style: .primary, isFullWidth: false, action: action.handler)
                    .padding(.top, EBPSpacing.xs)
            }
        }
        .padding(EBPSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// ─── EBPPillTag ───────────────────────────────────────────────────────────────

struct EBPPillTag: View {
    let text: String
    var color: Color = EBPColor.primary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// ─── EBPDivider ───────────────────────────────────────────────────────────────
// Deprecated: Industrial Precision prohibits horizontal dividers.
// Use background shifts or spacing instead.

struct EBPDivider: View {
    var body: some View {
        Rectangle()
            .fill(EBPColor.outlineVariant.opacity(0.15))
            .frame(height: 0.5)
    }
}

// ─── EBPRevenueBanner ─────────────────────────────────────────────────────────
// Gradient revenue card for Dashboard.

struct EBPRevenueBanner: View {
    let label: String
    let amount: String
    var subtitle: String? = nil
    var gradient: LinearGradient = EBPColor.heroGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.6)
            Text(amount)
                .font(EBPFont.stat)
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EBPSpacing.lg)
        .background(gradient, in: RoundedRectangle(cornerRadius: EBPRadius.xl))
        .ebpNeonGlow()
    }
}

// ─── PressScaleButtonStyle ────────────────────────────────────────────────────
/// Gives any button a satisfying scale-down on press.

struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(EBPAnimation.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressScaleButtonStyle {
    static var pressScale: PressScaleButtonStyle { PressScaleButtonStyle() }
}

// ─── View Helpers ─────────────────────────────────────────────────────────────

extension View {
    /// Conditionally apply a modifier.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Apply standard Industrial Precision card styling.
    func ebpCard(radius: CGFloat = EBPRadius.xl, shadow: Bool = false) -> some View {
        self
            .padding(EBPSpacing.md)
            .background(EBPColor.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: radius))
            .ebpGhostBorder(radius: radius)
            .if(shadow) { $0.ebpShadowSubtle() }
    }

    /// Horizontal padding using the standard content margin.
    func ebpHPadding() -> some View {
        self.padding(.horizontal, EBPSpacing.page)
    }
}

// ─── Date Extensions ─────────────────────────────────────────────────────────

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// ─── EBPDynamicBackground ───────────────────────────────────────────────────
// Industrial Precision ambient background with cyan neon orbs.

struct EBPDynamicBackground: View {
    var body: some View {
        ZStack {
            // Base gradient — surface tiers
            LinearGradient(
                colors: [
                    EBPColor.surfaceContainerLowest,
                    EBPColor.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated orbs
            GeometryReader { geo in
                ZStack {
                    // Primary cyan glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [EBPColor.primaryContainer.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: -100, y: -100)

                    // Secondary blue glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [EBPColor.primaryFixedDim.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(x: geo.size.width - 100, y: geo.size.height - 200)
                }
            }
            .ignoresSafeArea()
        }
    }
}
