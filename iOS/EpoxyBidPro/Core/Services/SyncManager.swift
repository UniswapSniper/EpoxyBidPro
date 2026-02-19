import Foundation

actor SyncManager {
    enum ConflictPolicy {
        case serverWins
        case clientWinsDrafts
    }

    private(set) var queuedChanges: [String] = []
    private let conflictPolicy: ConflictPolicy = .serverWins

    func enqueue(_ changeID: String) {
        queuedChanges.append(changeID)
    }

    func flushIfNeeded(isConnected: Bool) async {
        guard isConnected else { return }
        queuedChanges.removeAll()
    }
}
