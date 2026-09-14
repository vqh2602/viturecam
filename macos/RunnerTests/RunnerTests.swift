import Cocoa
import CoreImage
import CoreVideo
import XCTest
@testable import Beauty_Camera

final class RunnerTests: XCTestCase {
    private let extent = CGRect(x: 0, y: 0, width: 256, height: 256)
    private let context = CIContext()

    private func mesh() -> FaceMeshLandmarks {
        var result = FaceMeshLandmarks()
        result.hasFace = true
        result.landmarks = FaceMeshGeometry.canonicalUVs.map { SIMD3<Float>($0.x * 0.6 + 0.2, $0.y * 0.7 + 0.1, 0) }
        for (contour, rx, ry) in [(FaceMeshGeometry.outerLipContour, Float(0.16), Float(0.08)),
                                  (FaceMeshGeometry.innerLipContour, Float(0.12), Float(0.035))] {
            for (i, index) in contour.enumerated() {
                let angle = Float.pi - Float(i) * 2 * .pi / Float(contour.count)
                result.landmarks[index] = SIMD3<Float>(0.5 + rx * cos(angle), 0.65 - ry * sin(angle), 0)
            }
        }
        result.boundingBox = CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.7)
        result.noseBridge = CGPoint(x: 0.5, y: 0.3)
        result.noseTip = CGPoint(x: 0.5, y: 0.5)
        result.chinTip = CGPoint(x: 0.5, y: 0.8)
        result.mouthCenter = CGPoint(x: 0.5, y: 0.65)
        return result
    }

    private func pixel(_ image: CIImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &bytes, rowBytes: 4,
                       bounds: CGRect(x: x, y: y, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }

    private func buffer() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 256, 256, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(buffer)
    }

    private func render(_ renderer: BeautyRenderer, source: CVPixelBuffer, makeup: MakeupSettings = MakeupSettings(),
                        beauty: BeautySettings = BeautySettings(), face: FaceSettings = FaceSettings(),
                        landmarks: FaceMeshLandmarks? = nil) throws -> CIImage {
        let output = try buffer()
        renderer.processFrame(sourceBuffer: source, targetBuffer: output, beautyEnabled: true,
            compareMode: "none", splitRatio: 0.5, beauty: beauty, face: face, makeup: makeup,
            filter: FilterSettings(), color: ColorSettings(), background: BackgroundSettings(),
            landmarks: landmarks ?? mesh())
        // Snapshot before the renderer reuses its mask texture.
        return CIImage(cgImage: try XCTUnwrap(context.createCGImage(CIImage(cvPixelBuffer: output), from: extent)))
    }

    func testLipMaskExcludesMouthAndSurroundingSkin() throws {
        let mask = try XCTUnwrap(BeautyRenderer().createLipMask(landmarks: mesh(), extent: extent))
        XCTAssertGreaterThan(pixel(mask, x: 128, y: 104)[0], 200)
        XCTAssertLessThan(pixel(mask, x: 128, y: 89)[0], 2)
        XCTAssertLessThan(pixel(mask, x: 128, y: 114)[0], 2)
        XCTAssertLessThan(pixel(mask, x: 175, y: 89)[0], 2)
        // Asymmetric location catches accidental vertical mirroring.
        XCTAssertLessThan(pixel(mask, x: 128, y: 166)[0], 2)
    }

    func testClosedMouthAndMissingFaceDoNotProduceTintMask() throws {
        let renderer = BeautyRenderer()
        var landmarks = mesh()
        for (outer, inner) in zip(FaceMeshGeometry.outerLipContour, FaceMeshGeometry.innerLipContour) {
            landmarks.landmarks[inner] = landmarks.landmarks[outer]
        }
        let mask = try XCTUnwrap(renderer.createLipMask(landmarks: landmarks, extent: extent))
        XCTAssertLessThan(pixel(mask, x: 128, y: 104)[0], 2)
        landmarks.hasFace = false
        XCTAssertNil(renderer.createLipMask(landmarks: landmarks, extent: extent))
    }

    func testLipOpacityIsMonotonicAndDoesNotTintTeeth() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.55, green: 0.38, blue: 0.34)), to: source, bounds: extent, colorSpace: nil)
        let base = try render(renderer, source: source)
        let low = try render(renderer, source: source, makeup: MakeupSettings(from: ["lipPreset": "red", "lipOpacity": 0.2]))
        let high = try render(renderer, source: source, makeup: MakeupSettings(from: ["lipPreset": "red", "lipOpacity": 0.8]))
        func difference(_ image: CIImage, x: Int, y: Int) -> Int {
            zip(pixel(image, x: x, y: y), pixel(base, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        }
        XCTAssertGreaterThan(difference(low, x: 128, y: 104), 0)
        XCTAssertGreaterThan(difference(high, x: 128, y: 104), difference(low, x: 128, y: 104))
        XCTAssertLessThanOrEqual(difference(high, x: 128, y: 89), 2)
        XCTAssertLessThanOrEqual(difference(high, x: 128, y: 114), 2)
    }

    func testLipTintMovesWithMouthReshape() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.55, green: 0.38, blue: 0.34)), to: source, bounds: extent, colorSpace: nil)
        let makeup = MakeupSettings(from: ["lipPreset": "red", "lipOpacity": 0.8])
        let original = try render(renderer, source: source, makeup: makeup)
        let moved = try render(renderer, source: source, makeup: makeup, face: FaceSettings(from: ["mouthPosition": 1.0]))
        let base = try render(renderer, source: source)
        func centerY(_ image: CIImage) -> Double {
            var weightedY = 0.0
            var weights = 0.0
            for y in 50..<130 {
                for x in stride(from: 85, to: 172, by: 2) {
                    let weight = Double(zip(pixel(image, x: x, y: y), pixel(base, x: x, y: y))
                        .reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) })
                    weightedY += Double(y) * weight
                    weights += weight
                }
            }
            return weightedY / max(1, weights)
        }
        XCTAssertGreaterThan(abs(centerY(moved) - centerY(original)), 1.0,
                             "Lip tint must follow the reshaped mouth instead of remaining at old coordinates")
    }

    func testTeethWhiteningExcludesLipsAndDarkMouth() throws {
        let renderer = BeautyRenderer()
        for color in [CIColor(red: 0.7, green: 0.7, blue: 0.65), CIColor(red: 0.04, green: 0.02, blue: 0.02)] {
            let source = try buffer()
            context.render(CIImage(color: color), to: source, bounds: extent, colorSpace: nil)
            let base = try render(renderer, source: source)
            let whitened = try render(renderer, source: source, beauty: BeautySettings(from: ["teethWhitening": 1.0]))
            XCTAssertEqual(pixel(base, x: 128, y: 104), pixel(whitened, x: 128, y: 104))
            if color.red < 0.1 {
                XCTAssertEqual(pixel(base, x: 128, y: 89), pixel(whitened, x: 128, y: 89))
            } else {
                XCTAssertGreaterThan(pixel(whitened, x: 128, y: 89)[0], pixel(base, x: 128, y: 89)[0])
            }
        }
    }

    func testSkinSmoothingPreservesMouthAndBackground() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.50, green: 0.35, blue: 0.30),
            "inputColor1": CIColor(red: 0.54, green: 0.39, blue: 0.34), "inputWidth": 2.0
        ])!.outputImage!
        context.render(checker, to: source, bounds: extent, colorSpace: nil)
        let base = try render(renderer, source: source)
        let smooth = try render(renderer, source: source, beauty: BeautySettings(from: ["smooth": 1.0, "skinTexture": 0.5]))
        for (x, y) in [(128, 104), (128, 89), (5, 5)] {
            for (a, b) in zip(pixel(base, x: x, y: y), pixel(smooth, x: x, y: y)) {
                XCTAssertLessThanOrEqual(abs(Int(a) - Int(b)), 4)
            }
        }
        var changedPixels = 0
        for x in stride(from: 60, to: 196, by: 4) {
            for y in stride(from: 55, to: 200, by: 4) {
                if pixel(base, x: x, y: y) != pixel(smooth, x: x, y: y) { changedPixels += 1 }
            }
        }
        XCTAssertGreaterThan(changedPixels, 10, "Smoothing kernel must run, not silently fall back to original")
    }

    func testOneEuroResetsAfterGapAndInvalidInput() {
        let bank = OneEuroFilterBank468()
        let original = [SIMD3<Float>](repeating: SIMD3<Float>(0.2, 0.3, 0), count: 468)
        let moved = [SIMD3<Float>](repeating: SIMD3<Float>(0.6, 0.3, 0), count: 468)
        XCTAssertEqual(bank.filter(raw: original, timestamp: 1), original)
        XCTAssertEqual(bank.filter(raw: moved, timestamp: 2), moved)
        XCTAssertEqual(bank.filter(raw: original, timestamp: 1.5), original)
        var invalid = original
        invalid[0].x = .nan
        XCTAssertTrue(bank.filter(raw: invalid, timestamp: 3).isEmpty)
        XCTAssertEqual(bank.filter(raw: moved, timestamp: 3.01), moved)
    }

    func testOneEuroReducesJitterAndRespondsToMotion() {
        let bank = OneEuroFilterBank468()
        var last: Float = 0.5
        var rawError: Float = 0
        var filteredError: Float = 0
        for i in 0..<60 {
            let x: Float = 0.5 + (i.isMultiple(of: 2) ? 0.001 : -0.001)
            let result = bank.filter(raw: Array(repeating: SIMD3<Float>(x, 0.5, 0), count: 468), timestamp: Double(i) / 30)
            last = result[0].x
            if i > 10 { rawError += abs(x - 0.5); filteredError += abs(last - 0.5) }
        }
        XCTAssertLessThan(filteredError, rawError * 0.7)
        let moved = bank.filter(raw: Array(repeating: SIMD3<Float>(0.6, 0.5, 0), count: 468), timestamp: 2)
        XCTAssertGreaterThan(moved[0].x, 0.57)
    }

    func testCreateFullFaceSkinMaskCoversForeheadAndJawAndExcludesMouth() throws {
        let renderer = BeautyRenderer()
        var landmarks = mesh()
        // Provide faceContour running along jawline
        landmarks.faceContour = [
            CGPoint(x: 0.25, y: 0.35),
            CGPoint(x: 0.22, y: 0.50),
            CGPoint(x: 0.28, y: 0.65),
            CGPoint(x: 0.38, y: 0.78),
            CGPoint(x: 0.50, y: 0.82), // chin
            CGPoint(x: 0.62, y: 0.78),
            CGPoint(x: 0.72, y: 0.65),
            CGPoint(x: 0.78, y: 0.50),
            CGPoint(x: 0.75, y: 0.35)
        ]
        landmarks.leftEyeCenter = CGPoint(x: 0.38, y: 0.38)
        landmarks.rightEyeCenter = CGPoint(x: 0.62, y: 0.38)
        landmarks.mouthCenter = CGPoint(x: 0.50, y: 0.65)

        let mask = try XCTUnwrap(renderer.createFullFaceSkinMask(landmarks: landmarks, extent: extent))

        // Skin on cheek should be covered with high mask weight
        let cheekPx = pixel(mask, x: 128, y: 135)
        XCTAssertGreaterThan(cheekPx[0], 150, "Full-face skin mask must cover face skin with high weight")

        // Mouth center should be punched out (low weight) to protect lips/teeth
        let mouthPx = pixel(mask, x: 128, y: 90) // y = 1 - 0.65 = 0.35 * 256 ~= 90 in CI
        XCTAssertLessThan(mouthPx[0], 80, "Mouth cavity must be punched out to protect lips and teeth")

        // Distant background corner must be zero
        let bgPx = pixel(mask, x: 5, y: 5)
        XCTAssertEqual(bgPx[0], 0, "Background should not have skin mask")
    }

    func testFaceTrackerLifecycle() {
        let tracker = FaceTracker()
        XCTAssertFalse(tracker.currentLandmarks.hasFace)
        tracker.reset()
        XCTAssertFalse(tracker.currentLandmarks.hasFace)
    }

    func testSkinSegmenterLifecycleAndInference() throws {
        let segmenter = SkinSegmenter()
        segmenter.reset()

        let buf = try buffer()
        let mask = segmenter.processFrame(pixelBuffer: buf, targetWidth: 256, targetHeight: 256)
        // If model is loaded on the runner, mask should be generated
        if let mask = mask {
            XCTAssertEqual(mask.extent.width, 256)
            XCTAssertEqual(mask.extent.height, 256)
        }
        segmenter.reset()
    }

    func testDualCoreFusionSkinMaskWithFeatureProtection() throws {
        let renderer = BeautyRenderer()
        let landmarks = mesh()

        // Create a synthetic solid white skin segmentation mask (representing Class 3: Face-Skin)
        let whiteCI = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: extent)

        let fusedMask = try XCTUnwrap(renderer.createFaceSkinMask(
            segmentationMask: whiteCI,
            landmarks: landmarks,
            extent: extent
        ))

        // Cheek skin area should remain high
        let cheekPx = pixel(fusedMask, x: 128, y: 135)
        XCTAssertGreaterThan(cheekPx[0], 180, "Fused mask must preserve face skin")

        // Mouth cavity should be cleanly punched out from the skin mask
        let mouthPx = pixel(fusedMask, x: 128, y: 90)
        XCTAssertLessThan(mouthPx[0], 80, "Fused mask must punch out mouth cavity")
    }
}

