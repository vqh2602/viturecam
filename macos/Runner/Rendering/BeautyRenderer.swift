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
            vec4 axisNormalAndW,
            vec4 foreheadAndAxis,
            vec4 centralPts1,
            vec4 centralPts2,
            vec4 midJawPts,
            vec4 lowerJawPts,
            vec4 cheekPts,
            vec4 alarPts,
            vec4 mouthCornerPts,
            vec4 eyeCenterPts,
            vec4 eyeOuterPts,
            vec4 templePts,
            vec4 faceParams1,
            vec4 faceParams2,
            vec4 eyeParams,
            vec4 noseParams,
            vec4 mouthParams,
            vec4 miscParams
        ) {
            vec2 p = destCoord();
            vec2 offset = vec2(0.0, 0.0);

            vec2 axisNormal = axisNormalAndW.xy;
            float faceW = axisNormalAndW.z;
            vec2 foreheadCenter = foreheadAndAxis.xy;
            vec2 faceAxisDir = foreheadAndAxis.zw;

            vec2 noseCenter = centralPts1.xy;
            vec2 mouthCenter = centralPts1.zw;
            vec2 chinCenter = centralPts2.xy;
            vec2 noseBridgePt = centralPts2.zw;

            vec2 leftMidJaw = midJawPts.xy;
            vec2 rightMidJaw = midJawPts.zw;
            vec2 leftLowerJaw = lowerJawPts.xy;
            vec2 rightLowerJaw = lowerJawPts.zw;
            vec2 leftCheekCenter = cheekPts.xy;
            vec2 rightCheekCenter = cheekPts.zw;

            vec2 leftAlar = alarPts.xy;
            vec2 rightAlar = alarPts.zw;
            vec2 leftMouthCorner = mouthCornerPts.xy;
            vec2 rightMouthCorner = mouthCornerPts.zw;

            vec2 leftEyeCenter = eyeCenterPts.xy;
            vec2 rightEyeCenter = eyeCenterPts.zw;
            vec2 leftEyeOuter = eyeOuterPts.xy;
            vec2 rightEyeOuter = eyeOuterPts.zw;

            vec2 leftTemple = templePts.xy;
            vec2 rightTemple = templePts.zw;

            // 0. Inner Facial Core Protection Guard
            float distToInnerCore = min(length(p - noseCenter), length(p - mouthCenter));
            float innerGuard = smoothstep(faceW * 0.12, faceW * 0.24, distToInnerCore);

            // ==========================================
            // GROUP 1: MẶT (FACE)
            // ==========================================
            // A. Mid-Jaw Slimming (slimMid)
            float slimMidFactor = faceParams1.x;
            float jawRad = faceW * 0.22;
            if (abs(slimMidFactor) > 0.001) {
                float distLM = length(p - leftMidJaw);
                if (distLM < jawRad) {
                    float t = distLM / jawRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= axisNormal * (slimMidFactor * 0.22 * w * innerGuard * jawRad);
                }
                float distRM = length(p - rightMidJaw);
                if (distRM < jawRad) {
                    float t = distRM / jawRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += axisNormal * (slimMidFactor * 0.22 * w * innerGuard * jawRad);
                }
            }

            // B. Lower-Jaw (V-Face)
            float vFaceFactor = faceParams1.y;
            if (abs(vFaceFactor) > 0.001) {
                float distLL = length(p - leftLowerJaw);
                if (distLL < jawRad) {
                    float t = distLL / jawRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= axisNormal * (vFaceFactor * 0.22 * w * innerGuard * jawRad);
                }
                float distRL = length(p - rightLowerJaw);
                if (distRL < jawRad) {
                    float t = distRL / jawRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += axisNormal * (vFaceFactor * 0.22 * w * innerGuard * jawRad);
                }
            }

            // C. Chin Length & Width
            float chinDy = faceParams1.z;
            float chinDx = faceParams1.w;
            if (abs(chinDy) > 0.001 || abs(chinDx) > 0.001) {
                float distChin = length(p - chinCenter);
                float chinRad = faceW * 0.20;
                if (distChin < chinRad) {
                    float t = distChin / chinRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    float distToLip = length(p - mouthCenter);
                    float chinLipGuard = smoothstep(faceW * 0.08, faceW * 0.16, distToLip);
                    offset += faceAxisDir * (chinDy * 0.22 * w * chinLipGuard * chinRad);
                    vec2 toP = p - chinCenter;
                    float projNorm = dot(toP, axisNormal);
                    offset += axisNormal * (projNorm * chinDx * 0.35 * w);
                }
            }

            // D. Small Face (overall contraction toward face centroid)
            float smallFace = faceParams2.x;
            if (smallFace > 0.001) {
                vec2 faceCenter = (noseCenter + mouthCenter) * 0.5;
                float distFC = length(p - faceCenter);
                float faceRadius = faceW * 0.70;
                if (distFC < faceRadius) {
                    float t = distFC / faceRadius;
                    float w = (1.0 - t * t);
                    offset += (p - faceCenter) * (smallFace * 0.12 * w * innerGuard);
                }
            }

            // E. Cheek Width (Gò má)
            float cheekWidth = faceParams2.y;
            if (abs(cheekWidth) > 0.001) {
                float cheekRad = faceW * 0.18;
                float distLC = length(p - leftCheekCenter);
                if (distLC < cheekRad) {
                    float t = distLC / cheekRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= axisNormal * (cheekWidth * 0.20 * w * innerGuard * cheekRad);
                }
                float distRC = length(p - rightCheekCenter);
                if (distRC < cheekRad) {
                    float t = distRC / cheekRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += axisNormal * (cheekWidth * 0.20 * w * innerGuard * cheekRad);
                }
            }

            // F. Forehead Height (Trán)
            float forehead = faceParams2.z;
            if (abs(forehead) > 0.001) {
                float fhRad = faceW * 0.25;
                float distFH = length(p - foreheadCenter);
                if (distFH < fhRad) {
                    float t = distFH / fhRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= faceAxisDir * (forehead * 0.20 * w * fhRad);
                }
            }

            // G. Temple Width (Thái dương)
            float templeWidth = faceParams2.w;
            if (abs(templeWidth) > 0.001) {
                float tempRad = faceW * 0.18;
                float distLT = length(p - leftTemple);
                if (distLT < tempRad) {
                    float t = distLT / tempRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= axisNormal * (templeWidth * 0.20 * w * tempRad);
                }
                float distRT = length(p - rightTemple);
                if (distRT < tempRad) {
                    float t = distRT / tempRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += axisNormal * (templeWidth * 0.20 * w * tempRad);
                }
            }

            // ==========================================
            // GROUP 2: MŨI (NOSE)
            // ==========================================
            // A. Nose Width & Nostril Width
            float noseWidth = noseParams.x;
            float nostrilWidth = miscParams.y;
            float effectiveNoseWidth = noseWidth + nostrilWidth * 0.6;
            if (abs(effectiveNoseWidth) > 0.001) {
                float alarRad = faceW * 0.11;
                float distAL = length(p - leftAlar);
                if (distAL < alarRad) {
                    float t = distAL / alarRad;
                    float w = (1.0 - t * t);
                    offset += (noseCenter - leftAlar) * (effectiveNoseWidth * 0.30 * w);
                }
                float distAR = length(p - rightAlar);
                if (distAR < alarRad) {
                    float t = distAR / alarRad;
                    float w = (1.0 - t * t);
                    offset += (noseCenter - rightAlar) * (effectiveNoseWidth * 0.30 * w);
                }
            }

            // B. Nose Bridge (Sống mũi)
            float noseBridge = noseParams.y;
            if (abs(noseBridge) > 0.001) {
                vec2 midBridge = (noseCenter + noseBridgePt) * 0.5;
                float bridgeRad = faceW * 0.10;
                float distNB = length(p - midBridge);
                if (distNB < bridgeRad) {
                    float t = distNB / bridgeRad;
                    float w = (1.0 - t * t);
                    float projN = dot(p - midBridge, axisNormal);
                    offset += axisNormal * (projN * noseBridge * 0.35 * w);
                }
            }

            // C. Nose Tip (Đầu mũi)
            float noseTip = noseParams.z;
            if (abs(noseTip) > 0.001) {
                float tipRad = faceW * 0.08;
                float distNT = length(p - noseCenter);
                if (distNT < tipRad) {
                    float t = distNT / tipRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += (p - noseCenter) * (noseTip * 0.25 * w);
                }
            }

            // D. Nose Length (Chiều dài mũi)
            float noseLength = noseParams.w;
            if (abs(noseLength) > 0.001) {
                float lenRad = faceW * 0.12;
                float distNL = length(p - noseCenter);
                if (distNL < lenRad) {
                    float t = distNL / lenRad;
                    float w = (1.0 - t * t);
                    offset -= faceAxisDir * (noseLength * 0.18 * w * lenRad);
                }
            }

            // ==========================================
            // GROUP 3: MẮT (EYES)
            // ==========================================
            // A. Eye Size
            float eyeSize = eyeParams.x;
            if (eyeSize > 0.001) {
                float eyeRad = faceW * 0.16;
                float distEL = length(p - leftEyeCenter);
                if (distEL < eyeRad) {
                    float t = distEL / eyeRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= (p - leftEyeCenter) * (eyeSize * 0.24 * w);
                }
                float distER = length(p - rightEyeCenter);
                if (distER < eyeRad) {
                    float t = distER / eyeRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= (p - rightEyeCenter) * (eyeSize * 0.24 * w);
                }
            }

            // B. Eye Distance
            float eyeDist = eyeParams.y;
            if (abs(eyeDist) > 0.001) {
                float eyeRad = faceW * 0.16;
                float distEL = length(p - leftEyeCenter);
                if (distEL < eyeRad) {
                    float t = distEL / eyeRad;
                    float w = (1.0 - t * t);
                    offset += axisNormal * (eyeDist * 0.16 * w * eyeRad);
                }
                float distER = length(p - rightEyeCenter);
                if (distER < eyeRad) {
                    float t = distER / eyeRad;
                    float w = (1.0 - t * t);
                    offset -= axisNormal * (eyeDist * 0.16 * w * eyeRad);
                }
            }

            // C. Eye Height
            float eyeHeight = eyeParams.z;
            if (abs(eyeHeight) > 0.001) {
                float eyeRad = faceW * 0.16;
                float distEL = length(p - leftEyeCenter);
                if (distEL < eyeRad) {
                    float t = distEL / eyeRad;
                    float w = (1.0 - t * t);
                    offset += faceAxisDir * (eyeHeight * 0.18 * w * eyeRad);
                }
                float distER = length(p - rightEyeCenter);
                if (distER < eyeRad) {
                    float t = distER / eyeRad;
                    float w = (1.0 - t * t);
                    offset += faceAxisDir * (eyeHeight * 0.18 * w * eyeRad);
                }
            }

            // D. Eye Angle
            float eyeAngle = eyeParams.w;
            if (abs(eyeAngle) > 0.001) {
                float outerRad = faceW * 0.12;
                float distOL = length(p - leftEyeOuter);
                if (distOL < outerRad) {
                    float t = distOL / outerRad;
                    float w = (1.0 - t * t);
                    offset += faceAxisDir * (eyeAngle * 0.20 * w * outerRad);
                }
                float distOR = length(p - rightEyeOuter);
                if (distOR < outerRad) {
                    float t = distOR / outerRad;
                    float w = (1.0 - t * t);
                    offset += faceAxisDir * (eyeAngle * 0.20 * w * outerRad);
                }
            }

            // ==========================================
            // GROUP 4: MIỆNG (MOUTH)
            // ==========================================
            // A. Smile (Anatomical smile arc - lifts lip wings upward and outward, zero dent/shadow on cheek)
            float smile = mouthParams.x;
            if (smile > 0.001) {
                vec2 mouthVec = p - mouthCenter;
                float uNorm = dot(mouthVec, axisNormal);
                float halfW = faceW * 0.16;
                float tx = abs(uNorm) / max(1.0, halfW);
                float vVert = abs(dot(mouthVec, faceAxisDir));
                float lipHalfH = faceW * 0.06;

                // Lift is active strictly on the lips and commissure (never high onto cheek)
                if (tx <= 1.35 && vVert <= lipHalfH * 1.8) {
                    float wy = smoothstep(lipHalfH * 1.8, 0.0, vVert);
                    // Smooth quadratic smile curve along mouth width, peaking at the corners (tx ~ 1.0)
                    float wx = tx * tx * smoothstep(1.35, 0.95, tx);

                    float liftMag = smile * 0.22 * faceW * wx * wy;
                    if (uNorm < 0.0) {
                        // Left corner of face: lift up (-faceAxisDir) & out (-axisNormal)
                        // Inverse offset added to p: +faceAxisDir & +axisNormal
                        vec2 smileOffset = faceAxisDir * 0.70 + axisNormal * 0.25;
                        offset += smileOffset * liftMag;
                    } else {
                        // Right corner of face: lift up (-faceAxisDir) & out (+axisNormal)
                        // Inverse offset added to p: +faceAxisDir & -axisNormal
                        vec2 smileOffset = faceAxisDir * 0.70 - axisNormal * 0.25;
                        offset += smileOffset * liftMag;
                    }
                }
            }

            // B. Mouth Width
            float mouthWidth = mouthParams.y;
            if (abs(mouthWidth) > 0.001) {
                float cornerRad = faceW * 0.11;
                float distML = length(p - leftMouthCorner);
                if (distML < cornerRad) {
                    float t = distML / cornerRad;
                    float w = (1.0 - t * t);
                    offset += axisNormal * (mouthWidth * 0.22 * w * cornerRad);
                }
                float distMR = length(p - rightMouthCorner);
                if (distMR < cornerRad) {
                    float t = distMR / cornerRad;
                    float w = (1.0 - t * t);
                    offset -= axisNormal * (mouthWidth * 0.22 * w * cornerRad);
                }
            }

            // C. Mouth Size
            float mouthSize = mouthParams.z;
            if (abs(mouthSize) > 0.001) {
                float mRad = faceW * 0.16;
                float distMC = length(p - mouthCenter);
                if (distMC < mRad) {
                    float t = distMC / mRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset -= (p - mouthCenter) * (mouthSize * 0.20 * w);
                }
            }

            // D. Lip Thickness
            float lipThickness = mouthParams.w;
            if (abs(lipThickness) > 0.001) {
                float mRad = faceW * 0.14;
                float distMC = length(p - mouthCenter);
                if (distMC < mRad) {
                    float t = distMC / mRad;
                    float w = (1.0 - t * t);
                    float projDir = dot(p - mouthCenter, faceAxisDir);
                    offset += faceAxisDir * (sign(projDir) * lipThickness * 0.18 * w * (faceW * 0.05));
                }
            }

            // E. Mouth Position
            float mouthPos = miscParams.x;
            if (abs(mouthPos) > 0.001) {
                float mRad = faceW * 0.18;
                float distMC = length(p - mouthCenter);
                if (distMC < mRad) {
                    float t = distMC / mRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += faceAxisDir * (mouthPos * 0.22 * w * mRad);
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
                         abs(face.forehead) > 0.01 || abs(face.templeWidth) > 0.01 ||
                         face.eyeSize > 0.01 || abs(face.eyeDistance) > 0.01 ||
                         abs(face.eyeHeight) > 0.01 || abs(face.eyeAngle) > 0.01 ||
                         abs(face.noseWidth) > 0.01 || abs(face.noseBridge) > 0.01 ||
                         abs(face.noseTip) > 0.01 || abs(face.noseLength) > 0.01 ||
                         abs(face.nostrilWidth) > 0.01 ||
                         face.smile > 0.01 || abs(face.mouthWidth) > 0.01 ||
                         abs(face.mouthSize) > 0.01 || abs(face.lipThickness) > 0.01 ||
                         abs(face.mouthPosition) > 0.01

        if hasReshape && landmarks.hasFace {
            processedImage = applyFaceReshape(image: processedImage, face: face, landmarks: landmarks, extent: extent)
        }

        // 2. Skin Beautification (Natural Edge-Preserving Bilateral Smoothing, Pore Texture, Translucent Whitening)
        let hasSkinBeauty = beauty.smooth > 0.01 || beauty.whitening > 0.01 ||
                            beauty.skinBrightness > 0.01 || beauty.redness > 0.01 ||
                            beauty.darkCircle > 0.01 || beauty.eyeBag > 0.01 ||
                            beauty.teethWhitening > 0.01 || face.eyeBrightness > 0.01

        if hasSkinBeauty && landmarks.hasFace {
            processedImage = applySkinBeauty(
                image: processedImage,
                beauty: beauty,
                face: face,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 3. 3D Face Makeup (Lipstick, Blush, Eyebrows, Eyeliner, Eyeshadow)
        let hasMakeup = (makeup.lipPreset != "none" && makeup.lipOpacity > 0.01) ||
                        (makeup.blushPreset != "none" && makeup.blushOpacity > 0.01) ||
                        (makeup.eyebrowPreset != "none" && makeup.eyebrowOpacity > 0.01) ||
                        (makeup.eyelinerPreset != "none" && makeup.eyelinerOpacity > 0.01) ||
                        (makeup.eyeshadowPreset != "none" && makeup.eyeshadowOpacity > 0.01)

        if hasMakeup && landmarks.hasFace {
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

    // MARK: - Face Reshaping (Anatomical GPU Warp Kernel anchored on 468 landmarks)
    private func applyFaceReshape(
        image: CIImage,
        face: FaceSettings,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard let kernel = reshapeKernel, landmarks.hasFace else { return image }

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)

        // Feature Anchors in Core Image coordinate space (origin bottom-left)
        func ciPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        let noseBridge = ciPt(landmarks.noseBridge)
        let noseCenter = ciPt(landmarks.noseTip)
        let chinCenter = ciPt(landmarks.chinTip)
        let mouthCenter = ciPt(landmarks.mouthCenter)
        let leftMidJaw = ciPt(landmarks.leftMidJaw)
        let rightMidJaw = ciPt(landmarks.rightMidJaw)
        let leftLowerJaw = ciPt(landmarks.leftLowerJaw)
        let rightLowerJaw = ciPt(landmarks.rightLowerJaw)
        let leftCheekCenter = ciPt(landmarks.leftCheekCenter)
        let rightCheekCenter = ciPt(landmarks.rightCheekCenter)
        let leftAlar = ciPt(landmarks.leftAlar)
        let rightAlar = ciPt(landmarks.rightAlar)
        let leftMouthCorner = ciPt(landmarks.leftMouthCorner)
        let rightMouthCorner = ciPt(landmarks.rightMouthCorner)
        let leftEyeCenter = ciPt(landmarks.leftEyeCenter)
        let rightEyeCenter = ciPt(landmarks.rightEyeCenter)
        let leftEyeOuter = ciPt(landmarks.leftEyeOuter)
        let rightEyeOuter = ciPt(landmarks.rightEyeOuter)
        let foreheadCenter = ciPt(landmarks.foreheadCenter)
        let leftTemple = ciPt(landmarks.leftTemple)
        let rightTemple = ciPt(landmarks.rightTemple)

        // Central Facial Axis (points downward from nose bridge to chin tip)
        let axisVec = CGPoint(x: chinCenter.x - noseBridge.x, y: chinCenter.y - noseBridge.y)
        let axisLen = max(1.0, hypot(axisVec.x, axisVec.y))
        let axisDir = CGPoint(x: axisVec.x / axisLen, y: axisVec.y / axisLen)
        // Normal points 90 degrees to the right of the face axis
        let axisNormal = CGPoint(x: -axisDir.y, y: axisDir.x)

        // Reshape Factors
        let slimMidFactor = CGFloat(face.slimFace * 0.55 + face.jawWidth * 0.45)
        let vFaceFactor = CGFloat(face.vFace * 0.65 + face.slimFace * 0.25)
        let chinDy = CGFloat(face.chinLength)
        let chinDx = CGFloat(face.chinWidth)

        let smallFace = CGFloat(face.smallFace)
        let cheekWidth = CGFloat(face.cheekWidth)
        let forehead = CGFloat(face.forehead)
        let templeWidth = CGFloat(face.templeWidth)

        let eyeSize = CGFloat(face.eyeSize)
        let eyeDist = CGFloat(face.eyeDistance)
        let eyeHeight = CGFloat(face.eyeHeight)
        let eyeAngle = CGFloat(face.eyeAngle)

        let noseWidth = CGFloat(face.noseWidth)
        let noseBridgeVal = CGFloat(face.noseBridge)
        let noseTip = CGFloat(face.noseTip)
        let noseLength = CGFloat(face.noseLength)

        let smile = CGFloat(face.smile)
        let mouthWidth = CGFloat(face.mouthWidth)
        let mouthSize = CGFloat(face.mouthSize)
        let lipThickness = CGFloat(face.lipThickness)

        let mouthPos = CGFloat(face.mouthPosition)
        let nostrilWidth = CGFloat(face.nostrilWidth)

        let args: [Any] = [
            CIVector(x: axisNormal.x, y: axisNormal.y, z: faceW, w: 0.0),
            CIVector(x: foreheadCenter.x, y: foreheadCenter.y, z: axisDir.x, w: axisDir.y),
            CIVector(x: noseCenter.x, y: noseCenter.y, z: mouthCenter.x, w: mouthCenter.y),
            CIVector(x: chinCenter.x, y: chinCenter.y, z: noseBridge.x, w: noseBridge.y),
            CIVector(x: leftMidJaw.x, y: leftMidJaw.y, z: rightMidJaw.x, w: rightMidJaw.y),
            CIVector(x: leftLowerJaw.x, y: leftLowerJaw.y, z: rightLowerJaw.x, w: rightLowerJaw.y),
            CIVector(x: leftCheekCenter.x, y: leftCheekCenter.y, z: rightCheekCenter.x, w: rightCheekCenter.y),
            CIVector(x: leftAlar.x, y: leftAlar.y, z: rightAlar.x, w: rightAlar.y),
            CIVector(x: leftMouthCorner.x, y: leftMouthCorner.y, z: rightMouthCorner.x, w: rightMouthCorner.y),
            CIVector(x: leftEyeCenter.x, y: leftEyeCenter.y, z: rightEyeCenter.x, w: rightEyeCenter.y),
            CIVector(x: leftEyeOuter.x, y: leftEyeOuter.y, z: rightEyeOuter.x, w: rightEyeOuter.y),
            CIVector(x: leftTemple.x, y: leftTemple.y, z: rightTemple.x, w: rightTemple.y),
            CIVector(x: slimMidFactor, y: vFaceFactor, z: chinDy, w: chinDx),
            CIVector(x: smallFace, y: cheekWidth, z: forehead, w: templeWidth),
            CIVector(x: eyeSize, y: eyeDist, z: eyeHeight, w: eyeAngle),
            CIVector(x: noseWidth, y: noseBridgeVal, z: noseTip, w: noseLength),
            CIVector(x: smile, y: mouthWidth, z: mouthSize, w: lipThickness),
            CIVector(x: mouthPos, y: nostrilWidth, z: 0.0, w: 0.0)
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
        face: FaceSettings,
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

        // 6. Eye Brightness & Clarity (face.eyeBrightness)
        if face.eyeBrightness > 0.01 {
            let leftEye = CGPoint(x: landmarks.leftEyeCenter.x * width, y: (1.0 - landmarks.leftEyeCenter.y) * height)
            let rightEye = CGPoint(x: landmarks.rightEyeCenter.x * width, y: (1.0 - landmarks.rightEyeCenter.y) * height)
            let rx = faceW * 0.08
            let ry = faceH * 0.045
            if let eyeMask = createUnderEyeMask(extent: extent, leftCenter: leftEye, rightCenter: rightEye, rx: rx, ry: ry, intensity: face.eyeBrightness * 0.75) {
                var brightened = current
                if let ccFilter = CIFilter(name: "CIColorControls") {
                    ccFilter.setValue(current, forKey: kCIInputImageKey)
                    ccFilter.setValue(0.10 * face.eyeBrightness, forKey: kCIInputBrightnessKey)
                    ccFilter.setValue(1.0 + 0.16 * face.eyeBrightness, forKey: kCIInputContrastKey)
                    if let out = ccFilter.outputImage { brightened = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(brightened, forKey: kCIInputImageKey)
                    blend.setValue(current, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(eyeMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { current = out }
                }
            }
        }

        return current
    }

    // MARK: - Makeup (Lipstick, Blush, Eyebrows, Eyeliner, Eyeshadow)
    private func applyMakeup(image: CIImage, makeup: MakeupSettings, landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage {
        guard landmarks.hasFace, landmarks.landmarks.count >= 468 else { return image }
        var result = image

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)

        func ciPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        // 1. Lipstick (Exact 3D Contour Mask with Teeth & Oral Cavity Cutout)
        if makeup.lipPreset != "none" && makeup.lipOpacity > 0.01 {
            var lipR: CGFloat = 0.88; var lipG: CGFloat = 0.32; var lipB: CGFloat = 0.42
            switch makeup.lipPreset {
            case "nude":   lipR = 0.82; lipG = 0.50; lipB = 0.45
            case "rose":   lipR = 0.80; lipG = 0.32; lipB = 0.44
            case "coral":  lipR = 0.90; lipG = 0.38; lipB = 0.32
            case "red":    lipR = 0.88; lipG = 0.12; lipB = 0.18
            case "berry":  lipR = 0.68; lipG = 0.16; lipB = 0.32
            case "pink":   lipR = 0.92; lipG = 0.42; lipB = 0.58
            case "brown":  lipR = 0.62; lipG = 0.32; lipB = 0.28
            default: break
            }

            if let lipMask = createLipMask(landmarks: landmarks, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: lipR, green: lipG, blue: lipB, alpha: 1.0)).cropped(to: extent)
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(colorImg, forKey: kCIInputImageKey)
                    softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tintedLips = softLight.outputImage {
                        var effMask = lipMask
                        let opacity = CGFloat(min(1.0, makeup.lipOpacity * 0.90))
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(lipMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: opacity), forKey: "inputAVector")
                            if let out = matrix.outputImage { effMask = out }
                        }
                        if let blend = CIFilter(name: "CIBlendWithMask") {
                            blend.setValue(tintedLips, forKey: kCIInputImageKey)
                            blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                            blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                            if let blended = blend.outputImage { result = blended }
                        }
                    }
                }
            }
        }

        // 2. Blush (Targeted strictly at true cheek apples: landmarks 50 & 280)
        if makeup.blushPreset != "none" && makeup.blushOpacity > 0.01 {
            let rightCheek = ciPt(landmarks.rightCheekApple) // landmark 50 (camera left)
            let leftCheek = ciPt(landmarks.leftCheekApple)   // landmark 280 (camera right)
            let cheekRadius = faceW * 0.16

            var bR: CGFloat = 0.98; var bG: CGFloat = 0.42; var bB: CGFloat = 0.52
            switch makeup.blushPreset {
            case "peach": bR = 0.98; bG = 0.54; bB = 0.42
            case "coral": bR = 0.98; bG = 0.46; bB = 0.38
            case "mauve": bR = 0.88; bG = 0.48; bB = 0.65
            case "rosy":  fallthrough
            default:      bR = 0.98; bG = 0.42; bB = 0.52
            }

            if let blushOverlay = createCheekBlush(
                extent: extent,
                leftCheek: leftCheek,
                rightCheek: rightCheek,
                radius: cheekRadius,
                intensity: makeup.blushOpacity * 0.50,
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

        // 3. Eyebrows (Enhanced contour & tinting)
        if makeup.eyebrowPreset != "none" && makeup.eyebrowOpacity > 0.01 {
            var eR: CGFloat = 0.30; var eG: CGFloat = 0.22; var eB: CGFloat = 0.18
            switch makeup.eyebrowPreset {
            case "soft":    eR = 0.25; eG = 0.25; eB = 0.25
            case "brown":   eR = 0.24; eG = 0.15; eB = 0.12
            case "natural": fallthrough
            default:        eR = 0.30; eG = 0.22; eB = 0.18
            }

            if let browMask = createEyebrowMask(landmarks: landmarks, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: eR, green: eG, blue: eB, alpha: 1.0)).cropped(to: extent)
                if let multiply = CIFilter(name: "CIMultiplyBlendMode") {
                    multiply.setValue(colorImg, forKey: kCIInputImageKey)
                    multiply.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = multiply.outputImage {
                        var effMask = browMask
                        let opacity = CGFloat(makeup.eyebrowOpacity * 0.50)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(browMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: opacity), forKey: "inputAVector")
                            if let out = matrix.outputImage { effMask = out }
                        }
                        if let blend = CIFilter(name: "CIBlendWithMask") {
                            blend.setValue(tinted, forKey: kCIInputImageKey)
                            blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                            blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                            if let out = blend.outputImage { result = out }
                        }
                    }
                }
            }
        }

        // 4. Eyeliner (Lash line definition & cat eye wing)
        if makeup.eyelinerPreset != "none" && makeup.eyelinerOpacity > 0.01 {
            let isCat = makeup.eyelinerPreset == "cat"
            var lR: CGFloat = 0.12; var lG: CGFloat = 0.12; var lB: CGFloat = 0.12
            if makeup.eyelinerPreset == "brown" {
                lR = 0.22; lG = 0.16; lB = 0.14
            }

            if let linerMask = createEyelinerMask(landmarks: landmarks, isCatEye: isCat, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: lR, green: lG, blue: lB, alpha: 1.0)).cropped(to: extent)
                if let multiply = CIFilter(name: "CIMultiplyBlendMode") {
                    multiply.setValue(colorImg, forKey: kCIInputImageKey)
                    multiply.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = multiply.outputImage {
                        var effMask = linerMask
                        let opacity = CGFloat(makeup.eyelinerOpacity * 0.75)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(linerMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: opacity), forKey: "inputAVector")
                            if let out = matrix.outputImage { effMask = out }
                        }
                        if let blend = CIFilter(name: "CIBlendWithMask") {
                            blend.setValue(tinted, forKey: kCIInputImageKey)
                            blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                            blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                            if let out = blend.outputImage { result = out }
                        }
                    }
                }
            }
        }

        // 5. Eyeshadow (Upper eyelid gradient tone)
        if makeup.eyeshadowPreset != "none" && makeup.eyeshadowOpacity > 0.01 {
            var sR: CGFloat = 0.65; var sG: CGFloat = 0.52; var sB: CGFloat = 0.45
            switch makeup.eyeshadowPreset {
            case "sunset": sR = 0.95; sG = 0.55; sB = 0.42
            case "pink":   sR = 0.92; sG = 0.52; sB = 0.65
            case "smoky":  sR = 0.35; sG = 0.35; sB = 0.35
            case "earth":  fallthrough
            default:       sR = 0.65; sG = 0.52; sB = 0.45
            }

            if let shadowMask = createEyeshadowMask(landmarks: landmarks, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: sR, green: sG, blue: sB, alpha: 1.0)).cropped(to: extent)
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(colorImg, forKey: kCIInputImageKey)
                    softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = softLight.outputImage {
                        var effMask = shadowMask
                        let opacity = CGFloat(makeup.eyeshadowOpacity * 0.55)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(shadowMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: opacity), forKey: "inputAVector")
                            if let out = matrix.outputImage { effMask = out }
                        }
                        if let blend = CIFilter(name: "CIBlendWithMask") {
                            blend.setValue(tinted, forKey: kCIInputImageKey)
                            blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                            blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                            if let out = blend.outputImage { result = out }
                        }
                    }
                }
            }
        }

        return result
    }

    // MARK: - 3D Face Makeup Masks
    private func createLipMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        guard landmarks.landmarks.count >= 468 else { return nil }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func pt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        let outer = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 375, 321, 405, 314, 17, 84, 181, 91, 146]
        let inner = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]

        let path = CGMutablePath()
        if let first = outer.first {
            path.move(to: pt(first))
            for idx in outer.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }
        if let first = inner.first {
            path.move(to: pt(first))
            for idx in inner.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.drawPath(using: .eoFill)

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(2.0, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    private func createEyebrowMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        guard landmarks.landmarks.count >= 468 else { return nil }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func pt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        let rightBrow = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
        let leftBrow = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276]

        let path = CGMutablePath()
        if let first = rightBrow.first {
            path.move(to: pt(first))
            for idx in rightBrow.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }
        if let first = leftBrow.first {
            path.move(to: pt(first))
            for idx in leftBrow.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fillPath()

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(3.5, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    private func createEyelinerMask(landmarks: FaceMeshLandmarks, isCatEye: Bool, extent: CGRect) -> CIImage? {
        guard landmarks.landmarks.count >= 468 else { return nil }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func pt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        // Full upper lash line from inner canthus to outer corner
        // Camera-left (person's right eye): 133 (inner) -> ... -> 33 (outer)
        let rightUpperLash = [133, 173, 157, 158, 159, 160, 161, 246, 33]
        // Camera-right (person's left eye): 362 (inner) -> ... -> 263 (outer)
        let leftUpperLash = [362, 398, 384, 385, 386, 387, 388, 466, 263]

        context.setStrokeColor(gray: 1.0, alpha: 1.0)
        context.setLineWidth(max(2.0, extent.width * 0.0028))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let path = CGMutablePath()
        if let first = rightUpperLash.first {
            path.move(to: pt(first))
            for idx in rightUpperLash.dropFirst() { path.addLine(to: pt(idx)) }
            if isCatEye {
                let pOuter = pt(33)
                let pPrev = pt(246)
                let dirX = pOuter.x - pPrev.x
                let dirY = pOuter.y - pPrev.y
                let len = max(1.0, hypot(dirX, dirY))
                let wing = CGPoint(
                    x: pOuter.x + (dirX / len) * 14.0,
                    y: pOuter.y + (dirY / len) * 14.0 + 5.0
                )
                path.addLine(to: wing)
            }
        }

        if let first = leftUpperLash.first {
            path.move(to: pt(first))
            for idx in leftUpperLash.dropFirst() { path.addLine(to: pt(idx)) }
            if isCatEye {
                let pOuter = pt(263)
                let pPrev = pt(466)
                let dirX = pOuter.x - pPrev.x
                let dirY = pOuter.y - pPrev.y
                let len = max(1.0, hypot(dirX, dirY))
                let wing = CGPoint(
                    x: pOuter.x + (dirX / len) * 14.0,
                    y: pOuter.y + (dirY / len) * 14.0 + 5.0
                )
                path.addLine(to: wing)
            }
        }

        context.addPath(path)
        context.strokePath()

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(1.5, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    private func createEyeshadowMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        guard landmarks.landmarks.count >= 468 else { return nil }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func pt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        // Complete upper eyelid surface from lash line to palpebral crease
        let rightEyelid = [33, 246, 161, 160, 159, 158, 157, 173, 133, 243, 190, 56, 28, 27, 29, 30, 247]
        let leftEyelid = [263, 466, 388, 387, 386, 385, 384, 398, 362, 463, 414, 286, 258, 257, 259, 260, 467]

        let path = CGMutablePath()
        if let first = rightEyelid.first {
            path.move(to: pt(first))
            for idx in rightEyelid.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }
        if let first = leftEyelid.first {
            path.move(to: pt(first))
            for idx in leftEyelid.dropFirst() { path.addLine(to: pt(idx)) }
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fillPath()

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(5.0, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
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
