import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable, CaseIterable {
        case dashboard, crm, bids, jobs, more

        var displayName: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .crm: return "CRM"
            case .bids: return "Bids"
            case .jobs: return "Jobs"
            case .more: return "More"
            }
        }
    }

    enum DockHaptic {
        case light
        case medium
        case heavy
        case soft
        case rigid
        case success
    }

    @State private var selectedTab: Tab = .bids
    @State private var presentingScan = false
    @State private var presentingBidBuilder = false
    @State private var presentingCreateJob = false
    @State private var presentingCreateInvoice = false
    @StateObject private var workflowRouter = WorkflowRouter()
    @StateObject private var reachability = ReachabilityMonitor()
    @AppStorage("hasSeenCompactDockHint") private var hasSeenCompactDockHint = false
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
    @State private var showCompactDockHint = false
    @State private var showTooltipOverlay = false
    @State private var tooltipIndex = 0
    @State private var routeHandoffAnimating = false
    @State private var routeHandoffTab: Tab? = nil

    private struct TooltipStep {
        let tab: Tab
        let title: String
        let message: String
    }

    private var tooltipSteps: [TooltipStep] {
        [
            TooltipStep(
                tab: .dashboard,
                title: "Start on Dashboard",
                message: "Use Quick Actions for your most common tasks and check the KPI banner before you begin your day."
            ),
            TooltipStep(
                tab: .crm,
                title: "Work Your Follow-Ups",
                message: "Pipeline and AI Follow-Up Queue keep leads moving. Prioritize overdue follow-ups first."
            ),
            TooltipStep(
                tab: .bids,
                title: "Scan to Bid Fast",
                message: "Run Scan Space, then Build From Scan to prefill pricing and scope in one flow."
            ),
            TooltipStep(
                tab: .jobs,
                title: "Execute Without Gaps",
                message: "Create jobs from signed bids and use risk filters to catch schedule or margin issues early."
            ),
            TooltipStep(
                tab: .more,
                title: "Configure Operations",
                message: "Use More for invoicing, business profile, app language, and account settings."
            ),
        ]
    }

    private var currentTooltipStep: TooltipStep {
        tooltipSteps[min(tooltipIndex, tooltipSteps.count - 1)]
    }

    private var activeRouteTab: WorkflowRouter.RouteTab {
        switch selectedTab {
        case .dashboard: return .dashboard
        case .crm: return .crm
        case .bids: return .bids
        case .jobs: return .jobs
        case .more: return .more
        }
    }

    private var compactHintText: String {
        switch selectedTab {
        case .dashboard:
            return "Quick actions for your day are in the dock"
        case .crm:
            return "Tap Follow-Up to work your next AI priority"
        case .bids:
            return "Tap Scan to start LiDAR estimate flow"
        case .jobs:
            return "Tap Create Job to schedule execution faster"
        case .more:
            return "Tap Invoice to open billing in one step"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab content area ───────────────────────────────────────────
            TabView(selection: $selectedTab) {
                DashboardView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(Tab.dashboard)

                CRMView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("CRM", systemImage: "person.2.fill") }
                    .tag(Tab.crm)

                BidsView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Bids", systemImage: "doc.text.fill") }
                    .tag(Tab.bids)

                JobsView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                    .tag(Tab.jobs)

                MoreView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                    .tag(Tab.more)
            }
            .tint(EBPColor.accent)
            .scaleEffect(routeHandoffAnimating ? 0.996 : 1)
            .opacity(routeHandoffAnimating ? 0.985 : 1)
            .animation(EBPAnimation.smooth, value: routeHandoffAnimating)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: selectedTab == .dashboard ? 0 : 112)
            }

            quickActionDock(isCompact: workflowRouter.isDockCompact(for: activeRouteTab))
                .padding(.horizontal, EBPSpacing.md)
                .padding(.bottom, dockBottomPadding())

            if showCompactDockHint {
                Text(compactHintText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, dockBottomPadding() + 62)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !reachability.isConnected {
                offlineBanner
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(5)
            } else if let handoff = workflowRouter.handoffMessage {
                handoffBanner(handoff)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showTooltipOverlay {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissTooltips()
                    }

                tooltipCoachCard
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.bottom, dockBottomPadding() + 72)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $presentingScan) {
            if #available(iOS 16.0, *) {
                AutoScanView()
            } else {
                ScanView()
            }
        }
        .fullScreenCover(isPresented: $presentingBidBuilder) { BidBuilderView() }
        .sheet(isPresented: $presentingCreateJob) { AddJobSheet() }
        .sheet(isPresented: $presentingCreateInvoice) { CreateInvoiceSheet() }
        .onReceive(workflowRouter.$requestedTab) { route in
            guard let route else { return }

            let targetTab = tab(for: route)
            routeHandoffTab = targetTab
            AppHaptics.trigger(.soft, compact: true)

            withAnimation(EBPAnimation.snappy) {
                routeHandoffAnimating = true
                selectedTab = targetTab
            }
            workflowRouter.consumeRoute()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(EBPAnimation.smooth) {
                    routeHandoffAnimating = false
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                workflowRouter.consumeHandoffMessage()
                routeHandoffTab = nil
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .bids {
                workflowRouter.setDockCompact(false, for: .bids)
            }
        }
        .onChange(of: workflowRouter.compactDockTabs) { _, compactTabs in
            let nowCompact = compactTabs.contains(activeRouteTab)
            guard nowCompact, !hasSeenCompactDockHint, !showCompactDockHint else { return }

            showCompactDockHint = true
            hasSeenCompactDockHint = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCompactDockHint = false
                }
            }
        }
        .onAppear {
            guard !hasSeenFirstTimeTabTooltips else { return }
            tooltipIndex = 0
            selectedTab = tooltipSteps[0].tab
            withAnimation(.easeOut(duration: 0.2)) {
                showTooltipOverlay = true
            }
        }
    }

    // MARK: - Quick Action Dock

    private func quickActionDock(isCompact: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EBPSpacing.sm) {
                if isCompact {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                        Text("Dock")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }

                quickActionButton(
                    title: "Scan",
                    icon: "ruler",
                    color: EBPColor.accent,
                    textColor: .black,
                    compact: isCompact,
                    haptic: .heavy
                ) {
                    selectedTab = .bids
                    presentingScan = true
                }

                quickActionButton(
                    title: "Build Bid",
                    icon: "doc.text.fill",
                    color: EBPColor.primary,
                    textColor: .white,
                    compact: isCompact,
                    haptic: .medium
                ) {
                    selectedTab = .bids
                    presentingBidBuilder = true
                }

                quickActionButton(
                    title: "Create Job",
                    icon: "hammer.fill",
                    color: .orange,
                    textColor: .white,
                    compact: isCompact,
                    haptic: .rigid
                ) {
                    selectedTab = .jobs
                    presentingCreateJob = true
                }

                quickActionButton(
                    title: "Invoice",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    textColor: .white,
                    compact: isCompact,
                    haptic: .soft
                ) {
                    selectedTab = .more
                    presentingCreateInvoice = true
                }

                quickActionButton(
                    title: "Follow-Up",
                    icon: "person.badge.clock",
                    color: .blue,
                    textColor: .white,
                    compact: isCompact,
                    haptic: .success
                ) {
                    workflowRouter.navigate(to: .crm, handoffMessage: "Open AI Follow-Up Queue")
                }
            }
        }
        .padding(EBPSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.lg)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isCompact)
    }

    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        textColor: Color,
        compact: Bool,
        haptic: DockHaptic,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            triggerHaptic(haptic, compact: compact)
            withAnimation(EBPAnimation.snappy) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                if !compact {
                    Text(title)
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, 10)
            .background(color, in: Capsule())
        }
        .buttonStyle(.pressScale)
    }

    private func triggerHaptic(_ haptic: DockHaptic, compact: Bool) {
        let pattern: AppHaptics.Pattern = switch haptic {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        case .success: .success
        }
        AppHaptics.trigger(pattern, compact: compact)
    }

    // MARK: - Helpers

    private func dockBottomPadding() -> CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 0
        return 49 + safeBottom + 8
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            Text("Offline — changes will sync when connected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.18))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }

    private func handoffBanner(_ handoff: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: tabIcon(routeHandoffTab ?? selectedTab))
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.accent)

            Text(handoff)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Circle()
                .fill(EBPColor.accent.opacity(routeHandoffAnimating ? 0.9 : 0.45))
                .frame(width: 6, height: 6)
                .scaleEffect(routeHandoffAnimating ? 1.2 : 0.9)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: routeHandoffAnimating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .scaleEffect(routeHandoffAnimating ? 1.01 : 1)
        .animation(EBPAnimation.fast, value: routeHandoffAnimating)
    }

    private func tab(for route: WorkflowRouter.RouteTab) -> Tab {
        switch route {
        case .dashboard: return .dashboard
        case .crm: return .crm
        case .bids: return .bids
        case .jobs: return .jobs
        case .more: return .more
        }
    }

    private func tabIcon(_ tab: Tab) -> String {
        switch tab {
        case .dashboard: return "house.fill"
        case .crm: return "person.2.fill"
        case .bids: return "doc.text.fill"
        case .jobs: return "briefcase.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }

    private var tooltipCoachCard: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Text("Quick App Tour")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Text("\(tooltipIndex + 1)/\(tooltipSteps.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .contentTransition(.numericText())
            }

            HStack(spacing: 6) {
                ForEach(Array(tooltipSteps.indices), id: \.self) { idx in
                    Capsule()
                        .fill(idx <= tooltipIndex ? EBPColor.accent : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }

            Text(currentTooltipStep.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(currentTooltipStep.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: EBPSpacing.sm) {
                Button("Skip") {
                    dismissTooltips()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if tooltipIndex > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tooltipIndex -= 1
                            selectedTab = currentTooltipStep.tab
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }

                Button(tooltipIndex == tooltipSteps.count - 1 ? "Done" : "Next") {
                    advanceTooltip()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(EBPColor.accent, in: Capsule())
            }
        }
        .padding(EBPSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.lg)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .id(tooltipIndex)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private func advanceTooltip() {
        if tooltipIndex >= tooltipSteps.count - 1 {
            dismissTooltips()
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tooltipIndex += 1
            selectedTab = currentTooltipStep.tab
        }
    }

    private func dismissTooltips() {
        hasSeenFirstTimeTabTooltips = true
        withAnimation(.easeOut(duration: 0.2)) {
            showTooltipOverlay = false
        }
    }
}


