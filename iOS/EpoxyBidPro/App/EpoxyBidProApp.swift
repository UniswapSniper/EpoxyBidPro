import SwiftUI
import SwiftData

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
        .modelContainer(for: [
            Client.self,
            Lead.self,
            Measurement.self,
            Area.self,
            Bid.self,
            BidLineItem.self,
            BidSignature.self,
            Job.self,
            Invoice.self,
            Payment.self,
            Photo.self,
            CrewMember.self,
            Material.self,
            Template.self,
        ])
    }
}
