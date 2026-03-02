// ═══════════════════════════════════════════════════════════════════════════════
// ScanResultView.swift
// Post-scan results with polygon map, wall dimensions, quick estimates,
// and save-to-SwiftData → BidBuilder navigation.
// ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
import SwiftData
import simd

struct ScanResultView: View {

    // ── Inputs from ScanView ────────────────────────────────────────────────

    let totalSqFt: Double
    let perimeterFt: Double
    let wallLengthsFt: [Double]
    let cornerCount: Int
    let polygonVertices: [SIMD2<Float>]
    let polygonJson: String

    // ── Environment ─────────────────────────────────────────────────────────

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // ── Local State ─────────────────────────────────────────────────────────

    @State private var areaName = "Garage Floor"
    @State private var editedSqFt: Double = 0
    @State private var savedMeasurement: Measurement?
    @State private var showSuccessBanner = false
    @State private var navigateToBid = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                polygonMapSection
                dimensionsSection
                quickEstimateSection
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(EBPColor.canvas.ignoresSafeArea())
        .navigationTitle("Scan Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToBid) {
            if let m = savedMeasurement {
                BidBuilderView(initialMeasurement: m)
            }
        }
        .onAppear { editedSqFt = totalSqFt }
        .overlay(alignment: .top) {
            if showSuccessBanner {
                successBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Area
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", editedSqFt))
                        .font(EBPFont.stat)
                        .foregroundStyle(EBPColor.accent)
                    Text("sq ft")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 44)

                // Perimeter
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", perimeterFt))
                        .font(EBPFont.statSm)
                        .foregroundStyle(.primary)
                    Text("ft perimeter")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 44)

                // Corners
                VStack(spacing: 2) {
                    Text("\(cornerCount)")
                        .font(EBPFont.statSm)
                        .foregroundStyle(.primary)
                    Text("corners")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Editable area name
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(EBPColor.accent)
                    .font(.caption)
                TextField("Area Name", text: $areaName)
                    .font(EBPFont.callout)
            }
            .padding(12)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowSubtle()
    }

    // MARK: - Polygon Map

    private var polygonMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EBPSectionHeader(title: "Floor Plan")

            PolygonMapView(
                vertices: polygonVertices,
                wallLengthsFt: wallLengthsFt
            )
            .frame(height: 220)
            .padding(12)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
        }
    }

    // MARK: - Wall Dimensions

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EBPSectionHeader(title: "Wall Dimensions")

            VStack(spacing: 6) {
                ForEach(Array(wallLengthsFt.enumerated()), id: \.offset) { index, length in
                    HStack {
                        Text("Wall \(index + 1)")
                            .font(EBPFont.callout)
                        Spacer()
                        Text(String(format: "%.1f ft", length))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(EBPColor.accent)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(
                        index.isMultiple(of: 2)
                            ? EBPColor.surface
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }
            .padding(12)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
        }
    }

    // MARK: - Quick Estimates

    private var quickEstimateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EBPSectionHeader(title: "Quick Estimates")

            VStack(spacing: 8) {
                estimateRow("Residential Epoxy",  range: 3...5,   icon: "paintbrush.fill")
                estimateRow("Metallic Epoxy",     range: 6...10,  icon: "sparkles")
                estimateRow("Polyaspartic",       range: 8...14,  icon: "bolt.fill")
                estimateRow("Full Flake",         range: 5...8,   icon: "square.grid.3x3.fill")
            }
            .padding(14)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
        }
    }

    private func estimateRow(_ name: String, range: ClosedRange<Int>, icon: String) -> some View {
        let low  = editedSqFt * Double(range.lowerBound)
        let high = editedSqFt * Double(range.upperBound)
        return HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(EBPColor.accent)
                .frame(width: 22)
            Text(name)
                .font(EBPFont.callout)
            Spacer()
            Text("$\(Int(low)) – $\(Int(high))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(EBPColor.success)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save & Build Bid
            Button { saveAndBuildBid() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                    Text("Save & Build Bid")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(EBPColor.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                .shadow(color: EBPColor.accent.opacity(0.3), radius: 10, y: 4)
            }

            // Save Only
            Button { saveOnly() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Measurement")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(EBPColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EBPColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: EBPRadius.md)
                        .stroke(EBPColor.accent.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Save Logic

    private func saveAndBuildBid() {
        let measurement = persistMeasurement()
        savedMeasurement = measurement
        showSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            navigateToBid = true
        }
    }

    private func saveOnly() {
        _ = persistMeasurement()
        showSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private func persistMeasurement() -> Measurement {
        let measurement = Measurement(
            label: areaName,
            notes: "Perimeter scan – \(cornerCount) corners",
            totalSqFt: editedSqFt,
            scanDate: Date()
        )
        modelContext.insert(measurement)

        let area = Area(
            name: areaName,
            squareFeet: editedSqFt,
            polygonJson: polygonJson,
            sortOrder: 0,
            capturedAt: Date()
        )
        area.measurement = measurement
        modelContext.insert(area)

        try? modelContext.save()
        return measurement
    }

    private func showSuccess() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showSuccessBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSuccessBanner = false }
        }
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EBPColor.success)
            Text("Measurement saved!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(EBPColor.success.opacity(0.2))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
    }
}

// MARK: - Polygon Map View (2-D top-down)

struct PolygonMapView: View {

    let vertices: [SIMD2<Float>]
    let wallLengthsFt: [Double]

    var body: some View {
        GeometryReader { geo in
            let scaled = scaleToFit(vertices: vertices, in: geo.size, padding: 44)

            Canvas { context, _ in
                guard scaled.count >= 3 else { return }

                // Filled polygon
                var fillPath = Path()
                fillPath.move(to: scaled[0])
                for pt in scaled.dropFirst() { fillPath.addLine(to: pt) }
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(EBPColor.accent.opacity(0.12)))
                context.stroke(fillPath, with: .color(EBPColor.accent), lineWidth: 2.5)

                // Corner dots
                for pt in scaled {
                    let r: CGFloat = 4.5
                    let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(EBPColor.accent))
                }
            }

            // Wall length labels
            ForEach(Array(wallLengthsFt.enumerated()), id: \.offset) { idx, length in
                if idx < scaled.count {
                    let from = scaled[idx]
                    let to   = scaled[(idx + 1) % scaled.count]
                    let mid  = CGPoint(x: (from.x + to.x) / 2,
                                       y: (from.y + to.y) / 2)

                    Text(String(format: "%.1f'", length))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(EBPColor.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(EBPColor.surface.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .position(mid)
                }
            }
        }
    }

    // Scale + center polygon into the available rect.
    private func scaleToFit(vertices: [SIMD2<Float>],
                            in size: CGSize,
                            padding: CGFloat) -> [CGPoint] {
        guard !vertices.isEmpty else { return [] }

        let xs = vertices.map { CGFloat($0.x) }
        let ys = vertices.map { CGFloat($0.y) }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!

        let dw = maxX - minX
        let dh = maxY - minY
        let aw = size.width  - 2 * padding
        let ah = size.height - 2 * padding

        let scale: CGFloat
        if dw < 0.001 && dh < 0.001 { scale = 1 }
        else if dw < 0.001          { scale = ah / dh }
        else if dh < 0.001          { scale = aw / dw }
        else                        { scale = min(aw / dw, ah / dh) }

        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2

        return vertices.map { v in
            CGPoint(
                x: (CGFloat(v.x) - cx) * scale + size.width  / 2,
                y: (CGFloat(v.y) - cy) * scale + size.height / 2
            )
        }
    }
}
