import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable, CaseIterable {
        case home, pipeline, jobs, payments

        var displayName: String {
            switch self {
            case .home:     return "Home"
            case .pipeline: return "Pipeline"
            case .jobs:     return "Jobs"
            case .payments: return "Payments"
            }
        }
    }

    @State private var selectedTab: Tab = .home
    @StateObject private var workflowRouter = WorkflowRouter()
    @AppStorage("hasSeenFirstTimeTabTooltips") private var hasSeenFirstTimeTabTooltips = false
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
                tab: .home,
                title: "Your Command Center",
                message: "Check KPIs, see what needs attention today, and jump to any part of your business with Quick Actions."
            ),
            TooltipStep(
                tab: .pipeline,
                title: "Leads & Bids Together",
                message: "Manage your sales pipeline — from first contact to signed proposal. Scan spaces and build bids in one flow."
            ),
            TooltipStep(
                tab: .jobs,
                title: "Execute Without Gaps",
                message: "Create jobs from signed bids, track progress, and catch margin or schedule issues early."
            ),
            TooltipStep(
                tab: .payments,
                title: "Get Paid Faster",
                message: "Create invoices, track what's outstanding, and follow up on overdue payments."
            ),
        ]
    }

    private var currentTooltipStep: TooltipStep {
        tooltipSteps[min(tooltipIndex, tooltipSteps.count - 1)]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(Tab.home)

                PipelineView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Pipeline", systemImage: "arrow.triangle.swap") }
                    .tag(Tab.pipeline)

                JobsView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Jobs", systemImage: "hammer.fill") }
                    .tag(Tab.jobs)

                PaymentsView()
                    .environmentObject(workflowRouter)
                    .tabItem { Label("Payments", systemImage: "dollarsign.circle.fill") }
                    .tag(Tab.payments)
            }
            .tint(EBPColor.accent)
            .scaleEffect(routeHandoffAnimating ? 0.996 : 1)
            .opacity(routeHandoffAnimating ? 0.985 : 1)
            .animation(EBPAnimation.smooth, value: routeHandoffAnimating)

            if let handoff = workflowRouter.handoffMessage {
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
                    .padding(.bottom, 72)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
            }
        }
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
        .onAppear {
            guard !hasSeenFirstTimeTabTooltips else { return }
            tooltipIndex = 0
            selectedTab = tooltipSteps[0].tab
            withAnimation(.easeOut(duration: 0.2)) {
                showTooltipOverlay = true
            }
        }
    }

    // MARK: - Helpers

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
        case .home:     return .home
        case .pipeline: return .pipeline
        case .jobs:     return .jobs
        case .payments: return .payments
        }
    }

    private func tabIcon(_ tab: Tab) -> String {
        switch tab {
        case .home:     return "house.fill"
        case .pipeline: return "arrow.triangle.swap"
        case .jobs:     return "hammer.fill"
        case .payments: return "dollarsign.circle.fill"
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
