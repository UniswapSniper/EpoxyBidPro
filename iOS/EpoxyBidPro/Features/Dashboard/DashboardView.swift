import SwiftUI
import SwiftData
import Charts

// ─── REDESIGNED DASHBOARD ─────────────────────────────────────────────────────
// Modern, bold, beautiful dashboard for epoxy floor contractors

struct DashboardView: View {

    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var workflowLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var workflowBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var workflowMeasurements: [Measurement]
    @Query private var allMaterials: [Material]
    @Query(sort: \Client.createdAt, order: .reverse) private var recentClients: [Client]

    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var vm = AnalyticsViewModel()
    @State private var heroAppeared = false
    @State private var animateBackground = false
    
    // Quick Action States
    @State private var showBidBuilder = false
    @State private var showAddClient = false
    @State private var showNewInvoice = false

    private var userInitials: String {
        let name = authStore.userName
        let parts = name.split(separator: " ").prefix(2)
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
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var workflowSnapshot: WorkflowKPISnapshot {
        WorkflowKPIService.snapshot(
            leads: workflowLeads,
            bids: workflowBids,
            jobs: workflowJobs,
            invoices: workflowInvoices,
            measurements: workflowMeasurements
        )
    }

    private var nextAction: WorkflowNextAction {
        WorkflowKPIService.nextBestAction(from: workflowSnapshot)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Epic Background ─────────────────────────────────────────
                dynamicBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: EBPSpacing.xl) {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: VerticalScrollOffsetKey.self,
                                    value: geo.frame(in: .named("dashboardScroll")).minY
                                )
                        }
                        .frame(height: 0)
                        
                        // ── Floating Header ─────────────────────────────────
                        floatingHeader
                            .padding(.top, 20)

                        WorkflowKPIBanner(snapshot: workflowSnapshot)
                            .padding(.horizontal, EBPSpacing.md)

                        WorkflowNextActionBanner(action: nextAction) { target in
                            workflowRouter.navigate(to: target, handoffMessage: nextAction.title)
                        }
                        .padding(.horizontal, EBPSpacing.md)

                        todayBoardCard
                            .padding(.horizontal, EBPSpacing.md)

                        // ── MATERIAL COST ALERT ─────────────────────────────
                        if !allMaterials.isEmpty {
                            let unsyncedCount = allMaterials.filter { !$0.isSynced }.count
                            if unsyncedCount > 0 {
                                materialCostAlert(count: unsyncedCount)
                                    .padding(.horizontal, EBPSpacing.md)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }

                        // ── HERO REVENUE CARD ───────────────────────────────
                        heroRevenueCard
                            .padding(.horizontal, EBPSpacing.md)
                            .scaleEffect(heroAppeared ? 1.0 : 0.95)
                            .opacity(heroAppeared ? 1 : 0)
                            .animation(EBPAnimation.handoff.delay(0.1), value: heroAppeared)
                        
                        // ── RECENTLY VIEWED ─────────────────────────────────
                        recentlyViewedRow

                        // ── POWER ACTIONS ───────────────────────────────────
                        powerActionsSection
                            .padding(.horizontal, EBPSpacing.md)
                        
                        // ── LIVE METRICS ────────────────────────────────────
                        liveMetricsGrid
                            .padding(.horizontal, EBPSpacing.md)
                        
                        // ── ACTIVE JOBS ─────────────────────────────────────
                        activeJobsSection
                        
                        // ── ACTIVITY FEED ───────────────────────────────────
                        activityFeed
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical, EBPSpacing.lg)
                }
                .coordinateSpace(name: "dashboardScroll")
                .onPreferenceChange(VerticalScrollOffsetKey.self) { offset in
                    workflowRouter.setDockCompact(offset < -40, for: .dashboard)
                }
                .refreshable { await vm.loadDashboard() }
            }
            .navigationBarHidden(true)
            .onAppear {
                heroAppeared = true
                withAnimation(EBPAnimation.ambient.repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }
        }
        .task { await vm.loadDashboard() }
        // ── Sheets ───────────────────────────────────────────────────────────
        .fullScreenCover(isPresented: $showBidBuilder) { BidBuilderView() }
        .sheet(isPresented: $showAddClient) { AddClientSheet() }
        .sheet(isPresented: $showNewInvoice) { CreateInvoiceSheet() }
    }
    
    // MARK: - Dynamic Background
    
    private var dynamicBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated orbs
            GeometryReader { geo in
                ZStack {
                    // Cyan glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: animateBackground ? -130 : -80, y: animateBackground ? -130 : -80)
                        .scaleEffect(animateBackground ? 1.05 : 0.95)
                    
                    // Blue accent glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(
                            x: animateBackground ? geo.size.width - 140 : geo.size.width - 80,
                            y: animateBackground ? geo.size.height - 240 : geo.size.height - 170
                        )
                        .scaleEffect(animateBackground ? 1.08 : 0.92)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Floating Header
    
    private var floatingHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateString)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("\(greeting) 👋")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Profile button
            Button {
                workflowRouter.navigate(to: .more, handoffMessage: "Open company profile and settings")
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(userInitials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.cyan.opacity(0.5), radius: 10)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
    }
    
    // MARK: - Hero Revenue Card

    private var todayBoardCard: some View {
        let todayInstalls = workflowJobs.filter {
            guard let date = $0.scheduledDate else { return false }
            return Calendar.current.isDateInToday(date)
        }.count

        let todayFollowUps = workflowLeads.filter {
            guard let follow = $0.followUpDate else { return false }
            return Calendar.current.isDateInToday(follow)
        }.count

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("Today Board")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: EBPSpacing.sm) {
                todayCell("Visits", value: "\(todayFollowUps)", tint: .blue)
                todayCell("Installs", value: "\(todayInstalls)", tint: EBPColor.accent)
                todayCell("At Risk", value: "\(workflowSnapshot.atRiskJobs)", tint: EBPColor.warning)
                todayCell("Overdue", value: "\(workflowSnapshot.collectionRisks)", tint: EBPColor.danger)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
    }

    private func todayCell(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }
    
    private var heroRevenueCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                        Text("MONTHLY REVENUE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    
                    Text(vm.dashboardData?.monthRevenue.currencyFormatted ?? "$0")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color.cyan.opacity(0.5), radius: 20)
                    
                    // Growth indicator
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.bold))
                        Text("+23.4% vs last month")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
                }
                
                Spacer()
            }
            
            Divider()
                .background(.white.opacity(0.1))
            
            // Quick stats row
            HStack(spacing: 20) {
                quickStat(value: "\(vm.dashboardData?.openBids ?? 0)", label: "Open Bids")
                Divider().frame(height: 30).background(.white.opacity(0.1))
                quickStat(value: "\(vm.dashboardData?.activeJobs ?? 0)", label: "Active Jobs")
                Divider().frame(height: 30).background(.white.opacity(0.1))
                quickStat(value: "$\(Int((vm.dashboardData?.monthRevenue ?? 0) / 1000))K", label: "This Month")
            }

            // 7-day revenue sparkline
            revenueSparkline
        }
        .padding(28)
        .background(
            ZStack {
                // Glass effect
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Gradient border
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color.cyan.opacity(0.2), radius: 30, y: 10)
    }
    
    private func quickStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Material Cost Alert

    private func materialCostAlert(count: Int) -> some View {
        Button {
            workflowRouter.navigate(to: .more, handoffMessage: "Review unsynced material prices")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) material price\(count == 1 ? "" : "s") not synced")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Bids using these may have inaccurate costs — tap to review")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.12))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recently Viewed

    private enum RecentItem: Identifiable {
        case bid(Bid)
        case job(Job)
        case client(Client)

        var id: UUID {
            switch self {
            case .bid(let b): return b.id
            case .job(let j): return j.id
            case .client(let c): return c.id
            }
        }

        var icon: String {
            switch self {
            case .bid: return "doc.text.fill"
            case .job: return "hammer.fill"
            case .client: return "person.fill"
            }
        }

        var title: String {
            switch self {
            case .bid(let b): return b.title.isEmpty ? b.bidNumber : b.title
            case .job(let j): return j.title.isEmpty ? "Job" : j.title
            case .client(let c): return c.displayName
            }
        }

        var subtitle: String {
            switch self {
            case .bid(let b): return b.status.capitalized
            case .job(let j): return j.status.replacingOccurrences(of: "_", with: " ").capitalized
            case .client(let c): return c.clientType.capitalized
            }
        }

        var tint: Color {
            switch self {
            case .bid: return .purple
            case .job: return .orange
            case .client: return .cyan
            }
        }

        var date: Date {
            switch self {
            case .bid(let b): return b.createdAt
            case .job(let j): return j.createdAt
            case .client(let c): return c.createdAt
            }
        }
    }

    private var recentItems: [RecentItem] {
        let bids   = workflowBids.prefix(5).map   { RecentItem.bid($0) }
        let jobs   = workflowJobs.prefix(5).map   { RecentItem.job($0) }
        let clients = recentClients.prefix(5).map { RecentItem.client($0) }
        return (bids + jobs + clients)
            .sorted { $0.date > $1.date }
            .prefix(8)
            .map { $0 }
    }

    private var recentlyViewedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently Active")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, EBPSpacing.md)

            if recentItems.isEmpty {
                Text("No recent activity yet.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, EBPSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentItems) { item in
                            recentItemChip(item)
                        }
                    }
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func recentItemChip(_ item: RecentItem) -> some View {
        Button {
            switch item {
            case .bid:    workflowRouter.navigate(to: .bids, handoffMessage: "Opening recent bid")
            case .job:    workflowRouter.navigate(to: .jobs, handoffMessage: "Opening recent job")
            case .client: workflowRouter.navigate(to: .crm,  handoffMessage: "Opening recent client")
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.tint)
                    Text(item.subtitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(item.tint.opacity(0.8))
                        .lineLimit(1)
                }
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: 120, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(item.tint.opacity(0.1))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .stroke(item.tint.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Revenue Sparkline

    private struct SparkPoint: Identifiable {
        let id = UUID()
        let day: Date
        let amount: Double
    }

    private var sparklineData: [SparkPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset -> SparkPoint in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let total = workflowBids
                .filter { cal.isDate($0.createdAt, inSameDayAs: day) }
                .reduce(0.0) { $0 + Double(truncating: $1.totalPrice as NSNumber) }
            return SparkPoint(day: day, amount: total)
        }
    }

    private var revenueSparkline: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("7-Day Bid Activity")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                let total7 = sparklineData.reduce(0) { $0 + $1.amount }
                if total7 > 0 {
                    Text(total7, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.9))
                }
            }

            Chart(sparklineData) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Amount", point.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Amount", point.amount)
                )
                .foregroundStyle(Color.cyan)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Amount", point.amount)
                )
                .foregroundStyle(Color.cyan)
                .symbolSize(point.amount > 0 ? 20 : 8)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...(sparklineData.map(\.amount).max().map { $0 * 1.2 } ?? 100))
            .frame(height: 44)
        }
    }
    
    // MARK: - Power Actions
    
    private var powerActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                powerAction(
                    icon: "person.2",
                    title: "CRM Pipeline",
                    subtitle: "Follow Up Leads",
                    gradient: [Color.cyan, Color.blue],
                    action: {
                        workflowRouter.navigate(to: .crm, handoffMessage: "Review lead pipeline and follow-ups")
                    }
                )
                
                powerAction(
                    icon: "doc.badge.plus",
                    title: "New Bid",
                    subtitle: "Create Quote",
                    gradient: [Color.purple, Color.pink],
                    action: { showBidBuilder = true }
                )
                
                powerAction(
                    icon: "person.badge.plus",
                    title: "Add Client",
                    subtitle: "New Contact",
                    gradient: [Color.orange, Color.red],
                    action: { showAddClient = true }
                )
                
                powerAction(
                    icon: "dollarsign.circle",
                    title: "Invoice",
                    subtitle: "Bill Client",
                    gradient: [Color.green, Color.teal],
                    action: { showNewInvoice = true }
                )
            }
        }
    }
    
    private func powerAction(icon: String, title: String, subtitle: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.trigger(.light)
            withAnimation(EBPAnimation.snappy) {
                action()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.5) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: gradient.first!.opacity(0.3), radius: 15, y: 8)
        }
        .buttonStyle(.pressScale)
    }
    
    // MARK: - Live Metrics
    
    private var liveMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                metricCard(
                    value: "\(vm.dashboardData?.activeJobs ?? 0)",
                    label: "Active Jobs",
                    icon: "hammer.fill",
                    color: .cyan
                )
                
                metricCard(
                    value: "\(vm.dashboardData?.openBids ?? 0)",
                    label: "Open Bids",
                    icon: "doc.text.fill",
                    color: .purple
                )
                
                metricCard(
                    value: "$\(Int((vm.dashboardData?.monthRevenue ?? 0) / 1000))K",
                    label: "Revenue",
                    icon: "chart.bar.fill",
                    color: .green
                )
                
                metricCard(
                    value: vm.dashboardData?.overdueInvoices ?? 0 > 0 ? "\(vm.dashboardData?.overdueInvoices ?? 0)" : "✓",
                    label: "Invoices",
                    icon: vm.dashboardData?.overdueInvoices ?? 0 > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    color: vm.dashboardData?.overdueInvoices ?? 0 > 0 ? .orange : .green
                )
            }
        }
    }
    
    private func metricCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(height: 120)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            }
        )
    }
    
    // MARK: - Active Jobs
    
    private var activeJobsSection: some View {
        let activeJobs = workflowJobs
            .filter { !["COMPLETE", "INVOICED"].contains($0.status) }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Jobs")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    workflowRouter.navigate(to: .jobs, handoffMessage: "Open active jobs board")
                } label: {
                    Text("See All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, EBPSpacing.md)
            
            if activeJobs.isEmpty {
                HStack(spacing: EBPSpacing.sm) {
                    Image(systemName: "hammer.circle")
                        .foregroundStyle(.white.opacity(0.75))
                    Text("No active jobs yet. Create your first job from a signed bid.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                .padding(EBPSpacing.md)
                .ebpGlassmorphism(cornerRadius: EBPRadius.md)
                .padding(.horizontal, EBPSpacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(activeJobs), id: \.id) { job in
                            Button {
                                workflowRouter.navigate(to: .jobs, handoffMessage: "Open \(job.title.isEmpty ? job.jobNumber : job.title)")
                            } label: {
                                jobCard(
                                    title: job.title.isEmpty ? job.jobNumber : job.title,
                                    status: jobStatusLabel(job.status),
                                    progress: checklistProgress(for: job),
                                    dueDate: job.scheduledDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unscheduled"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, EBPSpacing.md)
                }
            }
        }
    }
    
    private func jobCard(title: String, status: String, progress: Double, dueDate: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.cyan)
                Spacer()
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }
            
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(dueDate)
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
        .frame(width: 200, height: 180)
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        )
    }
    
    // MARK: - Activity Feed
    
    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, EBPSpacing.md)
            
            if let activity = vm.dashboardData?.recentActivity, !activity.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(activity.prefix(5).enumerated()), id: \.element.id) { idx, item in
                        Button {
                            if let target = routeTab(for: item.entityType) {
                                workflowRouter.navigate(to: target, handoffMessage: item.description ?? "Open workflow details")
                            }
                        } label: {
                            activityRow(item: item)
                        }
                        .buttonStyle(.plain)
                        if idx < min(4, activity.count - 1) {
                            Divider()
                                .background(.white.opacity(0.05))
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal, EBPSpacing.md)
            }
        }
    }
    
    private func activityRow(item: ActivityItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(activityColor(for: item.entityType).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: activityIcon(for: item.entityType))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(activityColor(for: item.entityType))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description ?? item.action ?? "Activity")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                if let date = item.createdAt {
                    Text(date.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        case "bid":     return .purple
        case "job":     return .cyan
        case "invoice": return .green
        case "client":  return .orange
        default:        return .blue
        }
    }

    private func routeTab(for entityType: String?) -> WorkflowRouter.RouteTab? {
        switch entityType {
        case "bid":
            return .bids
        case "job":
            return .jobs
        case "invoice":
            return .more
        case "client":
            return .crm
        default:
            return .dashboard
        }
    }

    private func checklistProgress(for job: Job) -> Double {
        let total = job.checklistItems.count
        guard total > 0 else { return 0 }
        let completed = job.checklistItems.filter { $0.isComplete }.count
        return Double(completed) / Double(total)
    }

    private func jobStatusLabel(_ status: String) -> String {
        switch status {
        case "SCHEDULED": return "Scheduled"
        case "IN_PROGRESS": return "In Progress"
        case "PUNCH_LIST": return "Punch List"
        case "COMPLETE": return "Complete"
        case "INVOICED": return "Invoiced"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
