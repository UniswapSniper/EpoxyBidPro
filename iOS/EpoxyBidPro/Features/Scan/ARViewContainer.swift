// ═══════════════════════════════════════════════════════════════════════════════
// ARViewContainer.swift
// UIViewRepresentable that hosts the RealityKit ARView for perimeter scanning.
// ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {

    @ObservedObject var scanManager: ScanSessionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Render options — keep it clean
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableFaceMesh,
            .disableMotionBlur,
            .disableGroundingShadows
        ]

        // Show meshing / scene understanding on LiDAR devices for feedback
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            arView.debugOptions.insert(.showSceneUnderstanding)
        }

        // Coaching overlay guides the user to find a surface
        let coaching = ARCoachingOverlayView()
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        arView.addSubview(coaching)

        // Hand off to the scan manager
        scanManager.configureSession(for: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic updates needed — the ScanSessionManager drives everything.
    }
}
