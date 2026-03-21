import SwiftUI

struct WorkflowKPIBanner: View {
    let snapshot: WorkflowKPISnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label("Live Workflow", systemImage: "waveform.path.ecg.rectangle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.primaryContainer)
                Spacer()
                Text("Scans 7d: \(snapshot.scansThisWeek)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EBPColor.onSurfaceVariant)
            }

            Text(snapshot.headline)
                .font(.caption)
                .foregroundStyle(EBPColor.onSurface.opacity(0.85))

            HStack(spacing: EBPSpacing.xs) {
                item(label: "Leads", value: snapshot.readyLeads, color: EBPColor.secondary)
                item(label: "Bids", value: snapshot.bidsNeedingAction, color: EBPColor.primaryContainer)
                item(label: "Jobs", value: snapshot.atRiskJobs, color: EBPColor.error)
                item(label: "AR", value: snapshot.collectionRisks, color: EBPColor.primary)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.xl)
    }

    private func item(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(EBPColor.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(EBPColor.surfaceContainerHighest.opacity(0.6), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }
}
