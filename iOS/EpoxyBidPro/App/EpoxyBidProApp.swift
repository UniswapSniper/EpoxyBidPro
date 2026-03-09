import SwiftUI
import SwiftData

@main
struct EpoxyBidProApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var reachabilityMonitor = ReachabilityMonitor()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .system
    }

    private var appLocale: Locale {
        appLanguage.locale ?? .current
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(reachabilityMonitor)
                .environmentObject(subscriptionManager)
                .environment(\.locale, appLocale)
                .preferredColorScheme(nil)
                .paywallSheetPresenter()
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
            JobChecklistItem.self,
            Invoice.self,
            InvoiceLineItem.self,
            Payment.self,
            Photo.self,
            CrewMember.self,
            Material.self,
            Template.self,
        ])
    }
}
