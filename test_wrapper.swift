import SwiftUI
import RoomPlan

@available(iOS 16.0, *)
class MyRoomCaptureView: RoomCaptureView {
    var onWindowPresent: (() -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            onWindowPresent?()
        }
    }
}
