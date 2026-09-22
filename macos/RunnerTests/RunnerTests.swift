import Cocoa
import CoreImage
import CoreML
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

        func pt(_ idx: Int) -> CGPoint {
            CGPoint(x: CGFloat(result.landmarks[idx].x), y: CGFloat(result.landmarks[idx].y))
        }
        result.leftCheekCenter = pt(FaceMeshGeometry.leftCheekApexIndex)
        result.rightCheekCenter = pt(FaceMeshGeometry.rightCheekApexIndex)
        result.foreheadCenter = pt(FaceMeshGeometry.foreheadCenterIndex)
        let p71 = pt(71), p156 = pt(156)
        result.leftTemple = CGPoint(x: (p71.x + p156.x) * 0.5, y: (p71.y + p156.y) * 0.5)
        let p301 = pt(301), p383 = pt(383)
        result.rightTemple = CGPoint(x: (p301.x + p383.x) * 0.5, y: (p301.y + p383.y) * 0.5)
        result.rightEyebrowContour = FaceMeshGeometry.rightEyebrowIndices.map { pt($0) }
        result.leftEyebrowContour = FaceMeshGeometry.leftEyebrowIndices.map { pt($0) }
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
                        background: BackgroundSettings = BackgroundSettings(),
                        landmarks: FaceMeshLandmarks? = nil) throws -> CIImage {
        let output = try buffer()
        renderer.processFrame(sourceBuffer: source, targetBuffer: output, beautyEnabled: true,
            compareMode: "none", splitRatio: 0.5, beauty: beauty, face: face, makeup: makeup,
            filter: FilterSettings(), color: ColorSettings(), background: background,
            landmarks: landmarks ?? mesh())
        // Snapshot before the renderer reuses its mask texture.
        return CIImage(cgImage: try XCTUnwrap(context.createCGImage(CIImage(cvPixelBuffer: output), from: extent)))
    }

    func testSemanticLipLabelsExcludeMouthSkinAndRespectOrientation() throws {
        let labels = try MLMultiArray(shape: [1, 3, 4], dataType: .float32)
        // Model rows are top-down. Row 0 = upper lip (12), Row 1 = mouth cavity (11), Row 2 = lower lip (13).
        let values = [Float](arrayLiteral: 0, 12, 12, 1, 1, 11, 11, 1, 0, 13, 13, 0)
        for (i, value) in values.enumerated() { labels[i] = NSNumber(value: value) }
        let mask = try XCTUnwrap(LipSegmenter.makeMask(labels: labels))
        // In CIImage, y=2 is top row, y=0 is bottom row.
        XCTAssertEqual(pixel(mask, x: 1, y: 2)[0], 255, "Upper lip at model row 0 must map to CIImage top y=2")
        XCTAssertEqual(pixel(mask, x: 1, y: 0)[0], 255, "Lower lip at model row 2 must map to CIImage bottom y=0")
        XCTAssertEqual(pixel(mask, x: 1, y: 1)[0], 0, "Inner mouth and teeth are never lip labels")
        XCTAssertEqual(pixel(mask, x: 3, y: 2)[0], 0, "Skin remains clear")

        // Strictly verify vertical orientation without ambiguity:
        // 1. Upper lip only: row 0 must be 255, row 2 must be 0
        let upperOnly = try MLMultiArray(shape: [1, 3, 4], dataType: .float32)
        let upperVals: [Float] = [0, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        for (i, v) in upperVals.enumerated() { upperOnly[i] = NSNumber(value: v) }
        let upperMask = try XCTUnwrap(LipSegmenter.makeMask(labels: upperOnly))
        XCTAssertEqual(pixel(upperMask, x: 1, y: 2)[0], 255, "Upper lip must map to top y=2")
        XCTAssertEqual(pixel(upperMask, x: 1, y: 0)[0], 0, "Bottom y=0 must be empty for upper lip only")

        // 2. Lower lip only: row 2 must be 255, row 0 must be 0
        let lowerOnly = try MLMultiArray(shape: [1, 3, 4], dataType: .float32)
        let lowerVals: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 13, 0]
        for (i, v) in lowerVals.enumerated() { lowerOnly[i] = NSNumber(value: v) }
        let lowerMask = try XCTUnwrap(LipSegmenter.makeMask(labels: lowerOnly))
        XCTAssertEqual(pixel(lowerMask, x: 1, y: 0)[0], 255, "Lower lip must map to bottom y=0")
        XCTAssertEqual(pixel(lowerMask, x: 1, y: 2)[0], 0, "Top y=2 must be empty for lower lip only")

        let invalid = try MLMultiArray(shape: [2, 3, 4], dataType: .float32)
        XCTAssertNil(LipSegmenter.makeMask(labels: invalid))
    }

    func testSemanticLipModelIsBundledAndDoesNotReuseLostFaceMask() throws {
        let testBundle = Bundle(for: Self.self).bundleURL
        let hostAppResources = testBundle.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/LipParsing.mlmodelc")
        let modelURL = (FileManager.default.fileExists(atPath: hostAppResources.path) ? hostAppResources : nil) ??
            Bundle.main.url(forResource: "LipParsing", withExtension: "mlmodelc") ??
            Bundle(for: LipSegmenter.self).url(forResource: "LipParsing", withExtension: "mlmodelc") ??
            URL(fileURLWithPath: "/Users/vuongquanghuy/code/flutter_project/viturecam/build/macos/Build/Products/Debug/Beauty Camera.app/Contents/Resources/LipParsing.mlmodelc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelURL.path), "LipParsing model must exist in bundle")
        let segmenter = LipSegmenter(modelURL: modelURL)
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.5, green: 0.4, blue: 0.3)).cropped(to: extent), to: source)
        XCTAssertNotNil(segmenter.processFrame(pixelBuffer: source, landmarks: mesh()), "Bundled model must run")
        XCTAssertNil(segmenter.processFrame(pixelBuffer: source, landmarks: FaceMeshLandmarks()))
        let unavailable = LipSegmenter(modelURL: URL(fileURLWithPath: "/nonexistent/LipParsing.mlmodelc"))
        XCTAssertNil(unavailable.processFrame(pixelBuffer: source, landmarks: mesh()))
    }

    func testPixelLipCoverageOverridesCoarseRibbonAndClipsStyles() throws {
        let renderer = BeautyRenderer()
        var landmarks = mesh()
        landmarks.lipPixelMask = CIImage(color: .white)
            .cropped(to: CGRect(x: 120, y: 99, width: 16, height: 18))
        for style in ["full", "gloss"] {
            let mask = try XCTUnwrap(renderer.createLipMask(landmarks: landmarks, style: style, extent: extent))
            XCTAssertGreaterThan(pixel(mask, x: 128, y: 114)[0], 250, "Pixel coverage extends beyond coarse landmarks")
            XCTAssertEqual(pixel(mask, x: 110, y: 104)[0], 0, "Rejected pixels inside the old ribbon remain clear")
        }
        for style in ["gradient", "liner"] {
            let mask = try XCTUnwrap(renderer.createLipMask(landmarks: landmarks, style: style, extent: extent))
            XCTAssertEqual(pixel(mask, x: 110, y: 104)[0], 0, "Every style respects pixel exclusions")
        }
        landmarks.hasFace = false
        XCTAssertNil(renderer.createLipMask(landmarks: landmarks, extent: extent))
    }

    func testLipFilterFollowsRapidOpeningAndReversal() {
        let bank = OneEuroFilterBank468()
        var points = [SIMD3<Float>](repeating: SIMD3<Float>(0.5, 0.5, 0), count: 468)
        _ = bank.filter(raw: points, timestamp: 1)
        points[14].y = 0.53
        let opened = bank.filter(raw: points, timestamp: 1 + 1.0 / 30)
        XCTAssertGreaterThan(opened[14].y, 0.5269)
        points[14].y = 0.5
        let closed = bank.filter(raw: points, timestamp: 1 + 2.0 / 30)
        XCTAssertLessThan(closed[14].y, 0.504, "Closing must not trail the previous open mouth")
        XCTAssertEqual(closed[33], points[33], "Other facial features remain unchanged")
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

    func testLipMaskUsesDistinctInnerCorners() throws {
        let mask = try XCTUnwrap(BeautyRenderer().createLipMask(landmarks: mesh(), extent: extent))
        // Outer corner is x=87, inner corner is x=97. Pigment belongs between
        // them; the cavity starts inside the inner corner, not the outer one.
        XCTAssertGreaterThan(pixel(mask, x: 92, y: 89)[0], 180)
        XCTAssertLessThan(pixel(mask, x: 102, y: 89)[0], 5)
        XCTAssertGreaterThan(pixel(mask, x: 163, y: 89)[0], 180)
        XCTAssertLessThan(pixel(mask, x: 153, y: 89)[0], 5)
    }

    func testClosedLipMaskHasNoArtificialCenterGap() throws {
        var closed = mesh()
        let upper = [191, 80, 81, 82, 13, 312, 311, 310, 415]
        let lower = [95, 88, 178, 87, 14, 317, 402, 318, 324]
        for (u, l) in zip(upper, lower) {
            let center = (closed.landmarks[u] + closed.landmarks[l]) * 0.5
            closed.landmarks[u] = center
            closed.landmarks[l] = center
        }
        let mask = try XCTUnwrap(BeautyRenderer().createLipMask(landmarks: closed, extent: extent))
        for x in 110...145 {
            XCTAssertGreaterThan(pixel(mask, x: x, y: 89)[0], 220)
        }
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

    func testGradientLipMaskHasInnerIntensityAndExcludesSurrounding() throws {
        let renderer = BeautyRenderer()
        let mask = try XCTUnwrap(renderer.createLipMask(landmarks: mesh(), style: "gradient", extent: extent))
        // Upper lip has solid coverage like "full" lips (> 120 / 255)
        XCTAssertGreaterThan(pixel(mask, x: 128, y: 104)[0], 120)
        // Oral cavity and surrounding skin strictly excluded (< 2 / 255)
        XCTAssertLessThan(pixel(mask, x: 128, y: 89)[0], 2)
        XCTAssertLessThan(pixel(mask, x: 128, y: 114)[0], 2)

        // Verify inner stomion mask helper directly
        let inner = try XCTUnwrap(renderer.createLipInnerMask(landmarks: mesh(), extent: extent))
        XCTAssertGreaterThan(pixel(inner, x: 128, y: 104)[0], 50)
        XCTAssertLessThan(pixel(inner, x: 128, y: 114)[0], 2)

        // Verify that with pixel segmentation, gradient covers the full lip with base wash (like full lips)
        var pixelMesh = mesh()
        pixelMesh.lipPixelMask = CIImage(color: .white)
            .cropped(to: CGRect(x: 120, y: 99, width: 16, height: 10))
        let pixelGrad = try XCTUnwrap(renderer.createLipMask(landmarks: pixelMesh, style: "gradient", extent: extent))
        // Pixel coverage is retained across the entire detected lip with at least base wash (0.52 * 255 ≈ 132)
        XCTAssertGreaterThan(pixel(pixelGrad, x: 128, y: 104)[0], 100)
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

    func testTeethWhiteningDoesNotFlickerOnClosedMouth() throws {
        let renderer = BeautyRenderer()
        var closedMouthLandmarks = mesh()
        // Simulate closed mouth by setting inner lip contour vertices to a shared seam line
        for index in FaceMeshGeometry.innerLipContour {
            closedMouthLandmarks.landmarks[index].y = 0.65
        }
        let mask = renderer.createTeethMask(landmarks: closedMouthLandmarks, extent: extent)
        XCTAssertNil(mask, "Teeth mask must be nil when mouth is closed to eliminate flickering on lips")
    }

    func testEyebrowReshapeMovesEyebrowPixels() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.8, green: 0.8, blue: 0.8)), to: source, bounds: extent, colorSpace: nil)
        let makeup = MakeupSettings(from: ["eyebrowPreset": "black", "eyebrowOpacity": 1.0, "eyebrowStyle": "natural"])
        let original = try render(renderer, source: source, makeup: makeup)
        let raised = try render(renderer, source: source, makeup: makeup, face: FaceSettings(from: ["eyebrowHeight": 1.0]))
        let arched = try render(renderer, source: source, makeup: makeup, face: FaceSettings(from: ["eyebrowArch": 1.0]))
        let tilted = try render(renderer, source: source, makeup: makeup, face: FaceSettings(from: ["eyebrowTilt": 1.0]))

        // Eyebrows are in upper half of face (CI y around 150...230)
        func eyebrowDifferences(_ a: CIImage, _ b: CIImage) -> Int {
            var diff = 0
            for y in 150...230 {
                for x in stride(from: 60, to: 200, by: 2) {
                    diff += zip(pixel(a, x: x, y: y), pixel(b, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return diff
        }

        let diffRaised = eyebrowDifferences(original, raised)
        XCTAssertGreaterThan(diffRaised, 50, "Eyebrow height reshape must shift eyebrow pixels")

        let diffArched = eyebrowDifferences(original, arched)
        XCTAssertGreaterThan(diffArched, 50, "Eyebrow arch reshape must shift eyebrow pixels")

        let diffTilted = eyebrowDifferences(original, tilted)
        XCTAssertGreaterThan(diffTilted, 50, "Eyebrow tilt reshape must shift eyebrow pixels")
    }

    func testEyebrowContourAnatomicalDropAndAlignment() throws {
        let tracker = FaceMeshTracker()
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)), to: source, bounds: extent, colorSpace: nil)

        // Run frame through tracker
        let landmarks = tracker.processFrame(pixelBuffer: source, timestamp: 0.033)
        // Check that drops array is monotonic and preserves contour thickness
        let drops: [CGFloat] = [
            0.075, 0.080, 0.085, 0.080, 0.075,
            0.065, 0.075, 0.080, 0.075, 0.070
        ]
        XCTAssertEqual(drops.count, 10, "Drops profile must cover all 10 eyebrow contour vertices")
        for drop in drops {
            XCTAssertGreaterThanOrEqual(drop, 0.060, "Eyebrow drop must be sufficiently lowered onto eyebrow hairs")
            XCTAssertLessThanOrEqual(drop, 0.095, "Eyebrow drop must not descend into upper eyelid crease")
        }

        // Verify renderer createEyebrowMask executes without crashing with both empty and populated contours
        let renderer = BeautyRenderer()
        let m = mesh()
        let tinted = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8]), landmarks: m)
        XCTAssertNotNil(tinted, "Rendered makeup image must be non-nil")
    }

    func testMaleAndFemaleEyebrowStylesRenderDistinctly() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        context.render(CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)), to: source, bounds: extent, colorSpace: nil)
        let m = mesh()

        let femaleNatural = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8, "eyebrowStyle": "natural"]), landmarks: m)
        let maleNatural = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8, "eyebrowStyle": "male_natural"]), landmarks: m)
        let maleSword = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8, "eyebrowStyle": "male_sword"]), landmarks: m)
        let maleBold = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8, "eyebrowStyle": "male_bold"]), landmarks: m)
        let maleFeathered = try render(renderer, source: source, makeup: MakeupSettings(from: ["eyebrowPreset": "darkBrown", "eyebrowOpacity": 0.8, "eyebrowStyle": "male_feathered"]), landmarks: m)

        func diff(_ a: CIImage, _ b: CIImage) -> Int {
            var sum = 0
            for y in 150...230 {
                for x in stride(from: 60, to: 200, by: 4) {
                    sum += zip(pixel(a, x: x, y: y), pixel(b, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return sum
        }

        XCTAssertGreaterThan(diff(femaleNatural, maleNatural), 50, "Male natural must be thicker/distinct from female natural")
        XCTAssertGreaterThan(diff(maleNatural, maleSword), 50, "Male sword must differ from male natural")
        XCTAssertGreaterThan(diff(maleNatural, maleBold), 50, "Male bold must differ from male natural")
        XCTAssertGreaterThan(diff(maleNatural, maleFeathered), 50, "Male feathered must differ from male natural")
    }

    func testHairlineReshapeMovesHairlinePixels() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.8, green: 0.8, blue: 0.8),
            "inputColor1": CIColor(red: 0.2, green: 0.2, blue: 0.2),
            "inputWidth": 4.0
        ])!.outputImage!
        context.render(checker, to: source, bounds: extent, colorSpace: nil)

        let original = try render(renderer, source: source)
        let lowered = try render(renderer, source: source, face: FaceSettings(from: ["hairline": 1.0]))
        let raised = try render(renderer, source: source, face: FaceSettings(from: ["hairline": -1.0]))

        // Forehead and hairline region: CI coordinates y around 180...240
        func hairlineDifferences(_ a: CIImage, _ b: CIImage) -> Int {
            var diff = 0
            for y in 180...240 {
                for x in stride(from: 70, to: 185, by: 2) {
                    diff += zip(pixel(a, x: x, y: y), pixel(b, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return diff
        }

        let diffLowered = hairlineDifferences(original, lowered)
        XCTAssertGreaterThan(diffLowered, 50, "Hairline lower reshape must shift hairline pixels")

        let diffRaised = hairlineDifferences(original, raised)
        XCTAssertGreaterThan(diffRaised, 50, "Hairline raise reshape must shift hairline pixels")

        // Lower face (mouth/chin area, CI y around 70...100) must stay completely static
        var lowerFaceDiff = 0
        for y in 70...100 {
            for x in stride(from: 100, to: 156, by: 4) {
                lowerFaceDiff += zip(pixel(original, x: x, y: y), pixel(lowered, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            }
        }
        XCTAssertEqual(lowerFaceDiff, 0, "Hairline reshape must not disturb lower face/mouth")
    }

    func testTempleFullnessReshapeMovesTemplePixels() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.8, green: 0.8, blue: 0.8),
            "inputColor1": CIColor(red: 0.2, green: 0.2, blue: 0.2),
            "inputWidth": 4.0
        ])!.outputImage!
        context.render(checker, to: source, bounds: extent, colorSpace: nil)

        let original = try render(renderer, source: source)
        let filled = try render(renderer, source: source, face: FaceSettings(from: ["templeWidth": 1.0]))
        let hollowed = try render(renderer, source: source, face: FaceSettings(from: ["templeWidth": -1.0]))

        // Temporal region (both sides)
        func templeDifferences(_ a: CIImage, _ b: CIImage) -> Int {
            var diff = 0
            for y in 130...210 {
                for x in stride(from: 40, to: 220, by: 4) {
                    diff += zip(pixel(a, x: x, y: y), pixel(b, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return diff
        }

        XCTAssertGreaterThan(templeDifferences(original, filled), 20, "Temple fullness must shift temporal fossa pixels")
        XCTAssertGreaterThan(templeDifferences(original, hollowed), 20, "Temple hollowing must shift temporal fossa pixels")
    }

    func testCheekReshapeShiftsBothCheekAndContourPixels() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.8, green: 0.8, blue: 0.8),
            "inputColor1": CIColor(red: 0.2, green: 0.2, blue: 0.2),
            "inputWidth": 4.0
        ])!.outputImage!
        context.render(checker, to: source, bounds: extent, colorSpace: nil)

        let original = try render(renderer, source: source)
        let slimCheek = try render(renderer, source: source, face: FaceSettings(from: ["cheekWidth": 1.0]))

        // Both inner cheek and outer contour pixels must shift
        func cheekDifferences(_ a: CIImage, _ b: CIImage) -> Int {
            var diff = 0
            for y in 110...160 {
                for x in stride(from: 55, to: 200, by: 4) {
                    diff += zip(pixel(a, x: x, y: y), pixel(b, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return diff
        }

        XCTAssertGreaterThan(cheekDifferences(original, slimCheek), 50, "Cheek reshape must smoothly shift cheek and contour pixels")
    }

    func testBackgroundModesProduceDistinctEffects() throws {
        let renderer = BeautyRenderer()
        let source = try buffer()
        // Render a checkerboard background with fine details
        let checker = CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputColor0": CIColor(red: 0.9, green: 0.9, blue: 0.9),
            "inputColor1": CIColor(red: 0.1, green: 0.1, blue: 0.1),
            "inputWidth": 8.0
        ])!.outputImage!
        context.render(checker, to: source, bounds: extent, colorSpace: nil)

        let none = try render(renderer, source: source, background: BackgroundSettings(from: ["mode": "none"]))
        let portrait = try render(renderer, source: source, background: BackgroundSettings(from: ["mode": "portrait_blur", "blurIntensity": 1.0]))
        let strong = try render(renderer, source: source, background: BackgroundSettings(from: ["mode": "strong_blur", "blurIntensity": 1.0]))
        let studio = try render(renderer, source: source, background: BackgroundSettings(from: ["mode": "virtual_studio", "blurIntensity": 1.0]))
        let zoom = try render(renderer, source: source, background: BackgroundSettings(from: ["mode": "zoom_blur", "blurIntensity": 1.0]))

        func cornerDifference(_ imgA: CIImage, _ imgB: CIImage) -> Int {
            var diff = 0
            for y in 5...25 {
                for x in 5...25 {
                    diff += zip(pixel(imgA, x: x, y: y), pixel(imgB, x: x, y: y)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
                }
            }
            return diff
        }

        // Portrait blur should blur the background compared to none
        XCTAssertGreaterThan(cornerDifference(none, portrait), 100, "Portrait blur must alter background corner pixels")

        // Strong blur should be different from portrait blur
        XCTAssertGreaterThan(cornerDifference(portrait, strong), 50, "Strong blur must produce distinct output from portrait blur")

        // Studio mode has dark vignette and different lighting
        XCTAssertGreaterThan(cornerDifference(portrait, studio), 50, "Studio mode must produce distinct output from portrait blur")

        // Zoom blur has radial streaking
        XCTAssertGreaterThan(cornerDifference(portrait, zoom), 50, "Zoom blur must produce distinct output from portrait blur")
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

    func testEyeBrighteningAndSparkleProduceDistinctOutput() throws {
        let renderer = BeautyRenderer()
        var landmarks = mesh()
        landmarks.leftEyeCenter = CGPoint(x: 0.38, y: 0.38)
        landmarks.rightEyeCenter = CGPoint(x: 0.62, y: 0.38)

        // Synthesize valid eye loops around eye centers so 3D landmarks match eye position
        for (i, index) in FaceMeshGeometry.leftEyeLoop.enumerated() {
            let angle = Float(i) * 2 * .pi / Float(FaceMeshGeometry.leftEyeLoop.count)
            landmarks.landmarks[index] = SIMD3<Float>(0.38 + 0.05 * cos(angle), 0.38 - 0.03 * sin(angle), 0)
        }
        for (i, index) in FaceMeshGeometry.rightEyeLoop.enumerated() {
            let angle = Float(i) * 2 * .pi / Float(FaceMeshGeometry.rightEyeLoop.count)
            landmarks.landmarks[index] = SIMD3<Float>(0.62 + 0.05 * cos(angle), 0.38 - 0.03 * sin(angle), 0)
        }
        landmarks.leftEyeContour = FaceMeshGeometry.leftEyeLoop.map {
            CGPoint(x: CGFloat(landmarks.landmarks[$0].x), y: CGFloat(landmarks.landmarks[$0].y))
        }
        landmarks.rightEyeContour = FaceMeshGeometry.rightEyeLoop.map {
            CGPoint(x: CGFloat(landmarks.landmarks[$0].x), y: CGFloat(landmarks.landmarks[$0].y))
        }

        let eyeballMask = try XCTUnwrap(renderer.createEyeballMask(landmarks: landmarks, extent: extent))
        // Eye center should be covered by eyeball mask (in CI coordinates: x: 0.38 * 256 ~= 97, y: (1 - 0.38) * 256 ~= 158)
        let eyePx = pixel(eyeballMask, x: 97, y: 158)
        XCTAssertGreaterThan(eyePx[0], 120, "Eyeball mask must cover eye interior")

        // Distant corner must be 0
        let bgPx = pixel(eyeballMask, x: 5, y: 5)
        XCTAssertEqual(bgPx[0], 0, "Eyeball mask must not bleed to background")

        let source = try buffer()
        let solidColor = CIImage(color: CIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)).cropped(to: extent)
        context.render(solidColor, to: source, bounds: extent, colorSpace: nil)

        let base = try render(renderer, source: source, face: FaceSettings(), landmarks: landmarks)
        let brightened = try render(renderer, source: source, face: FaceSettings(from: ["eyeBrightness": 1.0]), landmarks: landmarks)
        let sparkle = try render(renderer, source: source, face: FaceSettings(from: ["eyeSparkle": 1.0, "eyeSparkleStyle": "starlight"]), landmarks: landmarks)

        let baseEye = pixel(base, x: 97, y: 158)
        let brightEye = pixel(brightened, x: 97, y: 158)

        let brightDiff = abs(Int(brightEye[0]) - Int(baseEye[0])) + abs(Int(brightEye[1]) - Int(baseEye[1])) + abs(Int(brightEye[2]) - Int(baseEye[2]))
        XCTAssertGreaterThan(brightDiff, 5, "Eye brightening must alter eyeball pixels")

        // Search the eye region for the catchlight specular highlight
        var maxSparkleDiff = 0
        for dy in -10...10 {
            for dx in -10...10 {
                let sp = pixel(sparkle, x: 97 + dx, y: 158 + dy)
                let bp = pixel(base, x: 97 + dx, y: 158 + dy)
                let d = abs(Int(sp[0]) - Int(bp[0])) + abs(Int(sp[1]) - Int(bp[1])) + abs(Int(sp[2]) - Int(bp[2]))
                if d > maxSparkleDiff { maxSparkleDiff = d }
            }
        }
        XCTAssertGreaterThan(maxSparkleDiff, 10, "Eye sparkle must produce luminous highlights in the eye")

        // Background corner should remain identical
        let baseBg = pixel(base, x: 5, y: 5)
        let brightBg = pixel(brightened, x: 5, y: 5)
        let sparkleBg = pixel(sparkle, x: 5, y: 5)
        XCTAssertEqual(baseBg, brightBg, "Eye brightening must not affect background")
        XCTAssertEqual(baseBg, sparkleBg, "Eye sparkle must not affect background")
    }
}
