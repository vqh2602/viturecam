import CoreVideo
import Foundation
import Vision

public struct SmoothedFaceLandmarks {
    public var hasFace: Bool = false
    public var boundingBox: CGRect = .zero
    public var faceContour: [CGPoint] = []
    public var leftEye: [CGPoint] = []
    public var rightEye: [CGPoint] = []
    public var leftEyeCenter: CGPoint = .zero
    public var rightEyeCenter: CGPoint = .zero
    public var leftEyebrow: [CGPoint] = []
    public var rightEyebrow: [CGPoint] = []
    public var noseCrest: [CGPoint] = []
    public var nose: [CGPoint] = []
    public var outerLips: [CGPoint] = []
    public var innerLips: [CGPoint] = []
    public var chinPoint: CGPoint = .zero
    public var mouthCenter: CGPoint = .zero
}

public final class FaceTracker {
    public var damping: CGFloat = 0.75 // 0.0 = raw, 1.0 = heavy smooth

    private let trackingQueue = DispatchQueue(label: "com.beautycamera.facetracking", qos: .userInteractive)
    private var isProcessing: Bool = false
    private var previousLandmarks = SmoothedFaceLandmarks()
    private let lock = NSLock()

    public init() {}

    public var currentLandmarks: SmoothedFaceLandmarks {
        lock.lock()
        defer { lock.unlock() }
        return previousLandmarks
    }

    public func processFrameAsync(pixelBuffer: CVPixelBuffer) {
        if isProcessing {
            // Drop tracking frame to maintain real-time 60fps throughput
            return
        }

        isProcessing = true
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let request = VNDetectFaceLandmarksRequest { [weak self] (req, err) in
                guard let self = self, err == nil else { return }
                guard let results = req.results as? [VNFaceObservation], let face = results.first, let landmarks = face.landmarks else {
                    self.updateNoFace()
                    return
                }
                self.updateLandmarks(face: face, landmarks: landmarks)
            }

            // High performance Vision request options
            request.preferBackgroundProcessing = false
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }

    private func updateNoFace() {
        lock.lock()
        defer { lock.unlock() }
        // Gradual fade rather than instant snap
        previousLandmarks.hasFace = false
    }

    private func updateLandmarks(face: VNFaceObservation, landmarks: VNFaceLandmarks2D) {
        lock.lock()
        defer { lock.unlock() }

        let box = face.boundingBox

        func convertPoints(_ points: [CGPoint]?) -> [CGPoint] {
            guard let points = points else { return [] }
            return points.map { pt in
                // Vision coordinates are normalized (0,0 bottom-left to 1,1 top-right)
                // Convert to image normalized space (0,0 top-left to 1,1 bottom-right)
                let x = box.origin.x + pt.x * box.size.width
                let y = 1.0 - (box.origin.y + pt.y * box.size.height)
                return CGPoint(x: x, y: y)
            }
        }

        func smoothPoints(prev: [CGPoint], next: [CGPoint]) -> [CGPoint] {
            if prev.count != next.count || prev.isEmpty {
                return next
            }
            return zip(prev, next).map { (p, n) in
                CGPoint(
                    x: p.x * damping + n.x * (1.0 - damping),
                    y: p.y * damping + n.y * (1.0 - damping)
                )
            }
        }

        func smoothPoint(prev: CGPoint, next: CGPoint) -> CGPoint {
            if prev == .zero { return next }
            return CGPoint(
                x: prev.x * damping + next.x * (1.0 - damping),
                y: prev.y * damping + next.y * (1.0 - damping)
            )
        }

        func calculateCenter(_ pts: [CGPoint]) -> CGPoint {
            guard !pts.isEmpty else { return .zero }
            let sum = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(pts.count), y: sum.y / CGFloat(pts.count))
        }

        let newContour = convertPoints(landmarks.faceContour?.normalizedPoints)
        let newLeftEye = convertPoints(landmarks.leftEye?.normalizedPoints)
        let newRightEye = convertPoints(landmarks.rightEye?.normalizedPoints)
        let newLeftEyebrow = convertPoints(landmarks.leftEyebrow?.normalizedPoints)
        let newRightEyebrow = convertPoints(landmarks.rightEyebrow?.normalizedPoints)
        let newNose = convertPoints(landmarks.nose?.normalizedPoints)
        let newNoseCrest = convertPoints(landmarks.noseCrest?.normalizedPoints)
        let newOuterLips = convertPoints(landmarks.outerLips?.normalizedPoints)
        let newInnerLips = convertPoints(landmarks.innerLips?.normalizedPoints)

        var result = SmoothedFaceLandmarks()
        result.hasFace = true
        result.boundingBox = CGRect(
            x: box.origin.x,
            y: 1.0 - box.origin.y - box.size.height,
            width: box.size.width,
            height: box.size.height
        )

        if previousLandmarks.hasFace {
            result.faceContour = smoothPoints(prev: previousLandmarks.faceContour, next: newContour)
            result.leftEye = smoothPoints(prev: previousLandmarks.leftEye, next: newLeftEye)
            result.rightEye = smoothPoints(prev: previousLandmarks.rightEye, next: newRightEye)
            result.leftEyebrow = smoothPoints(prev: previousLandmarks.leftEyebrow, next: newLeftEyebrow)
            result.rightEyebrow = smoothPoints(prev: previousLandmarks.rightEyebrow, next: newRightEyebrow)
            result.nose = smoothPoints(prev: previousLandmarks.nose, next: newNose)
            result.noseCrest = smoothPoints(prev: previousLandmarks.noseCrest, next: newNoseCrest)
            result.outerLips = smoothPoints(prev: previousLandmarks.outerLips, next: newOuterLips)
            result.innerLips = smoothPoints(prev: previousLandmarks.innerLips, next: newInnerLips)
        } else {
            result.faceContour = newContour
            result.leftEye = newLeftEye
            result.rightEye = newRightEye
            result.leftEyebrow = newLeftEyebrow
            result.rightEyebrow = newRightEyebrow
            result.nose = newNose
            result.noseCrest = newNoseCrest
            result.outerLips = newOuterLips
            result.innerLips = newInnerLips
        }

        result.leftEyeCenter = calculateCenter(result.leftEye)
        result.rightEyeCenter = calculateCenter(result.rightEye)
        result.mouthCenter = calculateCenter(result.outerLips)
        if let chin = result.faceContour.indices.contains(result.faceContour.count / 2) ? result.faceContour[result.faceContour.count / 2] : nil {
            result.chinPoint = chin
        }

        previousLandmarks = result
    }
}
