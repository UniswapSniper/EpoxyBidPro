import Foundation

final class WorkflowRouter: ObservableObject {
    enum RouteTab: String {
        case home
        case pipeline
        case jobs
        case payments
    }

    @Published var requestedTab: RouteTab?
    @Published var handoffMessage: String?

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
}
