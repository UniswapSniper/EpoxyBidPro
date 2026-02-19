import SwiftUI

enum EBPButtonStyle {
    case primary
    case secondary
    case destructive
}

struct EBPButton: View {
    let title: String
    let style: EBPButtonStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EBPSpacing.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return EBPColor.primary
        case .secondary: return EBPColor.secondary
        case .destructive: return EBPColor.danger
        }
    }
}

struct EBPCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(EBPSpacing.md)
            .background(EBPColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EBPBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, EBPSpacing.sm)
            .padding(.vertical, EBPSpacing.xs)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
