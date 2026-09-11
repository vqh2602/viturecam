import CoreImage
import CoreML
import CoreVideo
import Foundation
import Vision

public struct FaceMeshLandmarks {
    public var hasFace: Bool = false
    public var boundingBox: CGRect = .zero // In normalized image coordinates (0,0 top-left)
    public var landmarks: [SIMD3<Float>] = [] // 468 points, x in 0..1, y in 0..1, z depth
    public var confidence: Float = 0.0

    // Convenience Feature Anchors (normalized 0..1)
    public var leftEyeCenter: CGPoint = .zero
    public var rightEyeCenter: CGPoint = .zero
    public var mouthCenter: CGPoint = .zero
    public var chinTip: CGPoint = .zero
    public var noseTip: CGPoint = .zero
    public var noseBridge: CGPoint = .zero
    public var leftCheekCenter: CGPoint = .zero
    public var rightCheekCenter: CGPoint = .zero

    public init() {}
}

public final class FaceMeshTracker {
    public var damping: Float = 0.65 // 0.0 = raw, 1.0 = heavy smooth

    private let trackingQueue = DispatchQueue(label: "com.beautycamera.facemeshtracking", qos: .userInteractive)
    private var isProcessing: Bool = false
    private var model: MLModel?
    private var ciContext: CIContext?
    private var cropBuffer: CVPixelBuffer?

    private var previousLandmarks = FaceMeshLandmarks()
    private var missedFrames: Int = 0
    private let lock = NSLock()

    public init() {
        setupModel()
        setupCropBuffer()
    }

    private func setupModel() {
        let fileManager = FileManager.default

        // Candidate paths for FaceMesh.mlmodelc
        var candidateURLs: [URL] = []

        if let bundleURL = Bundle.main.url(forResource: "FaceMesh", withExtension: "mlmodelc") {
            candidateURLs.append(bundleURL)
        }
        let appResources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/FaceMesh.mlmodelc")
        candidateURLs.append(appResources)

        // Project directory fallback
        let projectPath = "/Users/vuongquanghuy/code/flutter_project/viturecam/macos/Runner/FaceTracking/FaceMesh.mlmodelc"
        candidateURLs.append(URL(fileURLWithPath: projectPath))

        for url in candidateURLs {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all // Apple Neural Engine + Metal GPU
                    self.model = try MLModel(contentsOf: url, configuration: config)
                    NSLog("[FaceMeshTracker] Successfully loaded FaceMesh model from: %@", url.path)
                    break
                } catch {
                    NSLog("[FaceMeshTracker] Failed to load model at %@: %@", url.path, error.localizedDescription)
                }
            }
        }

        if model == nil {
            NSLog("[FaceMeshTracker] Warning: FaceMesh.mlmodelc not found in candidate paths")
        }

        if let mtlDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: mtlDevice, options: [.priorityRequestLow: false])
        } else {
            self.ciContext = CIContext(options: nil)
        }
    }

    private func setupCropBuffer() {
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            192,
            192,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &cropBuffer
        )
    }

    public var currentLandmarks: FaceMeshLandmarks {
        lock.lock()
        defer { lock.unlock() }
        return previousLandmarks
    }

    public func processFrameAsync(pixelBuffer: CVPixelBuffer) {
        guard model != nil else { return }

        if isProcessing {
            // Drop tracking frame to maintain 60 FPS video throughput
            return
        }

        isProcessing = true
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

            let faceRequest = VNDetectFaceRectanglesRequest { [weak self] (req, err) in
                guard let self = self, err == nil else {
                    self?.updateNoFace()
                    return
                }
                guard let results = req.results as? [VNFaceObservation], let face = results.first else {
                    self.updateNoFace()
                    return
                }

                self.runFaceMeshInference(pixelBuffer: pixelBuffer, faceBox: face.boundingBox, imageWidth: width, imageHeight: height)
            }

            faceRequest.preferBackgroundProcessing = false
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([faceRequest])
        }
    }

    private func updateNoFace() {
        lock.lock()
        defer { lock.unlock() }
        missedFrames += 1
        if missedFrames > 8 {
            previousLandmarks.hasFace = false
        }
    }

    private func runFaceMeshInference(pixelBuffer: CVPixelBuffer, faceBox: CGRect, imageWidth: CGFloat, imageHeight: CGFloat) {
        guard let model = model, let cropBuffer = cropBuffer, let ciContext = ciContext else { return }

        // Convert Vision bounding box (normalized, bottom-left origin) to pixel rect
        // Add 25% padding around face to ensure complete chin, forehead, and cheeks are captured
        let padX = faceBox.width * 0.25
        let padY = faceBox.height * 0.25

        let expandedBox = CGRect(
            x: max(0.0, faceBox.origin.x - padX),
            y: max(0.0, faceBox.origin.y - padY * 0.6), // Less bottom padding, more top padding for forehead
            width: min(1.0, faceBox.width + padX * 2.0),
            height: min(1.0, faceBox.height + padY * 2.4)
        )

        // Make it a square crop in pixel space for 192x192 model input
        let pxBox = CGRect(
            x: expandedBox.origin.x * imageWidth,
            y: expandedBox.origin.y * imageHeight,
            width: expandedBox.width * imageWidth,
            height: expandedBox.height * imageHeight
        )

        let side = max(pxBox.width, pxBox.height)
        let cx = pxBox.midX
        let cy = pxBox.midY

        let squareCropPx = CGRect(
            x: max(0, min(imageWidth - side, cx - side * 0.5)),
            y: max(0, min(imageHeight - side, cy - side * 0.5)),
            width: min(side, imageWidth),
            height: min(side, imageHeight)
        )

        // Render 192x192 crop into cropBuffer via GPU
        let sourceCI = CIImage(cvPixelBuffer: pixelBuffer)
        let croppedCI = sourceCI.cropped(to: squareCropPx)

        // Transform to 192x192 target
        let scaleX = 192.0 / squareCropPx.width
        let scaleY = 192.0 / squareCropPx.height
        let scaledCI = croppedCI.transformed(by: CGAffineTransform(translationX: -squareCropPx.origin.x, y: -squareCropPx.origin.y))
                                 .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        ciContext.render(scaledCI, to: cropBuffer, bounds: CGRect(x: 0, y: 0, width: 192, height: 192), colorSpace: nil)

        // Run CoreML Inference
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input_image": cropBuffer])
            let output = try model.prediction(from: input)

            guard let multiArray = output.featureValue(for: "points_confidence")?.multiArrayValue else { return }
            let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

            let confidence = ptr[1404]
            if confidence < -35.0 {
                updateNoFace()
                return
            }

            // Extract 468 3D landmarks
            // Local crop space: (x_local in 0..192, y_local in 0..192)
            // Note: In CoreImage/Vision coordinates, Y=0 is at bottom; convert to standard top-left normalized
            var rawPoints: [SIMD3<Float>] = []
            rawPoints.reserveCapacity(468)

            let cropOriginX = Float(squareCropPx.origin.x / imageWidth)
            let cropOriginY = Float((imageHeight - squareCropPx.maxY) / imageHeight) // Top-left origin
            let cropW = Float(squareCropPx.width / imageWidth)
            let cropH = Float(squareCropPx.height / imageHeight)

            for i in 0..<468 {
                let localX = ptr[i * 3]
                let localY = ptr[i * 3 + 1]
                let localZ = ptr[i * 3 + 2]

                // MediaPipe local coordinates: 0..192, where y=0 is top, y=192 is bottom
                let normU = localX / 192.0
                let normV = localY / 192.0

                let imgX = cropOriginX + normU * cropW
                let imgY = cropOriginY + normV * cropH
                let imgZ = localZ / 192.0

                rawPoints.append(SIMD3<Float>(imgX, imgY, imgZ))
            }

            updateSmoothedLandmarks(rawPoints: rawPoints, confidence: confidence, squareCropPx: squareCropPx, imageWidth: imageWidth, imageHeight: imageHeight)
        } catch {
            NSLog("[FaceMeshTracker] Prediction error: %@", error.localizedDescription)
            updateNoFace()
        }
    }

    private func updateSmoothedLandmarks(
        rawPoints: [SIMD3<Float>],
        confidence: Float,
        squareCropPx: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        lock.lock()
        defer { lock.unlock() }
        missedFrames = 0

        var smoothedPoints: [SIMD3<Float>] = []
        smoothedPoints.reserveCapacity(468)

        let d = damping
        let oneMinusD = 1.0 - d

        if previousLandmarks.hasFace && previousLandmarks.landmarks.count == 468 {
            for i in 0..<468 {
                let prev = previousLandmarks.landmarks[i]
                let raw = rawPoints[i]
                smoothedPoints.append(SIMD3<Float>(
                    prev.x * d + raw.x * oneMinusD,
                    prev.y * d + raw.y * oneMinusD,
                    prev.z * d + raw.z * oneMinusD
                ))
            }
        } else {
            smoothedPoints = rawPoints
        }

        var res = FaceMeshLandmarks()
        res.hasFace = true
        res.confidence = confidence
        res.landmarks = smoothedPoints
        res.boundingBox = CGRect(
            x: squareCropPx.origin.x / imageWidth,
            y: (imageHeight - squareCropPx.maxY) / imageHeight,
            width: squareCropPx.width / imageWidth,
            height: squareCropPx.height / imageHeight
        )

        // Compute Anchors from 3D Mesh
        func pt(_ idx: Int) -> CGPoint {
            guard idx < smoothedPoints.count else { return .zero }
            return CGPoint(x: CGFloat(smoothedPoints[idx].x), y: CGFloat(smoothedPoints[idx].y))
        }

        // Eyes: Average contour landmarks for left and right eye centers
        let leftEyeIndices = [33, 133, 159, 145]
        let rightEyeIndices = [263, 362, 386, 374]

        var lx: CGFloat = 0, ly: CGFloat = 0
        for idx in leftEyeIndices { lx += CGFloat(smoothedPoints[idx].x); ly += CGFloat(smoothedPoints[idx].y) }
        res.leftEyeCenter = CGPoint(x: lx / CGFloat(leftEyeIndices.count), y: ly / CGFloat(leftEyeIndices.count))

        var rx: CGFloat = 0, ry: CGFloat = 0
        for idx in rightEyeIndices { rx += CGFloat(smoothedPoints[idx].x); ry += CGFloat(smoothedPoints[idx].y) }
        res.rightEyeCenter = CGPoint(x: rx / CGFloat(rightEyeIndices.count), y: ry / CGFloat(rightEyeIndices.count))

        // Mouth Center
        let upperMouth = pt(FaceMeshGeometry.mouthUpperCenterIndex)
        let lowerMouth = pt(FaceMeshGeometry.mouthLowerCenterIndex)
        res.mouthCenter = CGPoint(x: (upperMouth.x + lowerMouth.x) * 0.5, y: (upperMouth.y + lowerMouth.y) * 0.5)

        res.chinTip = pt(FaceMeshGeometry.chinTipIndex)
        res.noseTip = pt(FaceMeshGeometry.noseTipIndex)
        res.noseBridge = pt(FaceMeshGeometry.noseBridgeIndex)
        res.leftCheekCenter = pt(FaceMeshGeometry.leftCheekApexIndex)
        res.rightCheekCenter = pt(FaceMeshGeometry.rightCheekApexIndex)

        previousLandmarks = res
    }
}
