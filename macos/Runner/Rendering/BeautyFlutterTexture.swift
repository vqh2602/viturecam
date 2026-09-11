import CoreVideo
import FlutterMacOS
import Foundation

public final class BeautyFlutterTexture: NSObject, FlutterTexture {
    private var currentPixelBuffer: CVPixelBuffer?
    private let lock = NSLock()

    public override init() {
        super.init()
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = currentPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    public func updatePixelBuffer(_ buffer: CVPixelBuffer) {
        lock.lock()
        currentPixelBuffer = buffer
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        currentPixelBuffer = nil
        lock.unlock()
    }
}
