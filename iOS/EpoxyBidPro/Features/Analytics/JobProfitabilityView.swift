import SwiftUI
import Charts

// MARK: - Job Profitability View

struct JobProfitabilityView: View {

    let profitability: ProfitabilityData?
    @Binding var selectedRange: String
    let onRangeChange: () async -> Void
    let onExportCSV: () async -> Void

    private let ranges = ["30d", "90d", "1y"]

    private var jobs: [ProfitabilityJob] { profitability?.jobs ?? [] }
    private var avgMargin: Double {
        guard !jobs.isEmpty else { return 0 }
        return jobs.reduce(0) { $0 + $1.margin } / Double(jobs.count)
    }
    private var totalRevenue: Double { jobs.reduce(0) { $0 + $1.revenue } }
    private var totalCost: Double { jobs.reduce(0) { $0 + $1.cost } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // ── Range + Export ──────────────────────────────────────────
                HStack {
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
                    }
                    Button {
                        Task { await onExportCSV() }
                    } label: {
                        Label("CSV", systemImage: "arrow.down.doc")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, EBPSpacing.md)

                // ── Summary Row ─────────────────────────────────────────────
                HStack(spacing: 12) {
                    summaryCell(label: "Revenue", value: totalRevenue.currencyFormatted, color: .green)
                    Divider().frame(height: 44)
                    summaryCell(label: "Cost", value: totalCost.currencyFormatted, color: .orange)
                    Divider().frame(height: 44)
                    summaryCell(label: "Avg Margin", value: "\(String(format: "%.1f", avgMargin))%",
                                color: avgMargin >= 40 ? .green : avgMargin >= 20 ? .orange : .red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, EBPSpacing.md)

                // ── Margin Scatter/Bar Chart ────────────────────────────────
                if !jobs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job Margin Breakdown")
                            .font(.headline)

                        Chart(jobs) { job in
                            PointMark(
                                x: .value("Revenue", job.revenue),
                                y: .value("Margin %", job.margin)
                            )
                            .foregroundStyle(marginColor(job.margin).gradient)
                            .symbolSize(CGFloat(max(50, job.totalSqFt ?? 100) / 10))
                        }
                        .chartXAxis {
                            AxisMarks { v in
                                AxisValueLabel {
                                    if let d = v.as(Double.self) { Text("$\(Int(d / 1000))k") }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel {
                                    if let d = v.as(Double.self) { Text("\(Int(d))%") }
                                }
                            }
                        }
                        .frame(height: 240)

                        HStack(spacing: 16) {
                            legendDot(.green, "≥40% margin")
                            legendDot(.orange, "20-39%")
                            legendDot(.red, "<20%")
                        }
                        .font(.caption)
                    }
                    .ebpCard()

                    // ── Job Table ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Completed Jobs")
                            .font(.headline)
                            .padding(.bottom, 10)

                        ForEach(jobs.sorted(by: { $0.margin > $1.margin })) { job in
                            Divider()
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(marginColor(job.margin))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.title)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(job.coatingSystem ?? "Unspecified")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(job.revenue.currencyFormatted)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(String(format: "%.1f", job.margin))% margin")
                                        .font(.caption)
                                        .foregroundStyle(marginColor(job.margin))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .ebpCard()
                } else {
                    emptySate("No completed jobs in this period")
}

                Spacer(minLength: EBPSpacing.lg)
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func marginColor(_ m: Double) -> Color {
        m >= 40 ? .green : m >= 20 ? .orange : .red
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func emptySate(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie").font(.largeTitle).foregroundStyle(.tertiary)
            Text(msg).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}
