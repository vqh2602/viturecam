import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation
import Metal

public final class BeautyRenderer {
    private let mtlDevice: MTLDevice
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace
    public let faceMeshRenderer: FaceMeshRenderer
    private var reshapeKernel: CIWarpKernel?
    private var skinSmoothKernel: CIKernel?

    public init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac")
        }
        self.mtlDevice = device
        self.ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false
        ])
        self.colorSpace = CGColorSpaceCreateDeviceRGB()
        self.faceMeshRenderer = FaceMeshRenderer(device: device)

        setupReshapeKernel()
        setupSkinSmoothKernel()
    }

    private func setupReshapeKernel() {
        let kernelString = """
        kernel vec2 faceReshapeWarp(
            vec2 leftEyeCenter,
            vec2 rightEyeCenter,
            float eyeRadius,
            float eyeFactor,
            vec2 leftCheek,
            vec2 rightCheek,
            float cheekRadius,
            float cheekFactor,
            vec2 chinCenter,
            float chinRadius,
            float chinDy,
            float chinDx,
            vec2 noseCenter,
            float noseRadius,
            float noseFactor,
            vec2 leftMouth,
            vec2 rightMouth,
            float mouthRadius,
            float smileFactor
        ) {
            vec2 p = destCoord();
            vec2 offset = vec2(0.0, 0.0);

            // 1. Left Eye Magnification
            if (eyeFactor > 0.001) {
                vec2 d = p - leftEyeCenter;
                float dist = length(d);
                if (dist < eyeRadius) {
                    float t = dist / eyeRadius;
                    float weight = (1.0 - t * t);
                    offset -= d * (eyeFactor * 0.26 * weight * weight);
                }
            }

            // 2. Right Eye Magnification
            if (eyeFactor > 0.001) {
                vec2 d = p - rightEyeCenter;
                float dist = length(d);
                if (dist < eyeRadius) {
                    float t = dist / eyeRadius;
                    float weight = (1.0 - t * t);
                    offset -= d * (eyeFactor * 0.26 * weight * weight);
                }
            }

            // 3. Cheeks Slimming (V-Face, Slim Face, Cheek, Jaw)
            if (abs(cheekFactor) > 0.001) {
                vec2 dL = p - leftCheek;
                float distL = length(dL);
                if (distL < cheekRadius) {
                    float t = distL / cheekRadius;
                    float weight = (1.0 - t * t);
                    offset.x -= cheekFactor * 0.22 * weight * weight * cheekRadius;
                }

                vec2 dR = p - rightCheek;
                float distR = length(dR);
                if (distR < cheekRadius) {
                    float t = distR / cheekRadius;
                    float weight = (1.0 - t * t);
                    offset.x += cheekFactor * 0.22 * weight * weight * cheekRadius;
                }
            }

            // 4. Chin Length and Width
            if (abs(chinDy) > 0.001 || abs(chinDx) > 0.001) {
                vec2 d = p - chinCenter;
                float dist = length(d);
                if (dist < chinRadius) {
                    float t = dist / chinRadius;
                    float weight = (1.0 - t * t);
                    offset.y += chinDy * 0.24 * weight * weight * chinRadius;
                    offset.x += (p.x - chinCenter.x) * chinDx * 0.20 * weight;
                }
            }

            // 5. Nose Slimming
            if (abs(noseFactor) > 0.001) {
                vec2 d = p - noseCenter;
                float dist = length(d);
                if (dist < noseRadius) {
                    float t = dist / noseRadius;
                    float weight = (1.0 - t * t);
                    float dir = (p.x < noseCenter.x) ? -1.0 : 1.0;
                    offset.x += dir * noseFactor * 0.16 * weight * weight * noseRadius;
                }
            }

            // 6. Smile (Mouth corner lifting)
            if (smileFactor > 0.001) {
                vec2 dL = p - leftMouth;
                if (length(dL) < mouthRadius) {
                    float t = length(dL) / mouthRadius;
                    float weight = (1.0 - t * t);
                    offset.y -= smileFactor * 0.15 * weight * weight * mouthRadius;
                }
                vec2 dR = p - rightMouth;
                if (length(dR) < mouthRadius) {
                    float t = length(dR) / mouthRadius;
                    float weight = (1.0 - t * t);
                    offset.y -= smileFactor * 0.15 * weight * weight * mouthRadius;
                }
            }

            return p + offset;
        }
        """
        self.reshapeKernel = CIWarpKernel(source: kernelString)
    }

    private func setupSkinSmoothKernel() {
        let kernelString = """
        kernel vec4 naturalBeautySmooth(
            sampler originalImage,
            sampler blurredGuide,
            float smoothFactor,
            float textureFactor,
            float skinThreshold
        ) {
            vec2 pos = samplerCoord(originalImage);
            vec4 center = sample(originalImage, pos);
            vec3 centerRGB = center.rgb;

            vec3 accumColor = centerRGB;
            float totalWeight = 1.0;

            vec2 d1 = vec2( 0.0,  3.0);
            vec2 d2 = vec2( 3.0,  1.5);
            vec2 d3 = vec2( 2.5, -2.5);
            vec2 d4 = vec2(-1.5, -3.0);
            vec2 d5 = vec2(-3.0,  0.0);
            vec2 d6 = vec2(-2.0,  2.5);

            vec2 d7 = vec2( 0.0,  6.0);
            vec2 d8 = vec2( 5.5,  2.8);
            vec2 d9 = vec2( 4.5, -4.5);
            vec2 d10 = vec2(-3.0, -5.5);
            vec2 d11 = vec2(-5.5,  0.0);
            vec2 d12 = vec2(-4.0,  4.5);

            vec3 col; vec3 diff; float distSq; float w;

            col = sample(originalImage, pos + d1).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d2).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d3).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d4).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d5).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d6).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d7).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d8).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d9).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d10).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d11).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d12).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold); accumColor += col * w; totalWeight += w;

            vec3 smoothed = accumColor / totalWeight;

            // Deep blemishes smoothed via guide
            vec3 guide = sample(blurredGuide, samplerTransform(blurredGuide, pos)).rgb;
            vec3 baseSmooth = mix(smoothed, guide, smoothFactor * 0.40);
            
            // Edge-preserving contrast guard
            vec3 edgeDiff = centerRGB - baseSmooth;
            float edgeMag = dot(edgeDiff, edgeDiff);
            float edgePreserve = exp(-edgeMag * 22.0);
            vec3 finalSmooth = mix(centerRGB, baseSmooth, edgePreserve);

            // Frequency-separated pore texture preservation
            vec3 detail = centerRGB - finalSmooth;
            vec3 microPore = clamp(detail, vec3(-0.04), vec3(0.04));
            vec3 texturedSkin = finalSmooth + microPore * (textureFactor * 1.5);

            vec3 resultRGB = mix(centerRGB, texturedSkin, smoothFactor);
            return vec4(resultRGB, center.a);
        }
        """
        self.skinSmoothKernel = CIKernel(source: kernelString)
    }

    public func processFrame(
        sourceBuffer: CVPixelBuffer,
        targetBuffer: CVPixelBuffer,
        beautyEnabled: Bool,
        compareMode: String, // "none", "split", "raw"
        splitRatio: Double,   // 0.0 .. 1.0
        beauty: BeautySettings,
        face: FaceSettings,
        makeup: MakeupSettings,
        filter: FilterSettings,
        color: ColorSettings,
        background: BackgroundSettings,
        landmarks: FaceMeshLandmarks
    ) {
        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)

        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)

        if !beautyEnabled || compareMode == "raw" {
            ciContext.render(sourceImage, to: targetBuffer, bounds: extent, colorSpace: nil)
            return
        }

        var processedImage = sourceImage

        // 1. 3D Face Reshaping (Smooth GPU Warp using 468 landmark anchors - zero polygon overlays)
        let hasReshape = face.slimFace > 0.01 || face.smallFace > 0.01 || face.vFace > 0.01 ||
                         abs(face.jawWidth) > 0.01 || abs(face.cheekWidth) > 0.01 ||
                         abs(face.chinLength) > 0.01 || abs(face.chinWidth) > 0.01 ||
                         face.eyeSize > 0.01 || abs(face.noseWidth) > 0.01 || face.smile > 0.01

        if hasReshape && landmarks.hasFace {
            processedImage = applyFaceReshape(image: processedImage, face: face, landmarks: landmarks, extent: extent)
        }

        // 2. Skin Beautification (Natural Edge-Preserving Bilateral Smoothing, Pore Texture, Translucent Whitening)
        let hasSkinBeauty = beauty.smooth > 0.01 || beauty.whitening > 0.01 ||
                            beauty.skinBrightness > 0.01 || beauty.redness > 0.01 ||
                            beauty.darkCircle > 0.01 || beauty.eyeBag > 0.01 ||
                            beauty.teethWhitening > 0.01

        if hasSkinBeauty && landmarks.hasFace {
            processedImage = applySkinBeauty(
                image: processedImage,
                beauty: beauty,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 3. 3D Makeup (Lipstick & Blush mapped onto face mesh)
        if (makeup.lipPreset != "none" && makeup.lipOpacity > 0.01) || (makeup.blushPreset != "none" && makeup.blushOpacity > 0.01) {
            processedImage = applyMakeup(
                image: processedImage,
                makeup: makeup,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 4. Color adjustments (Real-time GPU)
        processedImage = applyColorAdjustments(image: processedImage, color: color)

        // 5. Aesthetic Filters
        if filter.filterId != "original" && filter.intensity > 0.01 {
            processedImage = applyFilter(image: processedImage, baseImage: sourceImage, filterId: filter.filterId, intensity: filter.intensity)
        }

        // 6. Background Effects (if enabled)
        if background.mode != "none" && background.blurIntensity > 0.01 {
            processedImage = applyBackgroundEffects(image: processedImage, mode: background.mode, intensity: background.blurIntensity, landmarks: landmarks, extent: extent)
        }

        // 7. Compare / Split Screen mode
        var finalImage = processedImage
        if compareMode == "split" {
            finalImage = applySplitComparison(
                rawImage: sourceImage,
                beautyImage: processedImage,
                splitRatio: max(0.0, min(1.0, splitRatio)),
                extent: extent
            )
        }

        // Clean GPU render to target CVPixelBuffer (single pass, zero feedback loop)
        ciContext.render(finalImage, to: targetBuffer, bounds: extent, colorSpace: colorSpace)
    }

    // MARK: - Face Reshaping (GPU Warp Kernel anchored on 468 landmarks)
    private func applyFaceReshape(
        image: CIImage,
        face: FaceSettings,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard let kernel = reshapeKernel else { return image }

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)

        let leftEye = CGPoint(x: landmarks.leftEyeCenter.x * width, y: (1.0 - landmarks.leftEyeCenter.y) * height)
        let rightEye = CGPoint(x: landmarks.rightEyeCenter.x * width, y: (1.0 - landmarks.rightEyeCenter.y) * height)
        let eyeRad = max(35.0, faceW * 0.20)
        let eyeFactor = CGFloat(face.eyeSize)

        let leftCheek = CGPoint(x: landmarks.leftCheekCenter.x * width, y: (1.0 - landmarks.leftCheekCenter.y) * height)
        let rightCheek = CGPoint(x: landmarks.rightCheekCenter.x * width, y: (1.0 - landmarks.rightCheekCenter.y) * height)
        let cheekRad = max(45.0, faceW * 0.28)
        let cheekFactor = CGFloat(face.slimFace * 0.50 + face.vFace * 0.60 + face.smallFace * 0.30 - face.cheekWidth * 0.35)

        let chinCenter = CGPoint(x: landmarks.chinTip.x * width, y: (1.0 - landmarks.chinTip.y) * height)
        let chinRad = max(40.0, faceW * 0.24)
        let chinDy = CGFloat(face.chinLength)
        let chinDx = CGFloat(face.chinWidth + face.jawWidth * 0.5)

        let noseCenter = CGPoint(x: landmarks.noseTip.x * width, y: (1.0 - landmarks.noseTip.y) * height)
        let noseRad = max(25.0, faceW * 0.16)
        let noseFactor = CGFloat(face.noseWidth)

        let leftMouth = CGPoint(x: (landmarks.mouthCenter.x - box.width * 0.12) * width, y: (1.0 - landmarks.mouthCenter.y) * height)
        let rightMouth = CGPoint(x: (landmarks.mouthCenter.x + box.width * 0.12) * width, y: (1.0 - landmarks.mouthCenter.y) * height)
        let mouthRad = max(28.0, faceW * 0.18)
        let smileFactor = CGFloat(face.smile)

        let args: [Any] = [
            CIVector(cgPoint: leftEye),
            CIVector(cgPoint: rightEye),
            eyeRad,
            eyeFactor,
            CIVector(cgPoint: leftCheek),
            CIVector(cgPoint: rightCheek),
            cheekRad,
            cheekFactor,
            CIVector(cgPoint: chinCenter),
            chinRad,
            chinDy,
            chinDx,
            CIVector(cgPoint: noseCenter),
            noseRad,
            noseFactor,
            CIVector(cgPoint: leftMouth),
            CIVector(cgPoint: rightMouth),
            mouthRad,
            smileFactor
        ]

        if let warped = kernel.apply(extent: extent, roiCallback: { _, rect in rect }, image: image, arguments: args) {
            return warped.cropped(to: extent)
        }

        return image
    }

    // MARK: - Color Adjustments
    private func applyColorAdjustments(image: CIImage, color: ColorSettings) -> CIImage {
        var result = image

        // Exposure
        if abs(color.exposure) > 0.001 {
            if let expFilter = CIFilter(name: "CIExposureAdjust") {
                expFilter.setValue(result, forKey: kCIInputImageKey)
                expFilter.setValue(color.exposure * 1.5, forKey: kCIInputEVKey)
                if let out = expFilter.outputImage { result = out }
            }
        }

        // Brightness, Contrast, Saturation
        if abs(color.brightness) > 0.001 || abs(color.contrast - 1.0) > 0.001 || abs(color.saturation - 1.0) > 0.001 {
            if let ccFilter = CIFilter(name: "CIColorControls") {
                ccFilter.setValue(result, forKey: kCIInputImageKey)
                ccFilter.setValue(color.brightness * 0.4, forKey: kCIInputBrightnessKey)
                ccFilter.setValue(color.contrast, forKey: kCIInputContrastKey)
                ccFilter.setValue(color.saturation, forKey: kCIInputSaturationKey)
                if let out = ccFilter.outputImage { result = out }
            }
        }

        // Temperature and Tint
        if abs(color.temperature) > 0.001 || abs(color.tint) > 0.001 {
            if let ttFilter = CIFilter(name: "CITemperatureAndTint") {
                ttFilter.setValue(result, forKey: kCIInputImageKey)
                let targetTemp = 6500.0 + color.temperature * 2500.0
                let targetTint = color.tint * 50.0
                ttFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                ttFilter.setValue(CIVector(x: targetTemp, y: targetTint), forKey: "inputTargetNeutral")
                if let out = ttFilter.outputImage { result = out }
            }
        }

        // Highlights and Shadows
        if abs(color.highlights) > 0.001 || abs(color.shadows) > 0.001 {
            if let hsFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                hsFilter.setValue(result, forKey: kCIInputImageKey)
                hsFilter.setValue(1.0 - (color.highlights * 0.5), forKey: "inputHighlightAmount")
                hsFilter.setValue(color.shadows * 0.8, forKey: "inputShadowAmount")
                if let out = hsFilter.outputImage { result = out }
            }
        }

        // Sharpness
        if color.sharpness > 0.01 {
            if let sharpFilter = CIFilter(name: "CIUnsharpMask") {
                sharpFilter.setValue(result, forKey: kCIInputImageKey)
                sharpFilter.setValue(color.sharpness * 1.2, forKey: kCIInputIntensityKey)
                sharpFilter.setValue(2.0, forKey: kCIInputRadiusKey)
                if let out = sharpFilter.outputImage { result = out }
            }
        }

        return result
    }

    // MARK: - Skin Beautification (Natural Edge-Preserving Bilateral Smoothing, Pore Texture, Translucent Whitening)
    private func applySkinBeauty(
        image: CIImage,
        beauty: BeautySettings,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard landmarks.hasFace else {
            return image
        }

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox

        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        var current = image

        // Generate Exact 468-Mesh Skin Mask with Gaussian feathering
        var faceMask: CIImage?
        if landmarks.landmarks.count == 468 {
            if let mtlMask = faceMeshRenderer.renderSkinMask(landmarks: landmarks, width: Int(width), height: Int(height)) {
                let ci = CIImage(mtlTexture: mtlMask, options: nil)
                if let flipped = ci?.transformed(by: CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0, y: -height)) {
                    // Feather the mask over 14px to guarantee invisible blending at the perimeter
                    if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                        blurFilter.setValue(flipped, forKey: kCIInputImageKey)
                        blurFilter.setValue(14.0, forKey: kCIInputRadiusKey)
                        faceMask = blurFilter.outputImage?.cropped(to: extent)
                    } else {
                        faceMask = flipped.cropped(to: extent)
                    }
                }
            }
        }

        let maskToUse = faceMask ?? createFaceOvalMask(
            extent: extent,
            center: CGPoint(x: box.midX * width, y: (1.0 - box.midY + 0.04 * box.height) * height),
            rx: faceW * 0.52,
            ry: faceH * 0.65,
            strength: 1.0
        )

        // 1. Face Skin Smoothing + Pore Texture Recovery
        if beauty.smooth > 0.01 {
            let guideRadius = max(4.0, (faceW / 140.0) * (3.0 + beauty.smooth * 5.0))
            var blurredGuide = current
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(current, forKey: kCIInputImageKey)
                blurFilter.setValue(guideRadius, forKey: kCIInputRadiusKey)
                if let out = blurFilter.outputImage?.cropped(to: extent) {
                    blurredGuide = out
                }
            }

            var smoothedSkin: CIImage?
            if let kernel = skinSmoothKernel {
                let smoothFactor = Float(min(1.0, beauty.smooth * 0.95))
                let textureFactor = Float(beauty.skinTexture)
                let skinThreshold = Float(32.0 + (1.0 - beauty.smooth) * 28.0)
                let args: [Any] = [
                    current,
                    blurredGuide,
                    smoothFactor,
                    textureFactor,
                    skinThreshold
                ]
                smoothedSkin = kernel.apply(
                    extent: extent,
                    roiCallback: { _, rect in rect.insetBy(dx: -10, dy: -10) },
                    arguments: args
                )?.cropped(to: extent)
            }

            let skinToBlend = smoothedSkin ?? blurredGuide

            if let mask = maskToUse {
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(skinToBlend, forKey: kCIInputImageKey)
                    blend.setValue(current, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(mask, forKey: kCIInputMaskImageKey)
                    if let blended = blend.outputImage {
                        current = blended
                    }
                }
            }
        }

        // 2. Whitening & Radiance (Photographic Gamma midtone expansion - zero black level lift/fog)
        if beauty.whitening > 0.01 || beauty.skinBrightness > 0.01 {
            var whitened = current
            let gammaPower = max(0.65, 1.0 - (beauty.whitening * 0.18 + beauty.skinBrightness * 0.14))
            if let gammaFilter = CIFilter(name: "CIGammaAdjust") {
                gammaFilter.setValue(current, forKey: kCIInputImageKey)
                gammaFilter.setValue(gammaPower, forKey: "inputPower")
                if let out = gammaFilter.outputImage {
                    whitened = out
                }
            }

            // Subtle porcelain cold-white tone (zero bias vector)
            if beauty.whitening > 0.01 {
                if let matrixFilter = CIFilter(name: "CIColorMatrix") {
                    matrixFilter.setValue(whitened, forKey: kCIInputImageKey)
                    let blueGain = 1.0 + CGFloat(beauty.whitening * 0.04)
                    matrixFilter.setValue(CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                    matrixFilter.setValue(CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0.0), forKey: "inputGVector")
                    matrixFilter.setValue(CIVector(x: 0.0, y: 0.0, z: blueGain, w: 0.0), forKey: "inputBVector")
                    matrixFilter.setValue(CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0), forKey: "inputBiasVector")
                    if let out = matrixFilter.outputImage {
                        whitened = out
                    }
                }
            }

            if let mask = maskToUse {
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(whitened, forKey: kCIInputImageKey)
                    blend.setValue(current, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(mask, forKey: kCIInputMaskImageKey)
                    if let blended = blend.outputImage {
                        current = blended
                    }
                }
            }
        }

        // 3. Dark Circles & Eye Bags Reduction
        if beauty.darkCircle > 0.01 || beauty.eyeBag > 0.01 {
            let intensity = min(1.0, beauty.darkCircle * 0.65 + beauty.eyeBag * 0.45)
            let leftEye = CGPoint(x: landmarks.leftEyeCenter.x * width, y: (1.0 - landmarks.leftEyeCenter.y) * height)
            let rightEye = CGPoint(x: landmarks.rightEyeCenter.x * width, y: (1.0 - landmarks.rightEyeCenter.y) * height)
            let underEyeOffsetY = faceH * 0.045
            let leftCenter = CGPoint(x: leftEye.x, y: leftEye.y - underEyeOffsetY)
            let rightCenter = CGPoint(x: rightEye.x, y: rightEye.y - underEyeOffsetY)
            let rx = faceW * 0.12
            let ry = faceH * 0.045

            if let underEyeMask = createUnderEyeMask(
                extent: extent,
                leftCenter: leftCenter,
                rightCenter: rightCenter,
                rx: rx,
                ry: ry,
                intensity: intensity
            ) {
                var brightened = current
                if let hsFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                    hsFilter.setValue(current, forKey: kCIInputImageKey)
                    hsFilter.setValue(1.0 + intensity * 0.8, forKey: "inputShadowAmount")
                    if let out = hsFilter.outputImage {
                        brightened = out
                    }
                }

                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(brightened, forKey: kCIInputImageKey)
                    blend.setValue(current, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(underEyeMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage {
                        current = out
                    }
                }
            }
        }

        // 4. Teeth Whitening
        if beauty.teethWhitening > 0.01 {
            let mouthPos = CGPoint(x: landmarks.mouthCenter.x * width, y: (1.0 - landmarks.mouthCenter.y) * height)
            let mRx = faceW * 0.10
            let mRy = faceH * 0.04
            if let teethMask = createFaceOvalMask(extent: extent, center: mouthPos, rx: mRx, ry: mRy, strength: beauty.teethWhitening * 0.60) {
                var whitenedTeeth = current
                if let ccFilter = CIFilter(name: "CIColorControls") {
                    ccFilter.setValue(current, forKey: kCIInputImageKey)
                    ccFilter.setValue(0.08 * beauty.teethWhitening, forKey: kCIInputBrightnessKey)
                    ccFilter.setValue(1.0 - 0.35 * beauty.teethWhitening, forKey: kCIInputSaturationKey)
                    if let out = ccFilter.outputImage {
                        whitenedTeeth = out
                    }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(whitenedTeeth, forKey: kCIInputImageKey)
                    blend.setValue(current, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(teethMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage {
                        current = out
                    }
                }
            }
        }

        // 5. Rosy Cheeks (Blush)
        if beauty.redness > 0.01 {
            let leftCheek = CGPoint(x: landmarks.leftCheekCenter.x * width, y: (1.0 - landmarks.leftCheekCenter.y) * height)
            let rightCheek = CGPoint(x: landmarks.rightCheekCenter.x * width, y: (1.0 - landmarks.rightCheekCenter.y) * height)
            let cheekRadius = faceW * 0.18

            if let blushOverlay = createCheekBlush(
                extent: extent,
                leftCheek: leftCheek,
                rightCheek: rightCheek,
                radius: cheekRadius,
                intensity: beauty.redness * 0.40
            ) {
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(blushOverlay, forKey: kCIInputImageKey)
                    softLight.setValue(current, forKey: kCIInputBackgroundImageKey)
                    if let out = softLight.outputImage?.cropped(to: extent) {
                        current = out
                    }
                }
            }
        }

        return current
    }

    // MARK: - Makeup (Lipstick & Blush)
    private func applyMakeup(image: CIImage, makeup: MakeupSettings, landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage {
        guard landmarks.hasFace else { return image }
        var result = image

        let width = extent.width
        let height = extent.height
        let faceW = max(50.0, landmarks.boundingBox.width * width)
        let faceH = max(60.0, landmarks.boundingBox.height * height)

        // 1. Lipstick (Exact mouth center from 3D Mesh)
        if makeup.lipPreset != "none" && makeup.lipOpacity > 0.01 {
            let mouthCenter = CGPoint(x: landmarks.mouthCenter.x * width, y: (1.0 - landmarks.mouthCenter.y) * height)
            let lipRx = faceW * 0.18
            let lipRy = faceH * 0.09

            var lipR: CGFloat = 0.88; var lipG: CGFloat = 0.32; var lipB: CGFloat = 0.42
            switch makeup.lipPreset {
            case "nude":   lipR = 0.82; lipG = 0.50; lipB = 0.45
            case "coral":  lipR = 0.95; lipG = 0.42; lipB = 0.35
            case "red":    lipR = 0.90; lipG = 0.15; lipB = 0.20
            case "berry":  lipR = 0.72; lipG = 0.18; lipB = 0.38
            case "pink":   lipR = 0.95; lipG = 0.45; lipB = 0.60
            case "brown":  lipR = 0.65; lipG = 0.35; lipB = 0.30
            default: break
            }

            let alpha = CGFloat(makeup.lipOpacity * 0.52)
            if let lipGrad = CIFilter(name: "CIRadialGradient") {
                lipGrad.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
                lipGrad.setValue(0.35, forKey: "inputRadius0")
                lipGrad.setValue(1.0, forKey: "inputRadius1")
                lipGrad.setValue(CIColor(red: lipR, green: lipG, blue: lipB, alpha: alpha), forKey: "inputColor0")
                lipGrad.setValue(CIColor(red: lipR, green: lipG, blue: lipB, alpha: 0.0), forKey: "inputColor1")

                var t = CGAffineTransform.identity
                t = t.translatedBy(x: mouthCenter.x, y: mouthCenter.y)
                t = t.scaledBy(x: lipRx, y: lipRy)

                if let lipOverlay = lipGrad.outputImage?.transformed(by: t).cropped(to: extent) {
                    if let blend = CIFilter(name: "CISoftLightBlendMode") {
                        blend.setValue(lipOverlay, forKey: kCIInputImageKey)
                        blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                        if let out = blend.outputImage?.cropped(to: extent) {
                            result = out
                        }
                    }
                }
            }
        }

        // 2. Blush (Targeted to left and right cheekbones from 3D Mesh)
        if makeup.blushPreset != "none" && makeup.blushOpacity > 0.01 {
            let leftCheek = CGPoint(x: landmarks.leftCheekCenter.x * width, y: (1.0 - landmarks.leftCheekCenter.y) * height)
            let rightCheek = CGPoint(x: landmarks.rightCheekCenter.x * width, y: (1.0 - landmarks.rightCheekCenter.y) * height)
            let cheekRadius = faceW * 0.18

            var bR: CGFloat = 0.98; var bG: CGFloat = 0.35; var bB: CGFloat = 0.45
            if makeup.blushPreset == "coral" {
                bR = 0.98; bG = 0.45; bB = 0.35
            } else if makeup.blushPreset == "peach" {
                bR = 0.98; bG = 0.50; bB = 0.40
            } else if makeup.blushPreset == "orange" {
                bR = 0.98; bG = 0.40; bB = 0.25
            }

            if let blushOverlay = createCheekBlush(
                extent: extent,
                leftCheek: leftCheek,
                rightCheek: rightCheek,
                radius: cheekRadius,
                intensity: makeup.blushOpacity * 0.45,
                colorR: bR, colorG: bG, colorB: bB
            ) {
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(blushOverlay, forKey: kCIInputImageKey)
                    softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let out = softLight.outputImage?.cropped(to: extent) {
                        result = out
                    }
                }
            }
        }

        return result
    }

    // MARK: - Face Mask Helpers
    private func createFaceOvalMask(extent: CGRect, center: CGPoint, rx: CGFloat, ry: CGFloat, strength: Double) -> CIImage? {
        guard let faceGrad = CIFilter(name: "CIRadialGradient") else { return nil }
        faceGrad.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        faceGrad.setValue(0.55, forKey: "inputRadius0")
        faceGrad.setValue(1.0, forKey: "inputRadius1")
        let c = CGFloat(strength)
        faceGrad.setValue(CIColor(red: c, green: c, blue: c, alpha: 1.0), forKey: "inputColor0")
        faceGrad.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 1.0), forKey: "inputColor1")

        var tFace = CGAffineTransform.identity
        tFace = tFace.translatedBy(x: center.x, y: center.y)
        tFace = tFace.scaledBy(x: rx, y: ry)
        return faceGrad.outputImage?.transformed(by: tFace).cropped(to: extent)
    }

    private func createCheekBlush(
        extent: CGRect,
        leftCheek: CGPoint,
        rightCheek: CGPoint,
        radius: CGFloat,
        intensity: Double,
        colorR: CGFloat = 0.98,
        colorG: CGFloat = 0.35,
        colorB: CGFloat = 0.45
    ) -> CIImage? {
        guard let lGrad = CIFilter(name: "CIRadialGradient"), let rGrad = CIFilter(name: "CIRadialGradient") else { return nil }
        let blushColor = CIColor(red: colorR, green: colorG, blue: colorB, alpha: CGFloat(intensity))
        let clearColor = CIColor(red: colorR, green: colorG, blue: colorB, alpha: 0.0)

        lGrad.setValue(CIVector(cgPoint: leftCheek), forKey: "inputCenter")
        lGrad.setValue(0.0, forKey: "inputRadius0")
        lGrad.setValue(radius, forKey: "inputRadius1")
        lGrad.setValue(blushColor, forKey: "inputColor0")
        lGrad.setValue(clearColor, forKey: "inputColor1")
        guard let lImg = lGrad.outputImage?.cropped(to: extent) else { return nil }

        rGrad.setValue(CIVector(cgPoint: rightCheek), forKey: "inputCenter")
        rGrad.setValue(0.0, forKey: "inputRadius0")
        rGrad.setValue(radius, forKey: "inputRadius1")
        rGrad.setValue(blushColor, forKey: "inputColor0")
        rGrad.setValue(clearColor, forKey: "inputColor1")
        guard let rImg = rGrad.outputImage?.cropped(to: extent) else { return nil }

        if let add = CIFilter(name: "CISourceOverCompositing") {
            add.setValue(rImg, forKey: kCIInputImageKey)
            add.setValue(lImg, forKey: kCIInputBackgroundImageKey)
            return add.outputImage?.cropped(to: extent)
        }
        return lImg
    }

    private func createUnderEyeMask(
        extent: CGRect,
        leftCenter: CGPoint,
        rightCenter: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        intensity: Double
    ) -> CIImage? {
        guard let lGrad = CIFilter(name: "CIRadialGradient"), let rGrad = CIFilter(name: "CIRadialGradient") else { return nil }
        let c = CGFloat(min(1.0, intensity))
        let whiteColor = CIColor(red: c, green: c, blue: c, alpha: 1.0)
        let blackColor = CIColor(red: 0, green: 0, blue: 0, alpha: 1.0)

        lGrad.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        lGrad.setValue(0.2, forKey: "inputRadius0")
        lGrad.setValue(1.0, forKey: "inputRadius1")
        lGrad.setValue(whiteColor, forKey: "inputColor0")
        lGrad.setValue(blackColor, forKey: "inputColor1")

        var tL = CGAffineTransform.identity
        tL = tL.translatedBy(x: leftCenter.x, y: leftCenter.y)
        tL = tL.scaledBy(x: rx, y: ry)
        guard let lImg = lGrad.outputImage?.transformed(by: tL).cropped(to: extent) else { return nil }

        rGrad.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        rGrad.setValue(0.2, forKey: "inputRadius0")
        rGrad.setValue(1.0, forKey: "inputRadius1")
        rGrad.setValue(whiteColor, forKey: "inputColor0")
        rGrad.setValue(blackColor, forKey: "inputColor1")

        var tR = CGAffineTransform.identity
        tR = tR.translatedBy(x: rightCenter.x, y: rightCenter.y)
        tR = tR.scaledBy(x: rx, y: ry)
        guard let rImg = rGrad.outputImage?.transformed(by: tR).cropped(to: extent) else { return nil }

        if let maxFilter = CIFilter(name: "CILightenBlendMode") {
            maxFilter.setValue(rImg, forKey: kCIInputImageKey)
            maxFilter.setValue(lImg, forKey: kCIInputBackgroundImageKey)
            return maxFilter.outputImage?.cropped(to: extent)
        }
        return lImg
    }

    // MARK: - Aesthetic Filters
    private func applyFilter(image: CIImage, baseImage: CIImage, filterId: String, intensity: Double) -> CIImage {
        var filtered = image

        switch filterId {
        case "clear":
            if let f = CIFilter(name: "CIColorControls") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(0.04, forKey: kCIInputBrightnessKey)
                f.setValue(1.15, forKey: kCIInputContrastKey)
                f.setValue(1.12, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { filtered = out }
            }
        case "milk":
            if let f = CIFilter(name: "CIColorMatrix") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 0.06, y: 0.06, z: 0.08, w: 0.0), forKey: "inputBiasVector")
                if let out = f.outputImage {
                    if let c = CIFilter(name: "CIColorControls") {
                        c.setValue(out, forKey: kCIInputImageKey)
                        c.setValue(0.92, forKey: kCIInputContrastKey)
                        c.setValue(0.95, forKey: kCIInputSaturationKey)
                        if let o2 = c.outputImage { filtered = o2 }
                    }
                }
            }
        case "film":
            if let f = CIFilter(name: "CIPhotoEffectProcess") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "warm":
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 8200, y: 15), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }
        case "cool":
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 5200, y: -10), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }
        case "retro":
            if let f = CIFilter(name: "CIPhotoEffectTransfer") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "peach":
            if let f = CIFilter(name: "CIColorMatrix") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 0.08, y: 0.03, z: 0.04, w: 0.0), forKey: "inputBiasVector")
                if let out = f.outputImage {
                    if let sat = CIFilter(name: "CIColorControls") {
                        sat.setValue(out, forKey: kCIInputImageKey)
                        sat.setValue(1.08, forKey: kCIInputSaturationKey)
                        if let o2 = sat.outputImage { filtered = o2 }
                    }
                }
            }
        case "bw":
            if let f = CIFilter(name: "CIPhotoEffectMono") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        default: break
        }

        if intensity < 0.999 {
            if let blend = CIFilter(name: "CIBlendWithAlphaMask") {
                blend.setValue(filtered, forKey: kCIInputImageKey)
                blend.setValue(image, forKey: kCIInputBackgroundImageKey)
                let mask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(intensity))).cropped(to: image.extent)
                blend.setValue(mask, forKey: kCIInputMaskImageKey)
                if let blended = blend.outputImage {
                    return blended
                }
            }
        }

        return filtered
    }

    // MARK: - Background Effects
    private func applyBackgroundEffects(image: CIImage, mode: String, intensity: Double, landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage {
        let blurRadius = intensity * 25.0
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage?.cropped(to: extent) else { return image }

        if landmarks.hasFace {
            let faceCenter = CGPoint(
                x: landmarks.boundingBox.midX * extent.width,
                y: (1.0 - landmarks.boundingBox.midY) * extent.height
            )
            let radius0 = max(extent.width, extent.height) * 0.2
            let radius1 = max(extent.width, extent.height) * 0.55

            if let gradient = CIFilter(name: "CIRadialGradient") {
                gradient.setValue(CIVector(cgPoint: faceCenter), forKey: "inputCenter")
                gradient.setValue(radius0, forKey: "inputRadius0")
                gradient.setValue(radius1, forKey: "inputRadius1")
                gradient.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0.0), forKey: "inputColor0")
                gradient.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1.0), forKey: "inputColor1")

                if let mask = gradient.outputImage?.cropped(to: extent) {
                    if let blend = CIFilter(name: "CIBlendWithMask") {
                        blend.setValue(blurred, forKey: kCIInputImageKey)
                        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
                        blend.setValue(mask, forKey: kCIInputMaskImageKey)
                        if let out = blend.outputImage { return out }
                    }
                }
            }
        }

        return blurred
    }

    // MARK: - Split Comparison
    private func applySplitComparison(rawImage: CIImage, beautyImage: CIImage, splitRatio: Double, extent: CGRect) -> CIImage {
        let splitX = extent.width * CGFloat(splitRatio)
        let leftRect = CGRect(x: 0, y: 0, width: splitX, height: extent.height)
        let rightRect = CGRect(x: splitX, y: 0, width: extent.width - splitX, height: extent.height)

        let leftPart = rawImage.cropped(to: leftRect)
        let rightPart = beautyImage.cropped(to: rightRect)

        let combined = rightPart.composited(over: leftPart)

        let dividerRect = CGRect(x: max(0, splitX - 1.0), y: 0, width: 2.0, height: extent.height)
        let divider = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.9)).cropped(to: dividerRect)

        return divider.composited(over: combined)
    }
}
