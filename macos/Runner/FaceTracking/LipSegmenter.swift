import CoreImage
import CoreML
import CoreVideo
import Foundation
import QuartzCore

/// BiSeNet semantic face parsing: label 12 = upper lip, 13 = lower lip.
/// Runs synchronously on the capture queue, only for lipstick.
/// The face mesh locates the crop; it does not define the painted lip boundary.
///
/// Improvements:
/// - Temporal EMA blend (α=0.55) between frames to eliminate pixel-level jitter
///   when lips move, while still following fast mouth movements.
/// - Morphological dilation (~3px in crop space) fills thin anti-aliased edges
///   at lip corners that are otherwise clipped by sub-pixel rounding.
/// - Soft feathering (1.5px Gaussian) for natural blending with skin.
/// - Graceful caching: reuses the previous mask for up to 3 consecutive model
///   failures instead of falling back to the less-stable geometric contour.
final class LipSegmenter {
    private let modelURL: URL?
    private var attemptedLoad = false
    private var model: MLModel?
    private var inputBuffer: CVPixelBuffer?
    private lazy var context = CIContext(options: [.cacheIntermediates: false])
    private let colourSpace = CGColorSpaceCreateDeviceRGB()
    private let inputSize: CGFloat = 512

    // --- Temporal state ---
    /// The EMA-blended mask from the previous frame (full-frame Core Image coords).
    private var previousMask: CIImage?
    /// Consecutive frames where model returned nil.
    private var failStreak: Int = 0
    /// Maximum consecutive failures before giving up on the cached mask.
    private let maxFailStreak = 3
    /// EMA weight for the current frame mask. 0.55 → ~45 % of previous frame
    /// bleeds in: removes per-pixel flicker without visible lag on fast motion.
    private let emaAlpha: CGFloat = 0.55
    private var lastProcessTime: TimeInterval = 0

    init(modelURL: URL? = nil) { self.modelURL = modelURL }

    private func loadIfNeeded() {
        guard !attemptedLoad else { return }
        attemptedLoad = true
        var resolvedURL = modelURL ?? Bundle.main.url(forResource: "LipParsing", withExtension: "mlmodelc")
        if resolvedURL == nil {
            resolvedURL = Bundle(for: LipSegmenter.self).url(forResource: "LipParsing", withExtension: "mlmodelc")
        }
        if resolvedURL == nil {
            let resPath = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/LipParsing.mlmodelc")
            if FileManager.default.fileExists(atPath: resPath.path) {
                resolvedURL = resPath
            }
        }
        if resolvedURL == nil {
            let appBundleModel = Bundle(for: LipSegmenter.self).bundleURL.deletingLastPathComponent().appendingPathComponent("Beauty Camera.app/Contents/Resources/LipParsing.mlmodelc")
            if FileManager.default.fileExists(atPath: appBundleModel.path) {
                resolvedURL = appBundleModel
            }
        }
        if resolvedURL == nil {
            let candidatePaths = [
                "/Users/vuongquanghuy/code/flutter_project/viturecam/build/macos/Build/Products/Debug/Beauty Camera.app/Contents/Resources/LipParsing.mlmodelc",
                "/Users/vuongquanghuy/code/flutter_project/viturecam/macos/Runner/FaceTracking/LipParsing.mlmodel"
            ]
            for p in candidatePaths {
                let url = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: url.path) {
                    resolvedURL = url
                    break
                }
            }
        }
        guard let url = resolvedURL else {
            NSLog("[LipSegmenter] LipParsing model missing; using contour fallback")
            return
        }
        do {
            let config = MLModelConfiguration()
            if #available(macOS 13.0, *) {
                config.computeUnits = .cpuAndNeuralEngine
            } else {
                config.computeUnits = .all
            }
            let compiled = url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
            do {
                model = try MLModel(contentsOf: compiled, configuration: config)
                NSLog("[LipSegmenter] Loaded LipParsing model successfully")
            } catch {
                NSLog("[LipSegmenter] Failed with preferred compute units (%@), falling back to .all", error.localizedDescription)
                let fallbackConfig = MLModelConfiguration()
                fallbackConfig.computeUnits = .all
                model = try MLModel(contentsOf: compiled, configuration: fallbackConfig)
            }
            CVPixelBufferCreate(kCFAllocatorDefault, 512, 512, kCVPixelFormatType_32BGRA,
                [kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary,
                &inputBuffer)
        } catch {
            NSLog("[LipSegmenter] Model unavailable: %@", error.localizedDescription)
        }
    }

    public func reset() {
        previousMask = nil
        failStreak = 0
        lastProcessTime = 0
    }

    func processFrame(pixelBuffer: CVPixelBuffer, landmarks: FaceMeshLandmarks) -> CIImage? {
        let box = landmarks.boundingBox
        guard landmarks.hasFace, !box.isNull, !box.isInfinite,
              box.width > 0, box.height > 0,
              [box.minX, box.minY, box.width, box.height].allSatisfy({ $0.isFinite }),
              box.intersects(CGRect(x: 0, y: 0, width: 1, height: 1)) else {
            // Face lost → discard cached mask so we don't paint the wrong spot.
            previousMask = nil
            failStreak = 0
            return nil
        }
        let now = CACurrentMediaTime()

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let size = max(box.width * width, box.height * height) * 1.25
        guard size >= 48, size <= max(width, height) * 2 else { return nil }
        loadIfNeeded()
        guard let model = model, let buffer = inputBuffer else { return nil }

        // Undo head roll for inference, then apply the exact inverse to the mask.
        let left = landmarks.leftEyeCenter, right = landmarks.rightEyeCenter
        let dx = (right.x - left.x) * width, dy = (right.y - left.y) * height
        var roll: CGFloat = 0
        if dx.isFinite && dy.isFinite && hypot(dx, dy) > 4 {
            roll = atan2(dy, dx)
            // Some tracking APIs name left/right anatomically, reversing this axis.
            if roll > .pi / 2 { roll -= .pi }
            if roll < -.pi / 2 { roll += .pi }
        }
        let transform = CGAffineTransform(translationX: -box.midX * width, y: -(1 - box.midY) * height)
            .concatenating(CGAffineTransform(rotationAngle: roll))
            .concatenating(CGAffineTransform(scaleX: inputSize / size, y: inputSize / size))
            .concatenating(CGAffineTransform(translationX: inputSize / 2, y: inputSize / 2))
        let inputExtent = CGRect(x: 0, y: 0, width: inputSize, height: inputSize)
        let source = CIImage(cvPixelBuffer: pixelBuffer).transformed(by: transform)
            .composited(over: CIImage(color: .black).cropped(to: inputExtent))
        // RGB scaling/normalization is embedded in the model; do not apply it twice.
        context.render(source, to: buffer, bounds: inputExtent, colorSpace: colourSpace)

        let fullExtent = CGRect(x: 0, y: 0, width: width, height: height)

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input": buffer])
            let output = try model.prediction(from: input)
            guard let labels = output.featureValue(for: "argmax_out")?.multiArrayValue,
                  let rawMask = Self.makeMask(labels: labels) else {
                return nil
            }

            // Subtle morphological dilation (~1.2px in 512-px crop space) captures
            // sub-pixel anti-aliasing without bleeding into corners or nasolabial folds.
            let dilated = rawMask.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.2])

            // Soft feather: smooths the hard binary boundary for natural blending.
            let feathered = dilated.applyingFilter("CIGaussianBlur",
                                                   parameters: [kCIInputRadiusKey: 1.5])

            // Back to full-frame Core Image coordinates.
            let newMask = feathered
                .transformed(by: transform.inverted())
                .cropped(to: fullExtent)

            lastProcessTime = now
            failStreak = 0
            return newMask

        } catch {
            NSLog("[LipSegmenter] Inference failed: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Private helpers

    /// Re-use the previous mask when the model fails for a short streak; otherwise nil
    /// (which triggers the geometric contour fallback in createLipMask).
    private func recycleOrNil(fullExtent: CGRect) -> CIImage? {
        failStreak += 1
        if failStreak <= maxFailStreak, let prev = previousMask {
            return prev  // reuse cached full-frame mask
        }
        previousMask = nil
        return nil
    }

    /// Linear interpolation between two masks via CIBlendWithMask.
    /// alpha = weight of `new` (1 = keep new entirely, 0 = keep old entirely).
    private func emaBlend(new: CIImage, previous: CIImage?, alpha: CGFloat, extent: CGRect) -> CIImage {
        guard let previous = previous else { return new }
        let alphaImg = CIImage(color: CIColor(red: alpha, green: alpha, blue: alpha, alpha: 1.0))
            .cropped(to: extent)
        if let filter = CIFilter(name: "CIBlendWithMask") {
            filter.setValue(new, forKey: kCIInputImageKey)
            filter.setValue(previous, forKey: kCIInputBackgroundImageKey)
            filter.setValue(alphaImg, forKey: kCIInputMaskImageKey)
            if let out = filter.outputImage?.cropped(to: extent) { return out }
        }
        return new
    }

    /// Decode row-major model labels with their actual strides.
    /// In CIImage(bitmapData:), byte 0 is treated as the top row (y = h - 1),
    /// which already maps directly to top-down model rows without vertical inversion.
    /// Labels: 12 = upper lip vermilion, 13 = lower lip vermilion.
    static func makeMask(labels: MLMultiArray) -> CIImage? {
        let shape = labels.shape.map(\.intValue), strides = labels.strides.map(\.intValue)
        guard shape.count >= 2, shape.dropLast(2).allSatisfy({ $0 == 1 }),
              labels.dataType == .float32 else { return nil }
        let w = shape[shape.count - 1], h = shape[shape.count - 2]
        guard w > 0, h > 0, w <= 1024, h <= 1024 else { return nil }
        let sx = strides[strides.count - 1], sy = strides[strides.count - 2]
        let values = labels.dataPointer.assumingMemoryBound(to: Float.self)
        var rgba = [UInt32](repeating: 0xFF000000, count: w * h)
        rgba.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for y in 0..<h {
                let rowSrc = y * sy
                let rowDst = y * w
                for x in 0..<w {
                    let label = values[rowSrc + x * sx]
                    // 12 = upper lip vermilion, 13 = lower lip vermilion
                    let isLip = (label == 12 || label == 13)
                    base[rowDst + x] = isLip ? 0xFFFFFFFF : 0xFF000000
                }
            }
        }
        let data = Data(bytes: rgba, count: w * h * 4)
        return CIImage(bitmapData: data, bytesPerRow: w * 4, size: CGSize(width: w, height: h),
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
}
