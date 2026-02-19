import SwiftUI
import SwiftData

@main
struct EpoxyBidProApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var reachabilityMonitor = ReachabilityMonitor()
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.english.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(reachabilityMonitor)
                .environment(\.locale, appLanguage.locale)
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
