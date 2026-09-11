import CoreMedia
import CoreVideo
import FlutterMacOS
import Foundation

public final class BeautyEngine: NSObject, CameraEngineDelegate {
    public let cameraEngine = CameraEngine()
    public let faceMeshTracker = FaceMeshTracker()
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

    // Performance tracking
    private var frameCount: Int = 0
    private var lastFpsUpdateTime: TimeInterval = CACurrentMediaTime()
    private(set) var currentFps: Double = 0.0
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
        cameraEngine.start(deviceId: deviceId, targetWidth: width, targetHeight: height, fps: fps) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.bufferPool.prepare(width: self.cameraEngine.currentWidth, height: self.cameraEngine.currentHeight)
            }
            let validId = self.textureId > 0 ? self.textureId : registeredId
            completion(success, error, validId)
        }
    }

    public func stopCamera(completion: (() -> Void)? = nil) {
        cameraEngine.stop { [weak self] in
            self?.flutterTexture.clear()
            completion?()
        }
    }

    public func getPerformanceStats() -> [String: Any] {
        return [
            "fps": currentFps,
            "renderTimeMs": lastRenderTimeMs,
            "droppedFrames": droppedFrames,
            "width": cameraEngine.currentWidth,
            "height": cameraEngine.currentHeight
        ]
    }

    // MARK: - CameraEngineDelegate
    public func cameraEngine(_ engine: CameraEngine, didOutput sampleBuffer: CMSampleBuffer) {
        guard let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            droppedFrames += 1
            return
        }

        let width = CVPixelBufferGetWidth(sourcePixelBuffer)
        let height = CVPixelBufferGetHeight(sourcePixelBuffer)

        // Ensure buffer pool matches current frame dimensions
        bufferPool.prepare(width: width, height: height)

        let targetPixelBuffer = bufferPool.getPixelBuffer() ?? sourcePixelBuffer

        // Asynchronously track 468 3D face mesh landmarks (runs on background queue via CoreML on ANE)
        faceMeshTracker.processFrameAsync(pixelBuffer: sourcePixelBuffer)

        let startTime = CACurrentMediaTime()

        // Real-time GPU Beauty, 3D Reshape & Color rendering
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
            landmarks: faceMeshTracker.currentLandmarks
        )

        let elapsedMs = (CACurrentMediaTime() - startTime) * 1000.0
        self.lastRenderTimeMs = elapsedMs

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
}
