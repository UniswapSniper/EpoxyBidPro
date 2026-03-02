import Foundation
import RoomPlan
import SwiftUI
import simd

@available(iOS 16.0, *)
class AutoScanManager: NSObject, ObservableObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate, NSCoding {
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init()
    }
    
    func encode(with coder: NSCoder) {
    }
    
    @Published var isScanning = false
    @Published var isComplete = false
    @Published var statusMessage: String?
    @Published var aiCoachMessage: String = "AI coach: Keep your phone level and pan slowly around every wall."
    @Published var scanQualityScore: Int = 40
    
    @Published var totalAreaSqFt: Double = 0
    @Published var totalPerimeterFt: Double = 0
    @Published var wallLengthsFt: [Double] = []
    @Published var polygonVertices: [SIMD2<Float>] = []
    
    var captureView: RoomCaptureView?
    var sessionConfig = RoomCaptureSession.Configuration()
    var capturedRoom: CapturedRoom?
    private var pendingStartRequested = false
    private var coachingTimer: Timer?
    private var scanStartedAt: Date?
    
    func startSession() {
        guard RoomCaptureSession.isSupported else {
            isScanning = false
            isComplete = false
            statusMessage = "RoomPlan requires a LiDAR-capable iPhone or iPad Pro."
            return
        }

        guard let view = captureView else {
            pendingStartRequested = true
            isScanning = false
            isComplete = false
            statusMessage = "Preparing camera…"
            return
        }

        pendingStartRequested = false
        isScanning = true
        isComplete = false
        statusMessage = nil
        scanStartedAt = Date()
        aiCoachMessage = "AI coach: Begin with a slow sweep across floor-to-wall boundaries."
        scanQualityScore = 48
        startCoachingTimer()
        view.captureSession.run(configuration: sessionConfig)
    }
    
    func setupCaptureView(_ view: RoomCaptureView) {
        self.captureView = view
        view.delegate = self
        view.captureSession.delegate = self

        if pendingStartRequested {
            startSession()
        }
    }
    
    func stopSession() {
        captureView?.captureSession.stop()
        pendingStartRequested = false
        isScanning = false
        stopCoachingTimer()
    }
    
    // RoomCaptureViewDelegate
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error {
            DispatchQueue.main.async {
                self.isScanning = false
                self.statusMessage = error.localizedDescription
            }
            return false
        }

        return true
    }
    
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error {
            DispatchQueue.main.async {
                self.isScanning = false
                self.statusMessage = error.localizedDescription
            }
            return
        }

        processRoom(processedResult)
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.stopCoachingTimer()
            if let error {
                self.statusMessage = error.localizedDescription
            }
        }
    }
    
    private func processRoom(_ room: CapturedRoom) {
        self.capturedRoom = room
        
        var totalAreaMeters: Float = 0
        // Floors usually have x and y dimensions representing width/depth in meters.
        for floor in room.floors {
            let area = floor.dimensions.x * floor.dimensions.y
            totalAreaMeters += area
        }
        
        // 1 sq meter = 10.7639 sq ft
        let m2ToSqFt: Float = 10.7639
        self.totalAreaSqFt = Double(totalAreaMeters * m2ToSqFt)
        
        var lengths = [Double]()
        var perimMeters: Float = 0
        let mToFt: Float = 3.28084
        
        for wall in room.walls {
            let length = wall.dimensions.x // x is usually width of the wall plane
            perimMeters += length
            lengths.append(Double(length * mToFt))
        }
        
        self.totalPerimeterFt = Double(perimMeters * mToFt)
        self.wallLengthsFt = lengths
        
        // Ensure polygon preview has something to render. RoomPlan center is standard (0,0) with floor spanning outwards.
        if let floor = room.floors.first {
            let width = floor.dimensions.x
            let depth = floor.dimensions.y
            let halfW = width / 2
            let halfD = depth / 2
            
            self.polygonVertices = [
                SIMD2(-halfW,  halfD),
                SIMD2( halfW,  halfD),
                SIMD2( halfW, -halfD),
                SIMD2(-halfW, -halfD)
            ]
        } else {
            self.polygonVertices = []
        }
        
        DispatchQueue.main.async {
            self.isComplete = true
            self.isScanning = false
            self.stopCoachingTimer()
            self.statusMessage = nil
            self.aiCoachMessage = self.completionCoachMessage()
            self.scanQualityScore = self.completionQualityScore()
            AppHaptics.trigger(.success)
        }
    }

    private func startCoachingTimer() {
        stopCoachingTimer()
        coachingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateLiveCoachGuidance()
            }
        }
    }

    private func stopCoachingTimer() {
        coachingTimer?.invalidate()
        coachingTimer = nil
    }

    private func updateLiveCoachGuidance() {
        guard isScanning else { return }

        let elapsed = Date().timeIntervalSince(scanStartedAt ?? Date())

        if elapsed < 8 {
            aiCoachMessage = "AI coach: Move in a smooth arc and keep each wall fully in frame."
            scanQualityScore = max(scanQualityScore, 52)
            return
        }

        if elapsed < 20 {
            aiCoachMessage = "AI coach: Capture all corners once and avoid fast pivots for cleaner geometry."
            scanQualityScore = max(scanQualityScore, 60)
            return
        }

        aiCoachMessage = "AI coach: Final pass — revisit missed corners and floor edges, then tap Done Scanning."
        scanQualityScore = max(scanQualityScore, 68)
    }

    private func completionCoachMessage() -> String {
        if wallLengthsFt.count < 4 {
            return "AI coach: Scan saved, but low wall coverage detected. Re-scan once for stronger estimate confidence."
        }

        if totalAreaSqFt < 40 {
            return "AI coach: Scan complete. Verify dimensions for small areas and confirm corner placements before bidding."
        }

        return "AI coach: Great capture quality. Measurements are ready for bid pricing."
    }

    private func completionQualityScore() -> Int {
        let wallPoints = min(wallLengthsFt.count * 5, 24)
        let areaPoints = totalAreaSqFt > 120 ? 10 : (totalAreaSqFt > 60 ? 6 : 3)
        return max(58, min(96, 62 + wallPoints + areaPoints))
    }
    
    func getPolygonJSON() -> String {
        return "[]" 
    }
}

@available(iOS 16.0, *)
struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @ObservedObject var manager: AutoScanManager
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        manager.setupCaptureView(view)
        return view
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
