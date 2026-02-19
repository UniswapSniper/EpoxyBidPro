import SwiftUI
import ARKit
import RealityKit

// ─── ARViewContainer ─────────────────────────────────────────────────────────
// UIViewRepresentable that hosts a RealityKit ARView with LiDAR mesh scanning.
// Shares its ARSession with ScanSessionManager (which acts as ARSessionDelegate).

struct ARViewContainer: UIViewRepresentable {

    @ObservedObject var scanManager: ScanSessionManager

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)

        // Visualize the LiDAR reconstruction mesh so users see floor outline
        arView.debugOptions = [.showSceneUnderstanding]

        // Enable scene understanding for accurate occlusion (non-debug features)
        arView.environment.sceneUnderstanding.options = [.occlusion]

        // Reduce render cost — we don't need HDR or person segmentation here
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableFaceMesh,
            .disableHDR,
            .disableMotionBlur,
        ]

        // Wire up our manager as the ARSession delegate
        arView.session.delegate = scanManager

        // Add coaching overlay (auto-hides once sufficient tracking is achieved)
        addCoachingOverlay(to: arView)

        // Start the session
        if scanManager.isLiDARAvailable {
            arView.session.run(scanManager.makeConfiguration(), options: [.removeExistingAnchors, .resetTracking])
        } else {
            // Fallback for non-LiDAR devices: horizontal plane detection only
            let fallbackConfig = ARWorldTrackingConfiguration()
            fallbackConfig.planeDetection = [.horizontal]
            arView.session.run(fallbackConfig, options: [.removeExistingAnchors, .resetTracking])
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic prop drives require updates
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }

    // MARK: - Private helpers

    private func addCoachingOverlay(to arView: ARView) {
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coaching)
    }
}
