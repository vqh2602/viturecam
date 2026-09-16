import AVFoundation
import Foundation

public protocol CameraEngineDelegate: AnyObject {
    func cameraEngineDidDropFrame(_ engine: CameraEngine)
    func cameraEngine(_ engine: CameraEngine, didOutput sampleBuffer: CMSampleBuffer)
}

public final class CameraEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public weak var delegate: CameraEngineDelegate?

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.beautycamera.camera.session", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "com.beautycamera.camera.capture", qos: .userInteractive)

    private var activeDevice: AVCaptureDevice?
    private var activeInput: AVCaptureDeviceInput?
    private(set) var isRunning: Bool = false
    private(set) var currentWidth: Int = 1920
    private(set) var currentHeight: Int = 1080
    private(set) var currentFps: Int = 30

    public override init() {
        super.init()
    }

    public static func getAvailableCameras() -> [[String: Any]] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
            deviceTypes.append(.continuityCamera)
        } else {
            deviceTypes.append(.externalUnknown)
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )

        let defaultDevice = AVCaptureDevice.default(for: .video)
        return discoverySession.devices.filter { $0.uniqueID != VirtualCameraManager.deviceUID }.map { device in
            return [
                "id": device.uniqueID,
                "name": device.localizedName,
                "isDefault": device.uniqueID == defaultDevice?.uniqueID
            ]
        }
    }

    public static func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }

    public func start(deviceId: String? = nil, targetWidth: Int = 1920, targetHeight: Int = 1080, fps: Int = 30, completion: ((Bool, String?) -> Void)? = nil) {
        Self.requestCameraPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                completion?(false, "Camera permission denied. Please allow Camera access in macOS System Settings > Privacy & Security > Camera.")
                return
            }

            self.sessionQueue.async { [weak self] in
                guard let self = self else { return }

                if self.isRunning {
                    self.stopInternal()
                }

            self.currentWidth = targetWidth
            self.currentHeight = targetHeight
            self.currentFps = fps

            let device: AVCaptureDevice?
            if let deviceId = deviceId, !deviceId.isEmpty {
                device = AVCaptureDevice(uniqueID: deviceId)
            } else {
                device = AVCaptureDevice.default(for: .video)
            }

            guard let selectedDevice = device else {
                DispatchQueue.main.async {
                    completion?(false, "No camera device found")
                }
                return
            }

            self.activeDevice = selectedDevice

            self.captureSession.beginConfiguration()

            // Select resolution preset
            if targetWidth >= 1920 && selectedDevice.supportsSessionPreset(.hd1920x1080) {
                self.captureSession.sessionPreset = .hd1920x1080
            } else if selectedDevice.supportsSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            } else {
                self.captureSession.sessionPreset = .high
            }

            do {
                let input = try AVCaptureDeviceInput(device: selectedDevice)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.activeInput = input
                } else {
                    self.captureSession.commitConfiguration()
                    DispatchQueue.main.async {
                        completion?(false, "Cannot add camera input to capture session")
                    }
                    return
                }
            } catch {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    completion?(false, "Camera input error: \(error.localizedDescription)")
                }
                return
            }

            // Configure frame rate if supported
            do {
                try selectedDevice.lockForConfiguration()
                let targetDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                var formatSupported = false
                for range in selectedDevice.activeFormat.videoSupportedFrameRateRanges {
                    if Double(fps) >= range.minFrameRate && Double(fps) <= range.maxFrameRate {
                        selectedDevice.activeVideoMinFrameDuration = targetDuration
                        selectedDevice.activeVideoMaxFrameDuration = targetDuration
                        formatSupported = true
                        break
                    }
                }
                if !formatSupported {
                    // Fallback to closest default
                    if let range = selectedDevice.activeFormat.videoSupportedFrameRateRanges.first {
                        selectedDevice.activeVideoMinFrameDuration = range.minFrameDuration
                        selectedDevice.activeVideoMaxFrameDuration = range.maxFrameDuration
                    }
                }
                selectedDevice.unlockForConfiguration()
            } catch {
                print("[CameraEngine] Could not lock device for frame rate configuration: \(error)")
            }

            // Configure output
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.captureQueue)

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            self.isRunning = self.captureSession.isRunning

            DispatchQueue.main.async {
                completion?(self.isRunning, self.isRunning ? nil : "Failed to start capture session")
            }
        }
    }
}

    public func stop(completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            self?.stopInternal()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    private func stopInternal() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        if let input = activeInput {
            captureSession.removeInput(input)
            activeInput = nil
        }
        captureSession.removeOutput(videoOutput)
        isRunning = false
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraEngine(self, didOutput: sampleBuffer)
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.cameraEngineDidDropFrame(self)
    }
}
