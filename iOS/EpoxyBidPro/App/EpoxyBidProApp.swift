import SwiftUI

@main
struct EpoxyBidProApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var reachabilityMonitor = ReachabilityMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(reachabilityMonitor)
                .preferredColorScheme(nil)
        }
    }
}
