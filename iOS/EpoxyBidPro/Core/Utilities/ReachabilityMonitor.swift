import Foundation
import Network

// ═══════════════════════════════════════════════════════════════════════════════
// ReachabilityMonitor.swift
// Monitors network connectivity using NWPathMonitor.
// Phase 2: Updated to @Observable (iOS 17+).
// ═══════════════════════════════════════════════════════════════════════════════

@Observable
final class ReachabilityMonitor {
    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "epoxybidpro.reachability")

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.detectConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func detectConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
