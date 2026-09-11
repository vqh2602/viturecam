import CoreVideo
import Foundation

public final class PixelBufferPool {
    private var pool: CVPixelBufferPool?
    private(set) var width: Int = 0
    private(set) var height: Int = 0
    private(set) var pixelFormat: OSType = kCVPixelFormatType_32BGRA

    public init() {}

    deinit {
        pool = nil
    }

    public func prepare(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) {
        if self.width == width && self.height == height && self.pixelFormat == pixelFormat && pool != nil {
            return
        }

        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.pool = nil

        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 6
        ]

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any]
        ]

        var newPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &newPool
        )

        if status == kCVReturnSuccess {
            self.pool = newPool
        } else {
            print("[PixelBufferPool] Failed to create CVPixelBufferPool: status \(status)")
        }
    }

    public func getPixelBuffer() -> CVPixelBuffer? {
        guard let pool = pool else { return nil }
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        if status == kCVReturnSuccess {
            return pixelBuffer
        }
        return nil
    }
}
