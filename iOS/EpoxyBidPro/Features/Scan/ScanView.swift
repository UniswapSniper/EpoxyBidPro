// ═══════════════════════════════════════════════════════════════════════════════
// ScanView.swift
// Full-screen perimeter-walk scanning UI.
// Phases: detectingFloor → placingStart → walking → complete.
// ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
import ARKit

struct ScanView: View {

    @StateObject private var scanManager = ScanSessionManager()
    @Environment(\.dismiss) private var dismiss

    @State private var showResult = false
    @State private var showResetConfirm = false
    @State private var pulseTracking = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ── AR Camera ────────────────────────────────────────
                ARViewContainer(scanManager: scanManager)
                    .ignoresSafeArea()

                // ── Overlays ─────────────────────────────────────────
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    statsBar
                    aiCoachBanner
                    guidanceBanner
                    bottomBar
                }
                .padding(.bottom, 10)

                // ── Phase-specific overlays ──────────────────────────
                if scanManager.phase == .detectingFloor {
                    detectingOverlay
                }

                if scanManager.phase == .placingStart {
                    placingStartOverlay
                }
                
                // ── Center Crosshair ─────────────────────────────
                if scanManager.phase == .placingStart || scanManager.phase == .walking {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(scanManager.isNearStartPoint ? EBPColor.success : EBPColor.onSurface)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden(true)
            .navigationDestination(isPresented: $showResult) {
                ScanResultView(
                    totalSqFt: scanManager.totalAreaSqFt,
                    perimeterFt: scanManager.totalPerimeterFt,
                    wallLengthsFt: scanManager.wallLengthsFt,
                    cornerCount: scanManager.cornerCount,
                    polygonVertices: scanManager.perimeterPoints.map(\.floorXZ),
                    polygonJson: scanManager.polygonJSON()
                )
            }
            .confirmationDialog("Reset Scan?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { scanManager.resetScan() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all corners and start over.")
            }
        }
        .onAppear { pulseTracking = true }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(EBPColor.onSurface)
                    .frame(width: 38, height: 38)
                    .background(EBPColor.surfaceContainerHigh)
                    .clipShape(Circle())
            }

            Spacer()

            if scanManager.isLiDARAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .font(.caption2)
                    Text("LiDAR")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(EBPColor.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(EBPColor.surfaceContainerHigh)
                .clipShape(Capsule())
            }

            if scanManager.phase == .walking && scanManager.perimeterPoints.count > 1 {
                Button { showResetConfirm = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(EBPColor.onSurface)
                        .frame(width: 38, height: 38)
                        .background(EBPColor.surfaceContainerHigh)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBar: some View {
        if scanManager.phase == .walking || scanManager.phase == .complete {
            HStack(spacing: 0) {
                statCell(
                    value: formatArea(scanManager.totalAreaSqFt),
                    label: "sq ft",
                    icon: "square.dashed"
                )
                Divider()
                    .frame(height: 32)
                    .background(Color.white.opacity(0.2))
                statCell(
                    value: "\(scanManager.cornerCount)",
                    label: "corners",
                    icon: "smallcircle.filled.circle"
                )
                Divider()
                    .frame(height: 32)
                    .background(Color.white.opacity(0.2))
                statCell(
                    value: formatLength(scanManager.totalPerimeterFt),
                    label: "perim",
                    icon: "arrow.triangle.2.circlepath"
                )
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(EBPColor.surfaceContainerHigh)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.3), value: scanManager.phase)
        }
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EBPColor.accent)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(EBPColor.onSurface)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(EBPColor.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Guidance Banner

    private var aiCoachBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(EBPColor.accent)
                Text("AI Scan Coach")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(EBPColor.onSurface)
                Spacer()
                Text("\(scanManager.scanQualityScore)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(scanQualityColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(scanQualityColor)
                        .frame(width: proxy.size.width * CGFloat(scanManager.scanQualityScore) / 100.0, height: 6)
                }
            }
            .frame(height: 6)

            Text(scanManager.aiCoachMessage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EBPColor.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EBPColor.surfaceContainerHigh)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(scanQualityColor.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .opacity(scanManager.phase == .complete ? 0.95 : 1)
    }

    private var guidanceBanner: some View {
        VStack(spacing: 4) {
            Text(scanManager.guidanceMessage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EBPColor.onSurface)
                .multilineTextAlignment(.center)

            if scanManager.phase == .walking && scanManager.currentWallLengthFt > 0.3 {
                Text("current wall: \(formatLength(scanManager.currentWallLengthFt)) ft")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(EBPColor.accent.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    private var scanQualityColor: Color {
        switch scanManager.scanQualityScore {
        case ..<45:
            return EBPColor.secondaryContainer
        case ..<75:
            return EBPColor.accent
        default:
            return EBPColor.success
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        switch scanManager.phase {
        case .detectingFloor:
            EmptyView()

        case .placingStart:
            EmptyView()  // handled by full-screen overlay

        case .walking:
            walkingBottomBar

        case .complete:
            completeBottomBar
        }
    }

    private var walkingBottomBar: some View {
        HStack(spacing: 24) {
            // Undo
            Button { scanManager.undoLastCorner() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(EBPColor.onSurface.opacity(0.8))
                        .background(EBPColor.surfaceContainerHigh)
                        .clipShape(Circle())
                    Text("Undo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EBPColor.onSurfaceVariant)
                }
            }
            .disabled(scanManager.perimeterPoints.count < 2)
            .opacity(scanManager.perimeterPoints.count < 2 ? 0.35 : 1)

            // Mark Corner (primary)
            Button { scanManager.markCorner() } label: {
                VStack(spacing: 6) {
                    ZStack {
                        // Outer pulsing ring
                        Circle()
                            .stroke(EBPColor.accent.opacity(0.3), lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseTracking ? 1.15 : 1.0)
                            .opacity(pulseTracking ? 0.0 : 0.6)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: pulseTracking
                            )

                        // Main button
                        Circle()
                            .fill(
                                scanManager.isNearStartPoint
                                    ? LinearGradient(colors: [EBPColor.success, EBPColor.success.opacity(0.7)],
                                                     startPoint: .top, endPoint: .bottom)
                                    : EBPColor.primaryGradient
                            )
                            .frame(width: 68, height: 68)
                            .overlay(
                                Image(systemName: scanManager.isNearStartPoint
                                      ? "checkmark" : "plus")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: (scanManager.isNearStartPoint ? EBPColor.success : EBPColor.accent).opacity(0.5),
                                    radius: 12, x: 0, y: 4)
                    }

                    Text(scanManager.isNearStartPoint ? "CLOSE" : "CORNER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(scanManager.isNearStartPoint ? EBPColor.success : EBPColor.accent)
                }
            }

            // Close loop
            Button { scanManager.closeLoop() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(canClose ? EBPColor.success : EBPColor.onSurface.opacity(0.35))
                        .background(EBPColor.surfaceContainerHigh)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(EBPColor.success.opacity(canClose ? 0.6 : 0), lineWidth: 2)
                        )
                    Text("Done")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EBPColor.onSurface.opacity(canClose ? 0.9 : 0.35))
                }
            }
            .disabled(!canClose)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var canClose: Bool {
        scanManager.perimeterPoints.count >= 3
    }

    private var completeBottomBar: some View {
        Button {
            showResult = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("View Results")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(EBPColor.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: EBPColor.accent.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: scanManager.phase)
    }

    // MARK: - Detecting Floor Overlay

    private var detectingOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: EBPColor.accent))
                    .scaleEffect(1.3)

                Text("Scanning for floor…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(EBPColor.onSurface)

                Text("Point your device downward\nand move slowly")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(EBPColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(EBPColor.surfaceContainerHigh)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(EBPColor.accent.opacity(0.15), lineWidth: 1)
            )

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
        .allowsHitTesting(false)
    }

    // MARK: - Placing Start Overlay

    private var placingStartOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "location.circle")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(EBPColor.accent)
                    .symbolEffect(.pulse, isActive: true)

                Text("Aim at a Corner")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(EBPColor.onSurface)

                Text("Point your camera at any corner of the room,\nthen tap below to place your start point.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EBPColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)

                Button { scanManager.placeStartPoint() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Place Start Point")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(EBPColor.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: EBPColor.accent.opacity(0.4), radius: 10)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(EBPColor.surfaceContainerHigh)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(EBPColor.accent.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 28)

            Spacer()
                .frame(height: 80)
        }
    }

    // MARK: - Formatting Helpers

    private func formatArea(_ sqft: Double) -> String {
        if sqft < 10 { return String(format: "%.1f", sqft) }
        return String(format: "%.0f", sqft)
    }

    private func formatLength(_ ft: Double) -> String {
        if ft < 10 { return String(format: "%.1f", ft) }
        return String(format: "%.0f", ft)
    }
}
