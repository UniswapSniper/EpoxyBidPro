import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// WorkflowRouter.swift
// Cross-tab navigation with handoff messaging.
// Phase 2: Updated to @Observable (iOS 17+).
// ═══════════════════════════════════════════════════════════════════════════════

@Observable
final class WorkflowRouter {
    enum RouteTab: String {
        case dashboard
        case crm
        case bids
        case jobs
        case more
    }

    var requestedTab: RouteTab?
    var handoffMessage: String?
    private(set) var compactDockTabs: Set<RouteTab> = []

    func navigate(to tab: RouteTab, handoffMessage: String? = nil) {
        self.handoffMessage = handoffMessage
        requestedTab = tab
    }

    func consumeRoute() {
        requestedTab = nil
    }

    func consumeHandoffMessage() {
        handoffMessage = nil
    }

    func setDockCompact(_ compact: Bool, for tab: RouteTab) {
        if compact {
            compactDockTabs.insert(tab)
        } else {
            compactDockTabs.remove(tab)
        }
    }

    func isDockCompact(for tab: RouteTab) -> Bool {
        compactDockTabs.contains(tab)
    }
}
