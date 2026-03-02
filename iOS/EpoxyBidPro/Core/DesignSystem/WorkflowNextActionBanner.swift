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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(action.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }

            Spacer()

            if let target = action.targetTab {
                Button {
                    onOpen(target)
                } label: {
                    Text("Open")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tintColor, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
    }

    private var tintColor: Color {
        switch action.kind {
        case .leads: return .blue
        case .bids: return EBPColor.accent
        case .jobs: return EBPColor.warning
        case .collections: return EBPColor.danger
        case .healthy: return EBPColor.success
        }
    }
}
