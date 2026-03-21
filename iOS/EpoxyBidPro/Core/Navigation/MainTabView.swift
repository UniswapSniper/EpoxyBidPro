import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable, CaseIterable {
        case dashboard, jobs, scan, clients, settings

        var displayName: String {
            switch self {
            case .dashboard: return "DASHBOARD"
            case .jobs:      return "JOBS"
            case .scan:      return "SCAN"
            case .clients:   return "CLIENTS"
            case .settings:  return "SETTINGS"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .jobs:      return "briefcase.fill"
            case .scan:      return "viewfinder"
            case .clients:   return "person.2.fill"
            case .settings:  return "gearshape.fill"
            }
        }
    }

    enum DockHaptic {
        case light, medium, heavy, soft, rigid, success
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var previousTab: Tab = .dashboard
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
                tab: .jobs,
                title: "Manage Your Work",
                message: "Track all jobs, schedules, and crew assignments. Create jobs from signed bids and monitor progress."
            ),
            TooltipStep(
                tab: .scan,
                title: "Scan to Bid Fast",
                message: "Run Scan Space, then Build From Scan to prefill pricing and scope in one flow."
            ),
            TooltipStep(
                tab: .clients,
                title: "Work Your Pipeline",
                message: "Pipeline and AI Follow-Up Queue keep leads moving. Prioritize overdue follow-ups first."
            ),
            TooltipStep(
                tab: .settings,
                title: "Configure Operations",
                message: "Manage invoicing, business profile, payments, app language, and account settings."
            ),
        ]
    }

    private var currentTooltipStep: TooltipStep {
        tooltipSteps[min(tooltipIndex, tooltipSteps.count - 1)]
    }

    private var activeRouteTab: WorkflowRouter.RouteTab {
        switch selectedTab {
        case .dashboard: return .dashboard
        case .jobs:      return .jobs
        case .scan:      return .scan
        case .clients:   return .clients
        case .settings:  return .settings
        }
    }

    private var compactHintText: String {
        switch selectedTab {
        case .dashboard:
            return "Quick actions for your day are in the dock"
        case .jobs:
            return "Tap Create Job to schedule execution faster"
        case .scan:
            return "Tap Scan to start LiDAR estimate flow"
        case .clients:
            return "Tap Follow-Up to work your next AI priority"
        case .settings:
            return "Tap Invoice to open billing in one step"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab content area ───────────────────────────────────────────
            ZStack {
                Group {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView()
                            .environmentObject(workflowRouter)
                    case .jobs:
                        JobsView()
                            .environmentObject(workflowRouter)
                    case .scan:
                        // Scan tab shows dashboard; actual scan is presented as fullScreenCover
                        DashboardView()
                            .environmentObject(workflowRouter)
                    case .clients:
                        CRMView()
                            .environmentObject(workflowRouter)
                    case .settings:
                        SettingsTabView()
                            .environmentObject(workflowRouter)
                    }
                }
            }
            .scaleEffect(routeHandoffAnimating ? 0.996 : 1)
            .opacity(routeHandoffAnimating ? 0.985 : 1)
            .animation(EBPAnimation.smooth, value: routeHandoffAnimating)

            // ── Quick Action Dock (above tab bar) ──────────────────────────
            quickActionDock(isCompact: workflowRouter.isDockCompact(for: activeRouteTab))
                .padding(.horizontal, EBPSpacing.md)
                .padding(.bottom, tabBarHeight() + 12)

            // ── Custom Glassmorphic Tab Bar ────────────────────────────────
            industrialTabBar

            if showCompactDockHint {
                Text(compactHintText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EBPColor.onSurface)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, tabBarHeight() + 74)
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
                    .padding(.bottom, tabBarHeight() + 80)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $presentingScan) {
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
            if newTab == .jobs {
                workflowRouter.setDockCompact(false, for: .jobs)
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

    // MARK: - Industrial Glassmorphic Tab Bar

    private var industrialTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabBarItem(tab)
            }
        }
        .padding(.horizontal, EBPSpacing.xs)
        .padding(.top, 12)
        .padding(.bottom, safeAreaBottom() + 8)
        .background(
            ZStack {
                EBPColor.surface.opacity(0.6)
                    .background(.ultraThinMaterial)
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EBPColor.primary.opacity(0.15))
                .frame(height: 0.5)
        }
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: EBPRadius.xl, topTrailingRadius: EBPRadius.xl)
        )
        .shadow(color: EBPColor.primaryFixedDim.opacity(0.05), radius: 40, x: 0, y: -4)
    }

    private func tabBarItem(_ tab: Tab) -> some View {
        Button {
            AppHaptics.trigger(.light, compact: true)
            if tab == .scan {
                previousTab = selectedTab
                presentingScan = true
            } else {
                withAnimation(EBPAnimation.snappy) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))

                Text(tab.displayName)
                    .font(EBPFont.micro)
                    .tracking(0.5)
            }
            .foregroundStyle(tabColor(tab))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: EBPRadius.xl)
                        .fill(EBPColor.primaryContainer.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: EBPRadius.xl)
                                .stroke(EBPColor.primaryContainer.opacity(0.20), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tabColor(_ tab: Tab) -> Color {
        if selectedTab == tab {
            return EBPColor.primaryContainer
        }
        return EBPColor.onSurfaceVariant
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
                    .foregroundStyle(EBPColor.onSurfaceVariant)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(EBPColor.surfaceContainerHigh, in: Capsule())
                }

                quickActionButton(
                    title: "Scan",
                    icon: "viewfinder",
                    color: EBPColor.primaryContainer,
                    textColor: EBPColor.onPrimary,
                    compact: isCompact,
                    haptic: .heavy
                ) {
                    presentingScan = true
                }

                quickActionButton(
                    title: "Build Bid",
                    icon: "doc.text.fill",
                    color: EBPColor.surfaceContainerHigh,
                    textColor: EBPColor.onSurface,
                    compact: isCompact,
                    haptic: .medium
                ) {
                    selectedTab = .jobs
                    presentingBidBuilder = true
                }

                quickActionButton(
                    title: "Create Job",
                    icon: "hammer.fill",
                    color: EBPColor.secondaryContainer,
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
                    color: EBPColor.success,
                    textColor: .white,
                    compact: isCompact,
                    haptic: .soft
                ) {
                    selectedTab = .settings
                    presentingCreateInvoice = true
                }

                quickActionButton(
                    title: "Follow-Up",
                    icon: "person.badge.clock",
                    color: EBPColor.primary,
                    textColor: EBPColor.onPrimary,
                    compact: isCompact,
                    haptic: .success
                ) {
                    workflowRouter.navigate(to: .clients, handoffMessage: "Open AI Follow-Up Queue")
                }
            }
        }
        .padding(EBPSpacing.sm)
        .ebpGlassmorphism(cornerRadius: EBPRadius.lg)
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

    private func safeAreaBottom() -> CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 0
    }

    private func tabBarHeight() -> CGFloat {
        // Tab bar content + top padding + bottom safe area + bottom padding
        return 56 + 12 + safeAreaBottom() + 8
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.secondaryContainer)
            Text("Offline \u{2014} changes will sync when connected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(EBPColor.onSurface)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(EBPColor.secondaryContainer.opacity(0.18))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(EBPColor.secondaryContainer.opacity(0.35), lineWidth: 0.5))
    }

    private func handoffBanner(_ handoff: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: (routeHandoffTab ?? selectedTab).icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.primaryContainer)

            Text(handoff)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EBPColor.onSurface)
                .lineLimit(1)

            Circle()
                .fill(EBPColor.primaryContainer.opacity(routeHandoffAnimating ? 0.9 : 0.45))
                .frame(width: 6, height: 6)
                .scaleEffect(routeHandoffAnimating ? 1.2 : 0.9)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: routeHandoffAnimating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ebpGlassmorphism(cornerRadius: EBPRadius.pill)
        .scaleEffect(routeHandoffAnimating ? 1.01 : 1)
        .animation(EBPAnimation.fast, value: routeHandoffAnimating)
    }

    private func tab(for route: WorkflowRouter.RouteTab) -> Tab {
        switch route.canonical {
        case .dashboard: return .dashboard
        case .jobs:      return .jobs
        case .scan:      return .scan
        case .clients:   return .clients
        case .settings:  return .settings
        default:         return .dashboard
        }
    }

    private var tooltipCoachCard: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Text("Quick App Tour")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.onSurfaceVariant)

                Spacer()

                Text("\(tooltipIndex + 1)/\(tooltipSteps.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EBPColor.onSurfaceVariant.opacity(0.65))
                    .contentTransition(.numericText())
            }

            HStack(spacing: 6) {
                ForEach(Array(tooltipSteps.indices), id: \.self) { idx in
                    Capsule()
                        .fill(idx <= tooltipIndex ? EBPColor.primaryContainer : EBPColor.surfaceContainerHighest)
                        .frame(height: 4)
                }
            }

            Text(currentTooltipStep.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(EBPColor.onSurface)

            Text(currentTooltipStep.message)
                .font(.subheadline)
                .foregroundStyle(EBPColor.onSurfaceVariant)

            HStack(spacing: EBPSpacing.sm) {
                Button("Skip") {
                    dismissTooltips()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(EBPColor.onSurfaceVariant)

                Spacer()

                if tooltipIndex > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tooltipIndex -= 1
                            selectedTab = currentTooltipStep.tab
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EBPColor.onSurface)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(EBPColor.surfaceContainerHigh, in: Capsule())
                }

                Button(tooltipIndex == tooltipSteps.count - 1 ? "Done" : "Next") {
                    advanceTooltip()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.onPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(EBPColor.primaryContainer, in: Capsule())
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.lg)
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

// MARK: - Settings Tab View (wraps SettingsSheet as a full tab)

struct SettingsTabView: View {
    var body: some View {
        SettingsSheet()
    }
}
