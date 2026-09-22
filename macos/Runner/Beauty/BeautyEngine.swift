import CoreMedia
import CoreVideo
import FlutterMacOS
import Foundation

public final class BeautyEngine: NSObject, CameraEngineDelegate {
    public let cameraEngine = CameraEngine()
    public let faceMeshTracker = FaceMeshTracker()
    public let faceTracker = FaceTracker()
    private let lipSegmenter = LipSegmenter()
    public let skinSegmenter = SkinSegmenter() // Core 2: MediaPipe Selfie Multiclass Segmentation (Class 3: Face-Skin)
    public var trackingEngine: String = "facemesh" // "facemesh" (MediaPipe CoreML Core 1) or "vision" (Apple Native Vision)
    public let beautyRenderer = BeautyRenderer()
    public let bufferPool = PixelBufferPool()
    public let flutterTexture = BeautyFlutterTexture()
    public let virtualCam = VirtualCameraManager.shared

    private let textureRegistry: FlutterTextureRegistry
    private(set) var textureId: Int64 = -1

    public var beautyEnabled: Bool = true
    public var compareMode: String = "none" // "none", "split", "raw"
    public var splitRatio: Double = 0.5

    public var beautySettings = BeautySettings()
    public var faceSettings = FaceSettings()
    public var makeupSettings = MakeupSettings()
    public var filterSettings = FilterSettings()
    public var colorSettings = ColorSettings()
    public var backgroundSettings = BackgroundSettings()

    // Processing Worker & latest frame store (decoupled from AVCapture callback)
    private struct CapturedFrame {
        let pixelBuffer: CVPixelBuffer
        let timestamp: Double
    }
    private let processingQueue = DispatchQueue(label: "com.beautycamera.processing.worker", qos: .userInteractive)
    private let frameLock = NSLock()
    private var latestFrame: CapturedFrame?
    private var isWorkerRunning: Bool = false

    // Lip Inference package: stores the segmentation mask along with face anchor geometry at inference time
    private struct LipInferenceResult {
        let mask: CIImage
        let sourceLandmarks: FaceMeshLandmarks
        let timestamp: CFTimeInterval
    }

    // Lip Segmentation background async worker (15-20 FPS, decoupled from camera render loop)
    private let lipQueue = DispatchQueue(label: "viturecam.lip.inference", qos: .userInitiated)
    private let lipLock = NSLock()
    private var lipInferenceRunning: Bool = false
    private var latestLipResult: LipInferenceResult?

    // Performance tracking
    private var frameCount: Int = 0
    private var lastFpsUpdateTime: TimeInterval = CACurrentMediaTime()
    private(set) var currentFps: Double = 0.0
    private(set) var lastTrackingTimeMs: Double = 0.0
    private(set) var lastProcessingTimeMs: Double = 0.0
    private(set) var lastRenderTimeMs: Double = 0.0
    private(set) var droppedFrames: Int = 0

    public init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
        self.cameraEngine.delegate = self
    }

    deinit {
        if textureId > 0 {
            textureRegistry.unregisterTexture(textureId)
        }
    }

    @discardableResult
    public func ensureTextureRegistered() -> Int64 {
        if textureId > 0 {
            return textureId
        }
        let id = textureRegistry.register(self.flutterTexture)
        NSLog("[BeautyEngine] Registered Flutter texture with id: %lld", id)
        self.textureId = id
        return id
    }

    public func startCamera(deviceId: String?, width: Int = 1920, height: Int = 1080, fps: Int = 30, completion: @escaping (Bool, String?, Int64) -> Void) {
        let registeredId = ensureTextureRegistered()
        frameLock.lock()
        latestFrame = nil
        isWorkerRunning = false
        frameLock.unlock()

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.faceMeshTracker.reset()
            self.faceTracker.reset()
            self.skinSegmenter.reset()
        }

        cameraEngine.start(deviceId: deviceId, targetWidth: width, targetHeight: height, fps: fps) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.processingQueue.async {
                    self.bufferPool.prepare(width: self.cameraEngine.currentWidth, height: self.cameraEngine.currentHeight)
                }
            }
            let validId = self.textureId > 0 ? self.textureId : registeredId
            completion(success, error, validId)
        }
    }

    public func stopCamera(completion: (() -> Void)? = nil) {
        virtualCam.stop()
        cameraEngine.stop { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            self.frameLock.lock()
            self.latestFrame = nil
            self.frameLock.unlock()

            self.processingQueue.async {
                self.flutterTexture.clear()
                self.faceMeshTracker.reset()
                self.faceTracker.reset()
                self.skinSegmenter.reset()
                self.lipLock.lock()
                self.latestLipResult = nil
                self.lipInferenceRunning = false
                self.lipSegmenter.reset()
                self.lipLock.unlock()
                completion?()
            }
        }
    }

    public func getPerformanceStats() -> [String: Any] {
        frameLock.lock()
        let dropped = droppedFrames
        frameLock.unlock()

        return [
            "fps": currentFps,
            "renderTimeMs": lastRenderTimeMs,
            "trackingTimeMs": lastTrackingTimeMs,
            "processingTimeMs": lastProcessingTimeMs,
            "droppedFrames": dropped,
            "width": cameraEngine.currentWidth,
            "height": cameraEngine.currentHeight
        ]
    }

    public func cameraEngineDidDropFrame(_ engine: CameraEngine) {
        frameLock.lock()
        droppedFrames += 1
        frameLock.unlock()
    }

    // MARK: - CameraEngineDelegate (AVCapture callback - Non-blocking)
    public func cameraEngine(_ engine: CameraEngine, didOutput sampleBuffer: CMSampleBuffer) {
        guard let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            frameLock.lock()
            droppedFrames += 1
            frameLock.unlock()
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let validTimestamp = timestamp.isFinite ? timestamp : CACurrentMediaTime()
        let frame = CapturedFrame(pixelBuffer: sourcePixelBuffer, timestamp: validTimestamp)

        var shouldStartWorker = false
        frameLock.lock()
        if latestFrame != nil {
            // Drop unconsumed older frame when newer frame arrives
            droppedFrames += 1
        }
        latestFrame = frame

        if !isWorkerRunning {
            isWorkerRunning = true
            shouldStartWorker = true
        }
        frameLock.unlock()

        // Return immediately to AVCapture!
        if shouldStartWorker {
            processingQueue.async { [weak self] in
                self?.runProcessingWorker()
            }
        }
    }

    // MARK: - Processing Worker Loop
    private func runProcessingWorker() {
        while true {
            let frame: CapturedFrame
            frameLock.lock()
            if let nextFrame = latestFrame {
                frame = nextFrame
                latestFrame = nil
            } else {
                isWorkerRunning = false
                frameLock.unlock()
                break
            }
            frameLock.unlock()

            processPipeline(frame: frame)
        }
    }

    private func processPipeline(frame: CapturedFrame) {
        let sourcePixelBuffer = frame.pixelBuffer
        let width = CVPixelBufferGetWidth(sourcePixelBuffer)
        let height = CVPixelBufferGetHeight(sourcePixelBuffer)

        // Ensure buffer pool matches current frame dimensions
        bufferPool.prepare(width: width, height: height)

        guard let targetPixelBuffer = bufferPool.getPixelBuffer() else {
            frameLock.lock()
            droppedFrames += 1
            frameLock.unlock()
            return
        }

        let processingStart = CACurrentMediaTime()
        let validTimestamp = frame.timestamp

        // Core 1: MediaPipe Face Landmarker / Apple Vision Tracker
        // -> eyes / nose / lips / jaw / chin
        // -> used for 3D Reshape, Makeup, Teeth, Eye Bag
        let hasLipMakeup = beautyEnabled && (makeupSettings.lipPreset != "none" && makeupSettings.lipOpacity > 0.01)
        faceMeshTracker.needsLipRefinement = hasLipMakeup

        var landmarks: FaceMeshLandmarks
        if trackingEngine == "facemesh" {
            landmarks = faceMeshTracker.processFrame(pixelBuffer: sourcePixelBuffer, timestamp: validTimestamp)
        } else {
            landmarks = faceTracker.processFrame(pixelBuffer: sourcePixelBuffer, timestamp: validTimestamp)
        }
        // Semantic lip segmentation (decoupled async background inference + 24 FPS FaceMesh warp):
        // Camera and rendering run at full 24 FPS without blocking.
        // LipSegmenter runs on dedicated background queue (viturecam.lip.inference) at 15–20 FPS.
        // On intermediate frames, the latest AI mask is warped according to current 24 FPS FaceMesh landmarks.
        if hasLipMakeup && landmarks.hasFace {
            lipLock.lock()
            let cachedResult = latestLipResult
            lipLock.unlock()

            if let cached = cachedResult {
                landmarks.lipPixelMask = warpLipMask(
                    result: cached,
                    current: landmarks,
                    frameWidth: CGFloat(width),
                    frameHeight: CGFloat(height)
                )
            } else {
                landmarks.lipPixelMask = nil
            }

            submitLipInferenceIfNeeded(pixelBuffer: sourcePixelBuffer, landmarks: landmarks)
        } else {
            lipLock.lock()
            latestLipResult = nil
            lipLock.unlock()
        }
        lastTrackingTimeMs = (CACurrentMediaTime() - processingStart) * 1000

        // Core 2: Face / Skin Segmentation (MediaPipe Selfie Multiclass Class 3: Face-Skin)
        // -> extracts genuine face skin mask, cleanly excluding headphones (AirPods Max), hair, clothes, and background
        // -> used for skin smoothing, pore texture, whitening, and skin tone
        let skinMask: CIImage?
        let hasSkinBeauty = beautySettings.smooth > 0.01 || beautySettings.skinTone > 0.01 ||
                            beautySettings.skinToneType != "natural" || beautySettings.whitening > 0.01 ||
                            beautySettings.skinBrightness > 0.01 || beautySettings.redness > 0.01
        if beautyEnabled && hasSkinBeauty {
            skinMask = skinSegmenter.processFrame(pixelBuffer: sourcePixelBuffer, targetWidth: CGFloat(width), targetHeight: CGFloat(height))
        } else {
            skinMask = nil
        }

        let startTime = CACurrentMediaTime()

        // Real-time GPU Beauty Engine combining Core 1 + Core 2
        beautyRenderer.processFrame(
            sourceBuffer: sourcePixelBuffer,
            targetBuffer: targetPixelBuffer,
            beautyEnabled: beautyEnabled,
            compareMode: compareMode,
            splitRatio: splitRatio,
            beauty: beautySettings,
            face: faceSettings,
            makeup: makeupSettings,
            filter: filterSettings,
            color: colorSettings,
            background: backgroundSettings,
            landmarks: landmarks,
            skinMask: skinMask
        )

        let elapsedMs = (CACurrentMediaTime() - startTime) * 1000.0
        self.lastRenderTimeMs = elapsedMs
        self.lastProcessingTimeMs = (CACurrentMediaTime() - processingStart) * 1000

        // Push to zero-copy Flutter Texture
        flutterTexture.updatePixelBuffer(targetPixelBuffer)
        if textureId > 0 {
            self.textureRegistry.textureFrameAvailable(self.textureId)
        }

        // Push to Virtual Camera if enabled
        if virtualCam.isActive {
            virtualCam.sendFrame(pixelBuffer: targetPixelBuffer)
        }

        // Calculate actual FPS
        frameCount += 1
        let now = CACurrentMediaTime()
        if now - lastFpsUpdateTime >= 1.0 {
            currentFps = Double(frameCount) / (now - lastFpsUpdateTime)
            frameCount = 0
            lastFpsUpdateTime = now
        }
    }

    // MARK: - Lip Inference & 24 FPS FaceMesh Warp Engine

    private func submitLipInferenceIfNeeded(
        pixelBuffer: CVPixelBuffer,
        landmarks: FaceMeshLandmarks
    ) {
        lipLock.lock()
        guard !lipInferenceRunning else {
            lipLock.unlock()
            return
        }
        lipInferenceRunning = true
        lipLock.unlock()

        let capturedLandmarks = landmarks
        let buffer = pixelBuffer

        lipQueue.async { [weak self] in
            guard let self = self else { return }

            autoreleasepool {
                let mask = self.lipSegmenter.processFrame(
                    pixelBuffer: buffer,
                    landmarks: capturedLandmarks
                )

                let now = CACurrentMediaTime()
                self.lipLock.lock()
                let stillEnabled = self.beautyEnabled &&
                    (self.makeupSettings.lipPreset != "none" && self.makeupSettings.lipOpacity > 0.01)

                if stillEnabled, let mask = mask {
                    self.latestLipResult = LipInferenceResult(
                        mask: mask,
                        sourceLandmarks: capturedLandmarks,
                        timestamp: now
                    )
                } else if !stillEnabled {
                    self.latestLipResult = nil
                }
                self.lipInferenceRunning = false
                self.lipLock.unlock()
            }
        }
    }

    private func warpLipMask(
        result: LipInferenceResult,
        current: FaceMeshLandmarks,
        frameWidth: CGFloat,
        frameHeight: CGFloat
    ) -> CIImage? {
        guard current.hasFace, result.sourceLandmarks.hasFace else {
            return nil
        }

        // Mask expires after 0.8s to avoid ghosting if face is occluded or lost
        if CACurrentMediaTime() - result.timestamp > 0.8 {
            return nil
        }

        func ciPoint(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * frameWidth, y: (1.0 - p.y) * frameHeight)
        }

        let srcCenter = ciPoint(result.sourceLandmarks.mouthCenter)
        let dstCenter = ciPoint(current.mouthCenter)

        let srcLeft = ciPoint(result.sourceLandmarks.leftMouthCorner)
        let srcRight = ciPoint(result.sourceLandmarks.rightMouthCorner)
        let srcVec = CGPoint(x: srcRight.x - srcLeft.x, y: srcRight.y - srcLeft.y)
        let srcDist = hypot(srcVec.x, srcVec.y)
        let srcAngle = atan2(srcVec.y, srcVec.x)

        let dstLeft = ciPoint(current.leftMouthCorner)
        let dstRight = ciPoint(current.rightMouthCorner)
        let dstVec = CGPoint(x: dstRight.x - dstLeft.x, y: dstRight.y - dstLeft.y)
        let dstDist = hypot(dstVec.x, dstVec.y)
        let dstAngle = atan2(dstVec.y, dstVec.x)

        guard srcDist > 10, dstDist > 10 else {
            return result.mask
        }

        // Horizontal scale follows mouth width
        let rawScaleX = dstDist / srcDist
        let scaleX = max(0.7, min(1.4, rawScaleX))

        // Vertical scale follows face height (nose bridge to chin tip) to keep lips natural when talking
        let srcFaceH = hypot(
            ciPoint(result.sourceLandmarks.chinTip).x - ciPoint(result.sourceLandmarks.noseBridge).x,
            ciPoint(result.sourceLandmarks.chinTip).y - ciPoint(result.sourceLandmarks.noseBridge).y
        )
        let dstFaceH = hypot(
            ciPoint(current.chinTip).x - ciPoint(current.noseBridge).x,
            ciPoint(current.chinTip).y - ciPoint(current.noseBridge).y
        )
        let scaleY: CGFloat
        if srcFaceH > 10 && dstFaceH > 10 {
            let rawScaleY = dstFaceH / srcFaceH
            scaleY = max(0.7, min(1.4, rawScaleY))
        } else {
            scaleY = scaleX
        }

        // Relative roll angle with wrap-around protection [-pi, pi]
        var deltaAngle = dstAngle - srcAngle
        while deltaAngle > .pi { deltaAngle -= 2 * .pi }
        while deltaAngle < -.pi { deltaAngle += 2 * .pi }

        let deltaDist = hypot(dstCenter.x - srcCenter.x, dstCenter.y - srcCenter.y)
        if deltaDist < 0.5 && abs(deltaAngle) < 0.005 && abs(scaleX - 1.0) < 0.01 && abs(scaleY - 1.0) < 0.01 {
            return result.mask
        }

        var transform = CGAffineTransform(translationX: -srcCenter.x, y: -srcCenter.y)
        transform = transform.concatenating(CGAffineTransform(rotationAngle: deltaAngle))
        transform = transform.concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
        transform = transform.concatenating(CGAffineTransform(translationX: dstCenter.x, y: dstCenter.y))

        let extent = CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight)
        return result.mask.transformed(by: transform).cropped(to: extent)
    }
}
