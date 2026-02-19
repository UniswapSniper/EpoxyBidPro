import ARKit
import simd

// ─── FloorMeshProcessor ───────────────────────────────────────────────────────
// Extracts floor surface area (in sq ft) from ARKit LiDAR mesh anchors.
// Uses triangle-based area summation over floor-classified mesh faces.

enum FloorMeshProcessor {

    // Conversion: 1 m² = 10.7639 sq ft
    private static let sqMetersToSqFt: Double = 10.7639

    // MARK: - Public API

    /// Total floor area across all mesh anchors, in sq ft.
    static func computeTotalFloorArea(from anchors: [ARMeshAnchor]) -> Double {
        let totalM2 = anchors.reduce(0.0) { $0 + floorArea(in: $1) }
        return totalM2 * sqMetersToSqFt
    }

    /// Builds a compact JSON string of floor polygon vertices [[x, z], ...]
    /// projected onto the XZ plane (Y = up in ARKit world coordinates).
    static func buildPolygonJson(from anchors: [ARMeshAnchor]) -> String {
        var points: [SIMD2<Float>] = []
        for anchor in anchors {
            points.append(contentsOf: floorVertices(in: anchor))
        }
        // Reduce to convex hull for compact storage
        let hull = convexHull(of: points)
        let jsonArray = hull.map { "[\(String(format: "%.3f", $0.x)),\(String(format: "%.3f", $0.y))]" }
        return "[\(jsonArray.joined(separator: ","))]"
    }

    // MARK: - Area computation

    private static func floorArea(in anchor: ARMeshAnchor) -> Double {
        let geometry = anchor.geometry
        let transform = anchor.transform
        let faceCount = geometry.faces.count

        var totalAreaM2: Float = 0.0

        for faceIndex in 0..<faceCount {
            guard faceClassification(geometry: geometry, faceIndex: faceIndex) == .floor else { continue }

            let (v0, v1, v2) = faceVertices(geometry: geometry, transform: transform, faceIndex: faceIndex)

            // Triangle area = 0.5 * |cross(e1, e2)|
            let e1 = v1 - v0
            let e2 = v2 - v0
            let cross = simd_cross(e1, e2)
            totalAreaM2 += simd_length(cross) * 0.5
        }

        return Double(totalAreaM2)
    }

    // MARK: - Polygon vertex extraction

    private static func floorVertices(in anchor: ARMeshAnchor) -> [SIMD2<Float>] {
        let geometry = anchor.geometry
        let transform = anchor.transform
        let faceCount = geometry.faces.count

        var xzPoints: [SIMD2<Float>] = []
        xzPoints.reserveCapacity(min(faceCount, 512))

        for faceIndex in 0..<faceCount {
            guard faceClassification(geometry: geometry, faceIndex: faceIndex) == .floor else { continue }

            let (v0, v1, v2) = faceVertices(geometry: geometry, transform: transform, faceIndex: faceIndex)
            // Project to XZ plane (Y is up in ARKit)
            xzPoints.append(SIMD2<Float>(v0.x, v0.z))
            xzPoints.append(SIMD2<Float>(v1.x, v1.z))
            xzPoints.append(SIMD2<Float>(v2.x, v2.z))

            // Cap collection to keep JSON size reasonable
            if xzPoints.count > 1500 { break }
        }
        return xzPoints
    }

    // MARK: - ARKit geometry helpers

    private static func faceClassification(geometry: ARMeshGeometry, faceIndex: Int) -> ARMeshClassification {
        let source = geometry.classification
        let offset = source.offset + faceIndex * source.stride
        let raw = source.buffer.contents().load(fromByteOffset: offset, as: UInt8.self)
        return ARMeshClassification(rawValue: raw) ?? .none
    }

    private static func faceVertices(
        geometry: ARMeshGeometry,
        transform: simd_float4x4,
        faceIndex: Int
    ) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        let i0 = faceVertexIndex(geometry: geometry, faceIndex: faceIndex, vertexPosition: 0)
        let i1 = faceVertexIndex(geometry: geometry, faceIndex: faceIndex, vertexPosition: 1)
        let i2 = faceVertexIndex(geometry: geometry, faceIndex: faceIndex, vertexPosition: 2)
        let v0 = worldSpaceVertex(geometry: geometry, vertexIndex: i0, transform: transform)
        let v1 = worldSpaceVertex(geometry: geometry, vertexIndex: i1, transform: transform)
        let v2 = worldSpaceVertex(geometry: geometry, vertexIndex: i2, transform: transform)
        return (v0, v1, v2)
    }

    private static func faceVertexIndex(geometry: ARMeshGeometry, faceIndex: Int, vertexPosition: Int) -> Int {
        let faces = geometry.faces
        let byteOffset = faceIndex * 3 * faces.bytesPerIndex + vertexPosition * faces.bytesPerIndex
        if faces.bytesPerIndex == 2 {
            return Int(faces.buffer.contents().load(fromByteOffset: byteOffset, as: UInt16.self))
        } else {
            return Int(faces.buffer.contents().load(fromByteOffset: byteOffset, as: UInt32.self))
        }
    }

    private static func worldSpaceVertex(
        geometry: ARMeshGeometry,
        vertexIndex: Int,
        transform: simd_float4x4
    ) -> SIMD3<Float> {
        let source = geometry.vertices
        let byteOffset = source.offset + vertexIndex * source.stride
        let localPos = source.buffer.contents().load(fromByteOffset: byteOffset, as: SIMD3<Float>.self)
        let worldPos4 = transform * SIMD4<Float>(localPos.x, localPos.y, localPos.z, 1)
        return SIMD3<Float>(worldPos4.x, worldPos4.y, worldPos4.z)
    }

    // MARK: - Convex Hull (Gift Wrapping)

    private static func convexHull(of points: [SIMD2<Float>]) -> [SIMD2<Float>] {
        guard points.count >= 3 else { return points }

        // Find leftmost point
        var startIdx = 0
        for i in 1..<points.count {
            if points[i].x < points[startIdx].x { startIdx = i }
        }

        var hull: [SIMD2<Float>] = []
        var current = startIdx

        repeat {
            hull.append(points[current])
            var next = (current + 1) % points.count

            for i in 0..<points.count {
                if orientation(points[current], points[next], points[i]) < 0 {
                    next = i
                }
            }
            current = next

            if hull.count > 256 { break } // safety cap
        } while current != startIdx

        return hull
    }

    /// Returns negative if (a→b→c) is counter-clockwise (left turn).
    private static func orientation(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}
