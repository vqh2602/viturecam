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
    public var leftMidJaw: CGPoint = .zero
    public var rightMidJaw: CGPoint = .zero
    public var leftLowerJaw: CGPoint = .zero
    public var rightLowerJaw: CGPoint = .zero
    public var leftAlar: CGPoint = .zero
    public var rightAlar: CGPoint = .zero
    public var leftMouthCorner: CGPoint = .zero
    public var rightMouthCorner: CGPoint = .zero
    public var foreheadCenter: CGPoint = .zero
    public var leftTemple: CGPoint = .zero
    public var rightTemple: CGPoint = .zero
    public var leftEyeOuter: CGPoint = .zero
    public var rightEyeOuter: CGPoint = .zero
    public var leftCheekApple: CGPoint = .zero
    public var rightCheekApple: CGPoint = .zero

    // Contours for full-face skin mask & feature protection
    public var faceContour: [CGPoint] = []
    public var outerLipContour: [CGPoint] = []
    public var innerLipContour: [CGPoint] = []
    public var leftEyeContour: [CGPoint] = []
    public var rightEyeContour: [CGPoint] = []
    public var leftEyebrowContour: [CGPoint] = []
    public var rightEyebrowContour: [CGPoint] = []

    public init() {}
}

public struct CanonicalROI {
    public var centerPx: CGPoint    // Center in pixel coordinates (0..W, 0..H, origin top-left)
    public var sizePx: CGFloat      // Size in pixels of the square ROI
    public var rollAngle: CGFloat   // True physical roll angle in radians (screen space: clockwise is positive)

    public init(centerPx: CGPoint, sizePx: CGFloat, rollAngle: CGFloat) {
        self.centerPx = centerPx
        self.sizePx = sizePx
        self.rollAngle = rollAngle
    }
}

// MARK: - One Euro Filter for 468 3D Landmarks (Casiez CHI 2012)
// Adaptive smoothing trades stationary jitter against motion lag; benchmark with capture timestamps.
public final class OneEuroFilterBank468 {
    public var minCutoff: Float = 3.5
    public var beta: Float = 50.0
    public var dCutoff: Float = 1.0

    private var xPrev: [SIMD3<Float>] = []
    private var rawPrev: [SIMD3<Float>] = []
    private var dxPrev: [SIMD3<Float>] = []
    private var lastTimestamp: TimeInterval?

    public init() {
        xPrev.reserveCapacity(468)
        dxPrev.reserveCapacity(468)
    }

    public func reset() {
        xPrev.removeAll(keepingCapacity: true)
        rawPrev.removeAll(keepingCapacity: true)
        dxPrev.removeAll(keepingCapacity: true)
        lastTimestamp = nil
    }

    @inline(__always)
    private func alpha(rate: Float, cutoff: Float) -> Float {
        let tau = 1.0 / (2.0 * Float.pi * cutoff)
        let te = 1.0 / rate
        return 1.0 / (1.0 + tau / te)
    }

    public func filter(raw: [SIMD3<Float>], timestamp: TimeInterval) -> [SIMD3<Float>] {
        guard raw.count == 468, timestamp.isFinite,
              raw.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            reset()
            return []
        }
        if let previous = lastTimestamp, timestamp <= previous || timestamp - previous > 0.25 {
            reset()
        }

        guard let tPrev = lastTimestamp, xPrev.count == 468, dxPrev.count == 468 else {
            xPrev = raw
            rawPrev = raw
            dxPrev = Array(repeating: SIMD3<Float>(0, 0, 0), count: 468)
            lastTimestamp = timestamp
            return raw
        }

        let dt = Float(max(0.001, min(0.1, timestamp - tPrev)))
        let rate = 1.0 / dt
        let alphaD = alpha(rate: rate, cutoff: dCutoff)
        let oneMinusAlphaD = 1.0 - alphaD

        var result = [SIMD3<Float>]()
        result.reserveCapacity(468)

        for i in 0..<468 {
            let x = raw[i]
            let prev = xPrev[i]
            let prevDx = dxPrev[i]

            // Filtered derivative
            let dx = (x - rawPrev[i]) / dt
            rawPrev[i] = x
            let edx = alphaD * dx + oneMinusAlphaD * prevDx
            dxPrev[i] = edx

            // Speed-adaptive cutoff
            let speed = length(edx)
            let cutoff = minCutoff + beta * speed
            let a = alpha(rate: rate, cutoff: cutoff)

            // Filtered position
            let filtered = a * x + (1.0 - a) * prev
            xPrev[i] = filtered
            result.append(filtered)
        }

        lastTimestamp = timestamp
        return result
    }
}

public final class FaceMeshTracker {
    private let trackingQueue = DispatchQueue(label: "com.beautycamera.facemeshtracking", qos: .userInteractive)
    private var model: MLModel?
    private var ciContext: CIContext?
    private var cropBuffer: CVPixelBuffer?

    private var previousLandmarks = FaceMeshLandmarks()
    private var smoothedROI: CanonicalROI?
    private let filterBank = OneEuroFilterBank468()
    private var frameTimestamp: TimeInterval = 0
    private var imageSize: CGSize = .zero
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

    /// Called on the capture queue. Return landmarks for this exact buffer before rendering it.
    /// AVCapture drops late frames instead of allowing a queue of obsolete frames to build up.
    public func processFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> FaceMeshLandmarks {
        trackingQueue.sync {
            frameTimestamp = timestamp.isFinite ? timestamp : ProcessInfo.processInfo.systemUptime
            trackFrame(pixelBuffer: pixelBuffer)
            return currentLandmarks
        }
    }

    public func reset() {
        trackingQueue.sync { updateNoFace() }
    }

    private func trackFrame(pixelBuffer: CVPixelBuffer) {
        guard model != nil else { updateNoFace(); return }
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        guard width > 0 && height > 0 else { updateNoFace(); return }
        let size = CGSize(width: width, height: height)
        if imageSize != size { updateNoFace(); imageSize = size }

        // FAST-PATH: If face is already reliably tracked, compute canonical ROI in true pixel space (Google MediaPipe standard)
        let prevROI: CanonicalROI? = {
            self.lock.lock()
            defer { self.lock.unlock() }
            if self.previousLandmarks.hasFace && self.previousLandmarks.confidence > 5.0 {
                return self.computeCanonicalROIFromLandmarks(self.previousLandmarks.landmarks, imageWidth: width, imageHeight: height)
            }
            return nil
        }()

        if let rawROI = prevROI {
            let smoothROI = self.smoothROI(rawROI)
            if self.runFaceMeshInference(pixelBuffer: pixelBuffer, roi: smoothROI, imageWidth: width, imageHeight: height) {
                return
            }
        }

        // SLOW-PATH / FALLBACK: Re-acquire face via Apple Vision face detection in pixel space with roll angle
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] (req, err) in
            guard let self = self, err == nil else {
                self?.updateNoFace()
                return
            }
            guard let results = req.results as? [VNFaceObservation], let face = results.first else {
                self.updateNoFace()
                return
            }

            let b = face.boundingBox // Vision bottom-left normalized coordinates
            let roll = CGFloat(face.roll?.floatValue ?? 0.0) // True radians from Vision

            let boxX = b.origin.x * width
            let boxY = (1.0 - b.maxY) * height
            let boxW = b.width * width
            let boxH = b.height * height

            let cx_px = boxX + boxW * 0.5
            let cy_px = boxY + boxH * 0.5
            let size_px = max(48.0, max(boxW, boxH) * 1.75)

            let initialROI = CanonicalROI(
                centerPx: CGPoint(x: cx_px, y: cy_px),
                sizePx: size_px,
                rollAngle: -roll
            )

            self.smoothedROI = initialROI
            _ = self.runFaceMeshInference(pixelBuffer: pixelBuffer, roi: initialROI, imageWidth: width, imageHeight: height)
        }

        faceRequest.preferBackgroundProcessing = false
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do { try handler.perform([faceRequest]) }
        catch { updateNoFace() }
    }

    private func computeCanonicalROIFromLandmarks(
        _ landmarks: [SIMD3<Float>],
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CanonicalROI? {
        guard landmarks.count >= 468 else { return nil }

        let W = imageWidth
        let H = imageHeight

        // Compute tight bounding box from all 468 landmarks in TRUE PIXEL SPACE (Google MediaPipe standard)
        var minX_px = CGFloat(landmarks[0].x) * W
        var maxX_px = minX_px
        var minY_px = CGFloat(landmarks[0].y) * H
        var maxY_px = minY_px

        for i in 1..<468 {
            let px = CGFloat(landmarks[i].x) * W
            let py = CGFloat(landmarks[i].y) * H
            if px < minX_px { minX_px = px }
            if px > maxX_px { maxX_px = px }
            if py < minY_px { minY_px = py }
            if py > maxY_px { maxY_px = py }
        }

        let boxW = maxX_px - minX_px
        let boxH = maxY_px - minY_px
        let cx_px = minX_px + boxW * 0.5
        let cy_px = minY_px + boxH * 0.5

        // 1.75x expansion around full face (avoids cutting off cheeks with headphones)
        let size_px = max(48.0, max(boxW, boxH) * 1.75)

        // True physical roll angle between outer eye corners in pixel space (zero aspect-ratio distortion!)
        let p33 = landmarks[33]   // Camera-left outer eye corner
        let p263 = landmarks[263] // Camera-right outer eye corner
        let dx_px = CGFloat(p263.x - p33.x) * W
        let dy_px = CGFloat(p263.y - p33.y) * H
        let roll = atan2(dy_px, dx_px)

        return CanonicalROI(centerPx: CGPoint(x: cx_px, y: cy_px), sizePx: size_px, rollAngle: roll)
    }

    private func smoothROI(_ newROI: CanonicalROI) -> CanonicalROI {
        guard let prev = smoothedROI else {
            smoothedROI = newROI
            return newROI
        }

        let alpha: CGFloat = 0.85 // Responsive 1-2 frame tracking (eliminates 400ms lag)
        let center = CGPoint(
            x: prev.centerPx.x * (1.0 - alpha) + newROI.centerPx.x * alpha,
            y: prev.centerPx.y * (1.0 - alpha) + newROI.centerPx.y * alpha
        )
        let sizePx = prev.sizePx * (1.0 - alpha) + newROI.sizePx * alpha

        var diffAngle = newROI.rollAngle - prev.rollAngle
        while diffAngle > .pi { diffAngle -= 2.0 * .pi }
        while diffAngle < -.pi { diffAngle += 2.0 * .pi }
        let rollAngle = prev.rollAngle + diffAngle * alpha

        let res = CanonicalROI(centerPx: center, sizePx: sizePx, rollAngle: rollAngle)
        smoothedROI = res
        return res
    }

    private func updateNoFace() {
        lock.lock()
        defer { lock.unlock() }
        previousLandmarks = FaceMeshLandmarks()
        smoothedROI = nil
        filterBank.reset()
    }

    @discardableResult
    private func runFaceMeshInference(
        pixelBuffer: CVPixelBuffer,
        roi: CanonicalROI,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> Bool {
        guard let model = model, let cropBuffer = cropBuffer, let ciContext = ciContext else {
            updateNoFace()
            return false
        }

        let W = imageWidth
        let H = imageHeight
        let cx_ci = roi.centerPx.x
        let cy_ci = H - roi.centerPx.y
        let sizePx = max(48.0, roi.sizePx)

        // In CoreImage: origin is bottom-left.
        // Screen roll angle theta: clockwise is positive.
        // CoreImage roll angle: counter-clockwise is positive, so theta_ci = -theta.
        // To counter-rotate the face to make it upright: rotate by -theta_ci = +theta!
        let theta_ci = -roi.rollAngle

        let T_ci = CGAffineTransform(translationX: -cx_ci, y: -cy_ci)
            .concatenating(CGAffineTransform(rotationAngle: -theta_ci))
            .concatenating(CGAffineTransform(scaleX: 192.0 / sizePx, y: 192.0 / sizePx))
            .concatenating(CGAffineTransform(translationX: 96.0, y: 96.0))

        let sourceCI = CIImage(cvPixelBuffer: pixelBuffer)
        let transformedCI = sourceCI.transformed(by: T_ci)

        ciContext.render(transformedCI, to: cropBuffer, bounds: CGRect(x: 0, y: 0, width: 192, height: 192), colorSpace: nil)

        // Run CoreML Inference
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input_image": cropBuffer])
            let output = try model.prediction(from: input)

            guard let multiArray = output.featureValue(for: "points_confidence")?.multiArrayValue,
                  multiArray.count == 1405, multiArray.dataType == .float32 else {
                updateNoFace()
                return false
            }
            let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

            let confidence = ptr[1404]
            if !confidence.isFinite || confidence < 5.0 {
                updateNoFace()
                return false
            }

            let T_ci_inv = T_ci.inverted()
            var rawPoints: [SIMD3<Float>] = []
            rawPoints.reserveCapacity(468)

            for i in 0..<468 {
                let u_model = ptr[i * 3]
                let v_model = ptr[i * 3 + 1]
                let z_model = ptr[i * 3 + 2]

                // In cropBuffer: row 0 (top) is v_model = 0, which corresponds to y = 192 in CoreImage
                let u_ci = CGFloat(u_model)
                let v_ci = 192.0 - CGFloat(v_model)

                let pt_ci = CGPoint(x: u_ci, y: v_ci).applying(T_ci_inv)

                // Convert CoreImage coordinate back to normalized screen space (0..1, top-left origin)
                let imgX = Float(pt_ci.x / W)
                let imgY = Float((H - pt_ci.y) / H)
                let imgZ = Float(z_model / 192.0) * Float(sizePx / W)

                rawPoints.append(SIMD3<Float>(imgX, imgY, imgZ))
            }

            guard rawPoints.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
                updateNoFace()
                return false
            }
            updateSmoothedLandmarks(rawPoints: rawPoints, confidence: confidence, roi: roi)
            return true
        } catch {
            NSLog("[FaceMeshTracker] Prediction error: %@", error.localizedDescription)
            updateNoFace()
            return false
        }
    }

    private func updateSmoothedLandmarks(
        rawPoints: [SIMD3<Float>],
        confidence: Float,
        roi: CanonicalROI
    ) {
        lock.lock()
        defer { lock.unlock() }
        let smoothedPoints = filterBank.filter(raw: rawPoints, timestamp: frameTimestamp)

        var res = FaceMeshLandmarks()
        res.hasFace = true
        res.confidence = confidence
        res.landmarks = smoothedPoints

        // Compute tight face bounding box from 468 landmarks (top-left normalized)
        var minX: Float = 1.0, maxX: Float = 0.0
        var minY: Float = 1.0, maxY: Float = 0.0
        for p in smoothedPoints {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        res.boundingBox = CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
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

        // Anatomical Jaw & Alar Anchors
        res.leftMidJaw = pt(FaceMeshGeometry.leftMidJawIndex)
        res.rightMidJaw = pt(FaceMeshGeometry.rightMidJawIndex)
        res.leftLowerJaw = pt(FaceMeshGeometry.leftLowerJawIndex)
        res.rightLowerJaw = pt(FaceMeshGeometry.rightLowerJawIndex)
        res.leftAlar = pt(FaceMeshGeometry.leftAlarIndex)
        res.rightAlar = pt(FaceMeshGeometry.rightAlarIndex)
        res.leftMouthCorner = pt(FaceMeshGeometry.leftMouthCornerIndex)
        res.rightMouthCorner = pt(FaceMeshGeometry.rightMouthCornerIndex)
        res.foreheadCenter = pt(FaceMeshGeometry.foreheadCenterIndex)
        res.leftTemple = pt(127)
        res.rightTemple = pt(356)
        res.leftEyeOuter = pt(33)
        res.rightEyeOuter = pt(263)
        res.leftCheekApple = pt(280)
        res.rightCheekApple = pt(50)

        // Contours for full-face mask, feature protection & makeup
        res.faceContour = FaceMeshGeometry.silhouetteIndices.map { pt($0) }
        res.outerLipContour = FaceMeshGeometry.outerLipContour.map { pt($0) }
        res.innerLipContour = FaceMeshGeometry.innerLipContour.map { pt($0) }
        res.rightEyeContour = FaceMeshGeometry.rightEyeLoop.map { pt($0) }
        res.leftEyeContour = FaceMeshGeometry.leftEyeLoop.map { pt($0) }
        res.rightEyebrowContour = FaceMeshGeometry.rightEyebrowIndices.map { pt($0) }
        res.leftEyebrowContour = FaceMeshGeometry.leftEyebrowIndices.map { pt($0) }

        previousLandmarks = res
    }
}
