import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case dashboard
        case crm
        case bids
        case jobs
        case more
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var presentingScan = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }
                .tag(Tab.dashboard)

            CRMView()
                .tabItem { Label("CRM", systemImage: "person.2") }
                .tag(Tab.crm)

            BidsView()
                .tabItem { Label("Bids", systemImage: "doc.text.below.ecg") }
                .tag(Tab.bids)

            JobsView()
                .tabItem { Label("Jobs", systemImage: "briefcase") }
                .tag(Tab.jobs)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
        .overlay(alignment: .bottom) {
            Button {
                presentingScan = true
            } label: {
                Image(systemName: "ruler")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(EBPColor.primary)
                    .clipShape(Circle())
                    .shadow(radius: 8)
            }
            .offset(y: -24)
            .accessibilityLabel("New Scan")
        }
        .sheet(isPresented: $presentingScan) {
            ScanView()
        }
    }
}
