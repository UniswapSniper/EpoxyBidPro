import SwiftUI
import SwiftData

// ─── ScanResultView ───────────────────────────────────────────────────────────
// Post-scan review screen: edit area names, add a label, save to SwiftData.

struct ScanResultView: View {

    @ObservedObject var scanManager: ScanSessionManager
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Local editable state mirrored from scanManager
    @State private var areaNames: [UUID: String] = [:]
    @State private var measurementLabel: String = ""
    @State private var measurementNotes: String = ""
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false

    private var totalSqFt: Double {
        scanManager.capturedAreas.reduce(0) { $0 + $1.squareFeet }
    }

    var body: some View {
        List {
            // ── Summary header ─────────────────────────────────────────────
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.0f", totalSqFt))
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(EBPColor.primary)
                        Text("total sq ft • \(scanManager.capturedAreas.count) area\(scanManager.capturedAreas.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(EBPColor.primary.opacity(0.25))
                }
                .padding(.vertical, EBPSpacing.sm)
            }

            // ── Measurement label & notes ─────────────────────────────────
            Section("Measurement Details") {
                TextField("Label (e.g. 123 Main St – Garage)", text: $measurementLabel)
                    .textInputAutocapitalization(.words)
                TextField("Notes (optional)", text: $measurementNotes, axis: .vertical)
                    .lineLimit(3)
            }

            // ── Area breakdown ─────────────────────────────────────────────
            Section("Areas") {
                ForEach(scanManager.capturedAreas) { area in
                    HStack {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(EBPColor.primary)

                        TextField("Area name", text: Binding(
                            get: { areaNames[area.id] ?? area.name },
                            set: { areaNames[area.id] = $0 }
                        ))
                        .textInputAutocapitalization(.words)

                        Spacer()

                        Text(String(format: "%.0f sq ft", area.squareFeet))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    scanManager.removeAreas(at: offsets)
                }
            }

            // ── Cost estimate preview ─────────────────────────────────────
            if totalSqFt > 0 {
                Section("Quick Estimate") {
                    QuickEstimateRow(label: "Residential Epoxy", rateLabel: "~$3–5 / sq ft",
                                     low: totalSqFt * 3, high: totalSqFt * 5)
                    QuickEstimateRow(label: "Metallic / Decorative", rateLabel: "~$6–10 / sq ft",
                                     low: totalSqFt * 6, high: totalSqFt * 10)
                    QuickEstimateRow(label: "Polyaspartic Full System", rateLabel: "~$8–14 / sq ft",
                                     low: totalSqFt * 8, high: totalSqFt * 14)
                }
                .listRowBackground(EBPColor.primary.opacity(0.04))
            }

            // ── Save button ───────────────────────────────────────────────
            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Label("Save Measurement", systemImage: "square.and.arrow.down")
                        }
                        Spacer()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)
                }
                .listRowBackground(EBPColor.primary)
                .disabled(isSaving || scanManager.capturedAreas.isEmpty)
            }
        }
        .navigationTitle("Review Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
        .onAppear {
            // Pre-fill names from manager
            for area in scanManager.capturedAreas {
                areaNames[area.id] = area.name
            }
        }
        .overlay {
            if showSaveSuccess {
                saveSuccessBanner
            }
        }
    }

    // MARK: - Save logic

    private func save() {
        isSaving = true

        // Build the Measurement object
        let measurement = Measurement()
        measurement.label = measurementLabel.isEmpty
            ? "Scan – \(Date().formatted(date: .abbreviated, time: .shortened))"
            : measurementLabel
        measurement.notes = measurementNotes
        measurement.totalSqFt = totalSqFt
        measurement.scanDate = Date()

        // Build Areas
        for (idx, capturedArea) in scanManager.capturedAreas.enumerated() {
            let area = Area()
            area.name = areaNames[capturedArea.id] ?? capturedArea.name
            area.squareFeet = capturedArea.squareFeet
            area.polygonJson = capturedArea.polygonVerticesJson
            area.sortOrder = idx
            area.capturedAt = capturedArea.capturedAt
            area.measurement = measurement
            measurement.areas.append(area)
            modelContext.insert(area)
        }

        modelContext.insert(measurement)

        do {
            try modelContext.save()
            withAnimation { showSaveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                onSaved()
            }
        } catch {
            isSaving = false
        }
    }

    // MARK: - Success banner

    private var saveSuccessBanner: some View {
        VStack {
            HStack(spacing: EBPSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Measurement Saved!")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(EBPSpacing.md)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.top, EBPSpacing.lg)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Quick Estimate Row

private struct QuickEstimateRow: View {
    let label: String
    let rateLabel: String
    let low: Double
    let high: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                Text(rateLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("$\(Int(low).formatted())–$\(Int(high).formatted())")
                .font(.caption.weight(.bold))
                .foregroundStyle(EBPColor.primary)
        }
    }
}
