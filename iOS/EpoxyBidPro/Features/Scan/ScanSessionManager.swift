// ═══════════════════════════════════════════════════════════════════════════════
// ScanSessionManager.swift
// Perimeter-walk scan engine: tracks corners placed by the user as they walk
// the room boundary, computes area via the Shoelace formula.
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import ARKit
import RealityKit
import Combine
import UIKit

// MARK: - Scan Phase

enum ScanPhase: Equatable {
    case detectingFloor      // Waiting for ARKit to find a horizontal plane
    case placingStart        // Floor found — user should place the start marker
    case walking             // Actively tracing the perimeter
    case complete            // Loop closed — results ready
}

// MARK: - Perimeter Point

struct PerimeterPoint: Identifiable, Equatable {
    let id = UUID()
    let worldPosition: SIMD3<Float>            // 3-D world position on the floor
    var floorXZ: SIMD2<Float> {                // 2-D projection for math
        SIMD2(worldPosition.x, worldPosition.z)
    }
}

// MARK: - ScanSessionManager

final class ScanSessionManager: NSObject, ObservableObject {

    // ── Published state ─────────────────────────────────────────────────────

    @Published var phase: ScanPhase             = .detectingFloor
    @Published var perimeterPoints: [PerimeterPoint] = []
    @Published var totalAreaSqFt: Double        = 0
    @Published var totalPerimeterFt: Double     = 0
    @Published var wallLengthsFt: [Double]      = []
    @Published var currentWallLengthFt: Double  = 0     // live wall being walked
    @Published var isNearStartPoint: Bool       = false
    @Published var isLiDARAvailable: Bool       = false
    @Published var guidanceMessage: String      = "Point your device at the floor"
    @Published var isSessionReady: Bool         = false
    @Published var cornerCount: Int             = 0

    // ── AR references ───────────────────────────────────────────────────────

    weak var arView: ARView?
    var renderer: PerimeterRenderer?

    // ── Internal state ──────────────────────────────────────────────────────

    private var floorPlaneAnchor: ARPlaneAnchor?
    private var floorY: Float                   = 0
    private var currentFloorPosition: SIMD3<Float>?
    private var currentDeviceXZ: SIMD2<Float>?

    // ── Tuning ──────────────────────────────────────────────────────────────

    /// How close (meters) to the start marker to trigger the "snap" indicator.
    private let snapRadius: Float = 0.50
    /// Minimum polygon sides for a valid area.
    private let minSides: Int = 3

    // MARK: - Session Configuration

    func configureSession(for arView: ARView) {
        self.arView = arView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            isLiDARAvailable = true
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        renderer = PerimeterRenderer(arView: arView)
    }

    // MARK: - User Actions

    /// Place the first perimeter point at the current device position.
    func placeStartPoint() {
        guard phase == .placingStart,
              let pos = currentFloorPosition else { return }

        let point = PerimeterPoint(worldPosition: pos)
        perimeterPoints = [point]
        cornerCount = 1
        phase = .walking
        guidanceMessage = "Aim at the next corner and tap ●"

        renderer?.addCornerMarker(at: pos, isStart: true)
        AppHaptics.trigger(.heavy)
    }

    /// Mark a new corner at the current position (or close the loop if near start).
    func markCorner() {
        guard phase == .walking,
              let pos = currentFloorPosition else { return }

        // Close loop if user is near start and has enough points
        if perimeterPoints.count >= minSides, isNearStartPoint {
            closeLoop()
            return
        }

        let point = PerimeterPoint(worldPosition: pos)
        perimeterPoints.append(point)
        cornerCount = perimeterPoints.count

        // Wall line from previous corner → this corner
        if perimeterPoints.count >= 2 {
            let prev = perimeterPoints[perimeterPoints.count - 2]
            renderer?.addWallLine(from: prev.worldPosition, to: pos)
        }

        renderer?.addCornerMarker(at: pos, isStart: false)
        recalculate()

        AppHaptics.trigger(.medium)
    }

    /// Remove the last corner (undo).
    func undoLastCorner() {
        guard phase == .walking, perimeterPoints.count > 1 else { return }
        perimeterPoints.removeLast()
        cornerCount = perimeterPoints.count
        recalculate()

        let positions = perimeterPoints.map(\.worldPosition)
        renderer?.rebuildVisualization(points: positions, isClosed: false)

        AppHaptics.trigger(.light)
    }

    /// Manually close the perimeter loop (final wall: last → first).
    func closeLoop() {
        guard perimeterPoints.count >= minSides else { return }

        phase = .complete
        guidanceMessage = "Scan complete!"
        recalculate()

        let positions = perimeterPoints.map(\.worldPosition)
        renderer?.rebuildVisualization(points: positions, isClosed: true)

        AppHaptics.trigger(.success)
    }

    /// Restart the scan from scratch.
    func resetScan() {
        perimeterPoints.removeAll()
        wallLengthsFt.removeAll()
        cornerCount = 0
        totalAreaSqFt = 0
        totalPerimeterFt = 0
        currentWallLengthFt = 0
        isNearStartPoint = false

        renderer?.clearAll()

        if floorPlaneAnchor != nil {
            phase = .placingStart
            guidanceMessage = "Tap to place your start point"
        } else {
            phase = .detectingFloor
            guidanceMessage = "Point your device at the floor"
        }
    }

    // MARK: - Calculations

    private func recalculate() {
        let xz = perimeterPoints.map(\.floorXZ)
        let closed = (phase == .complete)

        totalAreaSqFt    = PerimeterProcessor.polygonAreaSqFt(vertices: xz)
        totalPerimeterFt = PerimeterProcessor.perimeterLengthFt(vertices: xz, closed: closed)
        wallLengthsFt    = PerimeterProcessor.wallLengthsFt(vertices: xz, closed: closed)
    }

    private func checkProximityToStart() {
        guard perimeterPoints.count >= minSides,
              let curXZ = currentDeviceXZ,
              let startXZ = perimeterPoints.first?.floorXZ else {
            isNearStartPoint = false
            return
        }

        let dist = simd_distance(curXZ, startXZ)
        let wasNear = isNearStartPoint
        isNearStartPoint = dist < snapRadius

        if isNearStartPoint && !wasNear {
            AppHaptics.trigger(.light)
        }
    }

    // MARK: - Export

    /// JSON representation of the polygon for persistence.
    func polygonJSON() -> String {
        PerimeterProcessor.toJSON(vertices: perimeterPoints.map(\.floorXZ))
    }
}

// MARK: - ARSessionDelegate

extension ScanSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let t = frame.camera.transform
        let cam = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Raycast from screen center instead of dropping the camera exactly down
            let screenCenter = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
            var targetFloorPos: SIMD3<Float>?
            
            if let arView = self.arView,
               let hit = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .horizontal).first {
                targetFloorPos = SIMD3<Float>(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
            } else {
                // Mathematical intersection with the floor plane if raycast fails
                let dir = SIMD3<Float>(-t.columns.2.x, -t.columns.2.y, -t.columns.2.z)
                if dir.y < -0.01 {
                    let distance = (self.floorY - cam.y) / dir.y
                    targetFloorPos = cam + dir * distance
                }
            }

            guard let floorPos = targetFloorPos else { return }
            
            self.currentFloorPosition = floorPos
            self.currentDeviceXZ = SIMD2(floorPos.x, floorPos.z)
            
            // Render a reticle on the floor
            self.renderer?.updateReticle(at: floorPos)

            guard self.phase == .walking,
                  let lastPt = self.perimeterPoints.last else { return }

            // Live wall length
            let liveLen = Double(simd_distance(
                SIMD2(lastPt.worldPosition.x, lastPt.worldPosition.z),
                SIMD2(floorPos.x, floorPos.z)
            )) * PerimeterProcessor.metersToFeet
            self.currentWallLengthFt = liveLen

            // Tracking line
            self.renderer?.updateTrackingLine(
                from: lastPt.worldPosition,
                to: floorPos,
                isNearStart: self.isNearStartPoint
            )

            // Proximity check
            self.checkProximityToStart()

            // Guidance
            if self.isNearStartPoint {
                self.guidanceMessage = "Near start — tap ● to close the perimeter"
            } else {
                let c = self.perimeterPoints.count - 1
                self.guidanceMessage = "\(c) corner\(c == 1 ? "" : "s") marked · aim at the next corner"
            }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor,
                  plane.alignment == .horizontal else { continue }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                let existingArea = (self.floorPlaneAnchor?.planeExtent.width ?? 0)
                                 * (self.floorPlaneAnchor?.planeExtent.height ?? 0)
                let newArea = plane.planeExtent.width * plane.planeExtent.height

                if self.floorPlaneAnchor == nil || newArea > existingArea {
                    self.floorPlaneAnchor = plane
                    self.floorY = plane.transform.columns.3.y

                    if self.phase == .detectingFloor {
                        self.phase = .placingStart
                        self.isSessionReady = true
                        self.guidanceMessage = "Floor detected — aim at a corner and tap to start"
                        AppHaptics.trigger(.light)
                    }
                }
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if plane.identifier == self.floorPlaneAnchor?.identifier {
                    self.floorY = plane.transform.columns.3.y
                }
            }
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch camera.trackingState {
            case .notAvailable:
                self.guidanceMessage = "AR tracking unavailable"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.guidanceMessage = "Initializing — move slowly"
                case .excessiveMotion:
                    self.guidanceMessage = "Slow down — too much motion"
                case .insufficientFeatures:
                    self.guidanceMessage = "Point at a well-lit textured surface"
                case .relocalizing:
                    self.guidanceMessage = "Re-localizing…"
                @unknown default:
                    self.guidanceMessage = "Limited tracking"
                }
            case .normal:
                if self.phase == .detectingFloor {
                    self.guidanceMessage = "Point your device at the floor"
                }
            }
        }
    }
}
