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
    
    @Published var totalAreaSqFt: Double = 0
    @Published var totalPerimeterFt: Double = 0
    @Published var wallLengthsFt: [Double] = []
    @Published var polygonVertices: [SIMD2<Float>] = []
    
    var captureView: RoomCaptureView?
    var sessionConfig = RoomCaptureSession.Configuration()
    var capturedRoom: CapturedRoom?
    private var pendingStartRequested = false
    
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
            self.statusMessage = nil
            AppHaptics.trigger(.success)
        }
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
