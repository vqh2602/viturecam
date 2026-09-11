import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation
import Metal

public final class BeautyRenderer {
    private let mtlDevice: MTLDevice
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace

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
        landmarks: SmoothedFaceLandmarks
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

        // 1. Skin Beautification (Smoothing & Whitening)
        if beauty.smooth > 0.01 || beauty.whitening > 0.01 || beauty.skinBrightness > 0.01 {
            processedImage = applySkinBeauty(
                image: processedImage,
                smooth: beauty.smooth,
                whitening: beauty.whitening,
                brightness: beauty.skinBrightness,
                redness: beauty.redness,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 2. Color adjustments (Real-time GPU)
        processedImage = applyColorAdjustments(image: processedImage, color: color)

        // 3. Aesthetic Filters
        if filter.filterId != "original" && filter.intensity > 0.01 {
            processedImage = applyFilter(image: processedImage, baseImage: sourceImage, filterId: filter.filterId, intensity: filter.intensity)
        }

        // 4. Background Effects (if enabled)
        if background.mode != "none" && background.blurIntensity > 0.01 {
            processedImage = applyBackgroundEffects(image: processedImage, mode: background.mode, intensity: background.blurIntensity, landmarks: landmarks, extent: extent)
        }

        // 5. Compare / Split Screen mode
        var finalImage = processedImage
        if compareMode == "split" {
            finalImage = applySplitComparison(
                rawImage: sourceImage,
                beautyImage: processedImage,
                splitRatio: max(0.0, min(1.0, splitRatio)),
                extent: extent
            )
        }

        ciContext.render(finalImage, to: targetBuffer, bounds: extent, colorSpace: colorSpace)
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
                // Default daylight neutral is ~6500K
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

    // MARK: - Skin Beautification
    private func applySkinBeauty(
        image: CIImage,
        smooth: Double,
        whitening: Double,
        brightness: Double,
        redness: Double,
        landmarks: SmoothedFaceLandmarks,
        extent: CGRect
    ) -> CIImage {
        var current = image

        // Edge-preserving smooth: Blend guided bilateral blur with original
        if smooth > 0.01 {
            let blurRadius = 2.0 + smooth * 7.0
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(current, forKey: kCIInputImageKey)
                blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
                if let blurred = blurFilter.outputImage?.cropped(to: extent) {
                    // Soft light / lerp blend preserving edges
                    let blendAlpha = smooth * 0.7
                    if let blendFilter = CIFilter(name: "CIBlendWithAlphaMask") {
                        blendFilter.setValue(blurred, forKey: kCIInputImageKey)
                        blendFilter.setValue(current, forKey: kCIInputBackgroundImageKey)
                        let mask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(blendAlpha))).cropped(to: extent)
                        blendFilter.setValue(mask, forKey: kCIInputMaskImageKey)
                        if let blended = blendFilter.outputImage {
                            current = blended
                        }
                    }
                }
            }
        }

        // Whitening & Radiance
        if whitening > 0.01 || brightness > 0.01 {
            let lift = whitening * 0.15 + brightness * 0.12
            if let colorMatrix = CIFilter(name: "CIColorMatrix") {
                colorMatrix.setValue(current, forKey: kCIInputImageKey)
                // Subtle tone curve brightening and cool tinting for Asian beauty look
                let redVec = CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
                let greenVec = CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0.0)
                let blueVec = CIVector(x: 0.0, y: 0.0, z: 1.02 + CGFloat(whitening * 0.04), w: 0.0)
                let biasVec = CIVector(x: CGFloat(lift * 0.9), y: CGFloat(lift * 0.95), z: CGFloat(lift * 1.05), w: 0.0)

                colorMatrix.setValue(redVec, forKey: "inputRVector")
                colorMatrix.setValue(greenVec, forKey: "inputGVector")
                colorMatrix.setValue(blueVec, forKey: "inputBVector")
                colorMatrix.setValue(biasVec, forKey: "inputBiasVector")
                if let out = colorMatrix.outputImage?.cropped(to: extent) {
                    current = out
                }
            }
        }

        return current
    }

    // MARK: - Filters
    private func applyFilter(image: CIImage, baseImage: CIImage, filterId: String, intensity: Double) -> CIImage {
        var filtered = image

        switch filterId {
        case "clear":
            // High clarity, lifted whites, subtle cool vibrance
            if let f = CIFilter(name: "CIColorControls") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(0.04, forKey: kCIInputBrightnessKey)
                f.setValue(1.15, forKey: kCIInputContrastKey)
                f.setValue(1.12, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { filtered = out }
            }

        case "milk":
            // Creamy high-key aesthetic, softened contrast, radiant pastel highlights
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
            // Subtle cinematic film contrast, muted tones
            if let f = CIFilter(name: "CIPhotoEffectProcess") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }

        case "warm":
            // Golden hour sunset glow
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 8200, y: 15), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }

        case "cool":
            // Fresh modern cool tone
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 5200, y: -10), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }

        case "retro":
            // Vintage warm nostalgic tones
            if let f = CIFilter(name: "CIPhotoEffectTransfer") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }

        case "peach":
            // Soft rosy-peach radiance
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
            // Fine monochrome portrait
            if let f = CIFilter(name: "CIPhotoEffectMono") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }

        default:
            break
        }

        // Blend based on intensity
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
    private func applyBackgroundEffects(image: CIImage, mode: String, intensity: Double, landmarks: SmoothedFaceLandmarks, extent: CGRect) -> CIImage {
        // High quality background blur
        let blurRadius = intensity * 25.0
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage?.cropped(to: extent) else { return image }

        if landmarks.hasFace {
            // Elliptical radial vignette mask around face
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

        // Draw crisp 2px white divider line
        let dividerRect = CGRect(x: max(0, splitX - 1.0), y: 0, width: 2.0, height: extent.height)
        let divider = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 0.9)).cropped(to: dividerRect)

        return divider.composited(over: combined)
    }
}
