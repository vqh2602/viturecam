import CoreVideo
import Foundation
import Vision

/// Apple Native Vision Face Tracker
/// Leverages macOS Vision Framework (VNDetectFaceLandmarksRequest) running on Apple Neural Engine & GPU.
/// Delivers robust face contour tracking across all angles (yaw, pitch, roll) and with accessories (headphones, glasses).
public final class FaceTracker {
    public var damping: CGFloat = 0.70 // 0.0 = raw, 1.0 = heavy smooth

    private let trackingQueue = DispatchQueue(label: "com.beautycamera.visionfacetracking", qos: .userInteractive)
    private var previousLandmarks = FaceMeshLandmarks()
    private var lastTimestamp: TimeInterval?
    private let lock = NSLock()

    public init() {}

    public var currentLandmarks: FaceMeshLandmarks {
        lock.lock()
        defer { lock.unlock() }
        return previousLandmarks
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        previousLandmarks = FaceMeshLandmarks()
        lastTimestamp = nil
    }

    /// Process a camera frame synchronously on the capture thread, returning rich FaceMeshLandmarks.
    public func processFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> FaceMeshLandmarks {
        trackingQueue.sync {
            let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            guard width > 0 && height > 0 else {
                updateNoFace()
                return currentLandmarks
            }

            let request = VNDetectFaceLandmarksRequest()
            request.preferBackgroundProcessing = false
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

            do {
                try handler.perform([request])
                guard let results = request.results, let face = results.first else {
                    updateNoFace()
                    return currentLandmarks
                }
                updateFromObservation(face: face, width: width, height: height, timestamp: timestamp)
            } catch {
                updateNoFace()
            }

            return currentLandmarks
        }
    }

    private func updateNoFace() {
        lock.lock()
        defer { lock.unlock() }
        previousLandmarks = FaceMeshLandmarks()
        lastTimestamp = nil
    }

    private func updateFromObservation(
        face: VNFaceObservation,
        width: CGFloat,
        height: CGFloat,
        timestamp: TimeInterval
    ) {
        let b = face.boundingBox // In Vision bottom-left coordinates (0..1)
        let landmarks = face.landmarks

        // Convert Vision bounding box to screen normalized space (top-left origin 0,0 to bottom-right 1,1)
        let boxX = b.origin.x
        let boxY = 1.0 - (b.origin.y + b.height)
        let boxW = b.width
        let boxH = b.height
        let screenBox = CGRect(x: boxX, y: boxY, width: boxW, height: boxH)

        // Helper to convert Vision landmark normalized points (relative to boundingBox) to image normalized space (top-left)
        func convertPoints(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let points = region?.normalizedPoints, !points.isEmpty else { return [] }
            return points.map { pt in
                let px = b.origin.x + pt.x * b.width
                let py = 1.0 - (b.origin.y + pt.y * b.height)
                return CGPoint(x: px, y: py)
            }
        }

        func centerOf(_ pts: [CGPoint]) -> CGPoint {
            guard !pts.isEmpty else { return .zero }
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            for p in pts { sumX += p.x; sumY += p.y }
            return CGPoint(x: sumX / CGFloat(pts.count), y: sumY / CGFloat(pts.count))
        }

        let faceContour = convertPoints(landmarks?.faceContour)
        let leftEyePts = convertPoints(landmarks?.leftEye)
        let rightEyePts = convertPoints(landmarks?.rightEye)
        let leftEyebrowPts = convertPoints(landmarks?.leftEyebrow)
        let rightEyebrowPts = convertPoints(landmarks?.rightEyebrow)
        let nosePts = convertPoints(landmarks?.nose)
        let noseCrestPts = convertPoints(landmarks?.noseCrest)
        let rawOuterLipPts = convertPoints(landmarks?.outerLips)
        // Apple Vision outerLips: indices 0..6 (upper lip), 7 (right corner),
        // 8..12 (lower lip), 13 (left corner).
        // Reorder so that index 0 starts at left commissure to match FaceMeshGeometry.outerLipContour (landmark 61).
        let outerLipPts: [CGPoint]
        if rawOuterLipPts.count == 14 {
            outerLipPts = [rawOuterLipPts[13]] + Array(rawOuterLipPts[0..<13])
        } else {
            outerLipPts = rawOuterLipPts
        }
        let innerLipPts = convertPoints(landmarks?.innerLips)

        var res = FaceMeshLandmarks()
        res.hasFace = true
        res.confidence = face.confidence
        res.boundingBox = screenBox

        // Contours
        res.faceContour = faceContour
        res.outerLipContour = outerLipPts
        res.innerLipContour = innerLipPts
        res.leftEyeContour = leftEyePts
        res.rightEyeContour = rightEyePts
        res.leftEyebrowContour = leftEyebrowPts
        res.rightEyebrowContour = rightEyebrowPts

        // Eye Centers & Outer Corners
        res.leftEyeCenter = centerOf(leftEyePts)
        res.rightEyeCenter = centerOf(rightEyePts)
        if !leftEyePts.isEmpty {
            res.leftEyeOuter = leftEyePts.min(by: { $0.x < $1.x }) ?? res.leftEyeCenter
        }
        if !rightEyePts.isEmpty {
            res.rightEyeOuter = rightEyePts.max(by: { $0.x < $1.x }) ?? res.rightEyeCenter
        }

        // Eyebrows Center & Forehead
        let leftBrowCenter = centerOf(leftEyebrowPts)
        let rightBrowCenter = centerOf(rightEyebrowPts)
        let midBrowY = (leftBrowCenter.y > 0 && rightBrowCenter.y > 0)
            ? (leftBrowCenter.y + rightBrowCenter.y) * 0.5
            : (screenBox.minY + screenBox.height * 0.28)
        res.foreheadCenter = CGPoint(
            x: screenBox.midX,
            y: max(0.0, screenBox.minY + (midBrowY - screenBox.minY) * 0.45)
        )

        // Nose Bridge & Tip
        if !noseCrestPts.isEmpty {
            res.noseBridge = noseCrestPts.min(by: { $0.y < $1.y }) ?? CGPoint(x: screenBox.midX, y: midBrowY)
            res.noseTip = noseCrestPts.max(by: { $0.y < $1.y }) ?? centerOf(nosePts)
        } else {
            res.noseBridge = CGPoint(x: screenBox.midX, y: screenBox.minY + screenBox.height * 0.38)
            res.noseTip = CGPoint(x: screenBox.midX, y: screenBox.minY + screenBox.height * 0.55)
        }

        // Alar (Nostril wings)
        if !nosePts.isEmpty {
            res.leftAlar = nosePts.min(by: { $0.x < $1.x }) ?? res.noseTip
            res.rightAlar = nosePts.max(by: { $0.x < $1.x }) ?? res.noseTip
        } else {
            res.leftAlar = CGPoint(x: res.noseTip.x - screenBox.width * 0.10, y: res.noseTip.y)
            res.rightAlar = CGPoint(x: res.noseTip.x + screenBox.width * 0.10, y: res.noseTip.y)
        }

        // Mouth & Corners
        res.mouthCenter = centerOf(outerLipPts)
        if res.mouthCenter == .zero {
            res.mouthCenter = CGPoint(x: screenBox.midX, y: screenBox.minY + screenBox.height * 0.72)
        }
        if !outerLipPts.isEmpty {
            res.leftMouthCorner = outerLipPts.min(by: { $0.x < $1.x }) ?? CGPoint(x: res.mouthCenter.x - screenBox.width * 0.15, y: res.mouthCenter.y)
            res.rightMouthCorner = outerLipPts.max(by: { $0.x < $1.x }) ?? CGPoint(x: res.mouthCenter.x + screenBox.width * 0.15, y: res.mouthCenter.y)
        } else {
            res.leftMouthCorner = CGPoint(x: res.mouthCenter.x - screenBox.width * 0.15, y: res.mouthCenter.y)
            res.rightMouthCorner = CGPoint(x: res.mouthCenter.x + screenBox.width * 0.15, y: res.mouthCenter.y)
        }

        // Chin & Jaw Anchors from faceContour
        if !faceContour.isEmpty {
            // Chin tip is the lowest point (largest y in top-left coordinates)
            res.chinTip = faceContour.max(by: { $0.y < $1.y }) ?? CGPoint(x: screenBox.midX, y: screenBox.maxY)

            // Temples are the top endpoints of faceContour
            res.leftTemple = faceContour.first ?? CGPoint(x: screenBox.minX, y: screenBox.minY + screenBox.height * 0.25)
            res.rightTemple = faceContour.last ?? CGPoint(x: screenBox.maxX, y: screenBox.minY + screenBox.height * 0.25)

            // Sample jaw mid & lower points
            let count = faceContour.count
            if count >= 10 {
                res.leftMidJaw = faceContour[count / 6]
                res.leftLowerJaw = faceContour[count / 3]
                res.rightLowerJaw = faceContour[count * 2 / 3]
                res.rightMidJaw = faceContour[count * 5 / 6]
            } else {
                res.leftMidJaw = CGPoint(x: screenBox.minX + screenBox.width * 0.1, y: screenBox.minY + screenBox.height * 0.6)
                res.rightMidJaw = CGPoint(x: screenBox.maxX - screenBox.width * 0.1, y: screenBox.minY + screenBox.height * 0.6)
                res.leftLowerJaw = CGPoint(x: screenBox.minX + screenBox.width * 0.2, y: screenBox.minY + screenBox.height * 0.8)
                res.rightLowerJaw = CGPoint(x: screenBox.maxX - screenBox.width * 0.2, y: screenBox.minY + screenBox.height * 0.8)
            }
        } else {
            res.chinTip = CGPoint(x: screenBox.midX, y: screenBox.maxY)
            res.leftTemple = CGPoint(x: screenBox.minX, y: screenBox.minY + screenBox.height * 0.25)
            res.rightTemple = CGPoint(x: screenBox.maxX, y: screenBox.minY + screenBox.height * 0.25)
            res.leftMidJaw = CGPoint(x: screenBox.minX + screenBox.width * 0.1, y: screenBox.minY + screenBox.height * 0.6)
            res.rightMidJaw = CGPoint(x: screenBox.maxX - screenBox.width * 0.1, y: screenBox.minY + screenBox.height * 0.6)
            res.leftLowerJaw = CGPoint(x: screenBox.minX + screenBox.width * 0.2, y: screenBox.minY + screenBox.height * 0.8)
            res.rightLowerJaw = CGPoint(x: screenBox.maxX - screenBox.width * 0.2, y: screenBox.minY + screenBox.height * 0.8)
        }

        // Cheeks
        res.leftCheekCenter = CGPoint(
            x: res.leftEyeCenter.x * 0.7 + res.leftMidJaw.x * 0.3,
            y: (res.leftEyeCenter.y + res.noseTip.y) * 0.5
        )
        res.rightCheekCenter = CGPoint(
            x: res.rightEyeCenter.x * 0.7 + res.rightMidJaw.x * 0.3,
            y: (res.rightEyeCenter.y + res.noseTip.y) * 0.5
        )
        res.leftCheekApple = CGPoint(
            x: res.leftEyeCenter.x,
            y: res.leftEyeCenter.y + screenBox.height * 0.12
        )
        res.rightCheekApple = CGPoint(
            x: res.rightEyeCenter.x,
            y: res.rightEyeCenter.y + screenBox.height * 0.12
        )

        // Synthesize canonical 468 landmarks for full Metal shader / geometry compatibility
        let uvs = FaceMeshGeometry.canonicalUVs
        var synth468 = [SIMD3<Float>]()
        synth468.reserveCapacity(uvs.count)

        for uv in uvs {
            let px = Float(screenBox.origin.x + CGFloat(uv.x) * screenBox.width)
            let py = Float(screenBox.origin.y + CGFloat(uv.y) * screenBox.height)
            synth468.append(SIMD3<Float>(px, py, 0.0))
        }

        // Map exact anchors into synthetic 468 mesh
        func setAnchor(_ idx: Int, _ pt: CGPoint) {
            guard idx < synth468.count else { return }
            synth468[idx] = SIMD3<Float>(Float(pt.x), Float(pt.y), 0.0)
        }

        setAnchor(FaceMeshGeometry.noseTipIndex, res.noseTip)
        setAnchor(FaceMeshGeometry.noseBridgeIndex, res.noseBridge)
        setAnchor(FaceMeshGeometry.chinTipIndex, res.chinTip)
        setAnchor(FaceMeshGeometry.mouthUpperCenterIndex, CGPoint(x: res.mouthCenter.x, y: res.mouthCenter.y - screenBox.height * 0.02))
        setAnchor(FaceMeshGeometry.mouthLowerCenterIndex, CGPoint(x: res.mouthCenter.x, y: res.mouthCenter.y + screenBox.height * 0.02))
        setAnchor(FaceMeshGeometry.leftMouthCornerIndex, res.leftMouthCorner)
        setAnchor(FaceMeshGeometry.rightMouthCornerIndex, res.rightMouthCorner)
        setAnchor(FaceMeshGeometry.leftAlarIndex, res.leftAlar)
        setAnchor(FaceMeshGeometry.rightAlarIndex, res.rightAlar)
        setAnchor(FaceMeshGeometry.foreheadCenterIndex, res.foreheadCenter)
        setAnchor(FaceMeshGeometry.leftCheekApexIndex, res.leftCheekCenter)
        setAnchor(FaceMeshGeometry.rightCheekApexIndex, res.rightCheekCenter)
        setAnchor(50, res.leftCheekApple)
        setAnchor(280, res.rightCheekApple)
        setAnchor(127, res.leftTemple)
        setAnchor(356, res.rightTemple)
        setAnchor(33, res.leftEyeOuter)
        setAnchor(263, res.rightEyeOuter)

        // Align contours into synthetic 468 mesh
        func mapContour(points: [CGPoint], to indices: [Int]) {
            guard !points.isEmpty, !indices.isEmpty else { return }
            for (i, idx) in indices.enumerated() {
                let t = Double(i) / Double(indices.count)
                let ptIndex = min(points.count - 1, Int(t * Double(points.count)))
                setAnchor(idx, points[ptIndex])
            }
        }

        mapContour(points: outerLipPts, to: FaceMeshGeometry.outerLipContour)
        mapContour(points: innerLipPts, to: FaceMeshGeometry.innerLipContour)
        mapContour(points: leftEyePts, to: FaceMeshGeometry.leftEyeLoop)
        mapContour(points: rightEyePts, to: FaceMeshGeometry.rightEyeLoop)
        mapContour(points: leftEyebrowPts, to: FaceMeshGeometry.leftEyebrowIndices)
        mapContour(points: rightEyebrowPts, to: FaceMeshGeometry.rightEyebrowIndices)
        mapContour(points: faceContour, to: FaceMeshGeometry.silhouetteIndices)

        res.landmarks = synth468

        // Temporal smoothing
        lock.lock()
        defer { lock.unlock() }

        if previousLandmarks.hasFace {
            let d = Float(damping)
            let oneMinusD = 1.0 - d

            func smoothPt(_ prev: CGPoint, _ cur: CGPoint) -> CGPoint {
                return CGPoint(
                    x: prev.x * CGFloat(d) + cur.x * CGFloat(oneMinusD),
                    y: prev.y * CGFloat(d) + cur.y * CGFloat(oneMinusD)
                )
            }

            res.boundingBox = CGRect(
                x: previousLandmarks.boundingBox.origin.x * CGFloat(d) + res.boundingBox.origin.x * CGFloat(oneMinusD),
                y: previousLandmarks.boundingBox.origin.y * CGFloat(d) + res.boundingBox.origin.y * CGFloat(oneMinusD),
                width: previousLandmarks.boundingBox.width * CGFloat(d) + res.boundingBox.width * CGFloat(oneMinusD),
                height: previousLandmarks.boundingBox.height * CGFloat(d) + res.boundingBox.height * CGFloat(oneMinusD)
            )

            res.leftEyeCenter = smoothPt(previousLandmarks.leftEyeCenter, res.leftEyeCenter)
            res.rightEyeCenter = smoothPt(previousLandmarks.rightEyeCenter, res.rightEyeCenter)
            res.mouthCenter = smoothPt(previousLandmarks.mouthCenter, res.mouthCenter)
            res.chinTip = smoothPt(previousLandmarks.chinTip, res.chinTip)
            res.noseTip = smoothPt(previousLandmarks.noseTip, res.noseTip)
            res.noseBridge = smoothPt(previousLandmarks.noseBridge, res.noseBridge)
            res.leftCheekCenter = smoothPt(previousLandmarks.leftCheekCenter, res.leftCheekCenter)
            res.rightCheekCenter = smoothPt(previousLandmarks.rightCheekCenter, res.rightCheekCenter)
            res.leftMidJaw = smoothPt(previousLandmarks.leftMidJaw, res.leftMidJaw)
            res.rightMidJaw = smoothPt(previousLandmarks.rightMidJaw, res.rightMidJaw)
            res.leftLowerJaw = smoothPt(previousLandmarks.leftLowerJaw, res.leftLowerJaw)
            res.rightLowerJaw = smoothPt(previousLandmarks.rightLowerJaw, res.rightLowerJaw)
            res.leftAlar = smoothPt(previousLandmarks.leftAlar, res.leftAlar)
            res.rightAlar = smoothPt(previousLandmarks.rightAlar, res.rightAlar)
            res.leftMouthCorner = smoothPt(previousLandmarks.leftMouthCorner, res.leftMouthCorner)
            res.rightMouthCorner = smoothPt(previousLandmarks.rightMouthCorner, res.rightMouthCorner)
            res.foreheadCenter = smoothPt(previousLandmarks.foreheadCenter, res.foreheadCenter)
            res.leftTemple = smoothPt(previousLandmarks.leftTemple, res.leftTemple)
            res.rightTemple = smoothPt(previousLandmarks.rightTemple, res.rightTemple)
            res.leftEyeOuter = smoothPt(previousLandmarks.leftEyeOuter, res.leftEyeOuter)
            res.rightEyeOuter = smoothPt(previousLandmarks.rightEyeOuter, res.rightEyeOuter)
            res.leftCheekApple = smoothPt(previousLandmarks.leftCheekApple, res.leftCheekApple)
            res.rightCheekApple = smoothPt(previousLandmarks.rightCheekApple, res.rightCheekApple)

            if res.landmarks.count == previousLandmarks.landmarks.count {
                for i in 0..<res.landmarks.count {
                    let prev = previousLandmarks.landmarks[i]
                    let cur = res.landmarks[i]
                    res.landmarks[i] = SIMD3<Float>(
                        prev.x * d + cur.x * oneMinusD,
                        prev.y * d + cur.y * oneMinusD,
                        0.0
                    )
                }
            }
        }

        previousLandmarks = res
    }
}
