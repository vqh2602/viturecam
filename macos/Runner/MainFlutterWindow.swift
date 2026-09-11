import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    private var nativeChannel: FlutterMethodChannel?
    private var beautyEngine: BeautyEngine?

    override func awakeFromNib() {
        let controller = FlutterViewController()
        contentViewController = controller
        setContentSize(NSSize(width: 1280, height: 820))
        minSize = NSSize(width: 960, height: 640)
        center()
        title = "Beauty Camera"

        // Dark title bar style
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        styleMask.insert(.fullSizeContentView)

        RegisterGeneratedPlugins(registry: controller)

        let registrar = controller.registrar(forPlugin: "BeautyCamera")
        let engine = BeautyEngine(textureRegistry: registrar.textures)
        self.beautyEngine = engine

        nativeChannel = FlutterMethodChannel(name: "com.beautycamera/native", binaryMessenger: registrar.messenger)
        nativeChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self, let engine = self.beautyEngine else {
                result(FlutterError(code: "unavailable", message: "Beauty engine unavailable", details: nil))
                return
            }

            let args = call.arguments as? [String: Any] ?? [:]

            switch call.method {
            case "initialize":
                result(["success": true])

            case "requestCameraPermission":
                CameraEngine.requestCameraPermission { granted in
                    result(["granted": granted])
                }

            case "openCameraSettings":
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
                result(["success": true])

            case "getCameras":
                let cameras = CameraEngine.getAvailableCameras()
                result(cameras)

            case "startCamera":
                let deviceId = args["deviceId"] as? String
                let width = args["width"] as? Int ?? 1920
                let height = args["height"] as? Int ?? 1080
                let fps = args["fps"] as? Int ?? 30

                engine.startCamera(deviceId: deviceId, width: width, height: height, fps: fps) { success, error, textureId in
                    if success {
                        result(["success": true, "textureId": textureId])
                    } else {
                        result(FlutterError(code: "camera_error", message: error ?? "Failed to start camera", details: nil))
                    }
                }

            case "stopCamera":
                engine.stopCamera {
                    result(["success": true])
                }

            case "setBeautySettings":
                engine.beautySettings = BeautySettings(from: args)
                result(nil)

            case "setFaceSettings":
                engine.faceSettings = FaceSettings(from: args)
                result(nil)

            case "setMakeupSettings":
                engine.makeupSettings = MakeupSettings(from: args)
                result(nil)

            case "setFilter":
                engine.filterSettings = FilterSettings(from: args)
                result(nil)

            case "setColorSettings":
                engine.colorSettings = ColorSettings(from: args)
                result(nil)

            case "setBackgroundSettings":
                engine.backgroundSettings = BackgroundSettings(from: args)
                result(nil)

            case "enableBeauty":
                if let enabled = args["enabled"] as? Bool {
                    engine.beautyEnabled = enabled
                }
                result(nil)

            case "setCompareMode":
                if let mode = args["mode"] as? String {
                    engine.compareMode = mode
                }
                if let ratio = args["splitRatio"] as? Double {
                    engine.splitRatio = ratio
                }
                result(nil)

            case "startVirtualCamera":
                let success = engine.virtualCam.start()
                result(["success": success])

            case "stopVirtualCamera":
                engine.virtualCam.stop()
                result(["success": true])

            case "getPerformanceStats":
                result(engine.getPerformanceStats())

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        super.awakeFromNib()
    }
}
