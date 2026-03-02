// ═══════════════════════════════════════════════════════════════════════════════
// PerimeterRenderer.swift
// RealityKit entity management — wall lines, corner markers, tracking line.
// ═══════════════════════════════════════════════════════════════════════════════

import RealityKit
import UIKit
import simd

/// Renders the perimeter polygon in the AR scene as glowing cyan lines & markers.
final class PerimeterRenderer {

    // MARK: - Scene graph

    private let arView: ARView
    private let rootAnchor = AnchorEntity(world: .zero)

    private var wallEntities:   [ModelEntity] = []
    private var cornerEntities: [ModelEntity] = []
    private var trackingLineEntity: ModelEntity?
    private var startRingEntity:    ModelEntity?
    private var reticleEntity:      ModelEntity?

    // MARK: - Materials

    private let wallMaterial:     UnlitMaterial
    private let cornerMaterial:   UnlitMaterial
    private let startMaterial:    UnlitMaterial
    private let trackingMaterial: UnlitMaterial
    private let closeMaterial:    UnlitMaterial   // highlighted when near start

    // MARK: - Geometry constants

    private let wallHeight:   Float = 0.008   // 8 mm
    private let wallDepth:    Float = 0.028    // 28 mm wide ribbon
    private let cornerRadius: Float = 0.035    // 35 mm sphere
    private let startRadius:  Float = 0.055    // 55 mm
    private let trackDepth:   Float = 0.018    // thinner tracking line

    // MARK: - Init

    init(arView: ARView) {
        self.arView = arView

        // Electric cyan  (EBPColor.accent ≈ rgb(0, 255, 242))
        let cyanUI = UIColor(red: 0, green: 1.0, blue: 0.95, alpha: 0.92)
        wallMaterial     = UnlitMaterial(color: cyanUI)
        cornerMaterial   = UnlitMaterial(color: cyanUI)

        // Brighter start marker
        let startUI = UIColor(red: 0.15, green: 1.0, blue: 0.7, alpha: 1.0)
        startMaterial = UnlitMaterial(color: startUI)

        // Dimmer tracking line
        let trackUI = UIColor(red: 0, green: 1.0, blue: 0.95, alpha: 0.45)
        trackingMaterial = UnlitMaterial(color: trackUI)

        // Close-snap highlight (warm green)
        let closeUI = UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1.0)
        closeMaterial = UnlitMaterial(color: closeUI)

        arView.scene.addAnchor(rootAnchor)
    }

    // MARK: - Public API

    /// Add a permanent wall line between two floor-plane positions.
    func addWallLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let dir = end - start
        let length = simd_length(dir)
        guard length > 0.005 else { return }

        let mid = (start + end) / 2
        let mesh = MeshResource.generateBox(width: length, height: wallHeight, depth: wallDepth)
        let entity = ModelEntity(mesh: mesh, materials: [wallMaterial])
        entity.position = mid

        // Align local X-axis with wall direction
        let normDir = simd_normalize(SIMD3<Float>(dir.x, 0, dir.z))
        let refAxis = SIMD3<Float>(1, 0, 0)
        if simd_dot(refAxis, normDir) < -0.9999 {
            entity.orientation = simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0))
        } else {
            entity.orientation = simd_quatf(from: refAxis, to: normDir)
        }

        rootAnchor.addChild(entity)
        wallEntities.append(entity)
    }

    /// Add a corner sphere (start = larger, green-tinted).
    func addCornerMarker(at position: SIMD3<Float>, isStart: Bool) {
        let r = isStart ? startRadius : cornerRadius
        let mat = isStart ? startMaterial : cornerMaterial
        let mesh = MeshResource.generateSphere(radius: r)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.position = position
        rootAnchor.addChild(entity)
        cornerEntities.append(entity)

        if isStart {
            // Add a flat ring around start marker for visibility
            let ringMesh = MeshResource.generateBox(width: 0.18, height: 0.003, depth: 0.18, cornerRadius: 0.09)
            let ringEntity = ModelEntity(mesh: ringMesh, materials: [startMaterial])
            ringEntity.position = SIMD3(position.x, position.y - 0.002, position.z)
            rootAnchor.addChild(ringEntity)
            startRingEntity = ringEntity
        }
    }

    /// Update the dashed tracking line from last corner → current device floor position.
    func updateTrackingLine(from: SIMD3<Float>, to: SIMD3<Float>, isNearStart: Bool) {
        trackingLineEntity?.removeFromParent()

        let dir = to - from
        let length = simd_length(dir)
        guard length > 0.01 else { return }

        let mid = (from + to) / 2
        let mesh = MeshResource.generateBox(width: length, height: wallHeight * 0.6, depth: trackDepth)
        let mat = isNearStart ? closeMaterial : trackingMaterial
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.position = mid

        let normDir = simd_normalize(SIMD3<Float>(dir.x, 0, dir.z))
        let refAxis = SIMD3<Float>(1, 0, 0)
        if simd_dot(refAxis, normDir) < -0.9999 {
            entity.orientation = simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0))
        } else {
            entity.orientation = simd_quatf(from: refAxis, to: normDir)
        }

        rootAnchor.addChild(entity)
        trackingLineEntity = entity
    }

    /// Rebuild the full visualization (used after undo).
    func rebuildVisualization(points: [SIMD3<Float>], isClosed: Bool) {
        clearAll()

        for (i, pos) in points.enumerated() {
            addCornerMarker(at: pos, isStart: i == 0)
            if i > 0 {
                addWallLine(from: points[i - 1], to: pos)
            }
        }
        if isClosed, points.count >= 3 {
            addWallLine(from: points.last!, to: points.first!)
        }
    }

    /// Remove every entity from the AR scene.
    func clearAll() {
        (wallEntities + cornerEntities).forEach { $0.removeFromParent() }
        trackingLineEntity?.removeFromParent()
        startRingEntity?.removeFromParent()
        reticleEntity?.removeFromParent()
        wallEntities.removeAll()
        cornerEntities.removeAll()
        trackingLineEntity = nil
        startRingEntity    = nil
        reticleEntity      = nil
    }

    /// Update the floating reticle that shows exactly where the user is going to place a corner or start point.
    func updateReticle(at position: SIMD3<Float>) {
        if reticleEntity == nil {
            // A semi-transparent ring on the floor to show where the aim point is.
            let mesh = MeshResource.generateBox(width: 0.1, height: 0.002, depth: 0.1, cornerRadius: 0.05)
            let matLine = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7)
            let material = UnlitMaterial(color: matLine)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            rootAnchor.addChild(entity)
            reticleEntity = entity
        }
        reticleEntity?.position = position
    }
}
