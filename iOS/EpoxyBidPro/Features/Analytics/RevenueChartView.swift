import SwiftUI
import Charts

// MARK: - Revenue Chart View

struct RevenueChartView: View {

    let revenueData: RevenueData?
    let seasonalData: SeasonalData?
    @Binding var selectedRange: String
    let onRangeChange: () async -> Void

    @State private var chartMode: ChartMode = .daily

    enum ChartMode: String, CaseIterable {
        case daily = "Daily"
        case seasonal = "Seasonal"
    }

    private let ranges = ["7d", "30d", "90d", "1y"]

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

                // ── Total Revenue Card ──────────────────────────────────────
                if let rev = revenueData {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Revenue")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(rev.totalRevenue.currencyFormatted)
                                .font(.title.bold())
                                .foregroundStyle(EBPColor.primary)
                        }
                        Spacer()
                        // Payment method breakdown
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(rev.byMethod.sorted(by: { $0.value > $1.value }).prefix(3), id: \.key) { method, amount in
                                HStack(spacing: 6) {
                                    Text(method.capitalized)
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Text(amount.currencyFormatted)
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                    .ebpCard()
                }

                // ── Chart Mode Picker ───────────────────────────────────────
                Picker("Chart", selection: $chartMode) {
                    ForEach(ChartMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, EBPSpacing.md)

                // ── Daily Bar Chart ─────────────────────────────────────────
                if chartMode == .daily, let rev = revenueData {
                    let entries = rev.byDay.sorted(by: { $0.key < $1.key }).map {
                        (date: $0.key, amount: $0.value)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Revenue by Day")
                            .font(.headline)
                            .padding(.horizontal, EBPSpacing.md)

                        if entries.isEmpty {
                            ebpEmptyState("No revenue data for this period")
                        } else {
                            Chart(entries, id: \.date) { entry in
                                BarMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Revenue", entry.amount)
                                )
                                .foregroundStyle(EBPColor.primary.gradient)
                                .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: max(1, entries.count / 6))) { value in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel {
                                        if let v = value.as(Double.self) {
                                            Text("$\(Int(v / 1000))k")
                                        }
                                    }
                                }
                            }
                            .frame(height: 220)
                            .padding(.horizontal, EBPSpacing.md)
                        }
                    }
                }

                // ── Seasonal Bar Chart ──────────────────────────────────────
                if chartMode == .seasonal, let seas = seasonalData {
                    let monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Average Revenue")
                            .font(.headline)
                            .padding(.horizontal, EBPSpacing.md)

                        Chart(seas.seasonalAvg) { item in
                            BarMark(
                                x: .value("Month", monthNames[item.month - 1]),
                                y: .value("Avg Revenue", item.avgRevenue)
                            )
                            .foregroundStyle(EBPColor.primary.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 220)
                        .padding(.horizontal, EBPSpacing.md)
                    }
                }

                Spacer(minLength: EBPSpacing.lg)
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }
}

// MARK: - Helpers

private func ebpEmptyState(_ message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "chart.bar.xaxis")
            .font(.largeTitle).foregroundStyle(.tertiary)
        Text(message).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 140)
}

extension Double {
    var currencyFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}

extension View {
    func ebpCard() -> some View {
        self
            .padding(EBPSpacing.md)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, EBPSpacing.md)
    }
}
