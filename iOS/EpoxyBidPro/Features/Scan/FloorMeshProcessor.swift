// ═══════════════════════════════════════════════════════════════════════════════
// FloorMeshProcessor.swift  –  PerimeterProcessor
// Pure-geometry helpers: Shoelace area, perimeter, wall lengths, JSON export.
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import simd

enum PerimeterProcessor {

    // MARK: - Constants

    static let metersToFeet: Double  = 3.28084
    static let sqMToSqFt:   Double   = 10.7639

    // MARK: - Polygon Area (Shoelace)

    /// Returns the area of a simple polygon in **square meters**.
    /// Vertices are 2-D floor-plane coordinates (x, z).
    static func polygonArea(vertices: [SIMD2<Float>]) -> Float {
        guard vertices.count >= 3 else { return 0 }
        var sum: Float = 0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            sum += vertices[i].x * vertices[j].y
            sum -= vertices[j].x * vertices[i].y
        }
        return abs(sum) / 2.0
    }

    /// Area in **square feet**.
    static func polygonAreaSqFt(vertices: [SIMD2<Float>]) -> Double {
        Double(polygonArea(vertices: vertices)) * sqMToSqFt
    }

    // MARK: - Perimeter Length

    /// Total perimeter in **meters**. If `closed` the closing segment is included.
    static func perimeterLength(vertices: [SIMD2<Float>], closed: Bool) -> Float {
        guard vertices.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(vertices.count - 1) {
            total += simd_distance(vertices[i], vertices[i + 1])
        }
        if closed, vertices.count >= 3 {
            total += simd_distance(vertices.last!, vertices.first!)
        }
        return total
    }

    /// Perimeter in **feet**.
    static func perimeterLengthFt(vertices: [SIMD2<Float>], closed: Bool) -> Double {
        Double(perimeterLength(vertices: vertices, closed: closed)) * metersToFeet
    }

    // MARK: - Wall Lengths

    /// Individual wall segment lengths in **feet**, including closing segment when `closed`.
    static func wallLengthsFt(vertices: [SIMD2<Float>], closed: Bool) -> [Double] {
        guard vertices.count >= 2 else { return [] }
        var lengths: [Double] = []
        for i in 0..<(vertices.count - 1) {
            lengths.append(Double(simd_distance(vertices[i], vertices[i + 1])) * metersToFeet)
        }
        if closed, vertices.count >= 3 {
            lengths.append(Double(simd_distance(vertices.last!, vertices.first!)) * metersToFeet)
        }
        return lengths
    }

    // MARK: - JSON Export

    /// Encode the polygon as a JSON array of `{ "x": …, "z": … }` dictionaries.
    static func toJSON(vertices: [SIMD2<Float>]) -> String {
        let points: [[String: Double]] = vertices.map {
            ["x": Double($0.x), "z": Double($0.y)]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: points, options: .sortedKeys),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
