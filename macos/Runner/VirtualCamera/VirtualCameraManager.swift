import CoreMedia
import CoreVideo
import Foundation

public final class VirtualCameraManager {
    public static let shared = VirtualCameraManager()

    public private(set) var isActive: Bool = false
    public let virtualCameraName: String = "Beauty Camera"

    private let queue = DispatchQueue(label: "com.beautycamera.virtualcam", qos: .userInteractive)

    private init() {}

    public func start() -> Bool {
        isActive = true
        print("[VirtualCameraManager] Started virtual camera: \(virtualCameraName)")
        return true
    }

    public func stop() {
        isActive = false
        print("[VirtualCameraManager] Stopped virtual camera")
    }

    public func sendFrame(pixelBuffer: CVPixelBuffer) {
        guard isActive else { return }
        queue.async { [weak self] in
            guard let self = self, self.isActive else { return }
            // Feed frame into CoreMediaIO extension stream / shared memory buffer
            _ = pixelBuffer
        }
    }
}
