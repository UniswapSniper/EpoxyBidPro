import SwiftUI

struct DashboardView: View {

    @StateObject private var vm = AnalyticsViewModel()
    @State private var kpiAppeared = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                    // ── Hero Header ─────────────────────────────────────────
                    heroBanner

                    // ── Revenue Banner ──────────────────────────────────────
                    if let d = vm.dashboardData {
                        EBPRevenueBanner(
                            label: "This Month's Revenue",
                            amount: d.monthRevenue.currencyFormatted,
                            subtitle: "\(d.openBids) open bids in pipeline"
                        )
                        .ebpHPadding()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    // ── KPI Grid ────────────────────────────────────────────
                    if let d = vm.dashboardData {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: EBPSpacing.sm), GridItem(.flexible(), spacing: EBPSpacing.sm)],
                            spacing: EBPSpacing.sm
                        ) {
                            EBPStatCard(
                                title: "Active Jobs",
                                value: "\(d.activeJobs)",
                                icon: "hammer.fill",
                                tint: .blue
                            )
                            .scaleEffect(kpiAppeared ? 1 : 0.85)
                            .opacity(kpiAppeared ? 1 : 0)
                            .animation(EBPAnimation.bouncy.delay(0.05), value: kpiAppeared)

                            EBPStatCard(
                                title: "Open Bids",
                                value: "\(d.openBids)",
                                icon: "doc.text.fill",
                                tint: EBPColor.warning
                            )
                            .scaleEffect(kpiAppeared ? 1 : 0.85)
                            .opacity(kpiAppeared ? 1 : 0)
                            .animation(EBPAnimation.bouncy.delay(0.10), value: kpiAppeared)

                            EBPStatCard(
                                title: "Overdue Invoices",
                                value: "\(d.overdueInvoices)",
                                icon: d.overdueInvoices > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                                tint: d.overdueInvoices > 0 ? EBPColor.danger : EBPColor.success,
                                isAlert: d.overdueInvoices > 0
                            )
                            .scaleEffect(kpiAppeared ? 1 : 0.85)
                            .opacity(kpiAppeared ? 1 : 0)
                            .animation(EBPAnimation.bouncy.delay(0.15), value: kpiAppeared)

                            NavigationLink(destination: AnalyticsView()) {
                                analyticsShortcutCard
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(kpiAppeared ? 1 : 0.85)
                            .opacity(kpiAppeared ? 1 : 0)
                            .animation(EBPAnimation.bouncy.delay(0.20), value: kpiAppeared)
                        }
                        .ebpHPadding()
                    }

                    // ── Quick Actions ───────────────────────────────────────
                    quickActionsRow

                    // ── Recent Activity ─────────────────────────────────────
                    if let activity = vm.dashboardData?.recentActivity, !activity.isEmpty {
                        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                            EBPSectionHeader(title: "Recent Activity")
                                .ebpHPadding()

                            VStack(spacing: 0) {
                                ForEach(Array(activity.prefix(5).enumerated()), id: \.element.id) { idx, item in
                                    activityRow(item: item)
                                    if idx < min(4, activity.count - 1) {
                                        EBPDivider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                            .ebpShadowSubtle()
                            .ebpHPadding()
                        }
                    }

                    // ── Loading State ───────────────────────────────────────
                    if vm.isLoading && vm.dashboardData == nil {
                        loadingPlaceholder
                    }

                    // ── Error ───────────────────────────────────────────────
                    if let err = vm.errorMessage {
                        HStack(spacing: EBPSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(EBPColor.warning)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .ebpHPadding()
                    }

                    Spacer(minLength: 88) // clearance for floating LiDAR FAB
                }
                .padding(.vertical, EBPSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    profileButton
                }
            }
            .refreshable { await vm.loadDashboard() }
        }
        .task {
            await vm.loadDashboard()
            withAnimation { kpiAppeared = true }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Here's your\nbusiness today.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(EBPColor.primary.opacity(0.08))
                    .frame(width: 58, height: 58)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .ebpHPadding()
        .padding(.top, EBPSpacing.xs)
    }

    // MARK: - Analytics Shortcut Card

    private var analyticsShortcutCard: some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(EBPColor.primary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(EBPColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Analytics")
                    .font(EBPFont.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    Text("View All")
                        .font(.headline)
                        .foregroundStyle(EBPColor.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(EBPColor.primary.opacity(0.7))
                }
            }
            Spacer()
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            EBPSectionHeader(title: "Quick Actions")
                .ebpHPadding()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EBPSpacing.sm) {
                    quickAction(icon: "doc.text.badge.plus", label: "New Bid",     tint: EBPColor.primary)
                    quickAction(icon: "ruler",               label: "New Scan",    tint: Color.indigo)
                    quickAction(icon: "person.badge.plus",   label: "Add Client",  tint: EBPColor.success)
                    quickAction(icon: "dollarsign.circle",   label: "New Invoice", tint: EBPColor.warning)
                }
                .padding(.horizontal, EBPSpacing.md)
            }
        }
    }

    private func quickAction(icon: String, label: String, tint: Color) -> some View {
        VStack(spacing: EBPSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(tint.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: 76)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Activity Row

    private func activityRow(item: ActivityItem) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                Circle()
                    .fill(EBPColor.primary.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: activityIcon(for: item.entityType))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EBPColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description ?? item.action ?? "Activity")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let date = item.createdAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, 10)
    }

    private func activityIcon(for type: String?) -> String {
        switch type {
        case "bid":     return "doc.text"
        case "job":     return "hammer"
        case "invoice": return "dollarsign.circle"
        case "client":  return "person"
        default:        return "bell"
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        ZStack {
            Circle()
                .fill(EBPColor.primary.opacity(0.10))
            Text("J")
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.primary)
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: EBPSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .fill(Color(.systemFill))
                    .frame(height: 72)
                    .shimmer()
            }
        }
        .ebpHPadding()
    }
}

// ─── Shimmer Effect ───────────────────────────────────────────────────────────

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear,                     location: phase - 0.3),
                        .init(color: .white.opacity(0.45),       location: phase),
                        .init(color: .clear,                     location: phase + 0.3),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

