import SwiftUI
import Charts

// MARK: - CRM Analytics View

struct CRMAnalyticsView: View {

    let pipeline: CRMPipelineData?
    let ltvClients: [LTVClient]

    private let statusOrder = ["NEW", "CONTACTED", "SITE_VISIT", "BID_SENT", "WON", "LOST"]

    private var orderedLeads: [LeadStatusGroup] {
        guard let groups = pipeline?.leadsByStatus else { return [] }
        return groups.sorted {
            (statusOrder.firstIndex(of: $0.status) ?? 99) <
            (statusOrder.firstIndex(of: $1.status) ?? 99)
        }
    }

    private var totalPipelineValue: Double {
        pipeline?.leadsByStatus
            .compactMap { $0._sum.estimatedValue }
            .reduce(0, +) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // ── Pipeline Value Header ───────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pipeline Value")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(totalPipelineValue.currencyFormatted)
                            .font(.largeTitle.bold())
                            .foregroundStyle(EBPColor.primary)
                    }
                    Spacer()
                    if let groups = pipeline?.leadsByStatus {
                        VStack(alignment: .trailing, spacing: 4) {
                            let won = groups.first(where: { $0.status == "WON" })
                            let total = groups.reduce(0) { $0 + $1._count.status }
                            let wonCount = won?._count.status ?? 0
                            Text("Close Rate")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(total > 0 ? "\(Int(Double(wonCount) / Double(total) * 100))%" : "—")
                                .font(.title2.bold()).foregroundStyle(.green)
                        }
                    }
                }
                .ebpCard()

                // ── Pipeline Funnel Chart ───────────────────────────────────
                if !orderedLeads.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lead Pipeline")
                            .font(.headline)

                        let maxCount = orderedLeads.map { $0._count.status }.max() ?? 1
                        ForEach(orderedLeads) { group in
                            let pct = CGFloat(group._count.status) / CGFloat(maxCount)
                            HStack(spacing: 10) {
                                Text(group.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption.weight(.medium))
                                    .frame(width: 80, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(stageColor(group.status).gradient)
                                            .frame(width: geo.size.width * pct)
                                    }
                                }
                                .frame(height: 26)
                                Text("\(group._count.status)")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 28, alignment: .trailing)
                            }
                        }
                    }
                    .ebpCard()
                }

                // ── Lost Reason Breakdown ───────────────────────────────────
                if let reasons = pipeline?.lostReasons, !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lost Deal Analysis")
                            .font(.headline)

                        Chart(reasons) { reason in
                            SectorMark(
                                angle: .value("Count", reason._count.lostReason),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Reason", reason.lostReason ?? "Unknown"))
                            .cornerRadius(4)
                        }
                        .frame(height: 180)

                        ForEach(reasons.sorted(by: { $0._count.lostReason > $1._count.lostReason })) { r in
                            HStack {
                                Text(r.lostReason ?? "Unknown")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(r._count.lostReason) deals")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .ebpCard()
                }

                // ── Top Clients by Revenue ──────────────────────────────────
                if !ltvClients.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Top Clients by Lifetime Value")
                            .font(.headline)
                            .padding(.bottom, 12)

                        ForEach(ltvClients.prefix(10)) { client in
                            Divider()
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(EBPColor.primary.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Text(client.name.prefix(1))
                                        .font(.headline)
                                        .foregroundStyle(EBPColor.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.name.isEmpty ? client.company : client.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(client.jobCount) job\(client.jobCount == 1 ? "" : "s") · \(client.clientType.capitalized)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(client.totalRevenue.currencyFormatted)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Avg \(client.avgJobValue.currencyFormatted)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 9)
                        }
                    }
                    .ebpCard()
                }

                Spacer(minLength: EBPSpacing.lg)
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    private func stageColor(_ status: String) -> Color {
        switch status {
        case "NEW": return .blue
        case "CONTACTED": return .cyan
        case "SITE_VISIT": return .orange
        case "BID_SENT": return EBPColor.primary
        case "WON": return .green
        case "LOST": return .red
        default: return .gray
        }
    }
}
