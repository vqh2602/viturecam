import CoreImage
import CoreML
import CoreVideo
import Foundation

/// BiSeNet semantic face parsing: label 12 = upper lip, 13 = lower lip,
/// 11 = inner mouth. Runs synchronously on the capture queue, only for lipstick.
/// The face mesh locates the crop; it does not define the painted lip boundary.
final class LipSegmenter {
    private let modelURL: URL?
    private var attemptedLoad = false
    private var model: MLModel?
    private var inputBuffer: CVPixelBuffer?
    private lazy var context = CIContext(options: [.cacheIntermediates: false])
    private let colourSpace = CGColorSpaceCreateDeviceRGB()
    private let inputSize: CGFloat = 512

    init(modelURL: URL? = nil) { self.modelURL = modelURL }

    private func loadIfNeeded() {
        guard !attemptedLoad else { return }
        attemptedLoad = true
        guard let url = modelURL ?? Bundle.main.url(forResource: "LipParsing", withExtension: "mlmodelc") else {
            NSLog("[LipSegmenter] LipParsing model missing; using contour fallback")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let compiled = url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
            model = try MLModel(contentsOf: compiled, configuration: config)
            CVPixelBufferCreate(kCFAllocatorDefault, 512, 512, kCVPixelFormatType_32BGRA,
                [kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary,
                &inputBuffer)
        } catch {
            NSLog("[LipSegmenter] Model unavailable: %@", error.localizedDescription)
        }
    }

    func processFrame(pixelBuffer: CVPixelBuffer, landmarks: FaceMeshLandmarks) -> CIImage? {
        let box = landmarks.boundingBox
        guard landmarks.hasFace, !box.isNull, !box.isInfinite,
              box.width > 0, box.height > 0,
              [box.minX, box.minY, box.width, box.height].allSatisfy({ $0.isFinite }),
              box.intersects(CGRect(x: 0, y: 0, width: 1, height: 1)) else { return nil }
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
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input": buffer])
            let output = try model.prediction(from: input)
            guard let labels = output.featureValue(for: "argmax_out")?.multiArrayValue,
                  let mask = Self.makeMask(labels: labels) else { return nil }
            return mask.transformed(by: transform.inverted())
                .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        } catch {
            NSLog("[LipSegmenter] Inference failed: %@", error.localizedDescription)
            return nil
        }
    }

    /// Decode row-major model labels with their actual strides. Flip top-left
    /// model rows into Core Image's bottom-left coordinates exactly once.
    static func makeMask(labels: MLMultiArray) -> CIImage? {
        let shape = labels.shape.map(\.intValue), strides = labels.strides.map(\.intValue)
        guard shape.count >= 2, shape.dropLast(2).allSatisfy({ $0 == 1 }),
              labels.dataType == .float32 else { return nil }
        let w = shape[shape.count - 1], h = shape[shape.count - 2]
        guard w > 0, h > 0, w <= 1024, h <= 1024 else { return nil }
        let sx = strides[strides.count - 1], sy = strides[strides.count - 2]
        let values = labels.dataPointer.assumingMemoryBound(to: Float.self)
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let label = values[y * sy + x * sx]
                let value: UInt8 = label == 12 || label == 13 ? 255 : 0
                let offset = ((h - 1 - y) * w + x) * 4
                rgba[offset] = value; rgba[offset + 1] = value; rgba[offset + 2] = value
            }
        }
        return CIImage(bitmapData: Data(rgba), bytesPerRow: w * 4, size: CGSize(width: w, height: h),
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
}
