import CoreImage
import CoreML
import CoreVideo
import Foundation
import Metal
import QuartzCore

/// Core 2: Face & Skin Segmentation using MediaPipe Selfie Multiclass Segmentation (Class 3: Face-Skin)
/// Extracts genuine face skin boundaries with semantic awareness (AirPods Max, hair, clothes, background are excluded).
public final class SkinSegmenter {
    private var model: MLModel?
    private var ciContext: CIContext
    private var inputPixelBuffer: CVPixelBuffer?
    private let segmentationQueue = DispatchQueue(label: "com.beautycamera.skinsegmenter", qos: .userInteractive)
    private let lock = NSLock()

    // Cached mask for temporal smoothing & fallback
    private var cachedMask: CIImage?
    private var lastProcessTime: TimeInterval = 0

    public init() {
        if let mtlDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: mtlDevice, options: [.priorityRequestLow: false])
        } else {
            self.ciContext = CIContext(options: nil)
        }
        setupModel()
        setupInputBuffer()
    }

    private func setupModel() {
        let fileManager = FileManager.default
        var candidateURLs: [URL] = []

        if let bundleURL = Bundle.main.url(forResource: "SelfieSegmenter", withExtension: "mlmodelc") {
            candidateURLs.append(bundleURL)
        }
        let appResources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/SelfieSegmenter.mlmodelc")
        candidateURLs.append(appResources)

        let projectPath = "/Users/vuongquanghuy/code/flutter_project/viturecam/macos/Runner/FaceTracking/SelfieSegmenter.mlmodelc"
        candidateURLs.append(URL(fileURLWithPath: projectPath))

        for url in candidateURLs {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all // Apple Neural Engine + Metal GPU
                    self.model = try MLModel(contentsOf: url, configuration: config)
                    NSLog("[SkinSegmenter] Successfully loaded SelfieSegmenter model from: %@", url.path)
                    break
                } catch {
                    NSLog("[SkinSegmenter] Failed to load model at %@: %@", url.path, error.localizedDescription)
                }
            }
        }

        if model == nil {
            NSLog("[SkinSegmenter] Warning: SelfieSegmenter.mlmodelc not found in candidate paths")
        }
    }

    private func setupInputBuffer() {
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            256,
            256,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &inputPixelBuffer
        )
    }

    /// Process a camera frame and return a high-precision face-skin CIImage mask scaled to the target dimensions.
    public func processFrame(
        pixelBuffer: CVPixelBuffer,
        targetWidth: CGFloat,
        targetHeight: CGFloat
    ) -> CIImage? {
        guard let model = self.model, let inputBuf = self.inputPixelBuffer else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        let now = CACurrentMediaTime()
        // Rate-limit CoreML segmentation inference to ~15 FPS (every ~66ms).
        // Face skin boundaries (headphones, hair, clothes) change slowly;
        // reusing the cached mask on intermediate frames saves 50% CoreML & GPU overhead with zero quality loss.
        if let cached = cachedMask, now - lastProcessTime < 0.066,
           cached.extent.width == targetWidth, cached.extent.height == targetHeight {
            return cached
        }

        let srcWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let srcHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        guard srcWidth > 0, srcHeight > 0, targetWidth > 0, targetHeight > 0 else {
            return cachedMask
        }

        let inputCI = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = 256.0 / srcWidth
        let scaleY = 256.0 / srcHeight
        let scaledImage = inputCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Render hardware-accelerated 256x256 image for Neural Engine / GPU inference
        ciContext.render(
            scaledImage,
            to: inputBuf,
            bounds: CGRect(x: 0, y: 0, width: 256, height: 256),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        do {
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["image": inputBuf])
            let prediction = try model.prediction(from: inputProvider)

            var maskCI: CIImage?

            // 1. Direct Image Output (Grayscale 256x256 CVPixelBuffer)
            if let outputImageBuffer = prediction.featureValue(for: "face_skin_mask")?.imageBufferValue {
                maskCI = CIImage(cvPixelBuffer: outputImageBuffer)
            } else if let multiArray = prediction.featureValue(for: "face_skin_mask")?.multiArrayValue {
                // 2. MultiArray fallback: convert Float32 array [1, 1, 256, 256] to grayscale CIImage
                maskCI = createCIImageFromMultiArray(multiArray)
            }

            guard let rawMaskCI = maskCI else {
                return cachedMask
            }

            // Soft-edge feathering on native 256x256 mask BEFORE upscaling.
            // Blurring a 256x256 texture (65K pixels) takes <0.1ms vs ~15ms blurring at 1920x1080 (2M pixels)!
            let smoothed256: CIImage
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(rawMaskCI, forKey: kCIInputImageKey)
                blurFilter.setValue(2.0, forKey: kCIInputRadiusKey)
                smoothed256 = blurFilter.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256)) ?? rawMaskCI
            } else {
                smoothed256 = rawMaskCI
            }

            // Scale feathered mask to target canvas size with bilinear GPU filtering
            let upScaleX = targetWidth / 256.0
            let upScaleY = targetHeight / 256.0
            let fullSizeMask = smoothed256
                .transformed(by: CGAffineTransform(scaleX: upScaleX, y: upScaleY))
                .cropped(to: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

            cachedMask = fullSizeMask
            lastProcessTime = now
            return fullSizeMask
        } catch {
            NSLog("[SkinSegmenter] Inference failed: %@", error.localizedDescription)
            return cachedMask
        }
    }

    private func createCIImageFromMultiArray(_ multiArray: MLMultiArray) -> CIImage? {
        let count = multiArray.count
        guard count >= 256 * 256 else { return nil }

        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        var uint8Bytes = [UInt8](repeating: 0, count: 256 * 256)
        for i in 0..<(256 * 256) {
            let val = ptr[i]
            let clamped = max(0.0, min(1.0, val))
            uint8Bytes[i] = UInt8(clamped * 255.0)
        }

        let data = Data(uint8Bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: 256,
                height: 256,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: 256,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return CIImage(cgImage: cgImage)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        cachedMask = nil
    }
}
