import AppKit
import AVFoundation
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
    private var isSendingFrame = false
    private var activationRequest: OSSystemExtensionRequest?
    private var deactivationRequest: OSSystemExtensionRequest?
    private var isReinstalling = false
    private var connectionTimer: Timer?
    private var connectionAttempts = 0
    private var propertiesRequest: OSSystemExtensionRequest?
    private var diagnosingConnection = false
    private var discoverySession: AVCaptureDevice.DiscoverySession?
    // Accessed only on queue, alongside the sink objects.
    private var connectionFailure = "The camera device has not registered with macOS."

    private var bundledExtension: Bundle? {
        Bundle(url: Bundle.main.bundleURL.appendingPathComponent(
            "Contents/Library/SystemExtensions/\(extensionID).systemextension"))
    }

    public var isActive: Bool { queue.sync { state == "active" } }
    public var status: [String: Any] {
        queue.sync { ["active": state == "active", "state": state, "message": message] }
    }

    override private init() { super.init() }

    public func pokeDeviceDiscovery() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
            deviceTypes.append(.continuityCamera)
        } else {
            deviceTypes.append(.externalUnknown)
        }
        discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        _ = discoverySession?.devices
    }

    // Called on the main thread by Flutter; activation is asynchronous and may require user approval.
    public func start() -> [String: Any] {
        guard #available(macOS 12.3, *) else {
            setState("error", "Virtual Camera requires macOS 12.3 or later.")
            return status
        }
        guard activationRequest == nil, propertiesRequest == nil, connectionTimer == nil, !isActive else { return status }
        pokeDeviceDiscovery()

        // Installed builds must reconcile the bundled extension BEFORE the fast
        // path: connecting to the old device would otherwise skip every upgrade.
        if Bundle.main.bundleURL.path.hasPrefix("/Applications/"), bundledExtension != nil {
            inspectExtension(diagnosing: false)
        } else if queue.sync(execute: { self.connectSink() }) {
            // Development builds can use an already installed compatible sink.
            return status
        } else if !Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
            setState("error", "Move Beauty Camera to Applications and reopen it to install Virtual Camera.")
        } else {
            setState("error", "This build does not include Virtual Camera. Install a build with the camera extension.")
        }
        return status
    }

    private func inspectExtension(diagnosing: Bool) {
        diagnosingConnection = diagnosing
        setState("connecting", diagnosing ? "Checking the virtual camera connection…" : "Checking the installed camera extension…")
        let request = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        propertiesRequest = request
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        guard propertiesRequest === request else { return }
        propertiesRequest = nil
        let installed = properties.filter { $0.bundleIdentifier == extensionID }
        let version = bundledExtension?.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let snapshots = installed.map {
            VirtualCameraActivationPolicy.Installed(version: $0.bundleVersion, enabled: $0.isEnabled,
                awaitingApproval: $0.isAwaitingUserApproval, uninstalling: $0.isUninstalling)
        }
        switch VirtualCameraActivationPolicy.action(installed: snapshots, bundledVersion: version) {
        case .activate:
            if diagnosingConnection {
                setState("error", "The updated camera extension has not registered yet. Quit Beauty Camera, reopen it from Applications and try again.")
            } else {
                submitActivationRequest()
            }
        case .approval:
            // Keep discovering so enabling it in Settings completes this start
            // attempt without requiring the user to toggle Virtual Cam twice.
            beginConnecting(waitingForApproval: true)
        case .restart:
            setState("error", "macOS is finishing a camera extension replacement. Restart your Mac, then enable Virtual Cam again.")
        case .connect:
            if diagnosingConnection {
                let reason = queue.sync { connectionFailure }
                setState("error", "Beauty Camera is installed but unavailable in macOS. \(reason) Click 'Reinstall Extension' to reset the camera extension, or check System Settings.")
            } else {
                beginConnecting()
            }
        }
    }

    private func beginConnecting(waitingForApproval: Bool = false) {
        setState(waitingForApproval ? "approval" : "connecting", waitingForApproval
            ? "Enable Beauty Camera in System Settings → General → Login Items & Extensions → Camera Extensions."
            : "Waiting for macOS to register Beauty Camera…")
        connectionAttempts = 0
        pokeDeviceDiscovery()
        if queue.sync(execute: { self.connectSink() }) { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.connectionAttempts += 1
            if self.connectionAttempts % 4 == 0 { self.pokeDeviceDiscovery() }
            if self.queue.sync(execute: { self.connectSink() }) {
                timer.invalidate()
                self.connectionTimer = nil
            } else if self.connectionAttempts >= 120 {
                timer.invalidate()
                self.connectionTimer = nil
                self.inspectExtension(diagnosing: true)
            }
        }
        connectionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func submitActivationRequest() {
        setState("installing", "Setting up Beauty Camera for Google Meet…")
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        activationRequest = request
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    public func reinstall() -> [String: Any] {
        guard #available(macOS 12.3, *) else {
            setState("error", "Virtual Camera requires macOS 12.3 or later.")
            return status
        }
        guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
            setState("error", "Move Beauty Camera to Applications and reopen it to reinstall Virtual Camera.")
            return status
        }
        guard bundledExtension != nil else {
            setState("error", "This build does not include Virtual Camera. Install a build with the camera extension.")
            return status
        }

        stop()
        isReinstalling = true
        setState("installing", "Requesting macOS to uninstall old Camera Extension…")

        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        deactivationRequest = request
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        return status
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(fallback)
        }
    }

    public func stop() {
        connectionTimer?.invalidate()
        connectionTimer = nil
        activationRequest = nil
        propertiesRequest = nil
        deactivationRequest = nil
        isReinstalling = false
        discoverySession = nil
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
            isSendingFrame = false
            state = "off"
            message = ""
        }
    }

    private func setState(_ value: String, _ text: String) {
        queue.sync { state = value; message = text }
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        if deactivationRequest === request {
            setState("approval", "Allow uninstalling the old camera extension in System Settings or enter your admin password.")
            return
        }
        guard activationRequest === request else { return }
        setState("approval", "Allow Beauty Camera in macOS System Settings → General → Login Items & Extensions → Camera Extensions (or Privacy & Security).")
    }

    public func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties,
                        withExtension replacement: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        guard activationRequest === request,
              replacement.bundleVersion.compare(existing.bundleVersion, options: .numeric) != .orderedAscending else { return .cancel }
        return .replace
    }
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        if deactivationRequest === request {
            deactivationRequest = nil
            if isReinstalling {
                submitActivationRequest()
                return
            }
            setState("error", "Could not uninstall camera extension: \(error.localizedDescription)")
            return
        }
        if propertiesRequest === request {
            propertiesRequest = nil
            setState("error", "Could not check the installed camera extension: \(error.localizedDescription)")
            return
        }
        guard activationRequest === request else { return }
        activationRequest = nil
        isReinstalling = false
        setState("error", "Virtual Camera could not be installed: \(error.localizedDescription)")
    }

    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if deactivationRequest === request {
            deactivationRequest = nil
            if isReinstalling {
                submitActivationRequest()
                return
            }
            setState("off", "Camera extension uninstalled.")
            return
        }
        guard activationRequest === request else { return }
        activationRequest = nil
        isReinstalling = false
        guard result == .completed else {
            setState("error", "Restart your Mac to finish installing Beauty Camera, then enable Virtual Cam again.")
            return
        }
        beginConnecting()
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
        connectionFailure = "The camera device has not registered with macOS."
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
            guard let sink = streams.first else {
                connectionFailure = "The camera registered without a writable video stream."
                continue
            }
            var unmanagedQueue: Unmanaged<CMSimpleQueue>?
            // nil unregisters the queue callback; some CMIO versions then return
            // noErr with a nil queue. Register a callback even though our producer
            // polls capacity. It captures no manager, so teardown cannot retain it.
            let queueResult = CMIOStreamCopyBufferQueue(sink, { _, _, _ in }, nil, &unmanagedQueue)
            guard queueResult == noErr, let bufferQueue = unmanagedQueue?.takeRetainedValue() else {
                connectionFailure = queueResult == noErr
                    ? "macOS did not provide a video queue."
                    : "Opening the video queue failed (\(queueResult))."
                continue
            }
            let startResult = CMIODeviceStartStream(candidate, sink)
            guard startResult == noErr else {
                connectionFailure = "Starting the video stream failed (\(startResult))."
                continue
            }
            let attributes: [CFString: Any] = [kCVPixelBufferWidthKey: 1280, kCVPixelBufferHeightKey: 720,
                                               kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                                               kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true]
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess,
                  CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA,
                                                 width: 1280, height: 720, extensions: nil, formatDescriptionOut: &format) == noErr
            else {
                CMIODeviceStopStream(candidate, sink)
                connectionFailure = "The video buffer could not be allocated."
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
        let now = CMClockGetTime(CMClockGetHostTimeClock())

        // Non-blocking asynchronous dispatch so capture queue is never stalled by virtual camera encoding
        queue.async { [weak self] in
            guard let self = self else { return }
            guard now.seconds - self.lastFrameTime >= 1.0 / 30.0 else { return }
            guard self.state == "active", let buffers = self.buffers, let pool = self.pool, let format = self.format else { return }
            guard CMSimpleQueueGetCount(buffers) < CMSimpleQueueGetCapacity(buffers) else { return }
            guard !self.isSendingFrame else { return }
            self.isSendingFrame = true
            defer { self.isSendingFrame = false }

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
            self.context.render(fitted.composited(over: CIImage(color: .black).cropped(to: extent)),
                                to: target, bounds: extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                            presentationTimeStamp: now, decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            guard CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: target, dataReady: true,
                                                     makeDataReadyCallback: nil, refcon: nil, formatDescription: format, sampleTiming: &timing,
                                                     sampleBufferOut: &sample) == noErr, let sample = sample else { return }
            let retained = Unmanaged.passRetained(sample)
            if CMSimpleQueueEnqueue(buffers, element: retained.toOpaque()) != noErr { retained.release() }
            else { self.lastFrameTime = now.seconds }
        }
    }
}


/// Kept independent of OSSystemExtensionProperties so upgrade/approval behavior
/// can be tested without installing, disabling or replacing a user's extension.
enum VirtualCameraActivationPolicy {
    struct Installed {
        let version: String
        let enabled: Bool
        let awaitingApproval: Bool
        let uninstalling: Bool
    }
    enum Action { case activate, connect, approval, restart }

    static func action(installed: [Installed], bundledVersion: String) -> Action {
        let current = installed.filter { !$0.uninstalling }
        // During replacement macOS can report both retiring and active entries.
        // Prefer a usable same/newer version, and never downgrade an installed one.
        if current.contains(where: { $0.enabled && $0.version.compare(bundledVersion, options: .numeric) != .orderedAscending }) {
            return .connect
        }
        if current.contains(where: { $0.awaitingApproval }) { return .approval }
        if current.contains(where: { $0.version.compare(bundledVersion, options: .numeric) != .orderedAscending }) {
            return .approval
        }
        if current.isEmpty && !installed.isEmpty { return .restart }
        return .activate
    }
}
