import SwiftUI
import RoomPlan

@available(iOS 16.0, *)
struct AutoScanView: View {
    @StateObject private var scanManager = AutoScanManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showResult = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // RoomPlan Capture View
                RoomCaptureViewRepresentable(manager: scanManager)
                    .ignoresSafeArea()
                
                // Controls overlay
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(EBPColor.onSurface)
                                .frame(width: 38, height: 38)
                                .background(EBPColor.surfaceContainerHigh)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "square.fill.on.square.fill")
                                .font(.caption2)
                            Text("RoomPlan")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(EBPColor.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(EBPColor.surfaceContainerHigh)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

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
                    .background(Color.black.opacity(0.30))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(scanQualityColor.opacity(0.45), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if let statusMessage = scanManager.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(EBPColor.onSurface)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(EBPColor.surfaceContainerHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    if scanManager.isScanning {
                        Button {
                            scanManager.stopSession()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Done Scanning")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(EBPColor.error)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }
                    } else if !scanManager.isComplete {
                        Button {
                            scanManager.startSession()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Start Auto-Scan")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(EBPColor.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }
                        .disabled(scanManager.statusMessage == "Preparing camera…")
                        .opacity(scanManager.statusMessage == "Preparing camera…" ? 0.7 : 1)
                    } else {
                        Button {
                            showResult = true
                        } label: {
                            HStack(spacing: 8) {
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
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden(true)
            .navigationDestination(isPresented: $showResult) {
                ScanResultView(
                    totalSqFt: scanManager.totalAreaSqFt,
                    perimeterFt: scanManager.totalPerimeterFt,
                    wallLengthsFt: scanManager.wallLengthsFt,
                    cornerCount: scanManager.wallLengthsFt.count,
                    polygonVertices: scanManager.polygonVertices,
                    polygonJson: scanManager.getPolygonJSON()
                )
            }
            .onAppear {
                // Auto-start with a short delay to ensure RoomCaptureView is in window hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scanManager.startSession()
                }
            }
            .onDisappear {
                scanManager.stopSession()
            }
        }
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
}
