// swiftc macos/Runner/VirtualCamera/VirtualCameraManager.swift \
//   test/virtual_camera_regression.swift -o /tmp/virtual-camera-regression
// /tmp/virtual-camera-regression
// Optional local integration check (briefly opens ONLY the installed virtual sink):
// /tmp/virtual-camera-regression --connect-installed
import Foundation

@main
struct VirtualCameraRegression {
    static func main() {
        typealias Policy = VirtualCameraActivationPolicy
        func installed(_ version: String, enabled: Bool = true, approval: Bool = false,
                       uninstalling: Bool = false) -> Policy.Installed {
            Policy.Installed(version: version, enabled: enabled, awaitingApproval: approval, uninstalling: uninstalling)
        }
        precondition(Policy.action(installed: [], bundledVersion: "8") == .activate)
        precondition(Policy.action(installed: [installed("1")], bundledVersion: "8") == .activate,
                     "An enabled old extension must still be upgraded before connecting")
        precondition(Policy.action(installed: [installed("8")], bundledVersion: "8") == .connect)
        precondition(Policy.action(installed: [installed("10")], bundledVersion: "9") == .connect,
                     "Do not downgrade newer installations; compare build numbers numerically")
        precondition(Policy.action(installed: [installed("8", enabled: false, approval: true)], bundledVersion: "8") == .approval)
        precondition(Policy.action(installed: [installed("8", enabled: false)], bundledVersion: "8") == .approval)
        precondition(Policy.action(installed: [installed("1", uninstalling: true)], bundledVersion: "8") == .restart)
        precondition(Policy.action(installed: [installed("1", uninstalling: true), installed("8")], bundledVersion: "8") == .connect,
                     "Retiring copies must not hide an active replacement")
        print("PASS: initial install, upgrade, same version, no downgrade, actual approval state and replacement")

        if CommandLine.arguments.contains("--connect-installed") {
            let manager = VirtualCameraManager.shared
            for _ in 0..<2 {
                let status = manager.start()
                precondition(status["state"] as? String == "active", "Cannot connect to installed sink: \(status)")
                precondition(manager.isActive)
                manager.stop()
                precondition(manager.status["state"] as? String == "off")
            }
            print("PASS: installed virtual camera connects, stops and reconnects without activation or permission prompts")
        }
    }
}
