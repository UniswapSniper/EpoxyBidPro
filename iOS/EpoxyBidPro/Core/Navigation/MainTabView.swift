import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case dashboard, crm, bids, jobs, more
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var presentingScan = false
    @State private var fabPulse = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab content area ───────────────────────────────────────────
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(Tab.dashboard)

                CRMView()
                    .tabItem { Label("CRM", systemImage: "person.2.fill") }
                    .tag(Tab.crm)

                BidsView()
                    .tabItem { Label("Bids", systemImage: "doc.text.fill") }
                    .tag(Tab.bids)

                JobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                    .tag(Tab.jobs)

                MoreView()
                    .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                    .tag(Tab.more)
            }
            .tint(EBPColor.primary)

            // ── Floating LiDAR / Scan FAB ──────────────────────────────────
            // Sits above the centre of the tab bar.
            scanFAB
                .padding(.bottom, fabBottomPadding())
        }
        .sheet(isPresented: $presentingScan) {
            ScanView()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                fabPulse = true
            }
        }
    }

    // MARK: - FAB

    private var scanFAB: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            presentingScan = true
        } label: {
            ZStack {
                // Animated pulse ring
                Circle()
                    .stroke(EBPColor.primary.opacity(fabPulse ? 0 : 0.28), lineWidth: 8)
                    .scaleEffect(fabPulse ? 1.7 : 1.0)
                    .frame(width: 62, height: 62)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: fabPulse)

                // Main button circle
                Circle()
                    .fill(EBPColor.primaryGradient)
                    .frame(width: 62, height: 62)
                    .ebpShadowStrong()

                VStack(spacing: 2) {
                    Image(systemName: "ruler")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("SCAN")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1)
                }
            }
        }
        .accessibilityLabel("New LiDAR Scan")
    }

    // MARK: - Helpers

    /// Bottom padding so the FAB centre sits just above the tab bar labels.
    private func fabBottomPadding() -> CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 0
        // Tab bar intrinsic height is 49pt; we want the FAB centred ~20pt above it.
        return 49 + safeBottom + 20
    }
}


