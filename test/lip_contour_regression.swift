// swiftc macos/Runner/FaceTracking/{FaceMeshGeometry,LipContourRefiner}.swift \
//   test/lip_contour_regression.swift -o /tmp/lip-contour-test && /tmp/lip-contour-test
import CoreVideo
import Foundation
import simd

@main
struct LipContourRegression {
    static func main() {
        let width = 256, height = 256
        var storage: CVPixelBuffer?
        precondition(CVPixelBufferCreate(kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, nil, &storage) == kCVReturnSuccess)
        let buffer = storage!
        func paint(_ color: (Int, Int) -> SIMD3<UInt8>) {
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<height {
                for x in 0..<width {
                    let c = color(x, y), offset = y * stride + x * 4
                    bytes[offset] = c.z; bytes[offset + 1] = c.y
                    bytes[offset + 2] = c.x; bytes[offset + 3] = 255
                }
            }
        }
        func mesh(gap: Float) -> [SIMD3<Float>] {
            var points = [SIMD3<Float>](repeating: SIMD3<Float>(0.5, 0.5, 0.01), count: 468)
            for (contour, rx, ry) in [(FaceMeshGeometry.outerLipContour, Float(50), Float(18)),
                                      (FaceMeshGeometry.innerLipContour, Float(44), gap / 2)] {
                for (i, index) in contour.enumerated() {
                    let angle = Float.pi - Float(i) * 2 * .pi / Float(contour.count)
                    points[index] = SIMD3<Float>((128 + rx * cos(angle)) / 256,
                                                 (128 - ry * sin(angle)) / 256, 0.01)
                }
            }
            return points
        }
        paint { _, _ in SIMD3<UInt8>(160, 130, 120) }
        let closed = mesh(gap: 1.8)
        precondition(LipContourRefiner.refine(closed, in: buffer) == closed,
                     "Flat image must preserve every mesh point")
        precondition(LipContourRefiner.refine([], in: buffer).isEmpty)
        var invalid = closed; invalid[13].x = .nan
        precondition(LipContourRefiner.refine(invalid, in: buffer)[13].x.isNaN)
        var clipped = closed; clipped[61].x = 0
        precondition(LipContourRefiner.refine(clipped, in: buffer) == clipped)

        paint { _, y in y == 129 ? SIMD3<UInt8>(40, 20, 20) : SIMD3<UInt8>(160, 70, 65) }
        let contact = LipContourRefiner.refine(closed, in: buffer)
        precondition(contact[13].y == contact[14].y, "Closed lips must share one detected seam")
        precondition(abs(contact[13].y * 256 - 129) < 0.5, "Seam must follow this frame's dark line")
        for i in 0..<468 where !FaceMeshGeometry.lipIndices.contains(i) {
            precondition(contact[i] == closed[i], "Non-lip landmarks must not move")
        }

        paint { _, y in abs(y - 128) < 6 ? SIMD3<UInt8>(25, 15, 15) : SIMD3<UInt8>(160, 70, 65) }
        let opened = LipContourRefiner.refine(mesh(gap: 12), in: buffer)
        precondition((opened[14].y - opened[13].y) * 256 > 8,
                     "Broad dark cavity must stay open")

        // Same seam after a 90-degree roll: fitting must follow the mouth axis,
        // rather than assuming that the lip contact line is horizontal.
        paint { x, _ in x == 129 ? SIMD3<UInt8>(40, 20, 20) : SIMD3<UInt8>(160, 70, 65) }
        let rolled = closed.map { SIMD3<Float>($0.y, $0.x, $0.z) }
        let rolledContact = LipContourRefiner.refine(rolled, in: buffer)
        precondition(rolledContact[13].x == rolledContact[14].x)
        precondition(abs(rolledContact[13].x * 256 - 129) < 0.5)

        // A known pigment boundary two pixels outside the mesh should pull the
        // outer points toward the image, without expanding beyond the search band.
        paint { x, y in
            let dx = Float(x - 128) / 52, dy = Float(y - 128) / 20
            return dx * dx + dy * dy <= 1 ? SIMD3<UInt8>(180, 55, 60) : SIMD3<UInt8>(180, 140, 125)
        }
        let original = mesh(gap: 12)
        let edge = LipContourRefiner.refine(original, in: buffer)
        precondition(edge[0].y < original[0].y, "Upper lip must move toward actual pigment boundary")
        precondition(edge[17].y > original[17].y, "Lower lip must move toward actual pigment boundary")
        for i in FaceMeshGeometry.lipIndices {
            precondition(simd_length(edge[i] - original[i]) * 256 <= 5.01)
            precondition(edge[i].z == original[i].z)
        }
        print("PASS: low contrast, invalid/off-frame input, closed seam, open cavity, local edges and unchanged non-lip points")
    }
}
