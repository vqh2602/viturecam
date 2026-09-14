// Run from the project root:
// swiftc macos/Runner/FaceTracking/FaceMesh{Tracker,Geometry}.swift \
//   test/face_mesh_scale_regression.swift -o /tmp/face-mesh-scale-test
// /tmp/face-mesh-scale-test /path/to/face-image-or-gif
import CoreImage
import CoreVideo
import Foundation
import ImageIO

@main
struct FaceMeshScaleRegression {
    static func main() throws {
        guard CommandLine.arguments.count == 2,
              let source = CGImageSourceCreateWithURL(
                URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
              let frame = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Supply an image or GIF containing a clearly visible face")
        }
        let image = CIImage(cgImage: frame)
        let context = CIContext()
        let tracker = FaceMeshTracker()
        var storage: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frame.width, frame.height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &storage)
        precondition(status == kCVReturnSuccess)
        let buffer = storage!
        var timestamp = 1.0

        func track(_ input: CIImage) -> CGRect {
            context.render(input, to: buffer, bounds: image.extent, colorSpace: nil)
            timestamp += 1.0 / 30.0
            let result = tracker.processFrame(pixelBuffer: buffer, timestamp: timestamp)
            precondition(result.hasFace, "Lost face during scale regression")
            return result.boundingBox
        }

        // Repeating an identical frame must not cause growth/reacquisition cycles.
        let initial = track(image)
        var stable = initial
        for _ in 0..<90 {
            stable = track(image)
            precondition(abs(stable.width / initial.width - 1) < 0.15,
                         "Mesh width drifted on a stationary face")
            precondition(abs(stable.height / initial.height - 1) < 0.15,
                         "Mesh height drifted on a stationary face")
        }

        // Zoom out about an off-center pivot to check both scale and position.
        let pivot = CGPoint(x: image.extent.width * 0.65, y: image.extent.height * 0.4)
        var zoomed = stable
        for i in 1...90 {
            let scale = 1.0 - 0.35 * Double(min(i, 60)) / 60.0
            let transform = CGAffineTransform(translationX: -pivot.x, y: -pivot.y)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: pivot.x, y: pivot.y))
            let input = image.transformed(by: transform)
                .composited(over: CIImage(color: .black).cropped(to: image.extent))
            zoomed = track(input)
        }
        precondition(abs(zoomed.width / stable.width - 0.65) < 0.10,
                     "Mesh width did not follow zoom")
        precondition(abs(zoomed.height / stable.height - 0.65) < 0.10,
                     "Mesh height did not follow zoom")
        let expectedX = stable.midX * 0.65 + 0.65 * 0.35
        let expectedY = stable.midY * 0.65 + 0.60 * 0.35
        precondition(abs(zoomed.midX - expectedX) < 0.03 && abs(zoomed.midY - expectedY) < 0.03,
                     "Mesh center drifted during off-center zoom")
        print("PASS: stationary face stays stable and mesh follows off-center zoom out")
    }
}
