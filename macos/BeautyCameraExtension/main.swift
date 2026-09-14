import CoreMediaIO
import Foundation

let camera = CameraProvider()
CMIOExtensionProvider.startService(provider: camera.provider)
CFRunLoopRun()
