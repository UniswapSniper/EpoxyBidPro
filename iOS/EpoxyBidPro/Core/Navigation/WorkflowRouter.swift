import Foundation

final class WorkflowRouter: ObservableObject {
    enum RouteTab: String {
        case dashboard
        case jobs
        case scan
        case clients
        case settings

        // Backward-compatible aliases
        case home       // → dashboard
        case crm        // → clients
        case bids       // → jobs (bids accessible within jobs flow)
        case more       // → settings
        case pipeline   // → clients

        /// Canonical tab for navigation.
        var canonical: RouteTab {
            switch self {
            case .home:     return .dashboard
            case .crm:      return .clients
            case .bids:     return .jobs
            case .more:     return .settings
            case .pipeline: return .clients
            default:        return self
            }
        }
    }

    @Published var requestedTab: RouteTab?
    @Published var handoffMessage: String?
    @Published private(set) var compactDockTabs: Set<RouteTab> = []

    func navigate(to tab: RouteTab, handoffMessage: String? = nil) {
        self.handoffMessage = handoffMessage
        requestedTab = tab.canonical
    }

    func consumeRoute() {
        requestedTab = nil
    }

    func consumeHandoffMessage() {
        handoffMessage = nil
    }

    func setDockCompact(_ compact: Bool, for tab: RouteTab) {
        let t = tab.canonical
        if compact {
            compactDockTabs.insert(t)
        } else {
            compactDockTabs.remove(t)
        }
    }

    func isDockCompact(for tab: RouteTab) -> Bool {
        compactDockTabs.contains(tab.canonical)
    }
}
