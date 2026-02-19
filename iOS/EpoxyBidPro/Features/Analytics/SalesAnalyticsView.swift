import SwiftUI
import Charts

// MARK: - Sales Analytics View

struct SalesAnalyticsView: View {

    let bidAnalytics: BidAnalyticsData?
    let bidsByType: BidByTypeData?
    @Binding var selectedRange: String
    let onRangeChange: () async -> Void

    private let ranges = ["30d", "90d", "1y"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // ── Range Picker ────────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EBPSpacing.sm) {
                        ForEach(ranges, id: \.self) { r in
                            Button(r.uppercased()) {
                                selectedRange = r
                                Task { await onRangeChange() }
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(selectedRange == r ? EBPColor.primary : EBPColor.surface)
                            .foregroundStyle(selectedRange == r ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, EBPSpacing.md)
                }

                // ── KPI Cards ───────────────────────────────────────────────
                if let ba = bidAnalytics {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        kpiCard(title: "Win Rate", value: "\(ba.winRate)%", icon: "trophy.fill", color: .green)
                        kpiCard(title: "Avg Bid Value", value: ba.avgBidValue.currencyFormatted, icon: "dollarsign.circle.fill", color: EBPColor.primary)
                        kpiCard(title: "Total Bids", value: "\(ba.total)", icon: "doc.text.fill", color: .orange)
                        kpiCard(title: "Declined", value: "\(ba.declined)", icon: "xmark.circle.fill", color: .red)
                    }
                    .padding(.horizontal, EBPSpacing.md)

                    // ── Funnel Chart ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bid Funnel")
                            .font(.headline)

                        let stages: [(String, Int, Color)] = [
                            ("Created", ba.total, .blue),
                            ("Sent", ba.sent, EBPColor.primary),
                            ("Signed", ba.signed, .green),
                        ]

                        ForEach(stages, id: \.0) { label, value, color in
                            HStack(spacing: 12) {
                                Text(label)
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                                        let pct = ba.total > 0 ? CGFloat(value) / CGFloat(ba.total) : 0
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(color.gradient)
                                            .frame(width: geo.size.width * pct)
                                    }
                                }
                                .frame(height: 28)
                                Text("\(value)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .ebpCard()
                }

                // ── Win Rate by Coating System ──────────────────────────────
                if let bt = bidsByType, !bt.breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance by Coating System")
                            .font(.headline)

                        Chart(bt.breakdown) { row in
                            BarMark(
                                x: .value("Win Rate", row.winRate),
                                y: .value("System", row.coatingSystem)
                            )
                            .foregroundStyle(EBPColor.primary.gradient)
                            .annotation(position: .trailing) {
                                Text("\(row.winRate)%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(EBPColor.primary)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: [0, 25, 50, 75, 100]) {
                                AxisValueLabel { Text("\($0.as(Int.self) ?? 0)%") }
                            }
                        }
                        .frame(height: CGFloat(bt.breakdown.count) * 40 + 40)
                    }
                    .ebpCard()

                    // ── Revenue by System Table ───────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Revenue by System")
                            .font(.headline)
                            .padding(.bottom, 10)

                        ForEach(bt.breakdown) { row in
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.coatingSystem)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(row.total) bids · \(row.avgSqFt) avg sq ft")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(row.revenue.currencyFormatted)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Win \(row.winRate)%")
                                        .font(.caption)
                                        .foregroundStyle(row.winRate >= 50 ? .green : .orange)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .ebpCard()
                }

                Spacer(minLength: EBPSpacing.lg)
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
