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
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial)
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
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if let statusMessage = scanManager.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
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
                            .background(Color.red)
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
}
