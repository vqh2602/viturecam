# Virtual camera connection and updates

## Reproduced on 2026-09-17

The installed extension was `activated enabled`, and both AVCapture and CoreMediaIO listed Beauty Camera. Its writable output stream could start successfully. However, `CMIOStreamCopyBufferQueue` with a nil callback returned `noErr` and a nil queue. The manager rejected that result on every retry, then incorrectly suggested checking Camera Extensions permissions.

Registering a non-capturing queue callback returned a usable queue (capacity 10 on this machine). The corrected manager connected, stopped and reconnected to the installed extension without an activation request or permission prompt. No physical-camera frames were captured for this test.

The app was also on build 7 while its extension was fixed at `1.0/1`. The extension now inherits `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER` in Debug, Profile and Release. CI verifies the embedded extension's version matches the app before packaging.

## Startup behavior

Installed builds first query `OSSystemExtensionProperties`. Missing/older extensions are activated or replaced before connecting; an enabled same/newer extension connects directly. Numeric build comparison prevents downgrading a newer extension. Retiring entries do not hide an active replacement.

Device registration is retried for up to 60 seconds on the main run loop, including while menus are tracking. A timeout checks actual extension state: disabled/pending approval is distinguished from an enabled extension with a failed video connection. Enabling a disabled extension in Settings continues the pending connection. Stopped requests cannot later restart the camera through stale delegate callbacks.

The connection diagnostics distinguish a missing device, missing writable stream, queue failure, stream-start failure and allocation failure. No uninstall or permission reset is performed.

## Verification

```sh
swiftc macos/Runner/VirtualCamera/VirtualCameraManager.swift \
  test/virtual_camera_regression.swift -o /tmp/virtual-camera-regression
/tmp/virtual-camera-regression
```

An optional `--connect-installed` argument briefly opens only the installed virtual sink and checks start/stop/reconnect. Use it when the camera is not in use by another producer.

The extension Release target built successfully with test overrides `FLUTTER_BUILD_NAME=1.0.8` and `FLUTTER_BUILD_NUMBER=8`; its produced Info.plist contained `1.0.8/8`. This validates packaging inputs, not a signed app-upgrade installation. A full signed upgrade still needs acceptance testing when the next app build is installed.

Apple's [System Extensions request API](https://developer.apple.com/documentation/systemextensions/ossystemextensionrequest) provides the property/activation requests. The local SDK's `CMIOHardwareStream.h` documents that passing a NULL callback to `CMIOStreamCopyBufferQueue` unregisters the callback.
