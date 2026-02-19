import ARKit
import RealityKit
import Combine

// ─── Transient captured-area model (in-memory only, not SwiftData) ───────────

struct CapturedArea: Identifiable {
    let id = UUID()
    var name: String
    var squareFeet: Double
    var polygonVerticesJson: String   // [[x,z]] in meters
    let capturedAt: Date = Date()
}

// ─── ScanSessionManager ───────────────────────────────────────────────────────
// ARSessionDelegate that processes LiDAR mesh anchors in real time.
// Works alongside ARViewContainer which owns the ARView + its ARSession.

@MainActor
final class ScanSessionManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isLiDARAvailable: Bool = false
    @Published var sessionMessage: String = "Point at the floor and move slowly"
    @Published var detectedFloorSqFt: Double = 0
    @Published var capturedAreas: [CapturedArea] = []
    @Published var sessionError: String? = nil

    // MARK: - Internal state

    private var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private var updateCallCount: Int = 0

    // MARK: - Computed

    var totalCapturedSqFt: Double {
        capturedAreas.reduce(0) { $0 + $1.squareFeet }
    }

    var hasCaptures: Bool { !capturedAreas.isEmpty }

    // MARK: - Init

    override init() {
        super.init()
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    // MARK: - Session configuration

    /// Returns the ARWorldTrackingConfiguration that ARViewContainer should run.
    func makeConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        if isLiDARAvailable {
            config.sceneReconstruction = .meshWithClassification
        }
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .none
        return config
    }

    // MARK: - Area capture

    func captureArea(name: String) {
        guard detectedFloorSqFt > 1 else {
            sessionMessage = "No floor detected yet — keep scanning"
            return
        }
        let polygon = FloorMeshProcessor.buildPolygonJson(from: Array(meshAnchors.values))
        let area = CapturedArea(
            name: name.isEmpty ? "Area \(capturedAreas.count + 1)" : name,
            squareFeet: detectedFloorSqFt,
            polygonVerticesJson: polygon
        )
        capturedAreas.append(area)
        sessionMessage = "Captured: \(area.name) — \(String(format: "%.0f", area.squareFeet)) sq ft"
    }

    func removeArea(_ area: CapturedArea) {
        capturedAreas.removeAll { $0.id == area.id }
    }

    func removeAreas(at offsets: IndexSet) {
        capturedAreas.remove(atOffsets: offsets)
    }

    func renameArea(_ area: CapturedArea, to newName: String) {
        guard let idx = capturedAreas.firstIndex(where: { $0.id == area.id }) else { return }
        capturedAreas[idx].name = newName
    }

    // MARK: - Private

    private func recomputeFloorArea() {
        detectedFloorSqFt = FloorMeshProcessor.computeTotalFloorArea(from: Array(meshAnchors.values))
        if detectedFloorSqFt > 1 {
            sessionMessage = String(format: "%.0f sq ft detected — tap Capture to save an area", detectedFloorSqFt)
        }
    }
}

// MARK: - ARSessionDelegate

extension ScanSessionManager: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshes.isEmpty else { return }
        Task { @MainActor in
            for anchor in meshes { meshAnchors[anchor.identifier] = anchor }
            recomputeFloorArea()
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let meshes = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshes.isEmpty else { return }
        Task { @MainActor in
            for anchor in meshes { meshAnchors[anchor.identifier] = anchor }
            updateCallCount += 1
            // Throttle: recompute every 4th update to avoid heavy CPU
            if updateCallCount % 4 == 0 { recomputeFloorArea() }
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let ids = anchors.compactMap { ($0 as? ARMeshAnchor)?.identifier }
        guard !ids.isEmpty else { return }
        Task { @MainActor in
            ids.forEach { meshAnchors.removeValue(forKey: $0) }
            recomputeFloorArea()
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            sessionError = error.localizedDescription
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            sessionMessage = "Session interrupted"
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            sessionMessage = "Resuming scan…"
        }
    }
}
