import SwiftUI
import ARKit

// ─── ScanView ─────────────────────────────────────────────────────────────────
// Full-screen LiDAR scanning experience.
// Presented as a sheet from MainTabView.

struct ScanView: View {

    @StateObject private var scanManager = ScanSessionManager()
    @Environment(\.dismiss) private var dismiss

    @State private var isReviewing: Bool = false
    @State private var isShowingCaptureAlert: Bool = false
    @State private var captureAreaName: String = ""
    @State private var isShowingNoLiDARAlert: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ── AR / Camera layer ──────────────────────────────────────────
                if scanManager.isLiDARAvailable {
                    ARViewContainer(scanManager: scanManager)
                        .ignoresSafeArea()
                } else {
                    noLiDARPlaceholder
                }

                // ── HUD overlays ───────────────────────────────────────────────
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    capturedAreasDrawer
                    bottomBar
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $isReviewing) {
                ScanResultView(scanManager: scanManager, onSaved: { dismiss() })
            }
        }
        .alert("Name This Area", isPresented: $isShowingCaptureAlert) {
            TextField("e.g. Garage, Basement…", text: $captureAreaName)
            Button("Capture") {
                scanManager.captureArea(name: captureAreaName)
                captureAreaName = ""
            }
            Button("Cancel", role: .cancel) { captureAreaName = "" }
        } message: {
            Text(String(format: "%.0f sq ft will be saved", scanManager.detectedFloorSqFt))
        }
        .alert("LiDAR Not Available", isPresented: $isShowingNoLiDARAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("EpoxyBidPro's automatic floor measurement requires a LiDAR-equipped iPhone or iPad Pro.")
        }
        .onAppear {
            if !scanManager.isLiDARAvailable {
                isShowingNoLiDARAlert = true
            }
        }
    }

    // MARK: - Top bar (sq ft readout + close button)

    private var topBar: some View {
        HStack(alignment: .top, spacing: EBPSpacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .accessibilityLabel("Close")

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f sq ft", scanManager.detectedFloorSqFt))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(radius: 6)

                Text(scanManager.sessionMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 3)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(EBPSpacing.md)
        .padding(.top, 44)   // safe area top
        .background(.ultraThinMaterial.opacity(scanManager.isLiDARAvailable ? 0.6 : 0))
    }

    // MARK: - Captured areas list (shown when at least 1 area captured)

    @ViewBuilder
    private var capturedAreasDrawer: some View {
        if !scanManager.capturedAreas.isEmpty {
            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                HStack {
                    Label("Captured Areas", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "Total: %.0f sq ft", scanManager.totalCapturedSqFt))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(red: 0.4, green: 1, blue: 0.6))
                }

                ForEach(scanManager.capturedAreas) { area in
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .font(.caption)
                            .foregroundStyle(EBPColor.primary)
                        Text(area.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.0f sq ft", area.squareFeet))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                        Button {
                            scanManager.removeArea(area)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }
            .padding(EBPSpacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, EBPSpacing.md)
            .padding(.bottom, EBPSpacing.sm)
        }
    }

    // MARK: - Bottom action bar

    private var bottomBar: some View {
        HStack(spacing: EBPSpacing.md) {
            // Capture Area button
            Button {
                isShowingCaptureAlert = true
            } label: {
                Label("Capture Area", systemImage: "plus.viewfinder")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EBPColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!scanManager.isLiDARAvailable || scanManager.detectedFloorSqFt < 1)

            // Review & Save button
            if scanManager.hasCaptures {
                Button {
                    isReviewing = true
                } label: {
                    Label("Review", systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, EBPSpacing.md)
                        .background(Color.green.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(EBPSpacing.md)
        .padding(.bottom, 20)   // tab bar clearance
        .background(.ultraThinMaterial)
    }

    // MARK: - Non-LiDAR placeholder

    private var noLiDARPlaceholder: some View {
        ZStack {
            Color(.systemBackground)
            VStack(spacing: EBPSpacing.md) {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 64))
                    .foregroundStyle(EBPColor.primary)
                Text("LiDAR Required")
                    .font(.title2.bold())
                Text("Automatic floor measurement requires a LiDAR-equipped iPhone or iPad Pro.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, EBPSpacing.lg)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(EBPColor.primary)
            }
        }
        .ignoresSafeArea()
    }
}

