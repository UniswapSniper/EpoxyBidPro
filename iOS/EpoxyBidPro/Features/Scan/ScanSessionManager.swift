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
    @Published var aiCoachMessage: String       = "AI coach: Keep the device chest-high and tilted toward floor edges."
    @Published var scanQualityScore: Int        = 35
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
    private var cameraSpeedMps: Float           = 0
    private var lastCameraPosition: SIMD3<Float>?
    private var lastFrameTimestamp: TimeInterval?
    private var lastCoachUpdateTimestamp: TimeInterval = 0
    private var trackingStateBucket: TrackingStateBucket = .initializing

    // ── Tuning ──────────────────────────────────────────────────────────────

    /// How close (meters) to the start marker to trigger the "snap" indicator.
    private let snapRadius: Float = 0.50
    /// Minimum polygon sides for a valid area.
    private let minSides: Int = 3

    private enum TrackingStateBucket {
        case unavailable
        case initializing
        case excessiveMotion
        case insufficientFeatures
        case relocalizing
        case normal
    }

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
        updateAICoachMessage(force: true)

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
        updateAICoachMessage(force: true)
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
        updateAICoachMessage(force: true)
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
        updateAICoachMessage(force: true)
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

        aiCoachMessage = "AI coach: Re-scan slowly and capture each corner where direction changes."
        scanQualityScore = floorPlaneAnchor == nil ? 35 : 45
    }

    private func updateAICoachMessage(force: Bool = false) {
        let now = Date().timeIntervalSince1970
        if !force && (now - lastCoachUpdateTimestamp) < 0.4 { return }
        lastCoachUpdateTimestamp = now

        let trackingPoints: Int
        switch trackingStateBucket {
        case .normal:
            trackingPoints = 32
        case .initializing:
            trackingPoints = 20
        case .excessiveMotion:
            trackingPoints = 10
        case .insufficientFeatures:
            trackingPoints = 12
        case .relocalizing:
            trackingPoints = 8
        case .unavailable:
            trackingPoints = 5
        }

        let cornerPoints = min(perimeterPoints.count * 6, 30)
        let completionPoints = phase == .complete ? 22 : 0
        let speedPenalty = Int(max(0, (cameraSpeedMps - 0.9) * 22))
        let base = floorPlaneAnchor == nil ? 28 : 40
        let computed = base + trackingPoints + cornerPoints + completionPoints - speedPenalty
        scanQualityScore = max(12, min(98, computed))

        switch phase {
        case .detectingFloor:
            aiCoachMessage = "AI coach: Sweep left-to-right over floor edges in good light to lock the plane faster."
        case .placingStart:
            aiCoachMessage = "AI coach: Start at the farthest visible corner so your final closure is more precise."
        case .walking:
            if trackingStateBucket == .excessiveMotion || cameraSpeedMps > 1.1 {
                aiCoachMessage = "AI coach: Slow down and keep the camera stable for cleaner edge tracking."
            } else if trackingStateBucket == .insufficientFeatures {
                aiCoachMessage = "AI coach: Aim at textured floor/wall boundaries; avoid glossy blank surfaces."
            } else if isNearStartPoint && perimeterPoints.count >= minSides {
                aiCoachMessage = "AI coach: Great loop alignment — tap CLOSE near the start marker now."
            } else if perimeterPoints.count < 4 {
                aiCoachMessage = "AI coach: Mark every direction change. Most rooms need 4+ corners for bid-grade accuracy."
            } else {
                aiCoachMessage = "AI coach: Good pace. Keep reticle exactly on each corner before tapping."
            }
        case .complete:
            if wallLengthsFt.contains(where: { $0 < 1.5 }) {
                aiCoachMessage = "AI coach: Scan completed, but very short wall segments detected. Consider a quick re-scan for cleaner geometry."
            } else {
                aiCoachMessage = "AI coach: Strong capture quality. Measurements are ready for pricing and bid generation."
            }
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

            if let lastPos = self.lastCameraPosition, let lastTs = self.lastFrameTimestamp {
                let dt = max(0.0001, frame.timestamp - lastTs)
                let dist = simd_distance(lastPos, cam)
                self.cameraSpeedMps = Float(dist / Float(dt))
            }
            self.lastCameraPosition = cam
            self.lastFrameTimestamp = frame.timestamp
            
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

            self.updateAICoachMessage()
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
                        self.updateAICoachMessage(force: true)
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
                self.trackingStateBucket = .unavailable
                self.guidanceMessage = "AR tracking unavailable"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    self.trackingStateBucket = .initializing
                    self.guidanceMessage = "Initializing — move slowly"
                case .excessiveMotion:
                    self.trackingStateBucket = .excessiveMotion
                    self.guidanceMessage = "Slow down — too much motion"
                case .insufficientFeatures:
                    self.trackingStateBucket = .insufficientFeatures
                    self.guidanceMessage = "Point at a well-lit textured surface"
                case .relocalizing:
                    self.trackingStateBucket = .relocalizing
                    self.guidanceMessage = "Re-localizing…"
                @unknown default:
                    self.guidanceMessage = "Limited tracking"
                }
            case .normal:
                self.trackingStateBucket = .normal
                if self.phase == .detectingFloor {
                    self.guidanceMessage = "Point your device at the floor"
                }
            }
            self.updateAICoachMessage(force: true)
        }
    }
}
