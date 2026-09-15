import Foundation
import Metal
import simd

public final class FaceMeshRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private var skinMaskPipeline: MTLRenderPipelineState?
    private var reshapePipeline: MTLRenderPipelineState?
    private var makeupPipeline: MTLRenderPipelineState?
    private var samplerState: MTLSamplerState?

    // Geometry Buffers
    private var indexBuffer: MTLBuffer?
    private var lipIndexBuffer: MTLBuffer?
    private var cheekIndexBuffer: MTLBuffer?
    private var skinWeightsBuffer: MTLBuffer?
    private var featureTypesBuffer: MTLBuffer?
    private var reshapeWeightsBuffer: MTLBuffer?
    private var canonicalUVBuffer: MTLBuffer?
    private var positionBuffer: MTLBuffer?

    // Offscreen Mask Texture
    private var maskTexture: MTLTexture?
    private var maskWidth: Int = 0
    private var maskHeight: Int = 0

    public init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue

        setupPipelines()
        setupBuffers()
    }

    private func setupPipelines() {
        let metalSource = FaceMeshShaders.source

        guard !metalSource.isEmpty, let library = try? device.makeLibrary(source: metalSource, options: nil) else {
            NSLog("[FaceMeshRenderer] Failed to compile Metal library from source")
            return
        }

        // 1. Skin Mask Pipeline (Writes to single or 4-channel BGRA texture)
        let maskDesc = MTLRenderPipelineDescriptor()
        maskDesc.vertexFunction = library.makeFunction(name: "faceSkinMaskVertex")
        maskDesc.fragmentFunction = library.makeFunction(name: "faceSkinMaskFragment")
        maskDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.skinMaskPipeline = try? device.makeRenderPipelineState(descriptor: maskDesc)

        // 2. Face Reshaping Pipeline
        let reshapeDesc = MTLRenderPipelineDescriptor()
        reshapeDesc.vertexFunction = library.makeFunction(name: "faceReshapeVertex")
        reshapeDesc.fragmentFunction = library.makeFunction(name: "faceReshapeFragment")
        reshapeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        reshapeDesc.colorAttachments[0].isBlendingEnabled = true
        reshapeDesc.colorAttachments[0].rgbBlendOperation = .add
        reshapeDesc.colorAttachments[0].alphaBlendOperation = .add
        reshapeDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        reshapeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.reshapePipeline = try? device.makeRenderPipelineState(descriptor: reshapeDesc)

        // 3. Makeup Pipeline
        let makeupDesc = MTLRenderPipelineDescriptor()
        makeupDesc.vertexFunction = library.makeFunction(name: "faceMakeupVertex")
        makeupDesc.fragmentFunction = library.makeFunction(name: "faceMakeupFragment")
        makeupDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        makeupDesc.colorAttachments[0].isBlendingEnabled = true
        makeupDesc.colorAttachments[0].rgbBlendOperation = .add
        makeupDesc.colorAttachments[0].alphaBlendOperation = .add
        makeupDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        makeupDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.makeupPipeline = try? device.makeRenderPipelineState(descriptor: makeupDesc)

        // Linear Sampler
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        self.samplerState = device.makeSamplerState(descriptor: samplerDesc)
    }

    private func setupBuffers() {
        // 1. Index Buffers
        let triCount = FaceMeshGeometry.triangles.count
        self.indexBuffer = device.makeBuffer(
            bytes: FaceMeshGeometry.triangles,
            length: triCount * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        )

        let lipTriCount = FaceMeshGeometry.lipTriangles.count
        self.lipIndexBuffer = device.makeBuffer(
            bytes: FaceMeshGeometry.lipTriangles,
            length: lipTriCount * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        )

        var combinedCheekTriangles = FaceMeshGeometry.leftCheekTriangles
        combinedCheekTriangles.append(contentsOf: FaceMeshGeometry.rightCheekTriangles)
        self.cheekIndexBuffer = device.makeBuffer(
            bytes: combinedCheekTriangles,
            length: combinedCheekTriangles.count * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        )

        // 2. Skin Weights (Full face coverage with soft boundary falloff)
        var weights = FaceMeshGeometry.skinWeights
        for idx in FaceMeshGeometry.silhouetteIndices { weights[idx] = 0.85 }
        for idx in FaceMeshGeometry.eyeIndices { weights[idx] = 0.0 }
        for idx in FaceMeshGeometry.lipIndices { weights[idx] = 0.0 }
        for idx in FaceMeshGeometry.eyebrowIndices { weights[idx] = 0.0 }
        for idx in FaceMeshGeometry.nostrilIndices { weights[idx] = 0.0 }

        self.skinWeightsBuffer = device.makeBuffer(
            bytes: weights,
            length: weights.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )

        // 3. Feature Types & Reshape Weights
        var fTypes = [UInt32](repeating: 0, count: 468)
        var rWeights = [Float](repeating: 1.0, count: 468)

        // Outer silhouette boundary pinned to 0.0 displacement
        for idx in FaceMeshGeometry.silhouetteIndices {
            rWeights[idx] = 0.0
        }

        // Cheeks and Jaw (type 1)
        let cheekJaw = [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323, 454, 234, 116, 117, 118, 101, 205, 207, 214, 187, 123, 50, 203, 345, 346, 347, 330, 425, 427, 434, 411, 352, 280, 423]
        for idx in cheekJaw { fTypes[idx] = 1 }

        // Chin (type 2)
        let chin = [152, 377, 400, 148, 176, 149, 150, 378, 379, 175, 199, 200, 18]
        for idx in chin { fTypes[idx] = 2 }

        // Left Eye (type 3)
        let leftEye = [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
        for idx in leftEye { fTypes[idx] = 3 }

        // Right Eye (type 4)
        let rightEye = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
        for idx in rightEye { fTypes[idx] = 4 }

        // Nose (type 5)
        let nose = [2, 98, 327, 49, 279, 48, 278, 115, 344, 220, 440, 1, 4]
        for idx in nose { fTypes[idx] = 5 }

        // Mouth Corners (type 6)
        fTypes[FaceMeshGeometry.leftMouthCornerIndex] = 6
        fTypes[FaceMeshGeometry.rightMouthCornerIndex] = 6

        self.featureTypesBuffer = device.makeBuffer(
            bytes: fTypes,
            length: fTypes.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )

        self.reshapeWeightsBuffer = device.makeBuffer(
            bytes: rWeights,
            length: rWeights.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )

        self.canonicalUVBuffer = device.makeBuffer(
            bytes: FaceMeshGeometry.canonicalUVs,
            length: FaceMeshGeometry.canonicalUVs.count * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        )

        // Dynamic position buffer (468 points)
        self.positionBuffer = device.makeBuffer(
            length: 468 * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        )
    }

    private func ensureMaskTexture(width: Int, height: Int) -> MTLTexture? {
        if maskTexture == nil || maskWidth != width || maskHeight != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            desc.usage = [.renderTarget, .shaderRead]
            desc.storageMode = .private
            self.maskTexture = device.makeTexture(descriptor: desc)
            self.maskWidth = width
            self.maskHeight = height
        }
        return maskTexture
    }

    // MARK: - Render Passes

    public func renderSkinMask(landmarks: FaceMeshLandmarks, width: Int, height: Int) -> MTLTexture? {
        guard landmarks.hasFace, landmarks.landmarks.count == 468 else { return nil }
        guard let pipeline = skinMaskPipeline, let posBuf = positionBuffer, let idxBuf = indexBuffer, let weightsBuf = skinWeightsBuffer else { return nil }
        guard let targetTexture = ensureMaskTexture(width: width, height: height) else { return nil }

        // Update positions buffer
        let posPtr = posBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: 468)
        for i in 0..<468 {
            posPtr[i] = SIMD2<Float>(landmarks.landmarks[i].x, landmarks.landmarks[i].y)
        }

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return nil }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = targetTexture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return nil }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(posBuf, offset: 0, index: 0)
        encoder.setVertexBuffer(weightsBuf, offset: 0, index: 1)

        let indexCount = FaceMeshGeometry.triangles.count
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: idxBuf,
            indexBufferOffset: 0
        )
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        return targetTexture
    }

    public func renderReshape(
        inputTexture: MTLTexture,
        targetTexture: MTLTexture,
        faceSettings: FaceSettings,
        landmarks: FaceMeshLandmarks
    ) {
        guard landmarks.hasFace, landmarks.landmarks.count == 468 else { return }
        guard let pipeline = reshapePipeline, let posBuf = positionBuffer, let idxBuf = indexBuffer,
              let uvBuf = canonicalUVBuffer, let weightsBuf = reshapeWeightsBuffer, let typesBuf = featureTypesBuffer,
              let sampler = samplerState else { return }

        // Check if reshape is needed
        let needsReshape = faceSettings.slimFace > 0.01 || faceSettings.smallFace > 0.01 ||
                           faceSettings.vFace > 0.01 || abs(faceSettings.chinLength) > 0.01 ||
                           abs(faceSettings.chinWidth) > 0.01 || faceSettings.eyeSize > 0.01 ||
                           abs(faceSettings.noseWidth) > 0.01 || faceSettings.smile > 0.01

        guard needsReshape else { return }

        // Update positions buffer
        let posPtr = posBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: 468)
        for i in 0..<468 {
            posPtr[i] = SIMD2<Float>(landmarks.landmarks[i].x, landmarks.landmarks[i].y)
        }

        struct ReshapeUniforms {
            var slimFace: Float
            var smallFace: Float
            var vFace: Float
            var chinLength: Float
            var chinWidth: Float
            var eyeSize: Float
            var noseWidth: Float
            var smile: Float
            var leftEyeCenter: SIMD2<Float>
            var rightEyeCenter: SIMD2<Float>
            var noseCenter: SIMD2<Float>
            var chinCenter: SIMD2<Float>
            var faceCenter: SIMD2<Float>
            var faceWidth: Float
            var faceHeight: Float
        }

        var uniforms = ReshapeUniforms(
            slimFace: Float(faceSettings.slimFace),
            smallFace: Float(faceSettings.smallFace),
            vFace: Float(faceSettings.vFace),
            chinLength: Float(faceSettings.chinLength),
            chinWidth: Float(faceSettings.chinWidth),
            eyeSize: Float(faceSettings.eyeSize),
            noseWidth: Float(faceSettings.noseWidth),
            smile: Float(faceSettings.smile),
            leftEyeCenter: SIMD2<Float>(Float(landmarks.leftEyeCenter.x), Float(landmarks.leftEyeCenter.y)),
            rightEyeCenter: SIMD2<Float>(Float(landmarks.rightEyeCenter.x), Float(landmarks.rightEyeCenter.y)),
            noseCenter: SIMD2<Float>(Float(landmarks.noseTip.x), Float(landmarks.noseTip.y)),
            chinCenter: SIMD2<Float>(Float(landmarks.chinTip.x), Float(landmarks.chinTip.y)),
            faceCenter: SIMD2<Float>(Float(landmarks.boundingBox.midX), Float(landmarks.boundingBox.midY)),
            faceWidth: Float(landmarks.boundingBox.width),
            faceHeight: Float(landmarks.boundingBox.height)
        )

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = targetTexture
        passDesc.colorAttachments[0].loadAction = .load
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(posBuf, offset: 0, index: 0)
        encoder.setVertexBuffer(uvBuf, offset: 0, index: 1)
        encoder.setVertexBuffer(weightsBuf, offset: 0, index: 2)
        encoder.setVertexBuffer(typesBuf, offset: 0, index: 3)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ReshapeUniforms>.stride, index: 4)

        encoder.setFragmentTexture(inputTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: FaceMeshGeometry.triangles.count,
            indexType: .uint16,
            indexBuffer: idxBuf,
            indexBufferOffset: 0
        )
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
    }

    public func renderMakeup(
        targetTexture: MTLTexture,
        makeupSettings: MakeupSettings,
        landmarks: FaceMeshLandmarks
    ) {
        guard landmarks.hasFace, landmarks.landmarks.count == 468 else { return }
        guard let pipeline = makeupPipeline, let posBuf = positionBuffer,
              let uvBuf = canonicalUVBuffer, let sampler = samplerState else { return }

        let hasLip = makeupSettings.lipPreset != "none" && makeupSettings.lipOpacity > 0.01
        let hasBlush = makeupSettings.blushPreset != "none" && makeupSettings.blushOpacity > 0.01
        guard hasLip || hasBlush else { return }

        // Update positions buffer
        let posPtr = posBuf.contents().bindMemory(to: SIMD2<Float>.self, capacity: 468)
        for i in 0..<468 {
            posPtr[i] = SIMD2<Float>(landmarks.landmarks[i].x, landmarks.landmarks[i].y)
        }

        struct MakeupUniforms {
            var lipColor: SIMD4<Float>
            var blushColor: SIMD4<Float>
            var makeupMode: UInt32
            var leftCheekCenter: SIMD2<Float>
            var rightCheekCenter: SIMD2<Float>
            var cheekRadius: Float
        }

        // Determine Lip Color
        var lipR: Float = 0.88; var lipG: Float = 0.32; var lipB: Float = 0.42
        switch makeupSettings.lipPreset {
        case "nude":   lipR = 0.82; lipG = 0.50; lipB = 0.45
        case "coral":  lipR = 0.95; lipG = 0.42; lipB = 0.35
        case "red":    lipR = 0.90; lipG = 0.15; lipB = 0.20
        case "berry":  lipR = 0.72; lipG = 0.18; lipB = 0.38
        case "pink":   lipR = 0.95; lipG = 0.45; lipB = 0.60
        case "brown":  lipR = 0.65; lipG = 0.35; lipB = 0.30
        default: break
        }

        // Determine Blush Color
        var bR: Float = 0.98; var bG: Float = 0.35; var bB: Float = 0.45
        if makeupSettings.blushPreset == "coral" {
            bR = 0.98; bG = 0.45; bB = 0.35
        } else if makeupSettings.blushPreset == "peach" {
            bR = 0.98; bG = 0.50; bB = 0.40
        } else if makeupSettings.blushPreset == "orange" {
            bR = 0.98; bG = 0.40; bB = 0.25
        }

        let cheekRad = Float(landmarks.boundingBox.width * 0.18)

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = targetTexture
        passDesc.colorAttachments[0].loadAction = .load
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(posBuf, offset: 0, index: 0)
        encoder.setVertexBuffer(uvBuf, offset: 0, index: 1)
        encoder.setFragmentTexture(targetTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)

        // Draw Lips
        if hasLip, let lipIdxBuf = lipIndexBuffer {
            var lipUniforms = MakeupUniforms(
                lipColor: SIMD4<Float>(lipR, lipG, lipB, Float(makeupSettings.lipOpacity)),
                blushColor: SIMD4<Float>(0, 0, 0, 0),
                makeupMode: 0,
                leftCheekCenter: .zero,
                rightCheekCenter: .zero,
                cheekRadius: 0.0
            )
            encoder.setFragmentBytes(&lipUniforms, length: MemoryLayout<MakeupUniforms>.stride, index: 0)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: FaceMeshGeometry.lipTriangles.count,
                indexType: .uint16,
                indexBuffer: lipIdxBuf,
                indexBufferOffset: 0
            )
        }

        // Draw Blush
        if hasBlush, let cheekIdxBuf = cheekIndexBuffer {
            var blushUniforms = MakeupUniforms(
                lipColor: SIMD4<Float>(0, 0, 0, 0),
                blushColor: SIMD4<Float>(bR, bG, bB, Float(makeupSettings.blushOpacity)),
                makeupMode: 1,
                leftCheekCenter: SIMD2<Float>(Float(landmarks.leftCheekCenter.x), Float(landmarks.leftCheekCenter.y)),
                rightCheekCenter: SIMD2<Float>(Float(landmarks.rightCheekCenter.x), Float(landmarks.rightCheekCenter.y)),
                cheekRadius: cheekRad
            )
            encoder.setFragmentBytes(&blushUniforms, length: MemoryLayout<MakeupUniforms>.stride, index: 0)
            let totalCheekIndices = FaceMeshGeometry.leftCheekTriangles.count + FaceMeshGeometry.rightCheekTriangles.count
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: totalCheekIndices,
                indexType: .uint16,
                indexBuffer: cheekIdxBuf,
                indexBufferOffset: 0
            )
        }

        encoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
    }
}
