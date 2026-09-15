import CoreVideo
import Foundation
import simd

/// A bounded, image-guided refinement of the mesh's lip boundaries. The mesh
/// supplies anatomy; full-resolution pixels supply local boundary evidence.
/// Low contrast, unsupported buffers and out-of-frame contours keep the mesh.
enum LipContourRefiner {
    static func refine(_ mesh: [SIMD3<Float>], in buffer: CVPixelBuffer) -> [SIMD3<Float>] {
        guard mesh.count == 468,
              mesh.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return mesh }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return mesh }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        let scale = SIMD2<Float>(Float(width), Float(height))
        let points = mesh.map { SIMD2<Float>($0.x, $0.y) * scale }
        let lipWidth = simd_distance(points[61], points[291])
        guard lipWidth >= 24 else { return mesh }
        let radius = min(5, max(1, lipWidth * 0.025))
        let margin = radius + 4
        guard FaceMeshGeometry.lipIndices.allSatisfy({
            let p = points[$0]
            return p.x >= margin && p.y >= margin &&
                p.x < Float(width) - margin && p.y < Float(height) - margin
        }) else { return mesh }

        // Bilinear sampling avoids integer-pixel jumps when the face moves slowly.
        func rgb(_ p: SIMD2<Float>) -> SIMD3<Float> {
            let x = Int(p.x), y = Int(p.y)
            let fx = p.x - Float(x), fy = p.y - Float(y)
            func at(_ x: Int, _ y: Int) -> SIMD3<Float> {
                let offset = y * stride + x * 4
                return SIMD3<Float>(Float(bytes[offset + 2]), Float(bytes[offset + 1]), Float(bytes[offset])) / 255
            }
            return (at(x, y) * (1 - fx) + at(x + 1, y) * fx) * (1 - fy) +
                (at(x, y + 1) * (1 - fx) + at(x + 1, y + 1) * fx) * fy
        }
        func luma(_ p: SIMD2<Float>) -> Float {
            simd_dot(rgb(p), SIMD3<Float>(0.299, 0.587, 0.114))
        }
        func redness(_ c: SIMD3<Float>) -> Float {
            (c.x - c.y) / max(0.15, c.x + c.y)
        }
        var refined = points
        for (contour, isOuter) in [(FaceMeshGeometry.outerLipContour, true),
                                   (FaceMeshGeometry.innerLipContour, false)] {
            let center = contour.reduce(SIMD2<Float>.zero) { $0 + points[$1] } / Float(contour.count)
            var offsets = [Float](repeating: 0, count: contour.count)
            var normals = [SIMD2<Float>](repeating: .zero, count: contour.count)
            for i in contour.indices {
                let p = points[contour[i]]
                let tangent = points[contour[(i + 1) % contour.count]] -
                    points[contour[(i + contour.count - 1) % contour.count]]
                guard simd_length(tangent) > 0.5 else { continue }
                var normal = simd_normalize(SIMD2<Float>(-tangent.y, tangent.x))
                if simd_dot(normal, p - center) < 0 { normal = -normal }
                normals[i] = normal
                func evidence(_ displacement: Float) -> Float {
                    let candidate = p + normal * displacement
                    let inside = rgb(candidate - normal * 1.5)
                    let outside = rgb(candidate + normal * 1.5)
                    if isOuter {
                        // Lip pigment on the inside, skin on the outside. Do not
                        // chase arbitrary shadows or highlights on the skin.
                        return max(0, redness(inside) - redness(outside))
                    }
                    // For the inner ring, the outside is lip and the inside is
                    // oral cavity. Bright teeth remain protected by the mesh.
                    return max(0, simd_dot(outside - inside, SIMD3<Float>(0.299, 0.587, 0.114)))
                }
                let baseline = evidence(0)
                var bestScore = baseline, bestOffset: Float = 0
                for step in -10...10 {
                    let offset = Float(step) * radius / 10
                    let score = evidence(offset) - 0.025 * pow(offset / radius, 2)
                    if score > bestScore { bestScore = score; bestOffset = offset }
                }
                // A weak/ambiguous edge does not justify moving an anatomical point.
                if bestScore > max(0.045, baseline + 0.012) { offsets[i] = bestOffset }
            }
            for i in contour.indices where offsets[i] != 0 {
                // Regularize displacement, not landmark positions: preserve the
                // individual's Cupid's bow and asymmetric lip shape.
                let before = offsets[(i + contour.count - 1) % contour.count]
                let after = offsets[(i + 1) % contour.count]
                let offset = offsets[i] * 0.8 + (before + after) * 0.1
                refined[contour[i]] += normals[i] * offset
            }
        }

        // Near closure, fit BOTH boundaries to the same narrow dark contact
        // line. Never close an open cavity simply because its pixels are dark.
        let upper = [191, 80, 81, 82, 13, 312, 311, 310, 415]
        let lower = [95, 88, 178, 87, 14, 317, 402, 318, 324]
        let axis = simd_normalize(points[291] - points[61])
        var vertical = SIMD2<Float>(-axis.y, axis.x)
        if simd_dot(vertical, points[17] - points[0]) < 0 { vertical = -vertical }
        for (u, l) in zip(upper, lower) {
            guard simd_distance(points[u], points[l]) <= max(2, lipWidth * 0.025) else { continue }
            let center = (points[u] + points[l]) * 0.5
            var best = center, bestScore: Float = 0.04
            for step in -6...6 {
                let delta = Float(step) * min(radius, 2) / 6
                let p = center + vertical * delta
                let far = min(luma(p - vertical * 2.5), luma(p + vertical * 2.5))
                let near = min(luma(p - vertical), luma(p + vertical))
                let contrast = far - luma(p)
                // A broad dark opening fails this narrow-valley test.
                guard near - luma(p) > contrast * 0.55 else { continue }
                let score = contrast - abs(delta) * 0.01
                if score > bestScore { bestScore = score; best = p }
            }
            if bestScore > 0.04 { refined[u] = best; refined[l] = best }
        }
        // Reject local fits that invert the upper/lower boundary ordering.
        // A shared contact line has zero separation and remains valid.
        for (u, l) in zip(upper, lower) {
            if simd_dot(refined[l] - refined[u], vertical) < 0 {
                refined[u] = points[u]
                refined[l] = points[l]
            }
        }
        var result = mesh
        for index in FaceMeshGeometry.lipIndices {
            result[index].x = refined[index].x / scale.x
            result[index].y = refined[index].y / scale.y
        }
        return result
    }
}
