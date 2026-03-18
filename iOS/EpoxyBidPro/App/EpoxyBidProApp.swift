import SwiftUI
import SwiftData

@main
struct EpoxyBidProApp: App {
    @State private var authManager = AuthManager()
    @State private var reachabilityMonitor = ReachabilityMonitor()
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
                .environment(authManager)
                .environment(reachabilityMonitor)
                .environment(\.locale, appLocale)
                .preferredColorScheme(nil)
        }
        .modelContainer(for: ModelContainerConfig.allModelTypes)
    }
}
