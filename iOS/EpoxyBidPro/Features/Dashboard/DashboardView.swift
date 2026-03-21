import SwiftUI
import SwiftData
import Charts

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
// Industrial Precision design — tonal layering, no borders, neon accents.

struct DashboardView: View {

    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var vm = AnalyticsViewModel()

    @Query(sort: \Lead.createdAt, order: .reverse) private var workflowLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var workflowBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var workflowMeasurements: [Measurement]
    @Query private var allMaterials: [Material]

    @State private var heroAppeared = false
    @State private var showBidBuilder = false
    @State private var showAddClient = false
    @State private var showNewInvoice = false

    // MARK: - Computed

    private var userInitials: String {
        let parts = authStore.userName.split(separator: " ").prefix(2)
        if parts.isEmpty { return "?" }
        return parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

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

    private var workflowSnapshot: WorkflowKPISnapshot {
        WorkflowKPIService.snapshot(
            leads: workflowLeads, bids: workflowBids,
            jobs: workflowJobs, invoices: workflowInvoices,
            measurements: workflowMeasurements
        )
    }

    private var nextAction: WorkflowNextAction {
        WorkflowKPIService.nextBestAction(from: workflowSnapshot)
    }

    private var activeJobs: [Job] {
        Array(workflowJobs.filter { !["COMPLETE", "INVOICED", "PAID"].contains($0.status) }.prefix(5))
    }

    private var todayInstalls: Int {
        workflowJobs.filter {
            guard let d = $0.scheduledDate else { return false }
            return Calendar.current.isDateInToday(d)
        }.count
    }

    private var todayFollowUps: Int {
        workflowLeads.filter {
            guard let d = $0.followUpDate else { return false }
            return Calendar.current.isDateInToday(d)
        }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: VerticalScrollOffsetKey.self,
                                value: geo.frame(in: .named("dash")).minY
                            )
                        }
                        .frame(height: 0)

                        VStack(spacing: 24) {
                            header
                                .padding(.top, 16)

                            nextActionCard

                            revenueCard
                                .opacity(heroAppeared ? 1 : 0)
                                .offset(y: heroAppeared ? 0 : 16)

                            todayStrip

                            quickActions

                            if !activeJobs.isEmpty {
                                jobsCarousel
                            }

                            activityFeed
                        }
                        .padding(.horizontal, EBPSpacing.page)
                        .padding(.bottom, 120)
                    }
                }
                .coordinateSpace(name: "dash")
                .onPreferenceChange(VerticalScrollOffsetKey.self) { offset in
                    workflowRouter.setDockCompact(offset < -40, for: .dashboard)
                }
                .refreshable { await vm.loadDashboard() }
            }
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) { heroAppeared = true }
            }
        }
        .task { await vm.loadDashboard() }
        .fullScreenCover(isPresented: $showBidBuilder) { BidBuilderView() }
        .sheet(isPresented: $showAddClient) { AddClientSheet() }
        .sheet(isPresented: $showNewInvoice) { CreateInvoiceSheet() }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: EBPColor.surfaceContainerLowest, location: 0),
                .init(color: EBPColor.surface, location: 0.5),
                .init(color: EBPColor.surfaceContainerLowest, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString.uppercased())
                    .font(EBPFont.labelSm)
                    .tracking(1.2)
                    .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.6))

                Text(greeting)
                    .font(EBPFont.title)
                    .foregroundStyle(EBPColor.onSurface)
            }

            Spacer()

            Button {
                workflowRouter.navigate(to: .settings, handoffMessage: "Open profile and settings")
            } label: {
                Text(userInitials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(EBPColor.onPrimary)
                    .frame(width: 44, height: 44)
                    .background(EBPColor.primaryGradient)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Next Action Card

    private var nextActionCard: some View {
        Button {
            if let target = nextAction.targetTab {
                workflowRouter.navigate(to: target, handoffMessage: nextAction.title)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(nextActionTint.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: nextAction.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(nextActionTint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(nextAction.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EBPColor.onSurface)

                    Text(nextAction.subtitle)
                        .font(.caption)
                        .foregroundStyle(EBPColor.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(nextActionTint.opacity(0.7))
                    .padding(8)
                    .background(nextActionTint.opacity(0.1), in: Circle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: EBPRadius.xl)
                    .fill(EBPColor.surfaceContainerHigh)
            )
            .ebpGhostBorder(radius: EBPRadius.xl)
        }
        .buttonStyle(.pressScale)
    }

    private var nextActionTint: Color {
        switch nextAction.kind {
        case .leads:      return EBPColor.primary
        case .bids:       return EBPColor.primaryContainer
        case .jobs:       return EBPColor.secondaryContainer
        case .collections: return EBPColor.error
        case .healthy:    return EBPColor.success
        }
    }

    // MARK: - Revenue Card

    private var revenueCard: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("REVENUE")
                        .font(EBPFont.labelSm)
                        .tracking(1.5)
                        .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.6))

                    Text(vm.dashboardData?.monthRevenue.currencyFormatted ?? "$0")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(EBPColor.onSurface)
                        .contentTransition(.numericText())

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("23.4% vs last month")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(EBPColor.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(EBPColor.success.opacity(0.12), in: Capsule())
                }

                Spacer()
            }

            sparkline

            HStack(spacing: 0) {
                statPill(
                    value: "\(vm.dashboardData?.openBids ?? workflowBids.filter { ["DRAFT", "SENT", "VIEWED"].contains($0.status) }.count)",
                    label: "Open Bids",
                    color: EBPColor.tertiary
                )
                pillDivider
                statPill(
                    value: "\(vm.dashboardData?.activeJobs ?? activeJobs.count)",
                    label: "Active Jobs",
                    color: EBPColor.primaryContainer
                )
                pillDivider
                statPill(
                    value: "\(workflowSnapshot.collectionRisks)",
                    label: "Overdue",
                    color: workflowSnapshot.collectionRisks > 0 ? EBPColor.secondaryContainer : EBPColor.success
                )
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.xl)
                    .fill(EBPColor.surfaceContainer)

                RoundedRectangle(cornerRadius: EBPRadius.xl)
                    .fill(
                        LinearGradient(
                            colors: [EBPColor.primaryContainer.opacity(0.06), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            }
        )
        .ebpGhostBorder(radius: EBPRadius.xl)
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var pillDivider: some View {
        Rectangle()
            .fill(EBPColor.outlineVariant.opacity(0.15))
            .frame(width: 1, height: 32)
    }

    // MARK: - Sparkline

    private struct SparkPoint: Identifiable {
        let id = UUID()
        let day: Date
        let amount: Double
    }

    private var sparklineData: [SparkPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let total = workflowBids
                .filter { cal.isDate($0.createdAt, inSameDayAs: day) }
                .reduce(0.0) { $0 + Double(truncating: $1.totalPrice as NSNumber) }
            return SparkPoint(day: day, amount: total)
        }
    }

    private var sparkline: some View {
        Chart(sparklineData) { point in
            AreaMark(x: .value("Day", point.day), y: .value("$", point.amount))
                .foregroundStyle(
                    LinearGradient(
                        colors: [EBPColor.primaryContainer.opacity(0.25), EBPColor.primaryContainer.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

            LineMark(x: .value("Day", point.day), y: .value("$", point.amount))
                .foregroundStyle(EBPColor.primaryContainer.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...(sparklineData.map(\.amount).max().map { $0 * 1.3 } ?? 100))
        .frame(height: 48)
    }

    // MARK: - Today Strip

    private var todayStrip: some View {
        HStack(spacing: 10) {
            todayChip(icon: "calendar", value: "\(todayFollowUps)", label: "Follow-ups", tint: EBPColor.primary)
            todayChip(icon: "wrench.and.screwdriver", value: "\(todayInstalls)", label: "Installs", tint: EBPColor.primaryContainer)
            todayChip(icon: "exclamationmark.triangle", value: "\(workflowSnapshot.atRiskJobs)", label: "At Risk", tint: EBPColor.secondaryContainer)
            todayChip(icon: "scan.3d", value: "\(workflowSnapshot.scansThisWeek)", label: "Scans", tint: EBPColor.tertiary)
        }
    }

    private func todayChip(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint.opacity(0.8))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(EBPColor.onSurface)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: EBPRadius.md)
                .fill(EBPColor.surfaceContainerHigh)
        )
        .ebpGhostBorder(radius: EBPRadius.md)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            actionButton(icon: "person.2.fill", label: "Pipeline", color: EBPColor.primaryContainer) {
                workflowRouter.navigate(to: .clients, handoffMessage: "Review lead pipeline")
            }
            actionButton(icon: "doc.badge.plus", label: "New Bid", color: EBPColor.tertiary) {
                showBidBuilder = true
            }
            actionButton(icon: "person.badge.plus", label: "Client", color: EBPColor.secondaryContainer) {
                showAddClient = true
            }
            actionButton(icon: "dollarsign.circle.fill", label: "Invoice", color: EBPColor.success) {
                showNewInvoice = true
            }
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.trigger(.light)
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Text(label)
                    .font(EBPFont.labelSm)
                    .foregroundStyle(EBPColor.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: EBPRadius.lg)
                    .fill(EBPColor.surfaceContainerHigh)
            )
            .ebpGhostBorder(radius: EBPRadius.lg)
        }
        .buttonStyle(.pressScale)
    }

    // MARK: - Jobs Carousel

    private var jobsCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Active Jobs")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(EBPColor.onSurface)

                Spacer()

                Button {
                    workflowRouter.navigate(to: .jobs, handoffMessage: "Open jobs board")
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EBPColor.primary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeJobs, id: \.id) { job in
                        Button {
                            workflowRouter.navigate(to: .jobs, handoffMessage: "Open \(job.title.isEmpty ? job.jobNumber : job.title)")
                        } label: {
                            jobTile(job)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func jobTile(_ job: Job) -> some View {
        let progress = checklistProgress(for: job)
        let statusColor = WorkflowStatusPalette.job(job.status)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(jobStatusLabel(job.status))
                    .font(EBPFont.micro)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12), in: Capsule())

                Spacer()

                if let date = job.scheduledDate {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.6))
                }
            }

            Text(job.title.isEmpty ? job.jobNumber : job.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EBPColor.onSurface)
                .lineLimit(2)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(EBPColor.surfaceContainerHighest)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(statusColor)
                            .frame(width: max(geo.size.width * progress, 2))
                    }
                }
                .frame(height: 4)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.5))
            }
        }
        .frame(width: 170, height: 130)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: EBPRadius.lg)
                .fill(EBPColor.surfaceContainerHigh)
        )
        .ebpGhostBorder(radius: EBPRadius.lg)
    }

    // MARK: - Activity Feed

    private var activityFeed: some View {
        Group {
            if let activity = vm.dashboardData?.recentActivity, !activity.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Recent Activity")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(EBPColor.onSurface)

                    VStack(spacing: 0) {
                        ForEach(Array(activity.prefix(5).enumerated()), id: \.element.id) { idx, item in
                            Button {
                                if let target = routeTab(for: item.entityType) {
                                    workflowRouter.navigate(to: target, handoffMessage: item.description ?? "Open details")
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: activityIcon(for: item.entityType))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(activityColor(for: item.entityType))
                                        .frame(width: 36, height: 36)
                                        .background(activityColor(for: item.entityType).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.description ?? item.action ?? "Activity")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(EBPColor.onSurface)
                                            .lineLimit(1)

                                        if let date = item.createdAt {
                                            Text(date.relativeFormatted)
                                                .font(.caption2)
                                                .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.5))
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(EBPColor.outlineVariant)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)

                            if idx < min(4, activity.count - 1) {
                                // Spacing instead of divider line (No-Line Rule)
                                Spacer().frame(height: 1)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: EBPRadius.lg)
                            .fill(EBPColor.surfaceContainerHigh)
                    )
                    .ebpGhostBorder(radius: EBPRadius.lg)
                }
            }
        }
    }

    // MARK: - Helpers

    private func checklistProgress(for job: Job) -> Double {
        let total = job.checklistItems.count
        guard total > 0 else { return 0 }
        return Double(job.checklistItems.filter { $0.isComplete }.count) / Double(total)
    }

    private func jobStatusLabel(_ status: String) -> String {
        switch status {
        case "SCHEDULED":   return "Scheduled"
        case "IN_PROGRESS": return "In Progress"
        case "PUNCH_LIST":  return "Punch List"
        case "COMPLETE":    return "Complete"
        case "INVOICED":    return "Invoiced"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func activityIcon(for type: String?) -> String {
        switch type {
        case "bid":     return "doc.text.fill"
        case "job":     return "hammer.fill"
        case "invoice": return "dollarsign.circle.fill"
        case "client":  return "person.fill"
        default:        return "bell.fill"
        }
    }

    private func activityColor(for type: String?) -> Color {
        switch type {
        case "bid":     return EBPColor.tertiary
        case "job":     return EBPColor.primaryContainer
        case "invoice": return EBPColor.success
        case "client":  return EBPColor.secondaryContainer
        default:        return EBPColor.primary
        }
    }

    private func routeTab(for entityType: String?) -> WorkflowRouter.RouteTab? {
        switch entityType {
        case "bid":     return .jobs
        case "job":     return .jobs
        case "invoice": return .settings
        case "client":  return .clients
        default:        return .dashboard
        }
    }
}
