import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    Label("2 open leads", systemImage: "person.crop.circle.badge.plus")
                    Label("1 active job", systemImage: "hammer")
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}
