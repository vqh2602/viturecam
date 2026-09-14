import CoreImage
import CoreMedia
import CoreMediaIO
import CoreVideo
import Foundation
import SystemExtensions

public final class VirtualCameraManager: NSObject, OSSystemExtensionRequestDelegate {
    public static let shared = VirtualCameraManager()
    public let virtualCameraName = "Beauty Camera"
    public static let deviceUID = "3F021C86-4FE3-4E30-A577-6A595B308DA5"
    private let extensionID = "com.beautycamera.vqhapp.CameraExtension"
    private let queue = DispatchQueue(label: "com.beautycamera.virtualcam", qos: .userInteractive)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var state = "off"
    private var message = ""
    private var device: CMIODeviceID = 0
    private var stream: CMIOStreamID = 0
    private var buffers: CMSimpleQueue?
    private var pool: CVPixelBufferPool?
    private var format: CMVideoFormatDescription?
    private var lastFrameTime: Double = 0
    private var activationRequest: OSSystemExtensionRequest?
    private var connectionTimer: Timer?
    private var connectionAttempts = 0

    public var isActive: Bool { queue.sync { state == "active" } }
    public var status: [String: Any] {
        queue.sync { ["active": state == "active", "state": state, "message": message] }
    }

    override private init() { super.init() }

    // Called on the main thread by Flutter; activation is asynchronous and may require user approval.
    public func start() -> [String: Any] {
        guard #available(macOS 12.3, *) else {
            setState("error", "Virtual Camera requires macOS 12.3 or later.")
            return status
        }
        guard activationRequest == nil, connectionTimer == nil, !isActive else { return status }
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            setState("error", "Move Beauty Camera to Applications and reopen it to install Virtual Camera.")
            return status
        }
        let bundle = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/SystemExtensions/\(extensionID).systemextension")
        guard FileManager.default.fileExists(atPath: bundle.path) else {
            setState("error", "This build does not include Virtual Camera. Install a build with the camera extension.")
            return status
        }
        setState("installing", "Setting up Beauty Camera for Google Meet…")
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        activationRequest = request
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        return status
    }

    public func stop() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        activationRequest = nil
        queue.sync {
            if device != 0 && stream != 0 { CMIODeviceStopStream(device, stream) }
            // After stopping, release samples that the sink did not consume.
            if let buffers = buffers {
                while let item = CMSimpleQueueDequeue(buffers) {
                    Unmanaged<CMSampleBuffer>.fromOpaque(item).release()
                }
            }
            buffers = nil
            pool = nil
            format = nil
            device = 0
            stream = 0
            lastFrameTime = 0
            state = "off"
            message = ""
        }
    }

    private func setState(_ value: String, _ text: String) {
        queue.sync { state = value; message = text }
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        guard activationRequest === request else { return }
        setState("approval", "Allow Beauty Camera in macOS System Settings → General → Login Items & Extensions → Camera Extensions (or Privacy & Security).")
    }

    public func request(_: OSSystemExtensionRequest, actionForReplacingExtension _: OSSystemExtensionProperties,
                        withExtension _: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction { .replace }
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        guard activationRequest === request else { return }
        activationRequest = nil
        setState("error", "Virtual Camera could not be installed: \(error.localizedDescription)")
    }

    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        guard activationRequest === request else { return }
        activationRequest = nil
        guard result == .completed else {
            setState("error", "Restart your Mac to finish installing Beauty Camera, then enable Virtual Cam again.")
            return
        }
        setState("connecting", "Waiting for macOS to register Beauty Camera…")
        connectionAttempts = 0
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.connectionAttempts += 1
            if self.queue.sync(execute: { self.connectSink() }) {
                timer.invalidate()
                self.connectionTimer = nil
            } else if self.connectionAttempts >= 40 {
                timer.invalidate()
                self.connectionTimer = nil
                self.setState("error", "Beauty Camera is installed but unavailable. Check Camera Extensions in System Settings and try again.")
            }
        }
    }

    private func objectIDs(_ object: CMIOObjectID, selector: CMIOObjectPropertySelector,
                           scope: CMIOObjectPropertyScope = CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal)) -> [CMIOObjectID]
    {
        var address = CMIOObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: 0)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        let result = ids.withUnsafeMutableBytes {
            CMIOObjectGetPropertyData(object, &address, 0, nil, size, &size, $0.baseAddress!)
        }
        return result == noErr ? ids : []
    }

    private func connectSink() -> Bool {
        // Opt in to software devices when enumerating the CoreMediaIO system object.
        var allowAddress = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
                                                     mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: 0)
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &allowAddress, 0, nil, 4, &allow)
        for candidate in objectIDs(CMIOObjectID(kCMIOObjectSystemObject), selector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices)) {
            var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
                                                    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: 0)
            var unmanagedUID: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard CMIOObjectGetPropertyData(candidate, &address, 0, nil, size, &size, &unmanagedUID) == noErr,
                  let uid = unmanagedUID?.takeRetainedValue() as String?,
                  uid == Self.deviceUID else { continue }
            let streams = objectIDs(candidate, selector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
                                    scope: CMIOObjectPropertyScope(kCMIODevicePropertyScopeOutput))
            guard let sink = streams.first else { continue }
            var unmanagedQueue: Unmanaged<CMSimpleQueue>?
            guard CMIOStreamCopyBufferQueue(sink, nil, nil, &unmanagedQueue) == noErr,
                  let bufferQueue = unmanagedQueue?.takeRetainedValue() else { continue }
            guard CMIODeviceStartStream(candidate, sink) == noErr else { continue }
            let attributes: [CFString: Any] = [kCVPixelBufferWidthKey: 1280, kCVPixelBufferHeightKey: 720,
                                               kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                                               kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true]
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess,
                  CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA,
                                                 width: 1280, height: 720, extensions: nil, formatDescriptionOut: &format) == noErr
            else {
                CMIODeviceStopStream(candidate, sink)
                continue
            }
            device = candidate
            stream = sink
            buffers = bufferQueue
            state = "active"
            message = "Select Beauty Camera in Google Meet → Settings → Video."
            return true
        }
        return false
    }

    public func sendFrame(pixelBuffer: CVPixelBuffer) {
        // Synchronous on the capture queue: no unbounded backlog of retained camera frames.
        queue.sync {
            guard state == "active", let buffers = buffers, let pool = pool, let format = format else { return }
            let now = CMClockGetTime(CMClockGetHostTimeClock())
            guard now.seconds - lastFrameTime >= 1.0 / 30.0,
                  CMSimpleQueueGetCount(buffers) < CMSimpleQueueGetCapacity(buffers) else { return }
            var target: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool,
                                                                      [kCVPixelBufferPoolAllocationThresholdKey: 6] as CFDictionary, &target) == kCVReturnSuccess,
                let target = target else { return }
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            let scale = min(1280 / image.extent.width, 720 / image.extent.height)
            let fitted = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: (1280 - image.extent.width * scale) / 2,
                                                   y: (720 - image.extent.height * scale) / 2))
            let extent = CGRect(x: 0, y: 0, width: 1280, height: 720)
            context.render(fitted.composited(over: CIImage(color: .black).cropped(to: extent)),
                           to: target, bounds: extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                            presentationTimeStamp: now, decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            guard CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: target, dataReady: true,
                                                     makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleTiming: &timing,
                                                     sampleBufferOut: &sample) == noErr, let sample = sample else { return }
            let retained = Unmanaged.passRetained(sample)
            if CMSimpleQueueEnqueue(buffers, element: retained.toOpaque()) != noErr { retained.release() }
            else { lastFrameTime = now.seconds }
        }
    }
}
