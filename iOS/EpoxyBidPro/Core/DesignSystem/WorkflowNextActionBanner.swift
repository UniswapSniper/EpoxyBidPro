import SwiftUI

struct WorkflowNextActionBanner: View {
    let action: WorkflowNextAction
    let onOpen: (WorkflowRouter.RouteTab) -> Void

    var body: some View {
        HStack(spacing: EBPSpacing.sm) {
            Image(systemName: action.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.onSurface)
                    .lineLimit(1)
                Text(action.subtitle)
                    .font(.caption2)
                    .foregroundStyle(EBPColor.onSurfaceVariant)
                    .lineLimit(2)
            }

            Spacer()

            if let target = action.targetTab {
                Button {
                    onOpen(target)
                } label: {
                    Text("Open")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(EBPColor.onPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tintColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.xl)
    }

    private var tintColor: Color {
        switch action.kind {
        case .leads:      return EBPColor.primary
        case .bids:       return EBPColor.primaryContainer
        case .jobs:       return EBPColor.secondaryContainer
        case .collections: return EBPColor.error
        case .healthy:    return EBPColor.success
        }
    }
}
