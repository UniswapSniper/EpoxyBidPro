import SwiftUI

struct DashboardView: View {

    @StateObject private var vm = AnalyticsViewModel()

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                    // ── Hero Header ─────────────────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Here's your business\ntoday.")
                                .font(.title.bold())
                                .foregroundStyle(EBPColor.primary)
                        }
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 40))
                            .foregroundStyle(EBPColor.primary.opacity(0.18))
                    }
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.top, EBPSpacing.md)

                    // ── Month Revenue Banner ────────────────────────────────
                    if let d = vm.dashboardData {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This Month's Revenue")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(d.monthRevenue.currencyFormatted)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EBPSpacing.lg)
                        .background(
                            LinearGradient(
                                colors: [EBPColor.primary, Color(red: 0.10, green: 0.50, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .padding(.horizontal, EBPSpacing.md)
                    }

                    // ── KPI Grid ────────────────────────────────────────────
                    if let d = vm.dashboardData {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            dashKPI(
                                title: "Active Jobs",
                                value: "\(d.activeJobs)",
                                icon: "hammer.fill",
                                color: .blue,
                                alert: false
                            )
                            dashKPI(
                                title: "Open Bids",
                                value: "\(d.openBids)",
                                icon: "doc.text.fill",
                                color: .orange,
                                alert: false
                            )
                            dashKPI(
                                title: "Overdue Invoices",
                                value: "\(d.overdueInvoices)",
                                icon: "exclamationmark.circle.fill",
                                color: d.overdueInvoices > 0 ? .red : .green,
                                alert: d.overdueInvoices > 0
                            )
                            NavigationLink(destination: AnalyticsView()) {
                                HStack(spacing: 10) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title2)
                                        .foregroundStyle(EBPColor.primary)
                                        .frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Analytics")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("View All →")
                                            .font(.headline)
                                            .foregroundStyle(EBPColor.primary)
                                    }
                                }
                                .padding(EBPSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EBPColor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, EBPSpacing.md)
                    }

                    // ── Recent Activity ─────────────────────────────────────
                    if let activity = vm.dashboardData?.recentActivity, !activity.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Recent Activity")
                                .font(.headline)
                                .padding(.bottom, 10)

                            ForEach(activity) { item in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(EBPColor.primary.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.description ?? item.action ?? "Activity")
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        if let date = item.createdAt {
                                            Text(date, style: .relative)
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                        }
                        .padding(EBPSpacing.md)
                        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, EBPSpacing.md)
                    }

                    // ── Loading / Error ─────────────────────────────────────
                    if vm.isLoading && vm.dashboardData == nil {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    }

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.caption).foregroundStyle(.red)
                            .padding(.horizontal, EBPSpacing.md)
                    }

                    Spacer(minLength: 80) // clearance for floating LiDAR button
                }
                .padding(.bottom, EBPSpacing.lg)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await vm.loadDashboard()
            }
        }
        .task {
            await vm.loadDashboard()
        }
    }

    @ViewBuilder
    private func dashKPI(title: String, value: String, icon: String, color: Color, alert: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(.title3.bold())
                    if alert {
                        Image(systemName: "exclamationmark")
                            .font(.caption.bold())
                            .foregroundStyle(color)
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}
