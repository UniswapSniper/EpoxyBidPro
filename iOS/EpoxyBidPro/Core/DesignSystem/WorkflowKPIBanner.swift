import SwiftUI

struct WorkflowKPIBanner: View {
    let snapshot: WorkflowKPISnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label("Live Workflow", systemImage: "waveform.path.ecg.rectangle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.accent)
                Spacer()
                Text("Scans 7d: \(snapshot.scansThisWeek)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(snapshot.headline)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: EBPSpacing.xs) {
                item(label: "Leads", value: snapshot.readyLeads, color: EBPColor.warning)
                item(label: "Bids", value: snapshot.bidsNeedingAction, color: EBPColor.accent)
                item(label: "Jobs", value: snapshot.atRiskJobs, color: EBPColor.danger)
                item(label: "AR", value: snapshot.collectionRisks, color: EBPColor.primary)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
    }

    private func item(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }
}
