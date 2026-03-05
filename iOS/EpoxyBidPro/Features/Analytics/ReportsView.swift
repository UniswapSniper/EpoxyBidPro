import SwiftUI
import SwiftData
import Charts

// ─── ReportsView ──────────────────────────────────────────────────────────────
// Offline-capable local reports computed entirely from SwiftData:
//   • Monthly P&L overview
//   • Tax preparation summary
//   • Crew performance report
//   • Win-rate close-time analysis (local bid data)

struct ReportsView: View {

    // MARK: - Environment / Data

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Job.createdAt, order: .reverse)     private var allJobs: [Job]
    @Query(sort: \Bid.createdAt, order: .reverse)     private var allBids: [Bid]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var allInvoices: [Invoice]
    @Query private var allTimeEntries: [JobTimeEntry]

    // MARK: - State

    @State private var selectedReport: ReportType = .pnl
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    enum ReportType: String, CaseIterable, Identifiable {
        case pnl        = "P&L"
        case tax        = "Tax Prep"
        case crew       = "Crew"
        case winRate    = "Win Rate"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pnl:     return "chart.bar.fill"
            case .tax:     return "doc.text.magnifyingglass"
            case .crew:    return "person.3.fill"
            case .winRate: return "trophy.fill"
            }
        }
    }

    // MARK: - Computed — Year selector

    private var availableYears: [Int] {
        let years = allJobs.compactMap { job -> Int? in
            guard let d = job.completedAt ?? job.scheduledDate else { return nil }
            return Calendar.current.component(.year, from: d)
        }
        let unique = Set(years).union([Calendar.current.component(.year, from: Date())])
        return unique.sorted().reversed()
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EBPSpacing.lg) {
                reportTypePicker
                yearPicker

                switch selectedReport {
                case .pnl:     pnlSection
                case .tax:     taxSection
                case .crew:    crewSection
                case .winRate: winRateSection
                }
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Pickers

    private var reportTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EBPSpacing.sm) {
                ForEach(ReportType.allCases) { type in
                    Button {
                        withAnimation(EBPAnimation.sectionSwitch) { selectedReport = type }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon).font(.caption)
                            Text(type.rawValue).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedReport == type ? EBPColor.primary : EBPColor.surface)
                        .foregroundStyle(selectedReport == type ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var yearPicker: some View {
        HStack {
            Text("Year")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Year", selection: $selectedYear) {
                ForEach(availableYears.isEmpty ? [Calendar.current.component(.year, from: Date())] : availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, EBPSpacing.sm)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }

    // MARK: - P&L Section

    private var pnlSection: some View {
        let data = pnlData(for: selectedYear)

        return VStack(alignment: .leading, spacing: EBPSpacing.md) {
            sectionHeader("Monthly P&L — \(selectedYear)", icon: "chart.bar.fill")

            // Annual summary
            HStack(spacing: 0) {
                pnlSummaryCell(label: "Revenue", value: data.map { $0.revenue }.reduce(0, +), color: .green)
                Divider().frame(height: 44)
                pnlSummaryCell(label: "Cost", value: data.map { $0.cost }.reduce(0, +), color: .orange)
                Divider().frame(height: 44)
                let totalRev = data.map { $0.revenue }.reduce(0, +)
                let totalCost = data.map { $0.cost }.reduce(0, +)
                let profit = totalRev - totalCost
                pnlSummaryCell(label: "Profit", value: profit, color: profit >= 0 ? .green : .red)
            }
            .padding(.vertical, EBPSpacing.sm)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))

            // Monthly bar chart
            if !data.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Revenue vs Cost by Month")
                        .font(.headline)

                    let chartData = data.flatMap { row -> [(month: String, value: Double, category: String)] in
                        [
                            (month: row.monthName, value: row.revenue, category: "Revenue"),
                            (month: row.monthName, value: row.cost, category: "Cost")
                        ]
                    }

                    Chart(chartData, id: \.month) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.value)
                        )
                        .foregroundStyle(item.category == "Revenue" ? Color.green.gradient : Color.orange.gradient)
                    }
                    .chartLegend(position: .bottom)
                    .chartXAxis {
                        AxisMarks { v in
                            AxisValueLabel { if let s = v.as(String.self) { Text(s).font(.caption2) } }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisValueLabel {
                                if let d = v.as(Double.self) { Text("$\(Int(d / 1000))k").font(.caption2) }
                            }
                        }
                    }
                    .frame(height: 220)
                }
                .ebpCard()
            }

            // Month table
            VStack(alignment: .leading, spacing: 0) {
                Text("Month Breakdown")
                    .font(.headline)
                    .padding(.bottom, 10)
                ForEach(data) { row in
                    Divider()
                    HStack {
                        Text(row.monthName)
                            .font(.subheadline)
                            .frame(width: 40, alignment: .leading)
                        Spacer()
                        Text(row.revenue.currencyFormatted)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(width: 80, alignment: .trailing)
                        Text(row.cost.currencyFormatted)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 80, alignment: .trailing)
                        Text((row.revenue - row.cost).currencyFormatted)
                            .font(.caption.weight(.bold))
                            .foregroundStyle((row.revenue - row.cost) >= 0 ? .green : .red)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 7)
                }
            }
            .ebpCard()
        }
    }

    private func pnlSummaryCell(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value.currencyFormatted).font(.subheadline.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EBPSpacing.xs)
    }

    private func crewSummaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EBPSpacing.xs)
    }

    // MARK: - Tax Section

    private var taxSection: some View {
        let year = selectedYear
        let yearJobs = allJobs.filter {
            guard let d = $0.completedAt ?? $0.scheduledDate else { return false }
            return Calendar.current.component(.year, from: d) == year
        }
        let yearInvoices = allInvoices.filter {
            Calendar.current.component(.year, from: $0.createdAt) == year
        }
        let totalRevenue = yearJobs.reduce(Decimal(0)) { $0 + $1.revenue }
        let totalMaterials = yearJobs.reduce(Decimal(0)) { $0 + $1.actualCost }
        let totalLaborHours = allTimeEntries.filter {
            Calendar.current.component(.year, from: $0.clockedIn) == year
        }.reduce(0) { $0 + $1.durationHours }
        let laborCostEst = Decimal(totalLaborHours * 45.0)
        let totalExpenses = totalMaterials + laborCostEst
        let netIncome = totalRevenue - totalExpenses

        return VStack(alignment: .leading, spacing: EBPSpacing.md) {
            sectionHeader("Tax Prep Summary — \(year)", icon: "doc.text.magnifyingglass")

            VStack(spacing: 0) {
                taxRow("Gross Revenue", value: totalRevenue, color: .green)
                Divider().padding(.leading, EBPSpacing.md)
                taxRow("Material Costs", value: totalMaterials, color: .orange, deduction: true)
                Divider().padding(.leading, EBPSpacing.md)
                taxRow("Labor Costs (est.)", value: laborCostEst, color: .orange, deduction: true)
                Divider()
                taxRow("Net Income", value: netIncome, color: netIncome >= 0 ? .green : .red, bold: true)
            }
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))

            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Estimated tax at 25% bracket")
                        .font(.subheadline.weight(.semibold))
                }
                let taxEst = max(Decimal(0), netIncome * Decimal(0.25))
                HStack {
                    Text("Estimated tax liability:")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(taxEst.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                }
                Text("Consult a CPA for accurate tax filing. This is an estimate only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(EBPSpacing.md)
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: EBPRadius.md))

            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                Text("Record Summary")
                    .font(.headline)
                taxInfoRow("Completed Jobs", "\(yearJobs.count)")
                taxInfoRow("Invoices Issued", "\(yearInvoices.count)")
                taxInfoRow("Tracked Labor Hours", String(format: "%.1f hrs", totalLaborHours))
            }
            .ebpCard()
        }
    }

    private func taxRow(_ label: String, value: Decimal, color: Color, deduction: Bool = false, bold: Bool = false) -> some View {
        HStack {
            if deduction {
                Text("–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 14)
            }
            Text(label)
                .font(bold ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value.formatted(.currency(code: "USD")))
                .font(bold ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(EBPSpacing.md)
    }

    private func taxInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Crew Section

    private var crewSection: some View {
        let yearEntries = allTimeEntries.filter {
            Calendar.current.component(.year, from: $0.clockedIn) == selectedYear
        }
        let names = Set(yearEntries.map { $0.crewMember }).sorted()
        let rows: [(name: String, hours: Double, sessions: Int, avgSession: Double)] = names.map { name in
            let entries = yearEntries.filter { $0.crewMember == name && !$0.isActive }
            let hours = entries.reduce(0) { $0 + $1.durationHours }
            let avg = entries.isEmpty ? 0 : hours / Double(entries.count)
            return (name: name, hours: hours, sessions: entries.count, avgSession: avg)
        }.sorted { $0.hours > $1.hours }
        let maxHours = rows.first?.hours ?? 1

        return VStack(alignment: .leading, spacing: EBPSpacing.md) {
            sectionHeader("Crew Performance — \(selectedYear)", icon: "person.3.fill")

            if rows.isEmpty {
                noDataState("No time tracking data for this year.\nClock in crew members from Job Detail to build this report.")
            } else {
                let totalHoursAll = rows.reduce(0) { $0 + $1.hours }
                HStack(spacing: 0) {
                    crewSummaryCell(label: "Total Hours", value: String(format: "%.1f h", totalHoursAll), color: EBPColor.primary)
                    Divider().frame(height: 44)
                    crewSummaryCell(label: "Est. Labor Cost", value: (totalHoursAll * 45).currencyFormatted, color: .orange)
                    Divider().frame(height: 44)
                    crewSummaryCell(label: "Crew Members", value: "\(rows.count)", color: .secondary)
                }
                .padding(.vertical, EBPSpacing.sm)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Hours by Crew Member")
                        .font(.headline)
                        .padding(.bottom, 10)

                    ForEach(rows, id: \.name) { row in
                        Divider()
                        VStack(spacing: 6) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(EBPColor.primary.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Text(String(row.name.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(EBPColor.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name.isEmpty ? "Unknown" : row.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(row.sessions) sessions · avg \(String(format: "%.1f", row.avgSession)) hrs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.1f hrs", row.hours))
                                        .font(.subheadline.weight(.bold))
                                    Text("$\(Int(row.hours * 45))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                    let pct = maxHours > 0 ? CGFloat(row.hours / maxHours) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(EBPColor.primary.gradient)
                                        .frame(width: geo.size.width * pct)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, EBPSpacing.sm)
                        .padding(.horizontal, EBPSpacing.xs)
                    }
                }
                .ebpCard()
            }
        }
    }

    // MARK: - Win Rate Section

    private var winRateSection: some View {
        let yearBids = allBids.filter {
            Calendar.current.component(.year, from: $0.createdAt) == selectedYear
        }
        let total   = yearBids.count
        let sent    = yearBids.filter { ["SENT", "VIEWED", "SIGNED", "DECLINED"].contains($0.status) }.count
        let signed  = yearBids.filter { $0.status == "SIGNED" }.count
        let declined = yearBids.filter { $0.status == "DECLINED" }.count
        let winRate = sent > 0 ? Int(Double(signed) / Double(sent) * 100) : 0

        let avgCloseTime: Double = {
            let closedBids = yearBids.filter { $0.status == "SIGNED" && $0.signedAt != nil && $0.sentAt != nil }
            guard !closedBids.isEmpty else { return 0 }
            let totalDays = closedBids.reduce(0.0) { acc, b in
                guard let sent = b.sentAt, let signed = b.signedAt else { return acc }
                return acc + signed.timeIntervalSince(sent) / 86400
            }
            return totalDays / Double(closedBids.count)
        }()

        let avgValue = signed > 0
            ? yearBids.filter { $0.status == "SIGNED" }.reduce(Decimal(0)) { $0 + $1.totalPrice } / Decimal(signed)
            : Decimal(0)

        let bySystem: [(system: String, total: Int, signed: Int)] = {
            let systems = Set(yearBids.map { $0.coatingSystem }).sorted()
            return systems.map { sys in
                let bids = yearBids.filter { $0.coatingSystem == sys }
                let sig = bids.filter { $0.status == "SIGNED" }.count
                return (system: sys.isEmpty ? "Unspecified" : sys, total: bids.count, signed: sig)
            }
        }()

        return VStack(alignment: .leading, spacing: EBPSpacing.md) {
            sectionHeader("Win Rate Analysis — \(selectedYear)", icon: "trophy.fill")

            if total == 0 {
                noDataState("No bids found for \(selectedYear).")
            } else {
                // KPI grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    winKPI(label: "Win Rate", value: "\(winRate)%", icon: "trophy.fill", color: winRate >= 50 ? .green : .orange)
                    winKPI(label: "Total Bids", value: "\(total)", icon: "doc.text.fill", color: EBPColor.primary)
                    winKPI(label: "Avg Close Time", value: avgCloseTime > 0 ? "\(String(format: "%.0f", avgCloseTime))d" : "—", icon: "clock.fill", color: .blue)
                    winKPI(label: "Avg Win Value", value: NSDecimalNumber(decimal: avgValue).doubleValue.currencyFormatted, icon: "dollarsign.circle.fill", color: .green)
                }

                // Funnel
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bid Funnel")
                        .font(.headline)

                    let stages: [(String, Int, Color)] = [
                        ("Created", total, .blue),
                        ("Sent",    sent,   EBPColor.primary),
                        ("Signed",  signed, .green),
                    ]
                    ForEach(stages, id: \.0) { label, value, color in
                        HStack(spacing: 12) {
                            Text(label).font(.subheadline).frame(width: 64, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                                    let pct = total > 0 ? CGFloat(value) / CGFloat(total) : 0
                                    RoundedRectangle(cornerRadius: 6).fill(color.gradient)
                                        .frame(width: geo.size.width * pct)
                                }
                            }
                            .frame(height: 28)
                            Text("\(value)").font(.subheadline.weight(.semibold)).frame(width: 32, alignment: .trailing)
                        }
                    }
                    if declined > 0 {
                        HStack(spacing: 12) {
                            Text("Declined").font(.subheadline).frame(width: 64, alignment: .leading)
                            Spacer()
                            Text("\(declined)").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                        }
                    }
                }
                .ebpCard()

                // Win rate by coating system
                if !bySystem.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Win Rate by System")
                            .font(.headline)
                            .padding(.bottom, 10)
                        ForEach(bySystem, id: \.system) { row in
                            Divider()
                            HStack {
                                Text(row.system)
                                    .font(.subheadline)
                                Spacer()
                                let rate = row.total > 0 ? Int(Double(row.signed) / Double(row.total) * 100) : 0
                                Text("\(row.signed)/\(row.total)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(rate)%")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(rate >= 50 ? .green : .orange)
                                    .frame(width: 42, alignment: .trailing)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .ebpCard()
                }
            }
        }
    }

    private func winKPI(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
            }
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            Image(systemName: icon).font(.title3).foregroundStyle(EBPColor.primary)
            Text(title).font(.title3.weight(.bold))
        }
    }

    private func noDataState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie").font(.largeTitle).foregroundStyle(.tertiary)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - P&L Data Model

    private struct PnlRow: Identifiable {
        var id: Int { monthIndex }
        var monthIndex: Int
        var monthName: String
        var revenue: Double
        var cost: Double
    }

    private func pnlData(for year: Int) -> [PnlRow] {
        let monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return (1...12).map { month in
            let jobs = allJobs.filter { job in
                guard let d = job.completedAt ?? job.scheduledDate else { return false }
                let c = Calendar.current
                return c.component(.year, from: d) == year && c.component(.month, from: d) == month
            }
            let rev = jobs.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.revenue).doubleValue }
            let cost = jobs.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1.actualCost).doubleValue }
            return PnlRow(monthIndex: month, monthName: monthNames[month - 1], revenue: rev, cost: cost)
        }
    }
}

