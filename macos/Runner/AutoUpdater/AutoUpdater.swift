import Cocoa
import FlutterMacOS

class AutoUpdater {
    static let shared = AutoUpdater()
    private init() {}

    func getAppInfo() -> [String: Any] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let bundlePath = Bundle.main.bundlePath

        return [
            "version": version,
            "buildNumber": buildNumber,
            "bundlePath": bundlePath
        ]
    }

    func installUpdate(dmgPath: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dmgPath) else {
            completion(.failure(NSError(domain: "AutoUpdater", code: 404, userInfo: [NSLocalizedDescriptionKey: "DMG file not found at \(dmgPath)"])))
            return
        }

        let currentAppPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let mountId = UUID().uuidString.prefix(8)
        let mountPoint = "/tmp/beautycam_mount_\(mountId)"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Tạo thư mục mount point
                try? fileManager.removeItem(atPath: mountPoint)
                try fileManager.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

                // 1. Mount DMG ngầm
                NSLog("[AutoUpdater] Mounting DMG: %@ at %@", dmgPath, mountPoint)
                let attachTask = Process()
                attachTask.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                attachTask.arguments = ["attach", dmgPath, "-nobrowse", "-mountpoint", mountPoint, "-readonly"]
                try attachTask.run()
                attachTask.waitUntilExit()

                guard attachTask.terminationStatus == 0 else {
                    throw NSError(domain: "AutoUpdater", code: Int(attachTask.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG file (exit code \(attachTask.terminationStatus))"])
                }

                // 2. Tìm file .app trong DMG
                let contents = try fileManager.contentsOfDirectory(atPath: mountPoint)
                guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
                    // Unmount nếu không thấy app
                    let detachTask = Process()
                    detachTask.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detachTask.arguments = ["detach", mountPoint, "-force"]
                    try? detachTask.run()
                    throw NSError(domain: "AutoUpdater", code: 404, userInfo: [NSLocalizedDescriptionKey: "No .app bundle found inside DMG"])
                }

                let srcAppPath = (mountPoint as NSString).appendingPathComponent(appName)
                NSLog("[AutoUpdater] Found application bundle inside DMG: %@", srcAppPath)

                // 3. Tạo background updater script
                let scriptPath = "/tmp/beautycamera_updater_\(mountId).sh"
                let scriptContent = """
                #!/bin/bash
                APP_PID=\(pid)
                SRC_APP="\(srcAppPath)"
                TARGET_APP="\(currentAppPath)"
                MOUNT_DIR="\(mountPoint)"
                DMG_FILE="\(dmgPath)"

                # 1. Đợi ứng dụng hiện tại thoát hoàn toàn
                while kill -0 "$APP_PID" 2>/dev/null; do
                    sleep 0.2
                done

                sleep 0.5

                # 2. Xoá app cũ và thay thế bằng app mới
                if [ -w "$TARGET_APP" ] || [ -w "$(dirname "$TARGET_APP")" ]; then
                    rm -rf "$TARGET_APP"
                    ditto "$SRC_APP" "$TARGET_APP"
                else
                    osascript -e "do shell script \\"rm -rf '$TARGET_APP' && ditto '$SRC_APP' '$TARGET_APP'\\" with administrator privileges"
                fi

                # 3. Gỡ thuộc tính quarantine để macOS mở bình thường
                xattr -cr "$TARGET_APP" 2>/dev/null || true

                # 4. Unmount DMG và dọn file tạm
                hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
                rm -rf "$MOUNT_DIR" 2>/dev/null || true
                rm -f "$DMG_FILE" 2>/dev/null || true

                # 5. Khởi động lại ứng dụng mới
                open -n "$TARGET_APP"

                # 6. Tự dọn dẹp script
                rm -f "$0"
                """

                try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)

                // Cấp quyền thực thi cho script
                let chmodTask = Process()
                chmodTask.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodTask.arguments = ["+x", scriptPath]
                try chmodTask.run()
                chmodTask.waitUntilExit()

                // 4. Kích hoạt detached background process
                NSLog("[AutoUpdater] Launching detached updater script: %@", scriptPath)
                let runTask = Process()
                runTask.executableURL = URL(fileURLWithPath: "/bin/bash")
                runTask.arguments = ["-c", "nohup \"\(scriptPath)\" > /dev/null 2>&1 &"]
                try runTask.run()

                DispatchQueue.main.async {
                    completion(.success(true))

                    // Đợi 0.5s rồi tự thoát app để script bắt đầu ghi đè
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            } catch {
                NSLog("[AutoUpdater] Error during update: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
