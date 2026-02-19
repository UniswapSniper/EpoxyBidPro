import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// EBPComponents.swift
// Reusable, polished components for EpoxyBidPro.
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                        .strokeBorder(EBPColor.primary, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(EBPAnimation.fast, value: isLoading)
    }

    @ViewBuilder private var backgroundFill: some View {
        switch style {
        case .primary:
            EBPColor.primaryGradient
        case .secondary:
            EBPColor.surface
        case .ghost:
            Color.clear
        case .destructive:
            Color.red.opacity(0.12)
        case .tinted(let c):
            c.opacity(0.15)
        }
    }

    private var labelColor: Color {
        switch style {
        case .primary:            return .white
        case .secondary:          return .primary
        case .ghost:              return EBPColor.primary
        case .destructive:        return .red
        case .tinted(let c):      return c
        }
    }
}

// ─── EBPCard ──────────────────────────────────────────────────────────────────

struct EBPCard<Content: View>: View {
    let radius: CGFloat
    let shadow: Bool
    @ViewBuilder let content: Content

    init(radius: CGFloat = EBPRadius.md, shadow: Bool = true, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.shadow = shadow
        self.content = content()
    }

    var body: some View {
        content
            .padding(EBPSpacing.md)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: radius))
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
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, EBPSpacing.sm)
        .padding(.vertical, EBPSpacing.xs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// ─── EBPStatCard ──────────────────────────────────────────────────────────────
// A polished metric card used on Dashboard, Analytics, and summary bars.

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
                        .foregroundStyle(.red)
                }
            }

            Text(value)
                .font(EBPFont.statSm)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(EBPFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    @ViewBuilder private func trendBadge(_ d: TrendDirection) -> some View {
        let (color, icon): (Color, String) = switch d {
        case .up:      (EBPColor.success, "arrow.up.right")
        case .down:    (EBPColor.danger,  "arrow.down.right")
        case .neutral: (.secondary,       "minus")
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
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(EBPColor.primary.opacity(0.35))

            VStack(spacing: EBPSpacing.xs) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// ─── EBPDivider ───────────────────────────────────────────────────────────────

struct EBPDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.6))
            .frame(height: 0.5)
    }
}

// ─── EBPRevenueBanner ─────────────────────────────────────────────────────────
// Gradient revenue card used on Dashboard.

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
        .background(gradient, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowMedium()
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

    /// Apply standard card styling (background + corner radius + shadow).
    func ebpCard(radius: CGFloat = EBPRadius.md, shadow: Bool = true) -> some View {
        self
            .padding(EBPSpacing.md)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: radius))
            .if(shadow) { $0.ebpShadowSubtle() }
    }

    /// Horizontal padding using the standard content margin.
    func ebpHPadding() -> some View {
        self.padding(.horizontal, EBPSpacing.md)
    }
}

