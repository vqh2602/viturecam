import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation
import Metal
import Vision

public final class BeautyRenderer {
    private let mtlDevice: MTLDevice
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace
    public let faceMeshRenderer: FaceMeshRenderer
    private var reshapeKernel: CIWarpKernel?
    private var skinSmoothKernel: CIKernel?
    private var smoothedTeethOpenGate: Float = 0.0
    private var hasPreviousTeethFrame: Bool = false
    private lazy var personSegmentationRequest: Any? = {
        if #available(macOS 12.0, *) {
            let req = VNGeneratePersonSegmentationRequest()
            req.qualityLevel = .fast
            req.outputPixelFormat = kCVPixelFormatType_OneComponent8
            return req
        }
        return nil
    }()
    private let teethWhiteningKernel = CIColorKernel(source: """
        kernel vec4 teethWhiten(__sample image, __sample mouth, float strength) {
            if (mouth.r < 0.005 || strength < 0.005) {
                return image;
            }

            float r = image.r;
            float g = image.g;
            float b = image.b;
            float maxC = max(r, max(g, b));
            float minC = min(r, min(g, b));
            float brightness = dot(image.rgb, vec3(0.299, 0.587, 0.114));
            float saturation = (maxC - minC) / max(0.001, maxC);

            // Red excess over green (teeth enamel has r ~ g, while gums/tongue/lips have r >> g)
            float redExcess = max(0.0, r - g);
            float notGum = 1.0 - smoothstep(0.03, 0.11, redExcess);

            // Red excess over blue (tongue/lips have r >> b)
            float redOverBlue = max(0.0, r - b);
            float notTongue = 1.0 - smoothstep(0.05, 0.22, redOverBlue);

            // Teeth criteria:
            // 1. Bright enough (exclude deep throat / dark oral cavity / interdental shadow)
            float isBrightEnough = smoothstep(0.12, 0.28, brightness);
            // 2. Low saturation (lips and gums are heavily saturated, teeth have low saturation)
            float notTooSaturated = 1.0 - smoothstep(0.18, 0.42, saturation);

            float toothWeight = mouth.r * isBrightEnough * notTooSaturated * notGum * notTongue * strength;

            if (toothWeight <= 0.001) {
                return image;
            }

            // Neutralize yellow stain: boost blue towards min(r, g)
            float targetB = min(r, g);
            float yellowDelta = max(0.0, targetB - b);
            float deYellowB = b + yellowDelta * 0.70;

            // Lift luminance smoothly proportional to brightness (avoid flat additive jump on dark pixels)
            float lift = (0.05 + 0.18 * brightness) * strength;
            float newR = clamp(r + lift * (1.0 - r * 0.35), 0.0, 1.0);
            float newG = clamp(g + lift * (1.0 - g * 0.35), 0.0, 1.0);
            float newB = clamp(deYellowB + lift * 1.08 * (1.0 - deYellowB * 0.35), 0.0, 1.0);

            // Pearlescent subtle desaturation towards luminance
            float newLuma = dot(vec3(newR, newG, newB), vec3(0.299, 0.587, 0.114));
            newR = mix(newR, newLuma, 0.20);
            newG = mix(newG, newLuma, 0.20);
            newB = mix(newB, newLuma, 0.08);

            vec3 result = mix(image.rgb, vec3(newR, newG, newB), toothWeight);
            return vec4(result, image.a);
        }
        """)

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
            vec4 miscParams,
            vec4 browPts,
            vec4 browParams,
            vec4 sculptParams
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
            vec2 leftBrowCenter = browPts.xy;
            vec2 rightBrowCenter = browPts.zw;

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

            // D. Small Head & Face (Proportional cranial & facial reduction - no dents)
            float smallFace = faceParams2.x;
            if (smallFace > 0.001) {
                vec2 eyeMid = (leftEyeCenter + rightEyeCenter) * 0.5;
                vec2 headCenter = eyeMid * 0.85 + foreheadCenter * 0.15;
                float faceH = max(faceW * 1.1, length(chinCenter - foreheadCenter));
                float headRadius = max(faceW * 1.45, faceH * 1.30);
                vec2 vHead = p - headCenter;
                float distHC = length(vHead);
                if (distHC < headRadius) {
                    float t = distHC / headRadius;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    float projX = dot(vHead, axisNormal);
                    float projY = dot(vHead, faceAxisDir);
                    vec2 headShrinkDir = axisNormal * projX + faceAxisDir * (projY * 0.85);
                    offset += headShrinkDir * (smallFace * 0.09 * w);
                }
            }

            // E. Cheek Width (Gò má & Viền ngoài mặt - liền mạch, không lõm mặt)
            float cheekWidth = faceParams2.y;
            if (abs(cheekWidth) > 0.001) {
                float vertSpan = faceW * 0.22;
                float outSpan = faceW * 0.32;
                float inSpan = faceW * 0.18;

                // Left cheek & zygomatic contour (camera left)
                vec2 vLC = p - leftCheekCenter;
                float uL = dot(vLC, axisNormal);  // uL < 0: outward toward silhouette; uL > 0: inward toward nose
                float vL = dot(vLC, faceAxisDir);
                if (abs(vL) < vertSpan) {
                    float tV = abs(vL) / vertSpan;
                    float wV = (1.0 - tV * tV);
                    float wU = 0.0;
                    if (uL <= 0.0) {
                        if (-uL < outSpan) {
                            float tU = -uL / outSpan;
                            wU = (1.0 - tU * tU);
                        }
                    } else {
                        if (uL < inSpan) {
                            float tU = uL / inSpan;
                            wU = (1.0 - tU * tU);
                        }
                    }
                    if (wU > 0.0) {
                        float w = wU * wU * wV * wV * innerGuard;
                        offset -= axisNormal * (cheekWidth * 0.22 * w * (faceW * 0.18));
                    }
                }

                // Right cheek & zygomatic contour (camera right)
                vec2 vRC = p - rightCheekCenter;
                float uR = dot(vRC, axisNormal);  // uR > 0: outward toward silhouette; uR < 0: inward toward nose
                float vR = dot(vRC, faceAxisDir);
                if (abs(vR) < vertSpan) {
                    float tV = abs(vR) / vertSpan;
                    float wV = (1.0 - tV * tV);
                    float wU = 0.0;
                    if (uR >= 0.0) {
                        if (uR < outSpan) {
                            float tU = uR / outSpan;
                            wU = (1.0 - tU * tU);
                        }
                    } else {
                        if (-uR < inSpan) {
                            float tU = -uR / inSpan;
                            wU = (1.0 - tU * tU);
                        }
                    }
                    if (wU > 0.0) {
                        float w = wU * wU * wV * wV * innerGuard;
                        offset += axisNormal * (cheekWidth * 0.22 * w * (faceW * 0.18));
                    }
                }
            }

            // F. Forehead Height (Trán)
            float forehead = faceParams2.z;
            if (abs(forehead) > 0.001) {
                vec2 eyeMid = (leftEyeCenter + rightEyeCenter) * 0.5;
                vec2 vForehead = p - foreheadCenter;
                float u = dot(vForehead, axisNormal);    // Lateral offset (across forehead/temples)
                float v = dot(vForehead, faceAxisDir);   // Longitudinal (+ toward eyes/chin, - toward hair/scalp)

                float browDist = max(faceW * 0.25, length(foreheadCenter - eyeMid));
                float halfW = faceW * 0.48; // Width spanning forehead to temples

                if (abs(u) < halfW) {
                    float tU = abs(u) / halfW;
                    float wU = (1.0 - tU * tU) * (1.0 - tU * tU);

                    float wV = 0.0;
                    if (v > 0.0) {
                        // Below foreheadCenter towards eyebrows:
                        // Compress forehead skin smoothly, fading to 0 before eyebrows so eyes & brows never shift
                        float downSpan = browDist * 0.65;
                        if (v < downSpan) {
                            float tD = v / downSpan;
                            wV = (1.0 - tD * tD);
                        }
                    } else {
                        // Above foreheadCenter into the hairline and anterior hair:
                        // Pulls the entire hairline and front hair down smoothly in unison
                        float upSpan = browDist * 1.5;
                        if (-v < upSpan) {
                            float tUp = -v / upSpan;
                            wV = (1.0 - tUp * tUp);
                        }
                    }

                    if (wV > 0.0) {
                        float totalW = wU * wV;
                        // When forehead > 0 (shorter forehead/lower hairline):
                        // CIWarpKernel samples from -faceAxisDir (higher in hair), translating the hairline DOWN!
                        offset -= faceAxisDir * (forehead * 0.24 * browDist * totalW);
                    }
                }
            }

            // G. Temple Width (Thái dương - Làm đầy / Làm lõm hõm thái dương)
            float templeWidth = faceParams2.w;
            if (abs(templeWidth) > 0.001) {
                float tempRad = faceW * 0.22;
                float distLT = length(p - leftTemple);
                if (distLT < tempRad) {
                    float t = distLT / tempRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    // Left temple: templeWidth > 0 fills out hollow (+axisNormal samples inward to expand outward)
                    // templeWidth < 0 hollows/narrows (-axisNormal samples outward to contract inward)
                    offset += axisNormal * (templeWidth * 0.22 * w * tempRad);
                }
                float distRT = length(p - rightTemple);
                if (distRT < tempRad) {
                    float t = distRT / tempRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    // Right temple: templeWidth > 0 fills out hollow (-axisNormal samples inward to expand outward)
                    // templeWidth < 0 hollows/narrows (+axisNormal samples outward to contract inward)
                    offset -= axisNormal * (templeWidth * 0.22 * w * tempRad);
                }
            }

            // H. Hairline Adjustment (Hạ / Làm cao đường chân tóc)
            float hairline = browParams.w;
            if (abs(hairline) > 0.001) {
                vec2 vHair = p - foreheadCenter;
                float uH = dot(vHair, axisNormal);   // Across upper forehead and hairline
                float vH = dot(vHair, faceAxisDir);  // Along face axis: + towards eyes, - towards hair/crown

                vec2 browMid = (leftBrowCenter + rightBrowCenter) * 0.5;
                float browDist = max(faceW * 0.25, length(foreheadCenter - browMid));
                float hairHalfW = faceW * 0.55;

                if (abs(uH) < hairHalfW) {
                    float tU = abs(uH) / hairHalfW;
                    float wU = (1.0 - tU * tU) * (1.0 - tU * tU);

                    float wV = 0.0;
                    if (vH > 0.0) {
                        // Below foreheadCenter towards eyebrows:
                        // Compress upper forehead skin, strictly zero before eyebrows to keep brows and eyes static
                        float downSpan = browDist * 0.45;
                        if (vH < downSpan) {
                            float tD = vH / downSpan;
                            wV = (1.0 - tD * tD) * (1.0 - tD * tD);
                        }
                    } else {
                        // Above foreheadCenter into hairline and hair:
                        // Pulls the entire hairline and front hair volume smoothly
                        float upSpan = faceW * 0.70;
                        if (-vH < upSpan) {
                            float tUp = -vH / upSpan;
                            wV = (1.0 - tUp * tUp) * (1.0 - tUp * tUp);
                        }
                    }

                    if (wV > 0.0) {
                        float totalW = wU * wV;
                        // hairline > 0 (Hạ chân tóc): destination p samples from higher up (-faceAxisDir), pulling hair DOWN
                        // hairline < 0 (Làm cao chân tóc): destination p samples from forehead (+faceAxisDir), pushing hair UP
                        offset -= faceAxisDir * (hairline * 0.26 * browDist * totalW);
                    }
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
                float mRad = faceW * 0.20;
                float distMC = length(p - mouthCenter);
                if (distMC < mRad) {
                    float t = distMC / mRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    offset += faceAxisDir * (mouthPos * 0.45 * w * mRad);
                }
            }

            // F. Smile Corners (Tạo khóe cười / M-line smile corner lift)
            float smileCorners = miscParams.z;
            if (smileCorners > 0.001) {
                float cornerRad = faceW * 0.095;
                // Left mouth corner (camera left / person's right)
                float distLC = length(p - leftMouthCorner);
                if (distLC < cornerRad) {
                    float t = distLC / cornerRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    // Lift upward (-faceAxisDir) and flare slightly outward (-axisNormal)
                    // Inverse offset added to p: +faceAxisDir and +axisNormal
                    vec2 curlOffset = faceAxisDir * 0.85 + axisNormal * 0.32;
                    offset += curlOffset * (smileCorners * 0.26 * faceW * w);
                }
                // Right mouth corner (camera right / person's left)
                float distRC = length(p - rightMouthCorner);
                if (distRC < cornerRad) {
                    float t = distRC / cornerRad;
                    float w = (1.0 - t * t) * (1.0 - t * t);
                    // Lift upward (-faceAxisDir) and flare slightly outward (+axisNormal)
                    // Inverse offset added to p: +faceAxisDir and -axisNormal
                    vec2 curlOffset = faceAxisDir * 0.85 - axisNormal * 0.32;
                    offset += curlOffset * (smileCorners * 0.26 * faceW * w);
                }
            }

            // G. M-Shape / Heart Lips (Môi chữ M / Môi trái tim)
            float mShapeLips = miscParams.w;
            if (mShapeLips > 0.001) {
                vec2 mouthVec = p - mouthCenter;
                float u = dot(mouthVec, axisNormal);   // Horizontal along mouth width
                float v = dot(mouthVec, faceAxisDir);  // Vertical (+ down to chin, - up to nose)

                float mouthHalfW = max(faceW * 0.12, length(rightMouthCorner - leftMouthCorner) * 0.5);
                float lipHalfH = faceW * 0.075;

                float xNorm = u / mouthHalfW; // -1.0 at left corner, +1.0 at right corner
                float yNorm = v / lipHalfH;   // -1.0 at upper vermilion border, +1.0 at lower vermilion border

                if (abs(xNorm) <= 1.25 && abs(yNorm) <= 1.5) {
                    // Smooth 2D spatial envelope around the lips
                    float envX = (1.0 - min(1.0, abs(xNorm) / 1.25));
                    envX = envX * envX;
                    float envY = (1.0 - min(1.0, abs(yNorm) / 1.5));
                    envY = envY * envY;
                    float env = envX * envY;

                    float shiftY = 0.0;
                    float ax = abs(xNorm);

                    // 1. Upper Lip (yNorm <= 0.2): Sculpt M-shape contour
                    if (yNorm <= 0.2) {
                        // A. Two Cupid's Bow peaks at ax ~ 0.32: lift upward
                        // In CIWarpKernel, to lift upward (-faceAxisDir), offset must be +faceAxisDir
                        float peakDist = abs(ax - 0.32) / 0.18;
                        if (peakDist < 1.0) {
                            float wPeak = (1.0 - peakDist * peakDist);
                            shiftY += wPeak * wPeak * 0.55;
                        }

                        // B. Central Upper Tubercle (hạt môi/củ môi giữa) at ax < 0.20:
                        // Pull down (+faceAxisDir), offset must be -faceAxisDir
                        float centerDist = ax / 0.20;
                        if (centerDist < 1.0) {
                            float wCenter = (1.0 - centerDist * centerDist);
                            shiftY -= wCenter * wCenter * 0.45;
                        }

                        // C. Gentle arching along lateral upper lip (ax ~ 0.55 to 0.85)
                        float wingDist = abs(ax - 0.70) / 0.20;
                        if (wingDist < 1.0) {
                            float wWing = (1.0 - wingDist * wingDist);
                            shiftY += wWing * wWing * 0.22;
                        }
                    }

                    // 2. Lower Lip (yNorm > -0.1): Sculpt heart-shaped cleft & dual rounded lobes
                    if (yNorm > -0.1) {
                        // A. Central heart cleft: subtle upward dip at center bottom
                        float cleftDist = ax / 0.18;
                        if (cleftDist < 1.0) {
                            float wCleft = (1.0 - cleftDist * cleftDist);
                            shiftY += wCleft * wCleft * 0.35;
                        }

                        // B. Dual rounded lower lobes (2 túi mỡ môi dưới) at ax ~ 0.38:
                        float lobeDist = abs(ax - 0.38) / 0.20;
                        if (lobeDist < 1.0) {
                            float wLobe = (1.0 - lobeDist * lobeDist);
                            shiftY -= wLobe * wLobe * 0.40;
                        }
                    }

                    // 3. Subtle corner smile lift for sweet expression at corners (ax > 0.75)
                    if (ax > 0.75 && ax < 1.2) {
                        float cornerDist = abs(ax - 0.95) / 0.25;
                        if (cornerDist < 1.0) {
                            float wCorner = (1.0 - cornerDist * cornerDist);
                            shiftY += wCorner * wCorner * 0.25;
                        }
                    }

                    // Apply vertical M-sculpting offset along faceAxisDir
                    offset += faceAxisDir * (shiftY * mShapeLips * faceW * 0.045 * env);
                }
            }

            // ==========================================
            // GROUP 5: CHÂN MÀY (EYEBROWS)
            // ==========================================
            float browHeight = browParams.x; // Độ cao chân mày (dịch chuyển toàn bộ mày)
            float browTilt   = browParams.y; // Độ nghiêng chân mày (full mày)
            float browArch   = browParams.z; // Cung chân mày (uốn cong vòm cung)

            if (abs(browHeight) > 0.001 || abs(browTilt) > 0.001 || abs(browArch) > 0.001) {
                float halfBrowLen = faceW * 0.22;
                float halfBrowThick = faceW * 0.09;

                // A. Left Eyebrow (Camera Left)
                vec2 vBL = p - leftBrowCenter;
                float uL = dot(vBL, axisNormal);
                float wL = dot(vBL, faceAxisDir);
                float absUL = abs(uL);
                float absWL = abs(wL);

                if (absUL < halfBrowLen && absWL < halfBrowThick) {
                    float normUL = absUL / halfBrowLen;
                    float normWL = absWL / halfBrowThick;
                    float wW = (1.0 - normWL * normWL) * (1.0 - normWL * normWL);

                    // 1. Eyebrow Height: Dịch chuyển tịnh tiến toàn bộ vùng chân mày đồng đều
                    float tU_height = clamp((normUL - 0.60) / 0.40, 0.0, 1.0);
                    float envHeight = (1.0 - tU_height * tU_height) * wW;
                    float shiftH = browHeight * 0.015 * faceW * envHeight;

                    // 2. Eyebrow Arch: Uốn cong/nâng vòm cung tại trung tâm, neo giữ đầu và đuôi
                    float dSqArch = (uL / (faceW * 0.16)) * (uL / (faceW * 0.16)) + normWL * normWL;
                    float envArch = dSqArch < 1.0 ? (1.0 - dSqArch) * (1.0 - dSqArch) : 0.0;
                    float shiftA = browArch * 0.015 * faceW * envArch;

                    // 3. Eyebrow Tilt: Xoay full mày, tác động 100% lên phần đầu chân mày
                    float tiltSignL = -uL / (halfBrowLen * 0.65);
                    float tU_tilt = clamp((normUL - 0.70) / 0.30, 0.0, 1.0);
                    float envTilt = (1.0 - tU_tilt * tU_tilt) * (1.0 - tU_tilt * tU_tilt) * wW;
                    float shiftT = tiltSignL * browTilt * 0.012 * faceW * envTilt;

                    offset += faceAxisDir * (shiftH + shiftA + shiftT);
                }

                // B. Right Eyebrow (Camera Right)
                vec2 vBR = p - rightBrowCenter;
                float uR = dot(vBR, axisNormal);
                float wR = dot(vBR, faceAxisDir);
                float absUR = abs(uR);
                float absWR = abs(wR);

                if (absUR < halfBrowLen && absWR < halfBrowThick) {
                    float normUR = absUR / halfBrowLen;
                    float normWR = absWR / halfBrowThick;
                    float wW = (1.0 - normWR * normWR) * (1.0 - normWR * normWR);

                    // 1. Eyebrow Height: Dịch chuyển tịnh tiến toàn bộ vùng chân mày đồng đều
                    float tU_height = clamp((normUR - 0.60) / 0.40, 0.0, 1.0);
                    float envHeight = (1.0 - tU_height * tU_height) * wW;
                    float shiftH = browHeight * 0.015 * faceW * envHeight;

                    // 2. Eyebrow Arch: Uốn cong/nâng vòm cung tại trung tâm, neo giữ đầu và đuôi
                    float dSqArch = (uR / (faceW * 0.16)) * (uR / (faceW * 0.16)) + normWR * normWR;
                    float envArch = dSqArch < 1.0 ? (1.0 - dSqArch) * (1.0 - dSqArch) : 0.0;
                    float shiftA = browArch * 0.015 * faceW * envArch;

                    // 3. Eyebrow Tilt: Xoay full mày, tác động 100% lên phần đầu chân mày
                    float tiltSignR = uR / (halfBrowLen * 0.65);
                    float tU_tilt = clamp((normUR - 0.70) / 0.30, 0.0, 1.0);
                    float envTilt = (1.0 - tU_tilt * tU_tilt) * (1.0 - tU_tilt * tU_tilt) * wW;
                    float shiftT = tiltSignR * browTilt * 0.012 * faceW * envTilt;

                    offset += faceAxisDir * (shiftH + shiftA + shiftT);
                }
            }

            // ==========================================
            // ==========================================
            // GROUP 6: NỌNG CẰM & ĐƯỜNG VIỀN HÀM (DOUBLE CHIN & JAWLINE DEFINITION)
            // ==========================================
            // Note: Double chin reduction and jawline definition are handled via
            // anatomical optical submental depth shadowing & mandibular bone definition
            // in applySubmentalJawlineDepth(), rather than geometric distortion.
            // This prevents neck, collar, and background warping/stretching artifacts.

            return p + offset;
        }
        """
        self.reshapeKernel = CIWarpKernel(source: kernelString)
    }

    private func setupSkinSmoothKernel() {
        let kernelString = """
        kernel vec4 naturalBeautySmooth(
            sampler originalImage,
            float smoothFactor,
            float textureFactor,
            float skinThreshold,
            float sampleRadius
        ) {
            vec2 pos = samplerCoord(originalImage);
            vec4 center = sample(originalImage, pos);
            vec3 centerRGB = center.rgb;

            vec3 accumColor = centerRGB;
            float totalWeight = 1.0;

            // Concentric 20-sample pattern for smooth, natural coverage
            vec2 d1  = vec2( 0.0,    1.0);
            vec2 d2  = vec2( 0.866,  0.5);
            vec2 d3  = vec2( 0.866, -0.5);
            vec2 d4  = vec2( 0.0,   -1.0);
            vec2 d5  = vec2(-0.866, -0.5);
            vec2 d6  = vec2(-0.866,  0.5);

            vec2 d7  = vec2( 1.414,  1.414);
            vec2 d8  = vec2( 2.0,    0.0);
            vec2 d9  = vec2( 1.414, -1.414);
            vec2 d10 = vec2( 0.0,   -2.0);
            vec2 d11 = vec2(-1.414, -1.414);
            vec2 d12 = vec2(-2.0,    0.0);
            vec2 d13 = vec2(-1.414,  1.414);
            vec2 d14 = vec2( 0.0,    2.0);

            vec2 d15 = vec2( 2.77,   1.6);
            vec2 d16 = vec2( 2.77,  -1.6);
            vec2 d17 = vec2( 0.0,   -3.2);
            vec2 d18 = vec2(-2.77,  -1.6);
            vec2 d19 = vec2(-2.77,   1.6);
            vec2 d20 = vec2( 0.0,    3.2);

            vec3 col; vec3 diff; float distSq; float w;

            col = sample(originalImage, pos + d1 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d2 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d3 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d4 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d5 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d6 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.95; accumColor += col * w; totalWeight += w;

            col = sample(originalImage, pos + d7 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d8 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d9 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d10 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d11 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d12 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d13 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d14 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.75; accumColor += col * w; totalWeight += w;

            col = sample(originalImage, pos + d15 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d16 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d17 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d18 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d19 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;
            col = sample(originalImage, pos + d20 * sampleRadius).rgb; diff = col - centerRGB; distSq = dot(diff, diff); w = exp(-distSq * skinThreshold) * 0.50; accumColor += col * w; totalWeight += w;

            vec3 smoothed = accumColor / totalWeight;

            // Frequency Separation:
            // highFreq isolates genuine micro-skin pores and fine textural detail
            vec3 highFreq = centerRGB - smoothed;
            float detailMagnitude = length(highFreq);

            // Edge guard protects facial contours, eyes, lips and brows from blurring
            float edgeGuard = 1.0 - smoothstep(0.08, 0.30, detailMagnitude);

            // Base smooth blends low/mid-frequency blotches and acne blemishes
            vec3 smoothBase = mix(centerRGB, smoothed, smoothFactor * edgeGuard);

            // Frequency-separated micro-texture restoration (eliminates plastic/wax face look)
            vec3 pores = clamp(highFreq, vec3(-0.025), vec3(0.025));
            float textureWeight = textureFactor * 0.65;
            vec3 resultRGB = clamp(smoothBase + pores * (smoothFactor * textureWeight * edgeGuard), 0.0, 1.0);

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
        landmarks: FaceMeshLandmarks,
        skinMask: CIImage? = nil
    ) {
        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)
        let extent = CGRect(x: 0, y: 0, width: width, height: height)

        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)

        if !beautyEnabled || compareMode == "raw" {
            CVBufferPropagateAttachments(sourceBuffer, targetBuffer)
            ciContext.render(sourceImage, to: targetBuffer, bounds: extent, colorSpace: colorSpace)
            return
        }

        var processedImage = sourceImage
        if !landmarks.hasFace {
            hasPreviousTeethFrame = false
            smoothedTeethOpenGate = 0.0
        }

        // 1. 3D Face Reshaping (Smooth GPU Warp using 468 landmark anchors - zero polygon overlays)
        let hasReshape = face.slimFace > 0.01 || face.smallFace > 0.01 || face.vFace > 0.01 ||
                         abs(face.jawWidth) > 0.01 || abs(face.cheekWidth) > 0.01 ||
                         abs(face.chinLength) > 0.01 || abs(face.chinWidth) > 0.01 ||
                         abs(face.forehead) > 0.01 || abs(face.templeWidth) > 0.01 ||
                         abs(face.hairline) > 0.01 ||
                         face.eyeSize > 0.01 || abs(face.eyeDistance) > 0.01 ||
                         abs(face.eyeHeight) > 0.01 || abs(face.eyeAngle) > 0.01 ||
                         abs(face.eyebrowHeight) > 0.01 || abs(face.eyebrowArch) > 0.01 || abs(face.eyebrowTilt) > 0.01 ||
                         abs(face.noseWidth) > 0.01 || abs(face.noseBridge) > 0.01 ||
                         abs(face.noseTip) > 0.01 || abs(face.noseLength) > 0.01 ||
                         abs(face.nostrilWidth) > 0.01 ||
                         face.smile > 0.01 || face.smileCorners > 0.01 || face.mShapeLips > 0.01 || abs(face.mouthWidth) > 0.01 ||
                         abs(face.mouthSize) > 0.01 || abs(face.lipThickness) > 0.01 ||
                         abs(face.mouthPosition) > 0.01

        // 2. Skin Beautification (Natural Edge-Preserving Bilateral Smoothing, Pore Texture, Translucent Whitening)
        let hasSkinBeauty = beauty.smooth > 0.01 || beauty.skinTone > 0.01 || beauty.skinToneType != "natural" ||
                            beauty.whitening > 0.01 || beauty.skinBrightness > 0.01 || beauty.redness > 0.01 ||
                            beauty.darkCircle > 0.01 || beauty.eyeBag > 0.01 ||
                            beauty.teethWhitening > 0.01 || face.eyeBrightness > 0.01 || face.eyeSparkle > 0.01 ||
                            beauty.glassSkin > 0.01 || face.aegyoSal > 0.01

        if hasSkinBeauty && landmarks.hasFace {
            processedImage = applySkinBeauty(
                image: processedImage,
                beauty: beauty,
                face: face,
                landmarks: landmarks,
                extent: extent,
                skinMask: skinMask
            )
        }

        // 3. 3D Face Makeup (Lipstick, Blush, Eyebrows, Eyeliner, Eyeshadow, Contour)
        let hasMakeup = (makeup.lipPreset != "none" && makeup.lipOpacity > 0.01) ||
                        (makeup.blushPreset != "none" && makeup.blushOpacity > 0.01) ||
                        (makeup.eyebrowPreset != "none" && makeup.eyebrowOpacity > 0.01) ||
                        (makeup.eyelinerPreset != "none" && makeup.eyelinerOpacity > 0.01) ||
                        (makeup.eyeshadowPreset != "none" && makeup.eyeshadowOpacity > 0.01) ||
                        (makeup.contourPreset != "none" && makeup.contourOpacity > 0.01)

        if hasMakeup && landmarks.hasFace {
            processedImage = applyMakeup(
                image: processedImage,
                makeup: makeup,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 3b. Submental Depth & Jawline Contouring (Giảm nọng cằm & Viền hàm bằng hiệu ứng đổ bóng chiều sâu thay vì méo hình)
        if (face.doubleChin > 0.001 || face.jawline > 0.001) && landmarks.hasFace {
            processedImage = applySubmentalJawlineDepth(
                image: processedImage,
                doubleChin: face.doubleChin,
                jawline: face.jawline,
                landmarks: landmarks,
                extent: extent,
                skinMask: skinMask
            )
        }

        // Warp skin, makeup and their boundaries together, in the source landmark coordinate space.
        if hasReshape && landmarks.hasFace {
            processedImage = applyFaceReshape(image: processedImage, face: face, landmarks: landmarks, extent: extent)
        }

        // 4. Color adjustments (Real-time GPU)
        processedImage = applyColorAdjustments(image: processedImage, color: color)

        // 5. Aesthetic Filters
        if filter.filterId != "original" && filter.intensity > 0.01 {
            processedImage = applyFilter(image: processedImage, baseImage: sourceImage, filterId: filter.filterId, intensity: filter.intensity)
        }

        // 6. Background Effects (if enabled)
        if background.mode != "none" && background.blurIntensity > 0.01 {
            processedImage = applyBackgroundEffects(
                image: processedImage,
                sourceBuffer: sourceBuffer,
                mode: background.mode,
                intensity: background.blurIntensity,
                landmarks: landmarks,
                extent: extent
            )
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
        CVBufferPropagateAttachments(sourceBuffer, targetBuffer)
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
        let smileCorners = CGFloat(face.smileCorners)
        let mouthWidth = CGFloat(face.mouthWidth)
        let mouthSize = CGFloat(face.mouthSize)
        let lipThickness = CGFloat(face.lipThickness)

        let mouthPos = CGFloat(face.mouthPosition)
        let nostrilWidth = CGFloat(face.nostrilWidth)
        let mShapeLips = CGFloat(face.mShapeLips)

        // Brow Centers (True midpoint between inner head and outer tail)
        func browCenterFromLandmarks(headIdxA: Int, headIdxB: Int, tailIdxA: Int, tailIdxB: Int) -> CGPoint {
            let lmHeadA = landmarks.landmarks[headIdxA]
            let lmHeadB = landmarks.landmarks[headIdxB]
            let lmTailA = landmarks.landmarks[tailIdxA]
            let lmTailB = landmarks.landmarks[tailIdxB]
            let head = CGPoint(x: CGFloat(lmHeadA.x + lmHeadB.x) * 0.5, y: CGFloat(lmHeadA.y + lmHeadB.y) * 0.5)
            let tail = CGPoint(x: CGFloat(lmTailA.x + lmTailB.x) * 0.5, y: CGFloat(lmTailA.y + lmTailB.y) * 0.5)
            return ciPt(CGPoint(x: (head.x + tail.x) * 0.5, y: (head.y + tail.y) * 0.5))
        }

        func browCenterFromContour(_ contour: [CGPoint]) -> CGPoint {
            guard contour.count >= 10 else {
                let sumX = contour.reduce(0) { $0 + $1.x }
                let sumY = contour.reduce(0) { $0 + $1.y }
                let n = CGFloat(max(1, contour.count))
                return ciPt(CGPoint(x: sumX / n, y: sumY / n))
            }
            // contour[4] & [5] is head, contour[0] & [9] is tail
            let head = CGPoint(x: (contour[4].x + contour[5].x) * 0.5, y: (contour[4].y + contour[5].y) * 0.5)
            let tail = CGPoint(x: (contour[0].x + contour[9].x) * 0.5, y: (contour[0].y + contour[9].y) * 0.5)
            return ciPt(CGPoint(x: (head.x + tail.x) * 0.5, y: (head.y + tail.y) * 0.5))
        }

        let leftBrowCenter: CGPoint
        let rightBrowCenter: CGPoint
        if !landmarks.rightEyebrowContour.isEmpty && !landmarks.leftEyebrowContour.isEmpty {
            leftBrowCenter = browCenterFromContour(landmarks.rightEyebrowContour)
            rightBrowCenter = browCenterFromContour(landmarks.leftEyebrowContour)
        } else if landmarks.landmarks.count == 468 {
            // Camera Left (Subject Right): head [107, 55], tail [70, 46]
            leftBrowCenter = browCenterFromLandmarks(headIdxA: 107, headIdxB: 55, tailIdxA: 70, tailIdxB: 46)
            // Camera Right (Subject Left): head [336, 285], tail [300, 276]
            rightBrowCenter = browCenterFromLandmarks(headIdxA: 336, headIdxB: 285, tailIdxA: 300, tailIdxB: 276)
        } else {
            leftBrowCenter = CGPoint(x: leftEyeCenter.x - axisDir.y * faceW * 0.08, y: leftEyeCenter.y + axisDir.x * faceW * 0.08)
            rightBrowCenter = CGPoint(x: rightEyeCenter.x - axisDir.y * faceW * 0.08, y: rightEyeCenter.y + axisDir.x * faceW * 0.08)
        }

        let eyebrowHeight = CGFloat(face.eyebrowHeight)
        let eyebrowTilt = CGFloat(face.eyebrowTilt)
        let eyebrowArch = CGFloat(face.eyebrowArch)
        let hairline = CGFloat(face.hairline)

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
            CIVector(x: mouthPos, y: nostrilWidth, z: smileCorners, w: mShapeLips),
            CIVector(x: leftBrowCenter.x, y: leftBrowCenter.y, z: rightBrowCenter.x, w: rightBrowCenter.y),
            CIVector(x: eyebrowHeight, y: eyebrowTilt, z: eyebrowArch, w: hairline),
            CIVector(x: CGFloat(face.doubleChin), y: CGFloat(face.jawline), z: 0.0, w: 0.0)
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
        extent: CGRect,
        skinMask: CIImage? = nil
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

        // Dual-Core Mask: Core 2 (Selfie Multiclass Segmentation Class 3: Face-Skin)
        // Fallback: Core 1 (MediaPipe Face Landmarker convex contour)
        let maskToUse = createFaceSkinMask(segmentationMask: skinMask, landmarks: landmarks, extent: extent)

        // Edge-aware natural smoothing with radius proportional to face scale & micro-pore retention
        if beauty.smooth > 0.01 {
            let sampleRadius = min(8.5, max(1.8, faceW * 0.010))
            var smoothedSkin: CIImage?
            if let kernel = skinSmoothKernel {
                let smoothFactor = Float(min(1.0, max(0.0, beauty.smooth)))
                let textureFactor = Float(min(1.0, max(0.0, beauty.skinTexture)))
                let skinThreshold = Float(50.0 - beauty.smooth * 25.0)
                let args: [Any] = [
                    current.clampedToExtent(),
                    smoothFactor,
                    textureFactor,
                    skinThreshold,
                    Float(sampleRadius)
                ]
                smoothedSkin = kernel.apply(
                    extent: extent,
                    roiCallback: { _, rect in rect.insetBy(dx: -32, dy: -32) },
                    arguments: args
                )?.cropped(to: extent)
            }

            let skinToBlend = smoothedSkin ?? current

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

        // 1.5 Skin Tone Adjustment (Tông da chuyên biệt trên mặt nạ da 468 landmarks)
        if (beauty.skinTone > 0.01 || beauty.skinToneType != "natural"), let mask = maskToUse {
            current = applySkinTone(
                image: current,
                tone: beauty.skinTone,
                type: beauty.skinToneType,
                mask: mask,
                extent: extent
            )
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

        // 4. Teeth Whitening (Anti-flicker anatomical gate & stabilized oral aperture)
        if beauty.teethWhitening > 0.01 {
            if let mouthMask = createTeethMask(landmarks: landmarks, extent: extent),
               let whitened = teethWhiteningKernel?.apply(extent: extent,
                    arguments: [current, mouthMask, Float(beauty.teethWhitening)]) {
                current = whitened
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

        // 6. Eyeball Brightening & Sparkling Eyes (face.eyeBrightness & face.eyeSparkle)
        if face.eyeBrightness > 0.01 || face.eyeSparkle > 0.01 {
            if let eyeballMask = createEyeballMask(landmarks: landmarks, extent: extent) {
                if face.eyeBrightness > 0.01 {
                    current = applyEyeBrightening(
                        image: current,
                        intensity: face.eyeBrightness,
                        eyeballMask: eyeballMask,
                        extent: extent
                    )
                }
                if face.eyeSparkle > 0.01 {
                    current = applyEyeSparkle(
                        image: current,
                        intensity: face.eyeSparkle,
                        style: face.eyeSparkleStyle,
                        eyeballMask: eyeballMask,
                        landmarks: landmarks,
                        extent: extent
                    )
                }
            }
        }

        // 7. Aegyo-Sal / Bọng mắt cười (face.aegyoSal)
        if face.aegyoSal > 0.01 {
            current = applyAegyoSal(
                image: current,
                intensity: face.aegyoSal,
                landmarks: landmarks,
                extent: extent
            )
        }

        // 8. Glass Skin / Làm da bóng mịn (beauty.glassSkin)
        if beauty.glassSkin > 0.01 {
            current = applyGlassSkin(
                image: current,
                intensity: beauty.glassSkin,
                landmarks: landmarks,
                extent: extent,
                skinMask: skinMask
            )
        }

        return current
    }

    // MARK: - Skin Tone Adjustment (Tông da chuyên biệt trên lớp mặt nạ da)
    private func applySkinTone(
        image: CIImage,
        tone: Double,
        type: String,
        mask: CIImage,
        extent: CGRect
    ) -> CIImage {
        guard tone > 0.01 || type != "natural" else { return image }
        let intensity = CGFloat(max(0.0, min(1.0, tone)))

        var toned = image

        switch type {
        case "porcelain": // Trắng sứ: Alabaster cold-fair, giảm sắc vàng sạm, sáng mịn
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.04 * intensity
                let gGain = 1.0 - 0.02 * intensity
                let bGain = 1.0 + 0.12 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(toned, forKey: kCIInputImageKey)
                gamma.setValue(1.0 - 0.10 * intensity, forKey: "inputPower")
                if let out = gamma.outputImage { toned = out }
            }

        case "snow": // Tuyết lạnh: Alabaster cold white, trắng tuyết tinh khôi, sáng bừng midtone
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.05 * intensity
                let gGain = 1.0 + 0.02 * intensity
                let bGain = 1.0 + 0.18 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(toned, forKey: kCIInputImageKey)
                gamma.setValue(1.0 - 0.14 * intensity, forKey: "inputPower")
                if let out = gamma.outputImage { toned = out }
            }

        case "rosy": // Trắng hồng: Ánh hồng đào tươi tắn, rạng rỡ trẻ trung
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.14 * intensity
                let gGain = 1.0 - 0.03 * intensity
                let bGain = 1.0 + 0.06 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(0.02 * intensity, forKey: kCIInputBrightnessKey)
                cc.setValue(1.0 + 0.08 * intensity, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage { toned = out }
            }

        case "cherry": // Anh đào: Ánh hồng anh đào phớt tím thanh tú, khử sạm xỉn
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.15 * intensity
                let gGain = 1.0 - 0.03 * intensity
                let bGain = 1.0 + 0.10 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(0.02 * intensity, forKey: kCIInputBrightnessKey)
                cc.setValue(1.0 + 0.06 * intensity, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage { toned = out }
            }

        case "peach": // Hồng đào: Tông cam đào ngọt ngào, ấm mượt
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.12 * intensity
                let gGain = 1.0 + 0.03 * intensity
                let bGain = 1.0 - 0.08 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(1.0 + 0.10 * intensity, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage { toned = out }
            }

        case "coral": // San hô: Sắc cam san hô tươi sáng, tràn đầy năng lượng
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.15 * intensity
                let gGain = 1.0 + 0.05 * intensity
                let bGain = 1.0 - 0.06 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(0.01 * intensity, forKey: kCIInputBrightnessKey)
                cc.setValue(1.0 + 0.10 * intensity, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage { toned = out }
            }

        case "warm": // Nắng ấm: Sắc nắng mật ong vàng óng, da khỏe khoắn
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(toned, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 6500.0 + 1600.0 * intensity, y: 15.0 * intensity), forKey: "inputTargetNeutral")
                if let out = tt.outputImage { toned = out }
            }
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.06 * intensity
                let gGain = 1.0 + 0.04 * intensity
                let bGain = 1.0 - 0.06 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }

        case "honey": // Mật ong: Ánh vàng mật ong căng bóng, da bóng khỏe rạng ngời
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.09 * intensity
                let gGain = 1.0 + 0.07 * intensity
                let bGain = 1.0 - 0.04 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(toned, forKey: kCIInputImageKey)
                gamma.setValue(1.0 - 0.06 * intensity, forKey: "inputPower")
                if let out = gamma.outputImage { toned = out }
            }

        case "wheat": // Lúa mì: Tông lúa mì vàng sáng trang nhã, ấm áp
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.07 * intensity
                let gGain = 1.0 + 0.04 * intensity
                let bGain = 1.0 - 0.08 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(1.0 + 0.06 * intensity, forKey: kCIInputContrastKey)
                if let out = cc.outputImage { toned = out }
            }

        case "olive": // Ô-liu: Tông olive trung tính, giảm đỏ sưng và cân bằng sắc tố da
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 - 0.04 * intensity
                let gGain = 1.0 + 0.05 * intensity
                let bGain = 1.0 + 0.02 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(0.01 * intensity, forKey: kCIInputBrightnessKey)
                cc.setValue(1.0 + 0.04 * intensity, forKey: kCIInputContrastKey)
                if let out = cc.outputImage { toned = out }
            }

        case "tan": // Bánh mật: Nâu rám nắng phương Tây sang trọng, tương phản cao
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(toned, forKey: kCIInputImageKey)
                cc.setValue(-0.04 * intensity, forKey: kCIInputBrightnessKey)
                cc.setValue(1.0 + 0.12 * intensity, forKey: kCIInputContrastKey)
                cc.setValue(1.0 + 0.15 * intensity, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage { toned = out }
            }
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(toned, forKey: kCIInputImageKey)
                let rGain = 1.0 + 0.08 * intensity
                let gGain = 1.0 - 0.02 * intensity
                let bGain = 1.0 - 0.14 * intensity
                matrix.setValue(CIVector(x: rGain, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: gGain, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: bGain, w: 0.0), forKey: "inputBVector")
                if let out = matrix.outputImage { toned = out }
            }

        case "natural": // Tự nhiên: Cân bằng ấm/lạnh tinh tế
            if intensity > 0.01 {
                if let tt = CIFilter(name: "CITemperatureAndTint") {
                    tt.setValue(toned, forKey: kCIInputImageKey)
                    tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                    tt.setValue(CIVector(x: 6500.0 + 1000.0 * intensity, y: 0.0), forKey: "inputTargetNeutral")
                    if let out = tt.outputImage { toned = out }
                }
            }

        default:
            break
        }

        // Blend onto face skin with mesh mask (zero color bleed onto background/clothes)
        if let blend = CIFilter(name: "CIBlendWithMask") {
            blend.setValue(toned, forKey: kCIInputImageKey)
            blend.setValue(image, forKey: kCIInputBackgroundImageKey)
            blend.setValue(mask, forKey: kCIInputMaskImageKey)
            if let out = blend.outputImage { return out }
        }

        return toned
    }

    // MARK: - Makeup (Lipstick, Blush, Eyebrows, Eyeliner, Eyeshadow)
    private func applyMakeup(image: CIImage, makeup: MakeupSettings, landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage {
        guard landmarks.hasFace else { return image }
        var result = image

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)

        func ciPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        // 1. Lipstick (Exact 3D Contour Mask with Teeth & Oral Cavity Cutout + Styles: Full, Gradient, Liner, Gloss)
        if makeup.lipPreset != "none" && makeup.lipOpacity > 0.01 {
            var lipR: CGFloat = 0.88; var lipG: CGFloat = 0.12; var lipB: CGFloat = 0.18
            switch makeup.lipPreset {
            case "red":       lipR = 0.88; lipG = 0.12; lipB = 0.18
            case "ruby":      lipR = 0.72; lipG = 0.08; lipB = 0.16
            case "chili":     lipR = 0.78; lipG = 0.22; lipB = 0.16
            case "cherry":    lipR = 0.68; lipG = 0.10; lipB = 0.20
            case "wine":      lipR = 0.50; lipG = 0.08; lipB = 0.16
            case "coral":     lipR = 0.90; lipG = 0.38; lipB = 0.32
            case "orange":    lipR = 0.85; lipG = 0.35; lipB = 0.20
            case "peach":     lipR = 0.92; lipG = 0.48; lipB = 0.44
            case "rose":      lipR = 0.80; lipG = 0.32; lipB = 0.44
            case "pink":      lipR = 0.92; lipG = 0.42; lipB = 0.58
            case "nude":      lipR = 0.82; lipG = 0.50; lipB = 0.45
            case "nudePink":  lipR = 0.85; lipG = 0.55; lipB = 0.55
            case "berry":     lipR = 0.68; lipG = 0.16; lipB = 0.32
            case "plum":      lipR = 0.48; lipG = 0.15; lipB = 0.28
            case "brown":     lipR = 0.62; lipG = 0.32; lipB = 0.28
            case "caramel":   lipR = 0.72; lipG = 0.38; lipB = 0.24
            default:          lipR = 0.88; lipG = 0.12; lipB = 0.18
            }

            let lipStyle = makeup.lipStyle
            if let lipMask = createLipMask(landmarks: landmarks, style: lipStyle, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: lipR, green: lipG, blue: lipB, alpha: 1.0)).cropped(to: extent)
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(colorImg, forKey: kCIInputImageKey)
                    softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let softLightLips = softLight.outputImage {
                        var tintedLips = softLightLips

                        // For "gradient" (lòng môi):
                        // Inner core needs to be deeply saturated and intensely pigmented ("đậm từ trong ra ngoài").
                        // We composite a rich multiply stain layer so the center has deep, luscious color depth.
                        if lipStyle == "gradient",
                           let multiply = CIFilter(name: "CIMultiplyBlendMode") {
                            let deepR = max(0.0, lipR * 0.90)
                            let deepG = max(0.0, lipG * 0.60)
                            let deepB = max(0.0, lipB * 0.60)
                            let deepColor = CIImage(color: CIColor(red: deepR, green: deepG, blue: deepB, alpha: 1.0)).cropped(to: extent)
                            multiply.setValue(deepColor, forKey: kCIInputImageKey)
                            multiply.setValue(result, forKey: kCIInputBackgroundImageKey)
                            if let multLips = multiply.outputImage {
                                if let stainBlend = CIFilter(name: "CISoftLightBlendMode") {
                                    stainBlend.setValue(multLips, forKey: kCIInputImageKey)
                                    stainBlend.setValue(softLightLips, forKey: kCIInputBackgroundImageKey)
                                    if let rich = stainBlend.outputImage {
                                        tintedLips = rich
                                    }
                                }
                            }
                        }

                        var effMask = lipMask
                        let opacity = CGFloat(min(1.0, makeup.lipOpacity * 0.90))
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(lipMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: opacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                            matrix.setValue(CIVector(x: 0, y: opacity, z: 0, w: 0), forKey: "inputGVector")
                            matrix.setValue(CIVector(x: 0, y: 0, z: opacity, w: 0), forKey: "inputBVector")
                            if let out = matrix.outputImage { effMask = out }
                        }
                        if let blend = CIFilter(name: "CIBlendWithMask") {
                            blend.setValue(tintedLips, forKey: kCIInputImageKey)
                            blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                            blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                            if let blended = blend.outputImage {
                                result = blended

                                // 3D Gloss Highlight Sheen for "gloss" style (Refined, glassy sheen with natural specular tone)
                                if lipStyle == "gloss",
                                   let glossHl = createLipGlossHighlights(landmarks: landmarks, lipMask: lipMask, faceW: faceW, extent: extent, lipR: lipR, lipG: lipG, lipB: lipB, opacity: makeup.lipOpacity) {
                                    if let screen = CIFilter(name: "CIScreenBlendMode") {
                                        screen.setValue(glossHl, forKey: kCIInputImageKey)
                                        screen.setValue(result, forKey: kCIInputBackgroundImageKey)
                                        if let glossy = screen.outputImage?.cropped(to: extent) {
                                            result = glossy
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. Blush (Styles: apple, sunkissed, lifted, undereye, contour)
        if makeup.blushPreset != "none" && makeup.blushOpacity > 0.01 {
            var bR: CGFloat = 0.98; var bG: CGFloat = 0.48; var bB: CGFloat = 0.56
            switch makeup.blushPreset {
            case "peach":      bR = 0.98; bG = 0.56; bB = 0.44
            case "coral":      bR = 0.98; bG = 0.50; bB = 0.42
            case "apricot":    bR = 0.98; bG = 0.62; bB = 0.46
            case "strawberry": bR = 0.98; bG = 0.36; bB = 0.48
            case "mauve":      bR = 0.88; bG = 0.48; bB = 0.65
            case "terracotta": bR = 0.85; bG = 0.42; bB = 0.32
            case "plum":       bR = 0.78; bG = 0.38; bB = 0.55
            case "cherry":     bR = 0.90; bG = 0.28; bB = 0.38
            case "rosy":       fallthrough
            default:           bR = 0.98; bG = 0.48; bB = 0.56
            }

            if let blushOverlay = createStyledBlush(
                extent: extent,
                landmarks: landmarks,
                style: makeup.blushStyle,
                faceW: faceW,
                intensity: makeup.blushOpacity * 0.55,
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

        // 3. Eyebrows (Enhanced contour, styling & tinting)
        if makeup.eyebrowPreset != "none" && makeup.eyebrowOpacity > 0.01 {
            var eR: CGFloat = 0.30; var eG: CGFloat = 0.22; var eB: CGFloat = 0.18
            switch makeup.eyebrowPreset {
            case "black":     eR = 0.13; eG = 0.13; eB = 0.13
            case "darkBrown": eR = 0.24; eG = 0.17; eB = 0.12
            case "natural":   eR = 0.35; eG = 0.27; eB = 0.23
            case "chestnut":  fallthrough
            case "brown":     eR = 0.31; eG = 0.21; eB = 0.16
            case "ashBrown":  eR = 0.36; eG = 0.32; eB = 0.28
            case "soft":      fallthrough
            case "gray":      eR = 0.29; eG = 0.29; eB = 0.29
            case "blonde":    eR = 0.49; eG = 0.40; eB = 0.32
            case "redBrown":  eR = 0.36; eG = 0.20; eB = 0.16
            default:          eR = 0.30; eG = 0.22; eB = 0.18
            }

            if let browMask = createEyebrowMask(landmarks: landmarks, style: makeup.eyebrowStyle, faceW: faceW, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: eR, green: eG, blue: eB, alpha: 1.0)).cropped(to: extent)
                if let multiply = CIFilter(name: "CIMultiplyBlendMode") {
                    multiply.setValue(colorImg, forKey: kCIInputImageKey)
                    multiply.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = multiply.outputImage {
                        var effMask = browMask
                        let opacity = CGFloat(makeup.eyebrowOpacity * 0.52)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(browMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: opacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                            matrix.setValue(CIVector(x: 0, y: opacity, z: 0, w: 0), forKey: "inputGVector")
                            matrix.setValue(CIVector(x: 0, y: 0, z: opacity, w: 0), forKey: "inputBVector")
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

        // 4. Eyeliner (Lash line definition & styles: natural, classic, cat, puppy, fox)
        if makeup.eyelinerPreset != "none" && makeup.eyelinerOpacity > 0.01 {
            var lR: CGFloat = 0.12; var lG: CGFloat = 0.12; var lB: CGFloat = 0.12
            switch makeup.eyelinerPreset {
            case "black":     lR = 0.08; lG = 0.08; lB = 0.08
            case "classic":   lR = 0.15; lG = 0.15; lB = 0.15
            case "deepBrown": lR = 0.22; lG = 0.15; lB = 0.12
            case "brown":     lR = 0.29; lG = 0.20; lB = 0.17
            case "burgundy":  lR = 0.35; lG = 0.11; lB = 0.14
            case "plum":      lR = 0.26; lG = 0.14; lB = 0.22
            case "navy":      lR = 0.11; lG = 0.15; lB = 0.21
            case "white":     lR = 0.90; lG = 0.90; lB = 0.90
            default:          lR = 0.12; lG = 0.12; lB = 0.12
            }

            let linerStyle = (makeup.eyelinerPreset == "cat" && makeup.eyelinerStyle == "classic") ? "cat" : makeup.eyelinerStyle

            if let linerMask = createEyelinerMask(landmarks: landmarks, style: linerStyle, faceW: faceW, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: lR, green: lG, blue: lB, alpha: 1.0)).cropped(to: extent)
                let filterName = (makeup.eyelinerPreset == "white") ? "CIScreenBlendMode" : "CIMultiplyBlendMode"
                if let blendFilter = CIFilter(name: filterName) {
                    blendFilter.setValue(colorImg, forKey: kCIInputImageKey)
                    blendFilter.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = blendFilter.outputImage {
                        var effMask = linerMask
                        let opacity = CGFloat(makeup.eyelinerOpacity * 0.78)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(linerMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: opacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                            matrix.setValue(CIVector(x: 0, y: opacity, z: 0, w: 0), forKey: "inputGVector")
                            matrix.setValue(CIVector(x: 0, y: 0, z: opacity, w: 0), forKey: "inputBVector")
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

        // 5. Eyeshadow (Upper eyelid styles: gradient, halo, cutCrease, outerV, douyin)
        if makeup.eyeshadowPreset != "none" && makeup.eyeshadowOpacity > 0.01 {
            var sR: CGFloat = 0.63; var sG: CGFloat = 0.53; var sB: CGFloat = 0.50
            switch makeup.eyeshadowPreset {
            case "earth":     sR = 0.63; sG = 0.53; sB = 0.50
            case "peach":     sR = 0.96; sG = 0.64; sB = 0.38
            case "sunset":    sR = 1.00; sG = 0.54; sB = 0.40
            case "rose":      sR = 0.78; sG = 0.46; sB = 0.48
            case "pink":      sR = 0.96; sG = 0.56; sB = 0.69
            case "coral":     sR = 0.98; sG = 0.48; sB = 0.42
            case "mauve":     sR = 0.62; sG = 0.48; sB = 0.56
            case "champagne": sR = 0.91; sG = 0.78; sB = 0.66
            case "smoky":     sR = 0.30; sG = 0.30; sB = 0.30
            default:          sR = 0.63; sG = 0.53; sB = 0.50
            }

            if let shadowMask = createEyeshadowMask(landmarks: landmarks, style: makeup.eyeshadowStyle, faceW: faceW, extent: extent) {
                let colorImg = CIImage(color: CIColor(red: sR, green: sG, blue: sB, alpha: 1.0)).cropped(to: extent)
                if let softLight = CIFilter(name: "CISoftLightBlendMode") {
                    softLight.setValue(colorImg, forKey: kCIInputImageKey)
                    softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let tinted = softLight.outputImage {
                        var effMask = shadowMask
                        let opacity = CGFloat(makeup.eyeshadowOpacity * 0.60)
                        if let matrix = CIFilter(name: "CIColorMatrix") {
                            matrix.setValue(shadowMask, forKey: kCIInputImageKey)
                            matrix.setValue(CIVector(x: opacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                            matrix.setValue(CIVector(x: 0, y: opacity, z: 0, w: 0), forKey: "inputGVector")
                            matrix.setValue(CIVector(x: 0, y: 0, z: opacity, w: 0), forKey: "inputBVector")
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

        // 6. Contour & Highlight Makeup (Trang điểm tạo khối & bắt sáng đa phong cách)
        if makeup.contourPreset != "none" && makeup.contourOpacity > 0.01 {
            result = applyContour(
                image: result,
                makeup: makeup,
                landmarks: landmarks,
                extent: extent
            )
        }

        return result
    }

    // MARK: - 3D Face Teeth Whitening Mask (Anti-Flicker Stabilized Oral Aperture)
    /// Creates an anatomically stabilized inner mouth aperture mask for teeth whitening.
    /// Excludes lips via an inset boundary, prevents edge jitter with soft Gaussian feathering,
    /// and gates whitening based on mouth openness with temporal smoothing to eliminate flickering.
    public func createTeethMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else {
            smoothedTeethOpenGate = 0.0
            hasPreviousTeethFrame = false
            return nil
        }

        let width = extent.width
        let height = extent.height

        var mouthOpenDist: CGFloat = 0.0
        var mouthWidth: CGFloat = 1.0
        var innerPoints: [CGPoint] = []

        if landmarks.landmarks.count == 468 {
            func pt(_ idx: Int) -> CGPoint {
                let lm = landmarks.landmarks[idx]
                return CGPoint(x: CGFloat(lm.x) * width, y: CGFloat(1.0 - lm.y) * height)
            }
            let p13 = pt(13) // upper inner lip center
            let p14 = pt(14) // lower inner lip center
            let p78 = pt(78) // left corner
            let p308 = pt(308) // right corner

            mouthOpenDist = hypot(p14.x - p13.x, p14.y - p13.y)
            mouthWidth = max(10.0, hypot(p308.x - p78.x, p308.y - p78.y))
            innerPoints = FaceMeshGeometry.innerLipContour.map { pt($0) }
        } else if !landmarks.innerLipContour.isEmpty {
            func pt(_ p: CGPoint) -> CGPoint {
                return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
            }
            innerPoints = landmarks.innerLipContour.map { pt($0) }
            let ys = innerPoints.map(\.y)
            let xs = innerPoints.map(\.x)
            mouthOpenDist = (ys.max() ?? 0) - (ys.min() ?? 0)
            mouthWidth = max(10.0, (xs.max() ?? 1) - (xs.min() ?? 0))
        } else {
            return nil
        }

        // Mouth openness ratio (height relative to width)
        let openRatio = mouthOpenDist / mouthWidth

        // Anatomical gate: when lips are closed or barely parted, teeth are physically NOT exposed.
        // Smoothly fade from 0.0 at closed (<= 0.035) to 1.0 at open (>= 0.080)
        let minOpen: CGFloat = 0.035
        let fullOpen: CGFloat = 0.080
        let rawGate = max(0.0, min(1.0, (openRatio - minOpen) / (fullOpen - minOpen)))
        let openGate = Float(rawGate * rawGate * (3.0 - 2.0 * rawGate))

        // Temporal stabilization (EMA) to prevent frame-to-frame threshold oscillation (nhấp nháy)
        if !hasPreviousTeethFrame || smoothedTeethOpenGate <= 0.001 {
            smoothedTeethOpenGate = openGate
            hasPreviousTeethFrame = true
        } else {
            // Fast attack when opening (0.45), smooth decay when closing (0.25)
            let alpha: Float = openGate > smoothedTeethOpenGate ? 0.45 : 0.25
            smoothedTeethOpenGate = smoothedTeethOpenGate * (1.0 - alpha) + openGate * alpha
        }

        guard smoothedTeethOpenGate > 0.005 else { return nil }

        guard innerPoints.count >= 3,
              let minX = innerPoints.map(\.x).min(), let maxX = innerPoints.map(\.x).max(),
              let minY = innerPoints.map(\.y).min(), let maxY = innerPoints.map(\.y).max(),
              maxX - minX > 2, maxY - minY > 2 else { return nil }

        let lipW = maxX - minX
        let lipH = maxY - minY
        let bounds = CGRect(x: minX, y: minY, width: lipW, height: lipH)
            .insetBy(dx: -4, dy: -4).intersection(extent).integral
        guard !bounds.isEmpty,
              let w = Int(exactly: bounds.width), let h = Int(exactly: bounds.height),
              w > 0, h > 0 else { return nil }

        // Inset contour slightly (7%) towards inner center to stay strictly inside oral cavity and off lip borders
        let centerX = (minX + maxX) * 0.5
        let centerY = (minY + maxY) * 0.5
        let insetPoints = innerPoints.map { p -> CGPoint in
            CGPoint(x: centerX + (p.x - centerX) * 0.93,
                    y: centerY + (p.y - centerY) * 0.93)
        }

        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.translateBy(x: -bounds.minX, y: -bounds.minY)

        let path = CGMutablePath()
        path.move(to: insetPoints[0])
        for p in insetPoints.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()

        context.addPath(path)
        context.setFillColor(gray: CGFloat(smoothedTeethOpenGate), alpha: 1.0)
        context.drawPath(using: .eoFill)

        guard let bitmap = context.makeImage() else { return nil }
        let rawMask = CIImage(cgImage: bitmap).transformed(by:
            CGAffineTransform(translationX: bounds.minX, y: bounds.minY))

        // Smooth feathering (radius ~ 2.0 to 4.0 px) removes hard boundary stepping
        let feather = min(4.0, max(1.5, lipH * 0.12))
        return rawMask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: feather])
            .cropped(to: extent)
    }

    // MARK: - 3D Face Makeup Masks
    public func createLipMask(landmarks: FaceMeshLandmarks, style: String = "full", extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else { return nil }
        if let pixels = landmarks.lipPixelMask {
            let black = CIImage(color: .black).cropped(to: extent)
            let coverage = pixels.composited(over: black).cropped(to: extent)
            if style == "full" || style == "gloss" { return coverage }
            // Style intensity remains independent from detected coverage. Every style
            // (including gloss highlights) is clipped by the same current-frame pixels.
            var geometric = landmarks
            geometric.lipPixelMask = nil
            if let styled = createLipMask(landmarks: geometric, style: style, extent: extent) {
                return styled.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: coverage])
                    .cropped(to: extent)
            }
            return coverage
        }
        if landmarks.landmarks.count == 468 {
            func pt(_ idx: Int) -> CGPoint {
                let lm = landmarks.landmarks[idx]
                return CGPoint(x: CGFloat(lm.x) * extent.width, y: CGFloat(1 - lm.y) * extent.height)
            }
            let upperOuter = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291].map(pt)
            let upperInner = [308, 415, 310, 311, 312, 13, 82, 81, 80, 191, 78].map(pt)
            let lowerInner = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308].map(pt)
            let lowerOuter = [291, 375, 321, 405, 314, 17, 84, 181, 91, 146, 61].map(pt)
            return renderLipRibbons(upperOuter: upperOuter, upperInner: upperInner,
                                    lowerInner: lowerInner, lowerOuter: lowerOuter,
                                    style: style, extent: extent)
        } else if !landmarks.outerLipContour.isEmpty {
            func pt(_ p: CGPoint) -> CGPoint {
                return CGPoint(x: p.x * extent.width, y: (1.0 - p.y) * extent.height)
            }
            let outer = landmarks.outerLipContour.map(pt)
            let inner = landmarks.innerLipContour.map(pt)
            let n = outer.count
            let m = inner.count
            guard n >= 4 else { return nil }
            let midOut = n / 2
            let upperOuter = Array(outer[0...midOut])
            let lowerOuter = [outer[midOut]] + Array(outer[midOut..<n]) + [outer[0]]
            let upperInner: [CGPoint]
            let lowerInner: [CGPoint]
            if m >= 4 {
                let midIn = m / 2
                upperInner = [outer[midOut]] + Array(inner[0...midIn].reversed()) + [outer[0]]
                lowerInner = [outer[0]] + Array(inner[midIn..<m]) + [inner[0], outer[midOut]]
            } else {
                upperInner = upperOuter.reversed()
                lowerInner = lowerOuter.reversed()
            }
            return renderLipRibbons(upperOuter: upperOuter, upperInner: upperInner,
                                    lowerInner: lowerInner, lowerOuter: lowerOuter,
                                    style: style, extent: extent)
        }
        return nil
    }

    private func addSmoothCurves(to path: CGMutablePath, points: [CGPoint]) {
        guard points.count >= 2 else { return }
        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }
        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) * 0.14, y: p1.y + (p2.y - p0.y) * 0.14)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) * 0.14, y: p2.y - (p3.y - p1.y) * 0.14)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
    }

    // MARK: - Catmull-Rom Organic Spline Helper
    private func catmullRomSplinePath(points: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        let n = points.count
        guard n >= 3 else {
            if let f = points.first { path.move(to: f) }
            for p in points.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
            return path
        }
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]

            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6.0, y: p1.y + (p2.y - p0.y) / 6.0)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6.0, y: p2.y - (p3.y - p1.y) / 6.0)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        path.closeSubpath()
        return path
    }

    private func createRibbonPath(half1: [CGPoint], half2: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        guard half1.count >= 2, half2.count >= 2 else { return path }
        path.move(to: half1[0])
        addSmoothCurves(to: path, points: half1)
        // Outer and inner corners are distinct anatomical points. Connect them
        // explicitly instead of skipping the first point of the second arc.
        path.addLine(to: half2[0])
        addSmoothCurves(to: path, points: half2)
        path.closeSubpath()
        return path
    }

    private func renderLipRibbons(
        upperOuter: [CGPoint],
        upperInner: [CGPoint],
        lowerInner: [CGPoint],
        lowerOuter: [CGPoint],
        style: String = "full",
        extent: CGRect
    ) -> CIImage? {
        let allPoints = upperOuter + upperInner + lowerInner + lowerOuter
        guard allPoints.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              let minX = allPoints.map(\.x).min(), let maxX = allPoints.map(\.x).max(),
              let minY = allPoints.map(\.y).min(), let maxY = allPoints.map(\.y).max(),
              maxX - minX > 1, maxY - minY > 1 else { return nil }
        let lipWidth = maxX - minX
        let lipHeight = maxY - minY

        let bounds = CGRect(x: minX, y: minY, width: lipWidth, height: lipHeight)
            .insetBy(dx: -8, dy: -8).intersection(extent).integral
        guard !bounds.isEmpty,
              let w = Int(exactly: bounds.width), let h = Int(exactly: bounds.height),
              w > 0, h > 0 else { return nil }

        let upperRibbon = createRibbonPath(half1: upperOuter, half2: upperInner)
        let lowerRibbon = createRibbonPath(half1: lowerInner, half2: lowerOuter)

        let feather = min(1.0, max(0.4, lipWidth * 0.008))

        if style == "gradient" {
            // Lòng môi (Korean Ombre Gradient Lip):
            // 1. Full solid lip mask
            guard let solidContext = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            solidContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            solidContext.addPath(upperRibbon)
            solidContext.addPath(lowerRibbon)
            solidContext.setFillColor(gray: 1.0, alpha: 1.0)
            solidContext.fillPath()
            guard let solidBitmap = solidContext.makeImage() else { return nil }
            let fullLipMask = CIImage(cgImage: solidBitmap).transformed(by:
                CGAffineTransform(translationX: bounds.minX, y: bounds.minY)).cropped(to: extent)

            // 2. Gradient stomion wash
            guard let gradContext = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            gradContext.translateBy(x: -bounds.minX, y: -bounds.minY)

            gradContext.setFillColor(gray: 0.0, alpha: 1.0)
            gradContext.fill(bounds)

            gradContext.addPath(upperRibbon)
            gradContext.addPath(lowerRibbon)
            gradContext.clip()

            gradContext.setFillColor(gray: 0.02, alpha: 1.0)
            gradContext.fill(bounds)

            let contactPath = CGMutablePath()
            if let first = upperInner.first {
                contactPath.move(to: first)
                addSmoothCurves(to: contactPath, points: upperInner)
            }
            if let first = lowerInner.first {
                contactPath.move(to: first)
                addSmoothCurves(to: contactPath, points: lowerInner)
            }

            gradContext.setLineJoin(.round)
            gradContext.setLineCap(.round)

            gradContext.setStrokeColor(gray: 0.40, alpha: 1.0)
            gradContext.setLineWidth(max(6.0, lipHeight * 0.85))
            gradContext.addPath(contactPath)
            gradContext.strokePath()

            gradContext.setStrokeColor(gray: 0.70, alpha: 1.0)
            gradContext.setLineWidth(max(4.0, lipHeight * 0.55))
            gradContext.addPath(contactPath)
            gradContext.strokePath()

            gradContext.setStrokeColor(gray: 0.95, alpha: 1.0)
            gradContext.setLineWidth(max(2.5, lipHeight * 0.35))
            gradContext.addPath(contactPath)
            gradContext.strokePath()

            gradContext.setStrokeColor(gray: 1.0, alpha: 1.0)
            gradContext.setLineWidth(max(1.5, lipHeight * 0.18))
            gradContext.addPath(contactPath)
            gradContext.strokePath()

            // Central pout blossom
            let midX = (minX + maxX) * 0.5
            let midY = (minY + maxY) * 0.5
            let poutRect = CGRect(
                x: midX - lipWidth * 0.25,
                y: midY - lipHeight * 0.30,
                width: lipWidth * 0.50,
                height: lipHeight * 0.60
            )
            gradContext.setFillColor(gray: 0.98, alpha: 1.0)
            gradContext.fillEllipse(in: poutRect)

            guard let gradBitmap = gradContext.makeImage() else { return nil }
            let gradImg = CIImage(cgImage: gradBitmap).transformed(by:
                CGAffineTransform(translationX: bounds.minX, y: bounds.minY))

            let blurRadius = max(2.5, lipHeight * 0.14)
            let blurred = gradImg.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])

            if let blend = CIFilter(name: "CIBlendWithMask") {
                blend.setValue(blurred, forKey: kCIInputImageKey)
                blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
                blend.setValue(fullLipMask, forKey: kCIInputMaskImageKey)
                if let maskedGrad = blend.outputImage?.cropped(to: extent) {
                    return maskedGrad
                }
            }
            return blurred.cropped(to: extent)
        } else if style == "liner" {
            // Viền môi (Lip Liner)
            guard let context = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.translateBy(x: -bounds.minX, y: -bounds.minY)

            context.addPath(upperRibbon)
            context.addPath(lowerRibbon)
            context.setFillColor(gray: 0.45, alpha: 1)
            context.fillPath()

            let outerPath = CGMutablePath()
            if let first = upperOuter.first {
                outerPath.move(to: first)
                addSmoothCurves(to: outerPath, points: upperOuter)
            }
            if let first = lowerOuter.first {
                outerPath.move(to: first)
                addSmoothCurves(to: outerPath, points: lowerOuter)
            }
            context.setStrokeColor(gray: 1.0, alpha: 1)
            context.setLineWidth(max(2.5, lipWidth * 0.035))
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.addPath(outerPath)
            context.strokePath()

            guard let bitmap = context.makeImage() else { return nil }
            let ring = CIImage(cgImage: bitmap).transformed(by:
                CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            return ring.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: feather])
                .cropped(to: extent)
        } else {
            // Full or gloss: solid coverage of both upper & lower lips meeting seamlessly
            guard let context = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.translateBy(x: -bounds.minX, y: -bounds.minY)

            context.addPath(upperRibbon)
            context.addPath(lowerRibbon)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath()

            guard let bitmap = context.makeImage() else { return nil }
            let solidMask = CIImage(cgImage: bitmap).transformed(by:
                CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
            return solidMask.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: feather])
                .cropped(to: extent)
        }
    }

    /// 3D Specular Highlight Sheen for Glossy / Son bóng lips
    /// Refined, natural glassy sheen with realistic specular lobes and pearlescent tone.
    private func createLipGlossHighlights(
        landmarks: FaceMeshLandmarks,
        lipMask: CIImage,
        faceW: CGFloat,
        extent: CGRect,
        lipR: CGFloat = 0.88,
        lipG: CGFloat = 0.12,
        lipB: CGFloat = 0.18,
        opacity: Double = 0.8
    ) -> CIImage? {
        guard landmarks.hasFace, landmarks.landmarks.count == 468 else { return nil }
        func pt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * extent.width, y: CGFloat(1.0 - lm.y) * extent.height)
        }

        let p0 = pt(0)
        let p13 = pt(13)
        let p14 = pt(14)
        let p17 = pt(17)
        let p61 = pt(61)
        let p291 = pt(291)

        let lipW = max(20.0, hypot(p291.x - p61.x, p291.y - p61.y))
        let lipH = max(10.0, hypot(p17.x - p0.x, p17.y - p0.y))

        // Upper lip: small delicate glint at Cupid's bow crest
        let upperHl = CGPoint(x: (p0.x + p13.x) * 0.5, y: (p0.y + p13.y) * 0.5)

        // Lower lip: positioned at the plump cushions of the lower lip (midpoint between 14 and 17)
        let lowerCenter = CGPoint(x: (p14.x + p17.x) * 0.5, y: (p14.y + p17.y) * 0.5)
        let lobeOffset = lipW * 0.08
        let leftLowerHl = CGPoint(x: lowerCenter.x - lobeOffset, y: lowerCenter.y)
        let rightLowerHl = CGPoint(x: lowerCenter.x + lobeOffset, y: lowerCenter.y)
        let centerLowerHl = lowerCenter

        // Refined radius: compact natural glints instead of oversized blotches
        let hlRadius = min(faceW * 0.018, lipH * 0.28)

        // Refined tone (sắc độ tinh tế):
        // Soft translucent pearlescent sheen tinted with warm lipstick undertone instead of chalky white
        let glossR: CGFloat = 1.0
        let glossG: CGFloat = min(1.0, 0.94 + lipG * 0.05)
        let glossB: CGFloat = min(1.0, 0.94 + lipB * 0.05)

        // Refined alpha: 0.22 - 0.26 scaled by user opacity (gentle glassy sheen, not greasy paint)
        let userScale = CGFloat(min(1.0, max(0.2, opacity)))
        let peakAlpha = 0.26 * userScale
        let upperAlpha = 0.18 * userScale

        guard let grad1 = CIFilter(name: "CIRadialGradient"),
              let grad2 = CIFilter(name: "CIRadialGradient"),
              let grad3 = CIFilter(name: "CIRadialGradient"),
              let grad4 = CIFilter(name: "CIRadialGradient") else { return nil }

        let clear = CIColor(red: glossR, green: glossG, blue: glossB, alpha: 0.0)

        // Upper lip Cupid's bow:
        grad1.setValue(CIVector(cgPoint: upperHl), forKey: "inputCenter")
        grad1.setValue(0.0, forKey: "inputRadius0")
        grad1.setValue(hlRadius * 0.55, forKey: "inputRadius1")
        grad1.setValue(CIColor(red: glossR, green: glossG, blue: glossB, alpha: upperAlpha), forKey: "inputColor0")
        grad1.setValue(clear, forKey: "inputColor1")

        // Lower lip left plump lobe:
        grad2.setValue(CIVector(cgPoint: leftLowerHl), forKey: "inputCenter")
        grad2.setValue(0.0, forKey: "inputRadius0")
        grad2.setValue(hlRadius * 0.75, forKey: "inputRadius1")
        grad2.setValue(CIColor(red: glossR, green: glossG, blue: glossB, alpha: peakAlpha), forKey: "inputColor0")
        grad2.setValue(clear, forKey: "inputColor1")

        // Lower lip right plump lobe:
        grad3.setValue(CIVector(cgPoint: rightLowerHl), forKey: "inputCenter")
        grad3.setValue(0.0, forKey: "inputRadius0")
        grad3.setValue(hlRadius * 0.75, forKey: "inputRadius1")
        grad3.setValue(CIColor(red: glossR, green: glossG, blue: glossB, alpha: peakAlpha), forKey: "inputColor0")
        grad3.setValue(clear, forKey: "inputColor1")

        // Lower lip central dewy fill:
        grad4.setValue(CIVector(cgPoint: centerLowerHl), forKey: "inputCenter")
        grad4.setValue(0.0, forKey: "inputRadius0")
        grad4.setValue(hlRadius * 0.90, forKey: "inputRadius1")
        grad4.setValue(CIColor(red: glossR, green: glossG, blue: glossB, alpha: peakAlpha * 0.60), forKey: "inputColor0")
        grad4.setValue(clear, forKey: "inputColor1")

        guard let g1 = grad1.outputImage?.cropped(to: extent),
              let g2 = grad2.outputImage?.cropped(to: extent),
              let g3 = grad3.outputImage?.cropped(to: extent),
              let g4 = grad4.outputImage?.cropped(to: extent) else { return nil }

        var combined = g1.composited(over: g2.composited(over: g3.composited(over: g4)))
        if let blend = CIFilter(name: "CIBlendWithMask") {
            blend.setValue(combined, forKey: kCIInputImageKey)
            blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
            blend.setValue(lipMask, forKey: kCIInputMaskImageKey)
            if let clipped = blend.outputImage {
                combined = clipped
            }
        }
        return combined
    }

    private func createEyebrowMask(landmarks: FaceMeshLandmarks, style: String, faceW: CGFloat, extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else { return nil }
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

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * CGFloat(width), y: (1.0 - p.y) * CGFloat(height))
        }

        func lmPt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        var rightBrowPts: [CGPoint]
        var leftBrowPts: [CGPoint]

        func refineBrowPoints(_ pts: inout [CGPoint]) {
            guard pts.count >= 10 else { return }
            let drops: [CGFloat] = [
                0.075, // 0: tail top (70/300)
                0.080, // 1: arch outer (63/293)
                0.085, // 2: arch peak (105/334)
                0.080, // 3: body bridge (66/296)
                0.075, // 4: head top (107/336)
                0.065, // 5: head bot (55/285)
                0.075, // 6: body bot (65/295)
                0.080, // 7: arch bot (52/282)
                0.075, // 8: arch outer bot (53/283)
                0.070  // 9: tail bot (46/276)
            ]
            let browScale = faceW * 0.45
            for i in 0..<min(pts.count, drops.count) {
                pts[i].y -= browScale * drops[i]
            }
        }

        if !landmarks.rightEyebrowContour.isEmpty && !landmarks.leftEyebrowContour.isEmpty {
            rightBrowPts = landmarks.rightEyebrowContour.map(pt)
            leftBrowPts = landmarks.leftEyebrowContour.map(pt)
        } else if landmarks.landmarks.count >= 468 {
            rightBrowPts = FaceMeshGeometry.rightEyebrowIndices.map(lmPt)
            leftBrowPts = FaceMeshGeometry.leftEyebrowIndices.map(lmPt)
            refineBrowPoints(&rightBrowPts)
            refineBrowPoints(&leftBrowPts)
        } else {
            return nil
        }

        func transformBrow(pts: [CGPoint], isLeft: Bool) -> [CGPoint] {
            guard pts.count >= 10 else { return pts }
            var res = pts
            let head = pts[4]
            let tail = pts[0]
            let centerBaselineY = (head.y + tail.y) * 0.5

            switch style {
            case "korean":
                for i in 1...3 {
                    res[i].y = res[i].y * 0.65 + centerBaselineY * 0.35
                }
                for i in 6...8 {
                    res[i].y = res[i].y * 0.80 + (centerBaselineY - 4.0) * 0.20
                }
            case "arched":
                res[2].y += faceW * 0.008
                res[1].y += faceW * 0.005
                res[3].y += faceW * 0.003
                res[0].y -= faceW * 0.005
            case "willow":
                let n = pts.count
                for i in 0..<(n / 2) {
                    let topIdx = i
                    let botIdx = n - 1 - i
                    let midY = (pts[topIdx].y + pts[botIdx].y) * 0.5
                    res[topIdx].y = pts[topIdx].y * 0.65 + midY * 0.35
                    res[botIdx].y = pts[botIdx].y * 0.65 + midY * 0.35
                }
            case "male_natural":
                // Lông mày nam tự nhiên: Dày dặn, rậm hơn (+20% bản rộng), giữ nguyên cung mày tự nhiên
                let n = pts.count
                for i in 0..<(n / 2) {
                    let topIdx = i
                    let botIdx = n - 1 - i
                    let midY = (pts[topIdx].y + pts[botIdx].y) * 0.5
                    res[topIdx].y = midY + (pts[topIdx].y - midY) * 1.20
                    res[botIdx].y = midY + (pts[botIdx].y - midY) * 1.20
                }
            case "male_sword":
                // Lông mày kiếm (Sword Brow): Vát chéo sắc bén, đuôi mày thẳng và vểnh nhẹ nam tính
                let swordLift = faceW * 0.010
                res[0].y += swordLift
                res[9].y += swordLift * 0.80
                for i in 1...3 {
                    let t = CGFloat(4 - i) / 4.0
                    let targetY = head.y + (tail.y + swordLift - head.y) * t
                    res[i].y = res[i].y * 0.40 + targetY * 0.60
                }
                for i in 6...8 {
                    let t = CGFloat(i - 5) / 4.0
                    let targetY = pts[5].y + (pts[9].y + swordLift * 0.80 - pts[5].y) * t
                    res[i].y = res[i].y * 0.50 + targetY * 0.50
                }
            case "male_bold":
                // Lông mày ngang rậm nam giới: Bản to, phẳng ngang, dày dặn
                for i in 1...3 {
                    res[i].y = res[i].y * 0.45 + centerBaselineY * 0.55
                }
                for i in 6...8 {
                    res[i].y = res[i].y * 0.55 + (centerBaselineY - faceW * 0.012) * 0.45
                }
                let n = pts.count
                for i in 0..<(n / 2) {
                    let topIdx = i
                    let botIdx = n - 1 - i
                    let midY = (res[topIdx].y + res[botIdx].y) * 0.5
                    res[topIdx].y = midY + (res[topIdx].y - midY) * 1.25
                    res[botIdx].y = midY + (res[botIdx].y - midY) * 1.25
                }
            case "male_feathered":
                // Phẩy sợi nam: Dày dặn tự nhiên
                let n = pts.count
                for i in 0..<(n / 2) {
                    let topIdx = i
                    let botIdx = n - 1 - i
                    let midY = (pts[topIdx].y + pts[botIdx].y) * 0.5
                    res[topIdx].y = midY + (pts[topIdx].y - midY) * 1.18
                    res[botIdx].y = midY + (pts[botIdx].y - midY) * 1.18
                }
            default:
                break // "natural" strictly preserves the subject's authentic eyebrow contour
            }
            return res
        }

        rightBrowPts = transformBrow(pts: rightBrowPts, isLeft: true)
        leftBrowPts = transformBrow(pts: leftBrowPts, isLeft: false)

        // Smooth cubic spline for organic, non-geometric eyebrow outline
        func createSmoothBrowPath(pts: [CGPoint]) -> CGMutablePath {
            let path = CGMutablePath()
            let n = pts.count
            guard n >= 4 else { return path }
            path.move(to: pts[0])
            for i in 0..<n {
                let p0 = pts[(i - 1 + n) % n]
                let p1 = pts[i]
                let p2 = pts[(i + 1) % n]
                let p3 = pts[(i + 2) % n]

                let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) * 0.12, y: p1.y + (p2.y - p0.y) * 0.12)
                let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) * 0.12, y: p2.y - (p3.y - p1.y) * 0.12)
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
            path.closeSubpath()
            return path
        }

        func drawSoftOmbreBrow(pts: [CGPoint], isLeft: Bool) {
            guard pts.count >= 10 else { return }
            let browPath = createSmoothBrowPath(pts: pts)

            context.saveGState()
            context.addPath(browPath)
            context.clip()

            let head = CGPoint(x: (pts[4].x + pts[5].x) * 0.5, y: (pts[4].y + pts[5].y) * 0.5)
            let tail = pts[0]

            let isMale = style.starts(with: "male_")
            let colors: [CGFloat]
            let locations: [CGFloat]
            if isMale {
                // Lông mày nam: Chân mày đĩnh đạc, đầu mày vững (0.32), thân mày rậm khỏe (0.96), đuôi dày rõ (0.80)
                colors = [0.32, 0.68, 0.96, 0.95, 0.80]
                locations = [0.0, 0.18, 0.50, 0.78, 1.0]
            } else {
                // Lông mày nữ: Đầu mày tơ thoáng nhẹ (0.18), thân mày mềm (0.92), đuôi mày vuốt thanh mảnh (0.70)
                colors = [0.18, 0.55, 0.92, 0.95, 0.70]
                locations = [0.0, 0.20, 0.55, 0.78, 1.0]
            }
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors.map { CGColor(gray: $0, alpha: 1.0) } as CFArray, locations: locations) {
                context.drawLinearGradient(gradient, start: head, end: tail, options: [])
            }
            context.restoreGState()

            // Subtle perimeter stroke to reinforce natural brow hair shape
            let strokeAlpha: CGFloat = isMale ? 0.45 : 0.35
            let strokeWidth = max(1.0, faceW * (isMale ? 0.0035 : 0.003))
            context.setStrokeColor(gray: strokeAlpha, alpha: 1.0)
            context.setLineWidth(strokeWidth)
            context.addPath(browPath)
            context.strokePath()

            if style == "feathered" {
                // Phẩy sợi nữ: Sợi tơ mềm mại, bay nhẹ
                context.setStrokeColor(gray: 1.0, alpha: 0.85)
                context.setLineWidth(max(1.2, faceW * 0.005))
                context.setLineCap(.round)

                let strokeCount = 14
                for s in 0..<strokeCount {
                    let t = CGFloat(s) / CGFloat(strokeCount - 1)
                    let bx = head.x * (1 - t) + tail.x * t
                    let by = head.y * (1 - t) + tail.y * t
                    let hairLen: CGFloat = max(4.0, faceW * 0.024 * (1.0 - t * 0.3))
                    let angle: CGFloat = (isLeft ? 1 : -1) * ((1.0 - t) * 0.85 + t * 0.25)
                    let hx = bx + sin(angle) * hairLen
                    let hy = by + cos(angle) * hairLen
                    context.move(to: CGPoint(x: bx, y: by - 2.0))
                    context.addLine(to: CGPoint(x: hx, y: hy))
                }
                context.strokePath()
            } else if style == "male_feathered" {
                // Phẩy sợi nam: Sợi đậm rậm, đan xen tự nhiên theo thớ lông mày nam giới
                context.setStrokeColor(gray: 1.0, alpha: 0.92)
                context.setLineWidth(max(1.5, faceW * 0.0065))
                context.setLineCap(.round)

                let strokeCount = 18
                for s in 0..<strokeCount {
                    let t = CGFloat(s) / CGFloat(strokeCount - 1)
                    let bx = head.x * (1 - t) + tail.x * t
                    let by = head.y * (1 - t) + tail.y * t
                    let hairLen: CGFloat = max(5.0, faceW * 0.028 * (1.0 - t * 0.2))
                    let angle: CGFloat = (isLeft ? 1 : -1) * ((1.0 - t) * 0.95 + t * 0.15)
                    let hx = bx + sin(angle) * hairLen
                    let hy = by + cos(angle) * hairLen
                    context.move(to: CGPoint(x: bx, y: by - 2.5))
                    context.addLine(to: CGPoint(x: hx, y: hy))
                }
                context.strokePath()
            }
        }

        drawSoftOmbreBrow(pts: rightBrowPts, isLeft: true)
        drawSoftOmbreBrow(pts: leftBrowPts, isLeft: false)

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        let blurRadius: Double
        switch style {
        case "arched":          blurRadius = 2.4
        case "feathered":       blurRadius = 1.8
        case "willow":          blurRadius = 2.6
        case "korean":          blurRadius = 2.2
        case "male_sword":      blurRadius = 2.0
        case "male_bold":       blurRadius = 2.4
        case "male_feathered":  blurRadius = 1.8
        case "male_natural":    blurRadius = 2.2
        default:                blurRadius = 2.2 // "natural"
        }

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    private func createEyelinerMask(landmarks: FaceMeshLandmarks, style: String, faceW: CGFloat, extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else { return nil }
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

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * CGFloat(width), y: (1.0 - p.y) * CGFloat(height))
        }

        func lmPt(_ idx: Int) -> CGPoint {
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        let rightUpperLash: [CGPoint]
        let leftUpperLash: [CGPoint]

        if landmarks.landmarks.count >= 468 {
            rightUpperLash = FaceMeshGeometry.rightEyeLashLine.map(lmPt)
            leftUpperLash = FaceMeshGeometry.leftEyeLashLine.map(lmPt)
        } else if !landmarks.rightEyeContour.isEmpty && !landmarks.leftEyeContour.isEmpty {
            let rCount = landmarks.rightEyeContour.count
            rightUpperLash = Array(landmarks.rightEyeContour.prefix(rCount / 2 + 1)).map(pt)
            let lCount = landmarks.leftEyeContour.count
            leftUpperLash = Array(landmarks.leftEyeContour.prefix(lCount / 2 + 1)).map(pt)
        } else {
            return nil
        }

        let baseLineWidth = max(2.2, extent.width * 0.0026)
        context.setStrokeColor(gray: 1.0, alpha: 1.0)
        context.setLineWidth(baseLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let path = CGMutablePath()

        func drawLashWithWing(lash: [CGPoint], isLeft: Bool) {
            guard lash.count >= 2, let first = lash.first else { return }

            if style == "fox" {
                let pInner = lash[0]
                let pSecond = lash[1]
                let inDirX = pInner.x - pSecond.x
                let inDirY = pInner.y - pSecond.y
                let inLen = max(1.0, hypot(inDirX, inDirY))
                let innerPoint = CGPoint(
                    x: pInner.x + (inDirX / inLen) * (faceW * 0.024),
                    y: pInner.y + (inDirY / inLen) * (faceW * 0.024) - (faceW * 0.008)
                )
                path.move(to: innerPoint)
                path.addLine(to: pInner)
            } else {
                path.move(to: first)
            }

            for p in lash.dropFirst() { path.addLine(to: p) }

            let pOuter = lash.last!
            let pPrev = lash[lash.count - 2]
            let dirX = pOuter.x - pPrev.x
            let dirY = pOuter.y - pPrev.y
            let len = max(1.0, hypot(dirX, dirY))
            let ndx = dirX / len
            let ndy = dirY / len

            switch style {
            case "classic":
                let wingLen = max(9.0, faceW * 0.035)
                let wing = CGPoint(
                    x: pOuter.x + ndx * wingLen,
                    y: pOuter.y + ndy * wingLen + (faceW * 0.012)
                )
                path.addLine(to: wing)

            case "cat":
                let wingLen = max(15.0, faceW * 0.055)
                let wing = CGPoint(
                    x: pOuter.x + ndx * wingLen,
                    y: pOuter.y + ndy * wingLen + (faceW * 0.026)
                )
                path.addLine(to: wing)

            case "puppy":
                let wingLen = max(10.0, faceW * 0.036)
                let wing = CGPoint(
                    x: pOuter.x + ndx * wingLen,
                    y: pOuter.y + ndy * wingLen - (faceW * 0.015)
                )
                path.addLine(to: wing)

            case "fox":
                let wingLen = max(16.0, faceW * 0.060)
                let wing = CGPoint(
                    x: pOuter.x + ndx * wingLen,
                    y: pOuter.y + ndy * wingLen + (faceW * 0.020)
                )
                path.addLine(to: wing)

            case "natural":
                fallthrough
            default:
                break
            }
        }

        drawLashWithWing(lash: rightUpperLash, isLeft: false)
        drawLashWithWing(lash: leftUpperLash, isLeft: true)

        context.addPath(path)
        context.strokePath()

        if style == "cat" || style == "fox" {
            context.setLineWidth(baseLineWidth * 1.5)
            let catPath = CGMutablePath()
            if rightUpperLash.count >= 4 {
                let outerThird = Array(rightUpperLash.suffix(4))
                catPath.move(to: outerThird[0])
                for p in outerThird.dropFirst() { catPath.addLine(to: p) }
            }
            if leftUpperLash.count >= 4 {
                let outerThird = Array(leftUpperLash.suffix(4))
                catPath.move(to: outerThird[0])
                for p in outerThird.dropFirst() { catPath.addLine(to: p) }
            }
            context.addPath(catPath)
            context.strokePath()
        }

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(1.5, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    private func createEyeshadowMask(landmarks: FaceMeshLandmarks, style: String, faceW: CGFloat, extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else { return nil }
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

        func normPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * CGFloat(width), y: (1.0 - p.y) * CGFloat(height))
        }

        let path = CGMutablePath()

        if landmarks.landmarks.count >= 468 {
            let rightEyelid = [33, 246, 161, 160, 159, 158, 157, 173, 133, 56, 28, 27, 29, 30, 247]
            let leftEyelid = [263, 466, 388, 387, 386, 385, 384, 398, 362, 286, 258, 257, 259, 260, 467]

            if style == "outerV" {
                let rV = [159, 158, 157, 173, 133, 56, 28, 27]
                let lV = [386, 387, 388, 466, 263, 286, 258, 257]
                if let first = rV.first {
                    path.move(to: pt(first))
                    for idx in rV.dropFirst() { path.addLine(to: pt(idx)) }
                    path.closeSubpath()
                }
                if let first = lV.first {
                    path.move(to: pt(first))
                    for idx in lV.dropFirst() { path.addLine(to: pt(idx)) }
                    path.closeSubpath()
                }
            } else {
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
            }
        } else if !landmarks.rightEyeContour.isEmpty && !landmarks.leftEyeContour.isEmpty {
            let rLash = landmarks.rightEyeContour.prefix(landmarks.rightEyeContour.count / 2 + 1).map(normPt)
            let lLash = landmarks.leftEyeContour.prefix(landmarks.leftEyeContour.count / 2 + 1).map(normPt)
            let eyeHeight = CGFloat(width) * 0.025
            if let first = rLash.first {
                path.move(to: first)
                for p in rLash.dropFirst() { path.addLine(to: p) }
                for p in rLash.reversed() { path.addLine(to: CGPoint(x: p.x, y: p.y + eyeHeight)) }
                path.closeSubpath()
            }
            if let first = lLash.first {
                path.move(to: first)
                for p in lLash.dropFirst() { path.addLine(to: p) }
                for p in lLash.reversed() { path.addLine(to: CGPoint(x: p.x, y: p.y + eyeHeight)) }
                path.closeSubpath()
            }
        } else {
            return nil
        }

        context.addPath(path)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fillPath()

        if style == "halo" && landmarks.landmarks.count >= 468 {
            let rMid = CGPoint(x: (pt(159).x + pt(27).x) * 0.5, y: (pt(159).y + pt(27).y) * 0.5)
            let lMid = CGPoint(x: (pt(386).x + pt(257).x) * 0.5, y: (pt(386).y + pt(257).y) * 0.5)
            let spotR = max(6.0, faceW * 0.025)

            context.setFillColor(gray: 0.35, alpha: 1.0)
            context.fillEllipse(in: CGRect(x: rMid.x - spotR, y: rMid.y - spotR, width: spotR * 2, height: spotR * 2))
            context.fillEllipse(in: CGRect(x: lMid.x - spotR, y: lMid.y - spotR, width: spotR * 2, height: spotR * 2))
        } else if style == "cutCrease" && landmarks.landmarks.count >= 468 {
            context.setStrokeColor(gray: 1.0, alpha: 1.0)
            context.setLineWidth(max(1.8, faceW * 0.008))
            let rCrease = [56, 28, 27, 29, 30, 247]
            let lCrease = [286, 258, 257, 259, 260, 467]
            let creasePath = CGMutablePath()
            if let first = rCrease.first {
                creasePath.move(to: pt(first))
                for idx in rCrease.dropFirst() { creasePath.addLine(to: pt(idx)) }
            }
            if let first = lCrease.first {
                creasePath.move(to: pt(first))
                for idx in lCrease.dropFirst() { creasePath.addLine(to: pt(idx)) }
            }
            context.addPath(creasePath)
            context.strokePath()
        } else if style == "douyin" && landmarks.landmarks.count >= 468 {
            let rLower = [7, 163, 144, 145, 153, 154]
            let lLower = [249, 390, 373, 374, 380, 381]
            let aegyoPath = CGMutablePath()
            let aegyoOffset = max(4.0, faceW * 0.016)
            if let first = rLower.first {
                let p0 = pt(first)
                aegyoPath.move(to: CGPoint(x: p0.x, y: p0.y - aegyoOffset))
                for idx in rLower.dropFirst() {
                    let p = pt(idx)
                    aegyoPath.addLine(to: CGPoint(x: p.x, y: p.y - aegyoOffset))
                }
            }
            if let first = lLower.first {
                let p0 = pt(first)
                aegyoPath.move(to: CGPoint(x: p0.x, y: p0.y - aegyoOffset))
                for idx in lLower.dropFirst() {
                    let p = pt(idx)
                    aegyoPath.addLine(to: CGPoint(x: p.x, y: p.y - aegyoOffset))
                }
            }
            context.setStrokeColor(gray: 0.85, alpha: 1.0)
            context.setLineWidth(max(2.0, faceW * 0.009))
            context.setLineCap(.round)
            context.addPath(aegyoPath)
            context.strokePath()
        }

        guard let cgImg = context.makeImage() else { return nil }
        let ciMask = CIImage(cgImage: cgImg)

        let blurRadius: Double
        switch style {
        case "cutCrease": blurRadius = 3.5
        case "outerV":     blurRadius = 5.5
        case "douyin":     blurRadius = 6.0
        case "halo":       blurRadius = 5.0
        case "gradient":   fallthrough
        default:           blurRadius = 6.5
        }

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
            return blur.outputImage?.cropped(to: extent)
        }
        return ciMask
    }

    // MARK: - Face Mask Helpers

    /// Dual-Core Mask Fusion:
    /// Core 2 (Selfie Multiclass Segmentation Class 3: Face-Skin) provides semantic segmentation.
    /// Core 1 (Face Landmarker) provides feature hole protection (punching out soft eye and lip masks).
    /// If segmentation mask is unavailable, falls back to geometric full-face skin mask.
    public func createFaceSkinMask(
        segmentationMask: CIImage?,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage? {
        if let segMask = segmentationMask {
            return punchFeatureHoles(in: segMask, landmarks: landmarks, extent: extent)
        }
        return createFullFaceSkinMask(landmarks: landmarks, extent: extent)
    }

    private func punchFeatureHoles(in mask: CIImage, landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage {
        guard landmarks.hasFace else { return mask }
        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        // Render at a lightweight 480x270 mask (16x less memory & compute)
        let lowW = 480.0
        let lowH = 270.0
        let scaleX = lowW / width
        let scaleY = lowH / height

        func lowPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * lowW, y: (1.0 - p.y) * lowH)
        }

        guard let holeContext = CGContext(
            data: nil,
            width: Int(lowW),
            height: Int(lowH),
            bitsPerComponent: 8,
            bytesPerRow: Int(lowW),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return mask }

        holeContext.setFillColor(gray: 1, alpha: 1)
        holeContext.fill(CGRect(x: 0, y: 0, width: lowW, height: lowH))

        let eyeRx = faceW * scaleX * 0.125
        let eyeRy = faceH * scaleY * 0.065
        let leftEyeCenter = lowPt(landmarks.leftEyeCenter)
        let rightEyeCenter = lowPt(landmarks.rightEyeCenter)

        holeContext.setFillColor(gray: 0, alpha: 1)
        if leftEyeCenter != .zero {
            holeContext.fillEllipse(in: CGRect(
                x: leftEyeCenter.x - eyeRx,
                y: leftEyeCenter.y - eyeRy,
                width: eyeRx * 2,
                height: eyeRy * 2
            ))
        }
        if rightEyeCenter != .zero {
            holeContext.fillEllipse(in: CGRect(
                x: rightEyeCenter.x - eyeRx,
                y: rightEyeCenter.y - eyeRy,
                width: eyeRx * 2,
                height: eyeRy * 2
            ))
        }

        let mouthCenter = lowPt(landmarks.mouthCenter)
        let mouthRx = faceW * scaleX * 0.165
        let mouthRy = faceH * scaleY * 0.075
        if mouthCenter != .zero {
            holeContext.fillEllipse(in: CGRect(
                x: mouthCenter.x - mouthRx,
                y: mouthCenter.y - mouthRy,
                width: mouthRx * 2,
                height: mouthRy * 2
            ))
        }

        guard let holeCG = holeContext.makeImage() else { return mask }
        let holeCI = CIImage(cgImage: holeCG)

        // Soft feathering at low-res (<0.1ms GPU time!)
        let blurredHoleCI: CIImage
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(holeCI, forKey: kCIInputImageKey)
            blur.setValue(2.5, forKey: kCIInputRadiusKey)
            blurredHoleCI = blur.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: lowW, height: lowH)) ?? holeCI
        } else {
            blurredHoleCI = holeCI
        }

        let upscaledHole = blurredHoleCI
            .transformed(by: CGAffineTransform(scaleX: 1.0 / scaleX, y: 1.0 / scaleY))
            .cropped(to: extent)

        if let mult = CIFilter(name: "CIMultiplyCompositing") {
            mult.setValue(mask, forKey: kCIInputImageKey)
            mult.setValue(upscaledHole, forKey: kCIInputBackgroundImageKey)
            return mult.outputImage?.cropped(to: extent) ?? mask
        }
        return mask
    }

    /// Creates a complete full-face skin mask covering forehead, cheeks, jawline, and chin.
    /// Excludes eyes and mouth, and applies a smooth natural gradient falloff at the perimeter.
    public func createFullFaceSkinMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        guard landmarks.hasFace else { return nil }
        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox

        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        let lowW = 480.0
        let lowH = 270.0
        let scaleX = lowW / width
        let scaleY = lowH / height

        func lowPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * lowW, y: (1.0 - p.y) * lowH)
        }

        // Determine contour points: prefer faceContour (from Vision or FaceMesh), fallback to silhouette indices
        var contourPoints = landmarks.faceContour
        if contourPoints.isEmpty && landmarks.landmarks.count == 468 {
            contourPoints = FaceMeshGeometry.silhouetteIndices.map { idx in
                let lm = landmarks.landmarks[idx]
                return CGPoint(x: CGFloat(lm.x), y: CGFloat(lm.y))
            }
        }

        if !contourPoints.isEmpty && contourPoints.count >= 6 {
            let contourPts = contourPoints.map(lowPt)

            guard let context = CGContext(
                data: nil,
                width: Int(lowW),
                height: Int(lowH),
                bitsPerComponent: 8,
                bytesPerRow: Int(lowW),
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }

            // 1. Black background
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: lowW, height: lowH))

            // 2. White face silhouette
            let path = CGMutablePath()
            if let first = contourPts.first {
                path.move(to: first)
                for pt in contourPts.dropFirst() {
                    path.addLine(to: pt)
                }

                // If contour is an open jawline (temple to temple), arch smoothly across the top of forehead
                if let last = contourPts.last {
                    let gap = hypot(first.x - last.x, first.y - last.y)
                    if gap > (faceW * scaleX) * 0.30 {
                        let topForehead = CGPoint(
                            x: box.midX * lowW,
                            y: (1.0 - max(0.0, box.minY - box.height * 0.08)) * lowH
                        )
                        path.addQuadCurve(to: first, control: topForehead)
                    }
                }
                path.closeSubpath()
            }

            context.addPath(path)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath()

            // 3. Cut out eye and mouth holes in the same pass (zero extra context/composite pass!)
            let eyeRx = faceW * scaleX * 0.125
            let eyeRy = faceH * scaleY * 0.065
            let leftEyeCenter = lowPt(landmarks.leftEyeCenter)
            let rightEyeCenter = lowPt(landmarks.rightEyeCenter)

            context.setFillColor(gray: 0, alpha: 1)
            if leftEyeCenter != .zero {
                context.fillEllipse(in: CGRect(
                    x: leftEyeCenter.x - eyeRx,
                    y: leftEyeCenter.y - eyeRy,
                    width: eyeRx * 2,
                    height: eyeRy * 2
                ))
            }
            if rightEyeCenter != .zero {
                context.fillEllipse(in: CGRect(
                    x: rightEyeCenter.x - eyeRx,
                    y: rightEyeCenter.y - eyeRy,
                    width: eyeRx * 2,
                    height: eyeRy * 2
                ))
            }

            let mouthCenter = lowPt(landmarks.mouthCenter)
            let mouthRx = faceW * scaleX * 0.165
            let mouthRy = faceH * scaleY * 0.075
            if mouthCenter != .zero {
                context.fillEllipse(in: CGRect(
                    x: mouthCenter.x - mouthRx,
                    y: mouthCenter.y - mouthRy,
                    width: mouthRx * 2,
                    height: mouthRy * 2
                ))
            }

            guard let faceCG = context.makeImage() else { return nil }
            let baseFaceCI = CIImage(cgImage: faceCG)

            // Feather perimeter & feature holes smoothly in low-res (<0.1ms GPU blur!)
            let blurredCI: CIImage
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(baseFaceCI, forKey: kCIInputImageKey)
                blur.setValue(3.5, forKey: kCIInputRadiusKey)
                blurredCI = blur.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: lowW, height: lowH)) ?? baseFaceCI
            } else {
                blurredCI = baseFaceCI
            }

            // Upscale to canvas dimensions with GPU bilinear anti-aliasing
            let upscaled = blurredCI
                .transformed(by: CGAffineTransform(scaleX: 1.0 / scaleX, y: 1.0 / scaleY))
                .cropped(to: extent)

            return upscaled
        }

        // Fallback: anatomical radial oval covering full face
        let faceCenter = CGPoint(
            x: box.midX * width,
            y: (1.0 - (box.midY - box.height * 0.04)) * height
        )
        return createFaceOvalMask(
            extent: extent,
            center: faceCenter,
            rx: faceW * 0.58,
            ry: faceH * 0.68,
            strength: 1.0
        )
    }

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

    private func makeBlushOval(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        angle: CGFloat = 0.0,
        color: CIColor,
        extent: CGRect
    ) -> CIImage? {
        guard let grad = CIFilter(name: "CIRadialGradient") else { return nil }
        let clear = CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.0)
        grad.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        grad.setValue(0.0, forKey: "inputRadius0")
        grad.setValue(1.0, forKey: "inputRadius1")
        grad.setValue(color, forKey: "inputColor0")
        grad.setValue(clear, forKey: "inputColor1")

        guard let base = grad.outputImage else { return nil }
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        if abs(angle) > 0.001 {
            transform = transform.rotated(by: angle)
        }
        transform = transform.scaledBy(x: rx, y: ry)
        return base.transformed(by: transform).cropped(to: extent)
    }

    private func createStyledBlush(
        extent: CGRect,
        landmarks: FaceMeshLandmarks,
        style: String = "apple",
        faceW: CGFloat,
        intensity: Double,
        colorR: CGFloat = 0.98,
        colorG: CGFloat = 0.48,
        colorB: CGFloat = 0.56
    ) -> CIImage? {
        guard landmarks.hasFace else { return nil }

        func ciPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * extent.width, y: (1.0 - p.y) * extent.height)
        }

        let rightApple = ciPt(landmarks.rightCheekApple) // landmark 50 (camera left)
        let leftApple = ciPt(landmarks.leftCheekApple)   // landmark 280 (camera right)
        let noseBridge = ciPt(landmarks.noseBridge)      // landmark 168 (midline)
        let rightTemple = ciPt(landmarks.rightTemple)
        let leftTemple = ciPt(landmarks.leftTemple)
        let rightEye = ciPt(landmarks.rightEyeCenter)
        let leftEye = ciPt(landmarks.leftEyeCenter)
        let rightJaw = ciPt(landmarks.rightMidJaw)
        let leftJaw = ciPt(landmarks.leftMidJaw)

        let blushColor = CIColor(red: colorR, green: colorG, blue: colorB, alpha: CGFloat(intensity))

        switch style {
        case "sunkissed":
            // Say rượu / Ngang sống mũi: connects left cheek, bridge of nose, and right cheek
            let lCheek = makeBlushOval(center: leftApple, rx: faceW * 0.20, ry: faceW * 0.12, color: blushColor, extent: extent)
            let rCheek = makeBlushOval(center: rightApple, rx: faceW * 0.20, ry: faceW * 0.12, color: blushColor, extent: extent)
            let bridgeColor = CIColor(red: colorR, green: colorG, blue: colorB, alpha: CGFloat(intensity * 0.75))
            let bridge = makeBlushOval(center: noseBridge, rx: faceW * 0.14, ry: faceW * 0.08, color: bridgeColor, extent: extent)

            var res = lCheek
            if let r = rCheek { res = res?.composited(over: r) ?? r }
            if let b = bridge { res = res?.composited(over: b) ?? b }
            return res

        case "lifted":
            // Kéo thái dương / Nâng cơ: extends diagonally towards temples
            let rCenter = CGPoint(x: rightApple.x * 0.65 + rightTemple.x * 0.35, y: rightApple.y * 0.65 + rightTemple.y * 0.35)
            let rAngle = atan2(rightTemple.y - rightApple.y, rightTemple.x - rightApple.x)
            let rGrad = makeBlushOval(center: rCenter, rx: faceW * 0.22, ry: faceW * 0.10, angle: rAngle, color: blushColor, extent: extent)

            let lCenter = CGPoint(x: leftApple.x * 0.65 + leftTemple.x * 0.35, y: leftApple.y * 0.65 + leftTemple.y * 0.35)
            let lAngle = atan2(leftTemple.y - leftApple.y, leftTemple.x - leftApple.x)
            let lGrad = makeBlushOval(center: lCenter, rx: faceW * 0.22, ry: faceW * 0.10, angle: lAngle, color: blushColor, extent: extent)

            if let l = lGrad, let r = rGrad { return l.composited(over: r) }
            return lGrad ?? rGrad

        case "undereye":
            // Dưới mắt / Douyin: directly beneath lower eyelids
            let rCenter = CGPoint(x: rightEye.x * 0.65 + rightApple.x * 0.35, y: rightEye.y * 0.65 + rightApple.y * 0.35)
            let rGrad = makeBlushOval(center: rCenter, rx: faceW * 0.15, ry: faceW * 0.09, color: blushColor, extent: extent)

            let lCenter = CGPoint(x: leftEye.x * 0.65 + leftApple.x * 0.35, y: leftEye.y * 0.65 + leftApple.y * 0.35)
            let lGrad = makeBlushOval(center: lCenter, rx: faceW * 0.15, ry: faceW * 0.09, color: blushColor, extent: extent)

            if let l = lGrad, let r = rGrad { return l.composited(over: r) }
            return lGrad ?? rGrad

        case "contour":
            // Tạo khối hõm má: angled from cheek hollow down towards jaw
            let rCenter = CGPoint(x: rightApple.x * 0.55 + rightJaw.x * 0.45, y: rightApple.y * 0.55 + rightJaw.y * 0.45)
            let rAngle = atan2(rightJaw.y - rightApple.y, rightJaw.x - rightApple.x)
            let rGrad = makeBlushOval(center: rCenter, rx: faceW * 0.19, ry: faceW * 0.10, angle: rAngle, color: blushColor, extent: extent)

            let lCenter = CGPoint(x: leftApple.x * 0.55 + leftJaw.x * 0.45, y: leftApple.y * 0.55 + leftJaw.y * 0.45)
            let lAngle = atan2(leftJaw.y - leftApple.y, leftJaw.x - leftApple.x)
            let lGrad = makeBlushOval(center: lCenter, rx: faceW * 0.19, ry: faceW * 0.10, angle: lAngle, color: blushColor, extent: extent)

            if let l = lGrad, let r = rGrad { return l.composited(over: r) }
            return lGrad ?? rGrad

        case "apple":
            fallthrough
        default:
            // Gò má tròn: classic round apples
            let rGrad = makeBlushOval(center: rightApple, rx: faceW * 0.16, ry: faceW * 0.16, color: blushColor, extent: extent)
            let lGrad = makeBlushOval(center: leftApple, rx: faceW * 0.16, ry: faceW * 0.16, color: blushColor, extent: extent)
            if let l = lGrad, let r = rGrad { return l.composited(over: r) }
            return lGrad ?? rGrad
        }
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

    // MARK: - Eyeball Brightening & Sparkling Eyes (Mắt Sáng & Mắt Long Lanh)
    public func createEyeballMask(landmarks: FaceMeshLandmarks, extent: CGRect) -> CIImage? {
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * CGFloat(width), y: (1.0 - p.y) * CGFloat(height))
        }

        func lmPt(_ idx: Int) -> CGPoint {
            guard idx < landmarks.landmarks.count else { return .zero }
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * CGFloat(width), y: CGFloat(1.0 - lm.y) * CGFloat(height))
        }

        var rightPts: [CGPoint] = []
        var leftPts: [CGPoint] = []

        if landmarks.landmarks.count >= 468 {
            rightPts = FaceMeshGeometry.rightEyeLoop.map(lmPt)
            leftPts = FaceMeshGeometry.leftEyeLoop.map(lmPt)
        } else if !landmarks.rightEyeContour.isEmpty && !landmarks.leftEyeContour.isEmpty {
            rightPts = landmarks.rightEyeContour.map(pt)
            leftPts = landmarks.leftEyeContour.map(pt)
        }

        // Fallback for minimalist landmark setups where only eye centers are provided
        if rightPts.count < 3 || leftPts.count < 3 {
            let faceW = landmarks.boundingBox.width * extent.width
            let faceH = landmarks.boundingBox.height * extent.height
            let rx = max(8.0, faceW * 0.08)
            let ry = max(4.0, faceH * 0.045)
            let lCenter = landmarks.leftEyeCenter != .zero ? pt(landmarks.leftEyeCenter) : .zero
            let rCenter = landmarks.rightEyeCenter != .zero ? pt(landmarks.rightEyeCenter) : .zero
            if lCenter != .zero && rCenter != .zero {
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
                context.setFillColor(gray: 1.0, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: lCenter.x - rx, y: lCenter.y - ry, width: rx * 2, height: ry * 2))
                context.fillEllipse(in: CGRect(x: rCenter.x - rx, y: rCenter.y - ry, width: rx * 2, height: ry * 2))
                guard let cgImg = context.makeImage() else { return nil }
                let raw = CIImage(cgImage: cgImg)
                if let blur = CIFilter(name: "CIGaussianBlur") {
                    blur.setValue(raw, forKey: kCIInputImageKey)
                    blur.setValue(1.0, forKey: kCIInputRadiusKey)
                    return blur.outputImage?.cropped(to: extent)
                }
                return raw
            }
            return nil
        }

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

        context.setFillColor(gray: 1.0, alpha: 1.0)

        let rightPath = catmullRomSplinePath(points: rightPts)
        context.addPath(rightPath)
        context.fillPath()

        let leftPath = catmullRomSplinePath(points: leftPts)
        context.addPath(leftPath)
        context.fillPath()

        guard let maskCG = context.makeImage() else { return nil }
        let rawMask = CIImage(cgImage: maskCG)

        // Soft 1.0px Gaussian feathering along the eyelid boundaries
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(rawMask, forKey: kCIInputImageKey)
            blur.setValue(1.0, forKey: kCIInputRadiusKey)
            if let blurred = blur.outputImage?.cropped(to: extent) {
                return blurred
            }
        }
        return rawMask
    }

    private func applyEyeBrightening(
        image: CIImage,
        intensity: Double,
        eyeballMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        guard intensity > 0.01 else { return image }
        let safeIntensity = CGFloat(max(0.0, min(1.0, intensity)))

        // Whitening & clarity curve:
        // Brighten whites/sclera, lift midtones, enrich contrast to make iris vivid,
        // and slightly reduce saturation in sclera to eliminate tired/yellowish tint.
        var brightened = image
        if let cc = CIFilter(name: "CIColorControls") {
            cc.setValue(image, forKey: kCIInputImageKey)
            cc.setValue(0.08 * safeIntensity, forKey: kCIInputBrightnessKey)
            cc.setValue(1.0 + 0.18 * safeIntensity, forKey: kCIInputContrastKey)
            cc.setValue(1.0 - 0.12 * safeIntensity, forKey: kCIInputSaturationKey)
            if let out = cc.outputImage { brightened = out }
        }

        // Blend with the eyeball mask so changes are confined strictly to the eyeball interior
        if let blend = CIFilter(name: "CIBlendWithMask") {
            blend.setValue(brightened, forKey: kCIInputImageKey)
            blend.setValue(image, forKey: kCIInputBackgroundImageKey)
            blend.setValue(eyeballMask, forKey: kCIInputMaskImageKey)
            if let out = blend.outputImage?.cropped(to: extent) {
                return out
            }
        }
        return image
    }

    private func applyEyeSparkle(
        image: CIImage,
        intensity: Double,
        style: String,
        eyeballMask: CIImage,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard intensity > 0.01 else { return image }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { return image }

        func ciPt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * CGFloat(width), y: (1.0 - p.y) * CGFloat(height))
        }

        // Determine left and right eye centers
        var leftCenter = ciPt(landmarks.leftEyeCenter)
        var rightCenter = ciPt(landmarks.rightEyeCenter)

        if leftCenter == .zero && landmarks.landmarks.count >= 468 {
            let pts = FaceMeshGeometry.leftEyeLoop.map { landmarks.landmarks[$0] }
            let avgX = pts.reduce(0.0) { $0 + CGFloat($1.x) } / CGFloat(pts.count)
            let avgY = pts.reduce(0.0) { $0 + CGFloat($1.y) } / CGFloat(pts.count)
            leftCenter = ciPt(CGPoint(x: avgX, y: avgY))
        }

        if rightCenter == .zero && landmarks.landmarks.count >= 468 {
            let pts = FaceMeshGeometry.rightEyeLoop.map { landmarks.landmarks[$0] }
            let avgX = pts.reduce(0.0) { $0 + CGFloat($1.x) } / CGFloat(pts.count)
            let avgY = pts.reduce(0.0) { $0 + CGFloat($1.y) } / CGFloat(pts.count)
            rightCenter = ciPt(CGPoint(x: avgX, y: avgY))
        }

        guard leftCenter != .zero && rightCenter != .zero else { return image }

        // Central Facial Axis (points downward from nose bridge to chin tip)
        let chinCenter = ciPt(landmarks.chinTip)
        let noseBridge = ciPt(landmarks.noseBridge)
        let axisVec = CGPoint(x: chinCenter.x - noseBridge.x, y: chinCenter.y - noseBridge.y)
        let axisLen = hypot(axisVec.x, axisVec.y)
        let axisDir: CGPoint
        if axisLen > 1.0 {
            axisDir = CGPoint(x: axisVec.x / axisLen, y: axisVec.y / axisLen)
        } else {
            axisDir = CGPoint(x: 0, y: -1) // default upright downward axis
        }

        // Coordinate axes aligned with facial tilt:
        // upVec points towards forehead (+Y in upright face)
        let upVec = CGPoint(x: -axisDir.x, y: -axisDir.y)
        let downVec = axisDir
        let rightVec = CGPoint(x: -axisDir.y, y: axisDir.x)
        let leftVec = CGPoint(x: axisDir.y, y: -axisDir.x)

        let eyeDist = max(20.0, hypot(leftCenter.x - rightCenter.x, leftCenter.y - rightCenter.y))
        let irisR = max(3.5, eyeDist * 0.085)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }

        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        func drawSparkle(center: CGPoint) {
            switch style {
            case "natural":
                // 1. Natural Studio Catchlight: Primary soft reflection at 11 o'clock, secondary at 5 o'clock
                let c1 = CGPoint(
                    x: center.x + (upVec.x * 0.38 + rightVec.x * 0.22) * irisR,
                    y: center.y + (upVec.y * 0.38 + rightVec.y * 0.22) * irisR
                )
                let r1 = max(1.6, irisR * 0.26)
                context.setFillColor(gray: 1.0, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: c1.x - r1, y: c1.y - r1, width: r1 * 2, height: r1 * 2))

                let c2 = CGPoint(
                    x: center.x - (upVec.x * 0.32 + rightVec.x * 0.18) * irisR,
                    y: center.y - (upVec.y * 0.32 + rightVec.y * 0.18) * irisR
                )
                let r2 = max(1.0, irisR * 0.14)
                context.setFillColor(gray: 0.55, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: c2.x - r2, y: c2.y - r2, width: r2 * 2, height: r2 * 2))

            case "ring":
                // 2. Ring Light Catchlight: Elegant circular specular ring with center pinpoint
                let ringCenter = CGPoint(
                    x: center.x + upVec.x * (irisR * 0.05),
                    y: center.y + upVec.y * (irisR * 0.05)
                )
                let ringR = max(2.5, irisR * 0.46)
                let ringW = max(1.2, irisR * 0.16)

                context.setStrokeColor(gray: 1.0, alpha: 1.0)
                context.setLineWidth(ringW)
                context.strokeEllipse(in: CGRect(x: ringCenter.x - ringR, y: ringCenter.y - ringR, width: ringR * 2, height: ringR * 2))

                let pinCenter = CGPoint(
                    x: ringCenter.x + (upVec.x * 0.18 + rightVec.x * 0.12) * irisR,
                    y: ringCenter.y + (upVec.y * 0.18 + rightVec.y * 0.12) * irisR
                )
                let pinR = max(0.8, irisR * 0.12)
                context.setFillColor(gray: 0.85, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: pinCenter.x - pinR, y: pinCenter.y - pinR, width: pinR * 2, height: pinR * 2))

            case "crystal":
                // 3. Crystal Diamond Catchlight: Faceted diamond glint with twin shimmer points
                let gemCenter = CGPoint(
                    x: center.x + (upVec.x * 0.36 + rightVec.x * 0.22) * irisR,
                    y: center.y + (upVec.y * 0.36 + rightVec.y * 0.22) * irisR
                )
                let dTop = CGPoint(x: gemCenter.x + upVec.x * (irisR * 0.40), y: gemCenter.y + upVec.y * (irisR * 0.40))
                let dRight = CGPoint(x: gemCenter.x + rightVec.x * (irisR * 0.30), y: gemCenter.y + rightVec.y * (irisR * 0.30))
                let dBottom = CGPoint(x: gemCenter.x + downVec.x * (irisR * 0.35), y: gemCenter.y + downVec.y * (irisR * 0.35))
                let dLeft = CGPoint(x: gemCenter.x + leftVec.x * (irisR * 0.25), y: gemCenter.y + leftVec.y * (irisR * 0.25))

                let gemPath = CGMutablePath()
                gemPath.move(to: dTop)
                gemPath.addLine(to: dRight)
                gemPath.addLine(to: dBottom)
                gemPath.addLine(to: dLeft)
                gemPath.closeSubpath()

                context.setFillColor(gray: 1.0, alpha: 1.0)
                context.addPath(gemPath)
                context.fillPath()

                let dot1 = CGPoint(
                    x: center.x + (upVec.x * 0.14 + leftVec.x * 0.28) * irisR,
                    y: center.y + (upVec.y * 0.14 + leftVec.y * 0.28) * irisR
                )
                let rDot1 = max(1.0, irisR * 0.15)
                context.setFillColor(gray: 0.75, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: dot1.x - rDot1, y: dot1.y - rDot1, width: rDot1 * 2, height: rDot1 * 2))

                let dot2 = CGPoint(
                    x: center.x - (upVec.x * 0.26 + rightVec.x * 0.14) * irisR,
                    y: center.y - (upVec.y * 0.26 + rightVec.y * 0.14) * irisR
                )
                let rDot2 = max(0.8, irisR * 0.12)
                context.setFillColor(gray: 0.60, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: dot2.x - rDot2, y: dot2.y - rDot2, width: rDot2 * 2, height: rDot2 * 2))

            default: // "starlight"
                // 4. Starlight Catchlight: 4-pointed radiant star glint + glowing core + twinkle satellite
                let starCenter = CGPoint(
                    x: center.x + (upVec.x * 0.35 + rightVec.x * 0.20) * irisR,
                    y: center.y + (upVec.y * 0.35 + rightVec.y * 0.20) * irisR
                )
                let rayV = max(3.5, irisR * 0.72)
                let rayH = max(2.5, irisR * 0.52)
                let rayBase = max(1.0, irisR * 0.12)

                let starPath = CGMutablePath()
                starPath.move(to: CGPoint(x: starCenter.x + upVec.x * rayV, y: starCenter.y + upVec.y * rayV))
                starPath.addLine(to: CGPoint(x: starCenter.x + (upVec.x + rightVec.x) * (rayBase * 0.5), y: starCenter.y + (upVec.y + rightVec.y) * (rayBase * 0.5)))
                starPath.addLine(to: CGPoint(x: starCenter.x + rightVec.x * rayH, y: starCenter.y + rightVec.y * rayH))
                starPath.addLine(to: CGPoint(x: starCenter.x + (downVec.x + rightVec.x) * (rayBase * 0.5), y: starCenter.y + (downVec.y + rightVec.y) * (rayBase * 0.5)))
                starPath.addLine(to: CGPoint(x: starCenter.x + downVec.x * rayV, y: starCenter.y + downVec.y * rayV))
                starPath.addLine(to: CGPoint(x: starCenter.x + (downVec.x + leftVec.x) * (rayBase * 0.5), y: starCenter.y + (downVec.y + leftVec.y) * (rayBase * 0.5)))
                starPath.addLine(to: CGPoint(x: starCenter.x + leftVec.x * rayH, y: starCenter.y + leftVec.y * rayH))
                starPath.addLine(to: CGPoint(x: starCenter.x + (upVec.x + leftVec.x) * (rayBase * 0.5), y: starCenter.y + (upVec.y + leftVec.y) * (rayBase * 0.5)))
                starPath.closeSubpath()

                context.setFillColor(gray: 1.0, alpha: 1.0)
                context.addPath(starPath)
                context.fillPath()

                let coreR = max(1.2, irisR * 0.22)
                context.fillEllipse(in: CGRect(x: starCenter.x - coreR, y: starCenter.y - coreR, width: coreR * 2, height: coreR * 2))

                let c2 = CGPoint(
                    x: center.x - (upVec.x * 0.30 + rightVec.x * 0.18) * irisR,
                    y: center.y - (upVec.y * 0.30 + rightVec.y * 0.18) * irisR
                )
                let r2 = max(0.9, irisR * 0.12)
                context.setFillColor(gray: 0.65, alpha: 1.0)
                context.fillEllipse(in: CGRect(x: c2.x - r2, y: c2.y - r2, width: r2 * 2, height: r2 * 2))
            }
        }

        drawSparkle(center: leftCenter)
        drawSparkle(center: rightCenter)

        guard let maskCG = context.makeImage() else { return image }
        let sharpSparkle = CIImage(cgImage: maskCG)

        // Optical bloom: apply subtle blur and lighten blend to get crisp core with radiant specular halo
        var bloomSparkle = sharpSparkle
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(sharpSparkle, forKey: kCIInputImageKey)
            blur.setValue(max(0.6, irisR * 0.10), forKey: kCIInputRadiusKey)
            if let blurred = blur.outputImage?.cropped(to: extent),
               let lighten = CIFilter(name: "CILightenBlendMode") {
                lighten.setValue(sharpSparkle, forKey: kCIInputImageKey)
                lighten.setValue(blurred, forKey: kCIInputBackgroundImageKey)
                if let bloomed = lighten.outputImage?.cropped(to: extent) {
                    bloomSparkle = bloomed
                }
            }
        }

        // Multiply with eyeballMask to ensure the catchlights are strictly clipped inside the visible eye
        var clippedSparkle = bloomSparkle
        if let multiply = CIFilter(name: "CIMultiplyCompositing") {
            multiply.setValue(bloomSparkle, forKey: kCIInputImageKey)
            multiply.setValue(eyeballMask, forKey: kCIInputBackgroundImageKey)
            if let out = multiply.outputImage?.cropped(to: extent) {
                clippedSparkle = out
            }
        }

        // Scale sparkle mask by intensity
        let safeIntensity = CGFloat(max(0.0, min(1.0, intensity)))
        var finalMask = clippedSparkle
        if let matrix = CIFilter(name: "CIColorMatrix") {
            matrix.setValue(clippedSparkle, forKey: kCIInputImageKey)
            let s = safeIntensity * 0.92
            matrix.setValue(CIVector(x: s, y: 0, z: 0, w: 0), forKey: "inputRVector")
            matrix.setValue(CIVector(x: 0, y: s, z: 0, w: 0), forKey: "inputGVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: s, w: 0), forKey: "inputBVector")
            matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: s), forKey: "inputAVector")
            if let out = matrix.outputImage?.cropped(to: extent) {
                finalMask = out
            }
        }

        let whiteColor = CIColor(red: 1.0, green: 0.99, blue: 0.98)
        let whiteImage = CIImage(color: whiteColor).cropped(to: extent)
        if let blend = CIFilter(name: "CIBlendWithMask") {
            blend.setValue(whiteImage, forKey: kCIInputImageKey)
            blend.setValue(image, forKey: kCIInputBackgroundImageKey)
            blend.setValue(finalMask, forKey: kCIInputMaskImageKey)
            if let out = blend.outputImage?.cropped(to: extent) {
                return out
            }
        }
        return image
    }

    // MARK: - Aesthetic Filters
    private func applyFilter(image: CIImage, baseImage: CIImage, filterId: String, intensity: Double) -> CIImage {
        var filtered = image

        switch filterId {
        // --- Douyin Filters (Sáng Trong, Xinh Xắn, Da Phát Sáng Thủy Tinh) ---
        case "douyin_fairy": // Tiên Nữ: Làn da trắng sáng phát sáng, ánh hồng baby mộng mơ
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(filtered, forKey: kCIInputImageKey)
                gamma.setValue(0.82, forKey: "inputPower")
                if let out = gamma.outputImage {
                    if let matrix = CIFilter(name: "CIColorMatrix") {
                        matrix.setValue(out, forKey: kCIInputImageKey)
                        matrix.setValue(CIVector(x: 1.06, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                        matrix.setValue(CIVector(x: 0.0, y: 1.02, z: 0.0, w: 0.0), forKey: "inputGVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.10, w: 0.0), forKey: "inputBVector")
                        matrix.setValue(CIVector(x: 0.04, y: 0.03, z: 0.06, w: 0.0), forKey: "inputBiasVector")
                        if let out2 = matrix.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.03, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.10, forKey: kCIInputContrastKey)
                                cc.setValue(1.12, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "douyin_sweet": // Ngọt Ngào: Hồng đào ngọt ngào tươi tắn, đôi mắt long lanh
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 6300, y: 22), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let matrix = CIFilter(name: "CIColorMatrix") {
                        matrix.setValue(out, forKey: kCIInputImageKey)
                        matrix.setValue(CIVector(x: 1.08, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                        matrix.setValue(CIVector(x: 0.0, y: 1.02, z: 0.0, w: 0.0), forKey: "inputGVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.05, w: 0.0), forKey: "inputBVector")
                        matrix.setValue(CIVector(x: 0.04, y: 0.02, z: 0.02, w: 0.0), forKey: "inputBiasVector")
                        if let out2 = matrix.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.03, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.12, forKey: kCIInputContrastKey)
                                cc.setValue(1.18, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "douyin_moon": // Bạch Nguyệt: Ánh trăng ngọc ngà, trong veo thuần khiết, khử vàng tối
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(filtered, forKey: kCIInputImageKey)
                gamma.setValue(0.85, forKey: "inputPower")
                if let out = gamma.outputImage {
                    if let matrix = CIFilter(name: "CIColorMatrix") {
                        matrix.setValue(out, forKey: kCIInputImageKey)
                        matrix.setValue(CIVector(x: 1.03, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                        matrix.setValue(CIVector(x: 0.0, y: 1.02, z: 0.0, w: 0.0), forKey: "inputGVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.15, w: 0.0), forKey: "inputBVector")
                        matrix.setValue(CIVector(x: 0.02, y: 0.03, z: 0.07, w: 0.0), forKey: "inputBiasVector")
                        if let out2 = matrix.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.02, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.12, forKey: kCIInputContrastKey)
                                cc.setValue(0.98, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "douyin_dreamy": // Mộng Ảo: Làn sương mờ phát sáng nhẹ (soft mist bloom), xinh lung linh
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(filtered, forKey: kCIInputImageKey)
                gamma.setValue(0.88, forKey: "inputPower")
                if let brightened = gamma.outputImage {
                    if let blur = CIFilter(name: "CIGaussianBlur") {
                        blur.setValue(brightened, forKey: kCIInputImageKey)
                        blur.setValue(6.0, forKey: kCIInputRadiusKey)
                        if let blurred = blur.outputImage?.cropped(to: image.extent) {
                            if let soft = CIFilter(name: "CISoftLightBlendMode") {
                                soft.setValue(blurred, forKey: kCIInputImageKey)
                                soft.setValue(brightened, forKey: kCIInputBackgroundImageKey)
                                if let bloomed = soft.outputImage {
                                    if let cc = CIFilter(name: "CIColorControls") {
                                        cc.setValue(bloomed, forKey: kCIInputImageKey)
                                        cc.setValue(0.02, forKey: kCIInputBrightnessKey)
                                        cc.setValue(1.08, forKey: kCIInputContrastKey)
                                        cc.setValue(1.12, forKey: kCIInputSaturationKey)
                                        if let out = cc.outputImage { filtered = out }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        case "douyin_doll": // Búp Bê: Da trắng má hồng búp bê, nét mặt ngọt ngào đáng yêu
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 1.12, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.98, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.08, w: 0.0), forKey: "inputBVector")
                matrix.setValue(CIVector(x: 0.06, y: 0.02, z: 0.05, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let gamma = CIFilter(name: "CIGammaAdjust") {
                        gamma.setValue(out, forKey: kCIInputImageKey)
                        gamma.setValue(0.86, forKey: "inputPower")
                        if let out2 = gamma.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.03, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.14, forKey: kCIInputContrastKey)
                                cc.setValue(1.22, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "douyin_radiant": // Phát Sáng: Da căng bóng bật tông, rạng rỡ sức sống
            if let hs = CIFilter(name: "CIHighlightShadowAdjust") {
                hs.setValue(filtered, forKey: kCIInputImageKey)
                hs.setValue(0.88, forKey: "inputHighlightAmount")
                hs.setValue(1.28, forKey: "inputShadowAmount")
                if let out = hs.outputImage {
                    if let gamma = CIFilter(name: "CIGammaAdjust") {
                        gamma.setValue(out, forKey: kCIInputImageKey)
                        gamma.setValue(0.86, forKey: "inputPower")
                        if let out2 = gamma.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.04, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.15, forKey: kCIInputContrastKey)
                                cc.setValue(1.16, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "douyin_vintage": // Cổ Điển Hồng: Phong cách Douyin retro ấm áp ngọt ngào
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 7200, y: 16), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let matrix = CIFilter(name: "CIColorMatrix") {
                        matrix.setValue(out, forKey: kCIInputImageKey)
                        matrix.setValue(CIVector(x: 1.08, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                        matrix.setValue(CIVector(x: 0.0, y: 1.01, z: 0.0, w: 0.0), forKey: "inputGVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.06, w: 0.0), forKey: "inputBVector")
                        matrix.setValue(CIVector(x: 0.05, y: 0.02, z: 0.04, w: 0.0), forKey: "inputBiasVector")
                        if let out2 = matrix.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(1.14, forKey: kCIInputContrastKey)
                                cc.setValue(1.15, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "clear":
            if let f = CIFilter(name: "CIColorControls") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(0.04, forKey: kCIInputBrightnessKey)
                f.setValue(1.15, forKey: kCIInputContrastKey)
                f.setValue(1.12, forKey: kCIInputSaturationKey)
                if let out = f.outputImage { filtered = out }
            }
        case "pure":
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 0.04, y: 0.05, z: 0.07, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let gamma = CIFilter(name: "CIGammaAdjust") {
                        gamma.setValue(out, forKey: kCIInputImageKey)
                        gamma.setValue(0.92, forKey: "inputPower")
                        if let out2 = gamma.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(1.05, forKey: kCIInputContrastKey)
                                cc.setValue(0.96, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "clean":
            if let hs = CIFilter(name: "CIHighlightShadowAdjust") {
                hs.setValue(filtered, forKey: kCIInputImageKey)
                hs.setValue(0.85, forKey: "inputHighlightAmount")
                hs.setValue(1.15, forKey: "inputShadowAmount")
                if let out = hs.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(0.02, forKey: kCIInputBrightnessKey)
                        cc.setValue(1.10, forKey: kCIInputContrastKey)
                        cc.setValue(1.06, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "dewy":
            if let gamma = CIFilter(name: "CIGammaAdjust") {
                gamma.setValue(filtered, forKey: kCIInputImageKey)
                gamma.setValue(0.88, forKey: "inputPower")
                if let out = gamma.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(0.03, forKey: kCIInputBrightnessKey)
                        cc.setValue(1.12, forKey: kCIInputContrastKey)
                        cc.setValue(1.14, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
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
        case "sakura":
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 0.08, y: 0.02, z: 0.06, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let tt = CIFilter(name: "CITemperatureAndTint") {
                        tt.setValue(out, forKey: kCIInputImageKey)
                        tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                        tt.setValue(CIVector(x: 6300, y: 18), forKey: "inputTargetNeutral")
                        if let out2 = tt.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(0.02, forKey: kCIInputBrightnessKey)
                                cc.setValue(1.06, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "cream":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 7300, y: 8), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(0.03, forKey: kCIInputBrightnessKey)
                        cc.setValue(0.94, forKey: kCIInputContrastKey)
                        cc.setValue(1.02, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "idol":
            if let cc = CIFilter(name: "CIColorControls") {
                cc.setValue(filtered, forKey: kCIInputImageKey)
                cc.setValue(0.05, forKey: kCIInputBrightnessKey)
                cc.setValue(1.18, forKey: kCIInputContrastKey)
                cc.setValue(1.22, forKey: kCIInputSaturationKey)
                if let out = cc.outputImage {
                    if let gamma = CIFilter(name: "CIGammaAdjust") {
                        gamma.setValue(out, forKey: kCIInputImageKey)
                        gamma.setValue(0.90, forKey: "inputPower")
                        if let out2 = gamma.outputImage { filtered = out2 }
                    }
                }
            }
        case "film":
            if let f = CIFilter(name: "CIPhotoEffectProcess") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "kodak":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 7700, y: 14), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.14, forKey: kCIInputContrastKey)
                        cc.setValue(1.16, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "fuji":
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: 1.05, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.10, w: 0.0), forKey: "inputBVector")
                matrix.setValue(CIVector(x: 0.01, y: 0.02, z: 0.04, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.10, forKey: kCIInputContrastKey)
                        cc.setValue(1.08, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "retro":
            if let f = CIFilter(name: "CIPhotoEffectTransfer") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "vintage":
            if let f = CIFilter(name: "CIPhotoEffectInstant") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "cinema":
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 1.12, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                matrix.setValue(CIVector(x: 0.0, y: 1.02, z: 0.0, w: 0.0), forKey: "inputGVector")
                matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 1.16, w: 0.0), forKey: "inputBVector")
                matrix.setValue(CIVector(x: -0.01, y: 0.01, z: 0.03, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.18, forKey: kCIInputContrastKey)
                        cc.setValue(1.12, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "warm":
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 8200, y: 15), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }
        case "sunset":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 8800, y: 22), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.10, forKey: kCIInputContrastKey)
                        cc.setValue(1.20, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "latte":
            if let matrix = CIFilter(name: "CIColorMatrix") {
                matrix.setValue(filtered, forKey: kCIInputImageKey)
                matrix.setValue(CIVector(x: 0.06, y: 0.04, z: 0.02, w: 0.0), forKey: "inputBiasVector")
                if let out = matrix.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.08, forKey: kCIInputContrastKey)
                        cc.setValue(0.92, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "autumn":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 8000, y: 12), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let matrix = CIFilter(name: "CIColorMatrix") {
                        matrix.setValue(out, forKey: kCIInputImageKey)
                        matrix.setValue(CIVector(x: 1.10, y: 0.0, z: 0.0, w: 0.0), forKey: "inputRVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.98, z: 0.0, w: 0.0), forKey: "inputGVector")
                        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 0.92, w: 0.0), forKey: "inputBVector")
                        if let out2 = matrix.outputImage {
                            if let cc = CIFilter(name: "CIColorControls") {
                                cc.setValue(out2, forKey: kCIInputImageKey)
                                cc.setValue(1.14, forKey: kCIInputContrastKey)
                                cc.setValue(1.18, forKey: kCIInputSaturationKey)
                                if let out3 = cc.outputImage { filtered = out3 }
                            }
                        }
                    }
                }
            }
        case "cool":
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                f.setValue(CIVector(x: 5200, y: -10), forKey: "inputTargetNeutral")
                if let out = f.outputImage { filtered = out }
            }
        case "nordic":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 4800, y: -8), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.12, forKey: kCIInputContrastKey)
                        cc.setValue(0.85, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "cyber":
            if let tt = CIFilter(name: "CITemperatureAndTint") {
                tt.setValue(filtered, forKey: kCIInputImageKey)
                tt.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                tt.setValue(CIVector(x: 5000, y: 35), forKey: "inputTargetNeutral")
                if let out = tt.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(1.22, forKey: kCIInputContrastKey)
                        cc.setValue(1.35, forKey: kCIInputSaturationKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
            }
        case "bw":
            if let f = CIFilter(name: "CIPhotoEffectMono") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "noir":
            if let f = CIFilter(name: "CIPhotoEffectNoir") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage { filtered = out }
            }
        case "silver":
            if let f = CIFilter(name: "CIPhotoEffectTonal") {
                f.setValue(filtered, forKey: kCIInputImageKey)
                if let out = f.outputImage {
                    if let cc = CIFilter(name: "CIColorControls") {
                        cc.setValue(out, forKey: kCIInputImageKey)
                        cc.setValue(0.04, forKey: kCIInputBrightnessKey)
                        cc.setValue(1.26, forKey: kCIInputContrastKey)
                        if let out2 = cc.outputImage { filtered = out2 }
                    }
                }
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

    // MARK: - Background Effects & Person Segmentation
    private func createPersonForegroundMask(
        sourceBuffer: CVPixelBuffer?,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage? {
        let width = extent.width
        let height = extent.height

        // 1. AI Person Segmentation (Apple Vision Neural Engine)
        var visionMask: CIImage? = nil
        if #available(macOS 12.0, *), let buffer = sourceBuffer {
            if let req = personSegmentationRequest as? VNGeneratePersonSegmentationRequest {
                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
                if (try? handler.perform([req])) != nil,
                   let maskBuf = req.results?.first?.pixelBuffer {
                    let rawMask = CIImage(cvPixelBuffer: maskBuf)
                    let sx = width / CGFloat(CVPixelBufferGetWidth(maskBuf))
                    let sy = height / CGFloat(CVPixelBufferGetHeight(maskBuf))
                    let scaled = rawMask.transformed(by: CGAffineTransform(scaleX: sx, y: sy)).cropped(to: extent)
                    if let blur = CIFilter(name: "CIGaussianBlur") {
                        blur.setValue(scaled, forKey: kCIInputImageKey)
                        blur.setValue(3.5, forKey: kCIInputRadiusKey)
                        visionMask = blur.outputImage?.cropped(to: extent)
                    } else {
                        visionMask = scaled
                    }
                }
            }
        }

        // 2. Anatomical Bust Silhouette Fallback (Head, Hair, Neck & Shoulders)
        var anatomicalMask: CIImage? = nil
        if landmarks.hasFace {
            let faceW = max(30.0, landmarks.boundingBox.width * width)
            let faceH = max(40.0, landmarks.boundingBox.height * height)
            let faceCenter = CGPoint(
                x: landmarks.boundingBox.midX * width,
                y: (1.0 - landmarks.boundingBox.midY) * height
            )

            let wInt = Int(width)
            let hInt = Int(height)
            if wInt > 0 && hInt > 0,
               let context = CGContext(
                    data: nil, width: wInt, height: hInt,
                    bitsPerComponent: 8, bytesPerRow: wInt,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
               ) {
                context.setFillColor(gray: 0.0, alpha: 1.0)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.setFillColor(gray: 1.0, alpha: 1.0)

                // Head ellipse (covering hair volume and face)
                let headRx = faceW * 0.70
                let headRy = faceH * 0.80
                context.fillEllipse(in: CGRect(
                    x: faceCenter.x - headRx,
                    y: faceCenter.y - headRy * 0.75,
                    width: headRx * 2.0,
                    height: headRy * 2.0
                ))

                // Torso / shoulders trapezoid connecting from neck down to bottom of frame (y = 0 in CI)
                let neckY = max(0.0, faceCenter.y - headRy * 0.7)
                let leftShoulderX = max(0.0, faceCenter.x - faceW * 2.4)
                let rightShoulderX = min(width, faceCenter.x + faceW * 2.4)
                let leftNeckX = faceCenter.x - faceW * 0.60
                let rightNeckX = faceCenter.x + faceW * 0.60

                let torsoPath = CGMutablePath()
                torsoPath.move(to: CGPoint(x: leftNeckX, y: neckY))
                torsoPath.addLine(to: CGPoint(x: rightNeckX, y: neckY))
                torsoPath.addLine(to: CGPoint(x: rightShoulderX, y: 0))
                torsoPath.addLine(to: CGPoint(x: leftShoulderX, y: 0))
                torsoPath.closeSubpath()

                context.addPath(torsoPath)
                context.fillPath()

                if let cgImg = context.makeImage() {
                    let rawCI = CIImage(cgImage: cgImg)
                    let feather = max(8.0, min(24.0, faceW * 0.06))
                    if let blur = CIFilter(name: "CIGaussianBlur") {
                        blur.setValue(rawCI, forKey: kCIInputImageKey)
                        blur.setValue(feather, forKey: kCIInputRadiusKey)
                        anatomicalMask = blur.outputImage?.cropped(to: extent)
                    } else {
                        anatomicalMask = rawCI
                    }
                }
            }
        }

        // 3. Composite ML Vision Mask with Anatomical Protection
        if let vMask = visionMask, let aMask = anatomicalMask {
            if let maxF = CIFilter(name: "CIMaximumCompositing") {
                maxF.setValue(vMask, forKey: kCIInputImageKey)
                maxF.setValue(aMask, forKey: kCIInputBackgroundImageKey)
                return maxF.outputImage?.cropped(to: extent)
            }
            return vMask
        } else if let vMask = visionMask {
            return vMask
        } else {
            return anatomicalMask
        }
    }

    private func applyBackgroundEffects(
        image: CIImage,
        sourceBuffer: CVPixelBuffer?,
        mode: String,
        intensity: Double,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard mode != "none" && intensity > 0.01 else { return image }

        let width = extent.width
        let height = extent.height
        let faceCenter: CGPoint
        if landmarks.hasFace {
            faceCenter = CGPoint(
                x: landmarks.boundingBox.midX * width,
                y: (1.0 - landmarks.boundingBox.midY) * height
            )
        } else {
            faceCenter = CGPoint(x: width * 0.5, y: height * 0.5)
        }

        var backgroundEffect = image

        switch mode {
        case "portrait_blur":
            // 1. Chân Dung Tự Nhiên (Portrait Bokeh): Ống kính khẩu f/1.8, bokeh tròn dịu mắt
            let r = max(3.0, intensity * 28.0)
            if let disc = CIFilter(name: "CIDiscBlur") {
                disc.setValue(image, forKey: kCIInputImageKey)
                disc.setValue(r, forKey: kCIInputRadiusKey)
                backgroundEffect = disc.outputImage?.cropped(to: extent) ?? image
            } else if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(image, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                backgroundEffect = blur.outputImage?.cropped(to: extent) ?? image
            }

        case "strong_blur":
            // 2. Mờ Sâu Điện Ảnh (Cinematic Deep Blur): Tiêu cự tele 85mm f/1.2, xóa sạch hậu cảnh lộn xộn
            let r = max(12.0, intensity * 75.0)
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(image, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                if let blurred = blur.outputImage?.cropped(to: extent) {
                    backgroundEffect = blurred.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.95])
                }
            }

        case "virtual_studio":
            // 3. Studio Chuyên Nghiệp (Studio Backdrop): Nền mờ mịn + Dark Vignette 4 góc + Ánh sáng Studio
            let r = max(4.0, intensity * 35.0)
            var current = image
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(current, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                current = blur.outputImage?.cropped(to: extent) ?? current
            }
            if let colorAdjust = CIFilter(name: "CIColorControls") {
                colorAdjust.setValue(current, forKey: kCIInputImageKey)
                colorAdjust.setValue(Float(-0.08 * intensity), forKey: kCIInputBrightnessKey)
                colorAdjust.setValue(Float(1.0 + 0.14 * intensity), forKey: kCIInputContrastKey)
                colorAdjust.setValue(Float(1.0 - 0.10 * intensity), forKey: kCIInputSaturationKey)
                current = colorAdjust.outputImage?.cropped(to: extent) ?? current
            }
            if let vignette = CIFilter(name: "CIVignette") {
                vignette.setValue(current, forKey: kCIInputImageKey)
                vignette.setValue(Float(1.4 * intensity), forKey: kCIInputIntensityKey)
                vignette.setValue(Float(1.5), forKey: kCIInputRadiusKey)
                current = vignette.outputImage?.cropped(to: extent) ?? current
            }
            backgroundEffect = current

        case "zoom_blur":
            // 4. Hướng Tâm Năng Động (Radial Zoom Motion): Vệt chuyển động từ tâm khuôn mặt ra ngoài
            let amount = max(2.0, intensity * 40.0)
            if let zoom = CIFilter(name: "CIZoomBlur") {
                zoom.setValue(image, forKey: kCIInputImageKey)
                zoom.setValue(CIVector(cgPoint: faceCenter), forKey: "inputCenter")
                zoom.setValue(amount, forKey: "inputAmount")
                backgroundEffect = zoom.outputImage?.cropped(to: extent) ?? image
            }

        case "swirly_bokeh":
            // 5. Bokeh Xoáy Cổ Điển (Vintage Petzval Swirl): Xoáy tròn ma mị ở rìa ảnh
            let r = max(3.0, intensity * 24.0)
            var current = image
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(current, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                current = blur.outputImage?.cropped(to: extent) ?? current
            }
            if let twirl = CIFilter(name: "CITwirlDistortion") {
                twirl.setValue(current, forKey: kCIInputImageKey)
                twirl.setValue(CIVector(cgPoint: faceCenter), forKey: "inputCenter")
                twirl.setValue(max(width, height) * 0.75, forKey: "inputRadius")
                twirl.setValue(Float(intensity * 1.8), forKey: "inputAngle")
                current = twirl.outputImage?.cropped(to: extent) ?? current
            }
            if let vignette = CIFilter(name: "CIVignette") {
                vignette.setValue(current, forKey: kCIInputImageKey)
                vignette.setValue(Float(0.8 * intensity), forKey: kCIInputIntensityKey)
                vignette.setValue(Float(1.8), forKey: kCIInputRadiusKey)
                current = vignette.outputImage?.cropped(to: extent) ?? current
            }
            backgroundEffect = current

        case "dreamy_blur":
            // 6. Mộng Ảo Thiên Thần (Pastel Bloom Glow): Hậu cảnh mờ ảo phát sáng lung linh
            let r = max(4.0, intensity * 32.0)
            var current = image
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(current, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                current = blur.outputImage?.cropped(to: extent) ?? current
            }
            if let bloom = CIFilter(name: "CIBloom") {
                bloom.setValue(current, forKey: kCIInputImageKey)
                bloom.setValue(max(5.0, intensity * 25.0), forKey: kCIInputRadiusKey)
                bloom.setValue(Float(0.9 * intensity), forKey: kCIInputIntensityKey)
                current = bloom.outputImage?.cropped(to: extent) ?? current
            }
            if let color = CIFilter(name: "CIColorControls") {
                color.setValue(current, forKey: kCIInputImageKey)
                color.setValue(Float(0.04 * intensity), forKey: kCIInputBrightnessKey)
                color.setValue(Float(1.0 - 0.20 * intensity), forKey: kCIInputSaturationKey)
                current = color.outputImage?.cropped(to: extent) ?? current
            }
            backgroundEffect = current

        case "motion_blur":
            // 7. Chuyển Động Điện Ảnh (Cinematic Motion Panning): Mờ vệt ngang sống động
            let r = max(4.0, intensity * 45.0)
            if let motion = CIFilter(name: "CIMotionBlur") {
                motion.setValue(image, forKey: kCIInputImageKey)
                motion.setValue(r, forKey: kCIInputRadiusKey)
                motion.setValue(0.0, forKey: kCIInputAngleKey)
                backgroundEffect = motion.outputImage?.cropped(to: extent) ?? image
            }

        default:
            // Fallback: Portrait Blur
            let r = max(3.0, intensity * 25.0)
            if let blur = CIFilter(name: "CIGaussianBlur") {
                blur.setValue(image, forKey: kCIInputImageKey)
                blur.setValue(r, forKey: kCIInputRadiusKey)
                backgroundEffect = blur.outputImage?.cropped(to: extent) ?? image
            }
        }

        // Tách chủ thể và hòa trộn (Foreground Isolation via Mask)
        if let personMask = createPersonForegroundMask(sourceBuffer: sourceBuffer, landmarks: landmarks, extent: extent) {
            if let blend = CIFilter(name: "CIBlendWithMask") {
                blend.setValue(image, forKey: kCIInputImageKey)
                blend.setValue(backgroundEffect, forKey: kCIInputBackgroundImageKey)
                blend.setValue(personMask, forKey: kCIInputMaskImageKey)
                return blend.outputImage?.cropped(to: extent) ?? backgroundEffect
            }
        }

        return backgroundEffect
    }

    // MARK: - Aegyo-Sal / Bọng Mắt Cười
    /// Creates realistic Korean/Douyin style aegyo-sal (youthful under-eye smile rolls).
    /// Generates a luminous plump highlight directly under the lower lash line
    /// combined with a soft depth shadow groove beneath to create a natural 3D smile bag.
    private func applyAegyoSal(
        image: CIImage,
        intensity: Double,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard intensity > 0.01, landmarks.hasFace else { return image }
        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        func lmPt(_ idx: Int) -> CGPoint {
            guard idx < landmarks.landmarks.count else { return .zero }
            let lm = landmarks.landmarks[idx]
            return CGPoint(x: CGFloat(lm.x) * width, y: CGFloat(1.0 - lm.y) * height)
        }

        // Lower eyelid curves
        var rightLowerLash: [CGPoint] = []
        var leftLowerLash: [CGPoint] = []

        if landmarks.landmarks.count >= 468 {
            // Camera Left (subject's right): lower lash line from inner to outer corner
            let rIndices = [133, 155, 154, 153, 145, 144, 163, 7, 33]
            rightLowerLash = rIndices.map { lmPt($0) }
            // Camera Right (subject's left): lower lash line from inner to outer corner
            let lIndices = [362, 382, 381, 380, 374, 373, 390, 249, 263]
            leftLowerLash = lIndices.map { lmPt($0) }
        } else if !landmarks.rightEyeContour.isEmpty && !landmarks.leftEyeContour.isEmpty {
            let halfR = landmarks.rightEyeContour.count / 2
            rightLowerLash = landmarks.rightEyeContour.suffix(from: halfR).map { pt($0) }
            let halfL = landmarks.leftEyeContour.count / 2
            leftLowerLash = landmarks.leftEyeContour.suffix(from: halfL).map { pt($0) }
        } else {
            let eyeR = pt(landmarks.rightEyeCenter)
            let eyeL = pt(landmarks.leftEyeCenter)
            let eyeSpan = faceW * 0.08
            let offsetDown = faceH * 0.02
            rightLowerLash = [
                CGPoint(x: eyeR.x - eyeSpan, y: eyeR.y - offsetDown),
                CGPoint(x: eyeR.x, y: eyeR.y - offsetDown * 1.5),
                CGPoint(x: eyeR.x + eyeSpan, y: eyeR.y - offsetDown)
            ]
            leftLowerLash = [
                CGPoint(x: eyeL.x - eyeSpan, y: eyeL.y - offsetDown),
                CGPoint(x: eyeL.x, y: eyeL.y - offsetDown * 1.5),
                CGPoint(x: eyeL.x + eyeSpan, y: eyeL.y - offsetDown)
            ]
        }

        guard rightLowerLash.count >= 2, leftLowerLash.count >= 2 else { return image }

        let allPoints = rightLowerLash + leftLowerLash
        guard let minX = allPoints.map(\.x).min(), let maxX = allPoints.map(\.x).max(),
              let minY = allPoints.map(\.y).min(), let maxY = allPoints.map(\.y).max() else { return image }

        let bagPad = faceW * 0.06
        let bagBounds = CGRect(
            x: minX - bagPad,
            y: minY - bagPad * 1.5,
            width: (maxX - minX) + bagPad * 2.0,
            height: (maxY - minY) + bagPad * 2.5
        ).intersection(extent).integral

        guard !bagBounds.isEmpty,
              let bW = Int(exactly: bagBounds.width), let bH = Int(exactly: bagBounds.height),
              bW > 0, bH > 0 else { return image }

        // Render Highlight & Shadow into two separate mask buffers
        let colorSpace = CGColorSpaceCreateDeviceGray()

        // 1. Highlight Mask (the plump roll)
        guard let hlContext = CGContext(
            data: nil, width: bW, height: bH, bitsPerComponent: 8, bytesPerRow: bW,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        hlContext.setFillColor(gray: 0.0, alpha: 1.0)
        hlContext.fill(CGRect(x: 0, y: 0, width: bW, height: bH))
        hlContext.translateBy(x: -bagBounds.minX, y: -bagBounds.minY)

        let hlStrokeWidth = max(2.5, faceW * 0.016)
        hlContext.setLineWidth(hlStrokeWidth)
        hlContext.setLineCap(.round)
        hlContext.setLineJoin(.round)
        hlContext.setStrokeColor(gray: 1.0, alpha: 1.0)

        let rollOffset = faceH * 0.014
        func drawOffsetPath(points: [CGPoint], dy: CGFloat, in ctx: CGContext) {
            guard let first = points.first else { return }
            let p = CGMutablePath()
            p.move(to: CGPoint(x: first.x, y: first.y - dy))
            for pt in points.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x, y: pt.y - dy))
            }
            ctx.addPath(p)
            ctx.strokePath()
        }

        drawOffsetPath(points: rightLowerLash, dy: rollOffset, in: hlContext)
        drawOffsetPath(points: leftLowerLash, dy: rollOffset, in: hlContext)

        guard let hlBitmap = hlContext.makeImage() else { return image }
        var hlMask = CIImage(cgImage: hlBitmap).transformed(by: CGAffineTransform(translationX: bagBounds.minX, y: bagBounds.minY))

        // 2. Shadow Mask (the crease groove underneath)
        guard let shContext = CGContext(
            data: nil, width: bW, height: bH, bitsPerComponent: 8, bytesPerRow: bW,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        shContext.setFillColor(gray: 0.0, alpha: 1.0)
        shContext.fill(CGRect(x: 0, y: 0, width: bW, height: bH))
        shContext.translateBy(x: -bagBounds.minX, y: -bagBounds.minY)

        let shStrokeWidth = max(1.5, faceW * 0.009)
        shContext.setLineWidth(shStrokeWidth)
        shContext.setLineCap(.round)
        shContext.setLineJoin(.round)
        shContext.setStrokeColor(gray: 1.0, alpha: 1.0)

        let shadowOffset = faceH * 0.026
        drawOffsetPath(points: rightLowerLash, dy: shadowOffset, in: shContext)
        drawOffsetPath(points: leftLowerLash, dy: shadowOffset, in: shContext)

        guard let shBitmap = shContext.makeImage() else { return image }
        var shMask = CIImage(cgImage: shBitmap).transformed(by: CGAffineTransform(translationX: bagBounds.minX, y: bagBounds.minY))

        // Soft Gaussian Blur for natural flesh integration
        let blurHl = max(2.0, Double(faceW * 0.012))
        let blurSh = max(1.5, Double(faceW * 0.008))

        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(hlMask, forKey: kCIInputImageKey)
            blurFilter.setValue(blurHl, forKey: kCIInputRadiusKey)
            if let out = blurFilter.outputImage?.cropped(to: extent) { hlMask = out }

            blurFilter.setValue(shMask, forKey: kCIInputImageKey)
            blurFilter.setValue(blurSh, forKey: kCIInputRadiusKey)
            if let out = blurFilter.outputImage?.cropped(to: extent) { shMask = out }
        }

        var result = image

        // A. Composite Shadow Crease (Natural soft taupe-brown shadow)
        let shOpacity = CGFloat(intensity * 0.42)
        let shadowColor = CIImage(color: CIColor(red: 0.38, green: 0.28, blue: 0.24, alpha: 1.0)).cropped(to: extent)
        if let softLight = CIFilter(name: "CISoftLightBlendMode") {
            softLight.setValue(shadowColor, forKey: kCIInputImageKey)
            softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
            if let tinted = softLight.outputImage {
                var effShMask = shMask
                if let matrix = CIFilter(name: "CIColorMatrix") {
                    matrix.setValue(shMask, forKey: kCIInputImageKey)
                    matrix.setValue(CIVector(x: shOpacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    matrix.setValue(CIVector(x: 0, y: shOpacity, z: 0, w: 0), forKey: "inputGVector")
                    matrix.setValue(CIVector(x: 0, y: 0, z: shOpacity, w: 0), forKey: "inputBVector")
                    if let out = matrix.outputImage { effShMask = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(tinted, forKey: kCIInputImageKey)
                    blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(effShMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { result = out }
                }
            }
        }

        // B. Composite Plump Highlight (Luminous champagne/ivory pearl)
        let hlOpacity = CGFloat(intensity * 0.55)
        let hlColor = CIImage(color: CIColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1.0)).cropped(to: extent)
        if let softLight = CIFilter(name: "CISoftLightBlendMode") {
            softLight.setValue(hlColor, forKey: kCIInputImageKey)
            softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
            if let tinted = softLight.outputImage {
                var effHlMask = hlMask
                if let matrix = CIFilter(name: "CIColorMatrix") {
                    matrix.setValue(hlMask, forKey: kCIInputImageKey)
                    matrix.setValue(CIVector(x: hlOpacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    matrix.setValue(CIVector(x: 0, y: hlOpacity, z: 0, w: 0), forKey: "inputGVector")
                    matrix.setValue(CIVector(x: 0, y: 0, z: hlOpacity, w: 0), forKey: "inputBVector")
                    if let out = matrix.outputImage { effHlMask = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(tinted, forKey: kCIInputImageKey)
                    blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(effHlMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { result = out }
                }
            }
        }

        return result
    }

    // MARK: - Contour & Highlight Makeup (Trang Điểm Tạo Khối & Bắt Sáng)
    private func applyContour(
        image: CIImage,
        makeup: MakeupSettings,
        landmarks: FaceMeshLandmarks,
        extent: CGRect
    ) -> CIImage {
        guard makeup.contourPreset != "none", makeup.contourOpacity > 0.01, landmarks.hasFace else { return image }

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        // 1. Color Palette for Contour
        var cR: CGFloat = 0.58; var cG: CGFloat = 0.46; var cB: CGFloat = 0.40
        switch makeup.contourPreset {
        case "taupe":      cR = 0.58; cG = 0.46; cB = 0.40 // Natural Taupe
        case "warmBrown":  cR = 0.64; cG = 0.44; cB = 0.34 // Warm Brown
        case "coolAsh":    cR = 0.52; cG = 0.46; cB = 0.46 // Cool Ash
        case "bronze":     cR = 0.68; cG = 0.46; cB = 0.32 // Bronze Glow
        case "caramel":    cR = 0.62; cG = 0.42; cB = 0.30 // Warm Caramel
        case "deep":       cR = 0.42; cG = 0.30; cB = 0.24 // Deep Espresso
        case "softTaupe":  cR = 0.66; cG = 0.54; cB = 0.48 // Soft Taupe
        default:           cR = 0.58; cG = 0.46; cB = 0.40
        }

        // Highlight color: Warm champagne pearl
        let hR: CGFloat = 0.98; let hG: CGFloat = 0.95; let hB: CGFloat = 0.90

        let style = makeup.contourStyle // vShape, natural, sculpted, nose, soft

        // Context for full face bounds
        let faceBounds = CGRect(
            x: box.minX * width,
            y: (1.0 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        ).insetBy(dx: -faceW * 0.15, dy: -faceH * 0.15).intersection(extent).integral

        guard !faceBounds.isEmpty,
              let fbW = Int(exactly: faceBounds.width), let fbH = Int(exactly: faceBounds.height),
              fbW > 0, fbH > 0 else { return image }

        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Create Shadow Mask
        guard let shCtx = CGContext(
            data: nil, width: fbW, height: fbH, bitsPerComponent: 8, bytesPerRow: fbW,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        shCtx.setFillColor(gray: 0.0, alpha: 1.0)
        shCtx.fill(CGRect(x: 0, y: 0, width: fbW, height: fbH))
        shCtx.translateBy(x: -faceBounds.minX, y: -faceBounds.minY)

        // Create Highlight Mask
        guard let hlCtx = CGContext(
            data: nil, width: fbW, height: fbH, bitsPerComponent: 8, bytesPerRow: fbW,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        hlCtx.setFillColor(gray: 0.0, alpha: 1.0)
        hlCtx.fill(CGRect(x: 0, y: 0, width: fbW, height: fbH))
        hlCtx.translateBy(x: -faceBounds.minX, y: -faceBounds.minY)

        let noseBridgePt = pt(landmarks.noseBridge)
        let noseTipPt = pt(landmarks.noseTip)
        let leftAlarPt = pt(landmarks.leftAlar)
        let rightAlarPt = pt(landmarks.rightAlar)
        let chinTipPt = pt(landmarks.chinTip)
        let foreheadPt = pt(landmarks.foreheadCenter)
        let leftCheekPt = pt(landmarks.leftCheekCenter)
        let rightCheekPt = pt(landmarks.rightCheekCenter)
        let leftMidJawPt = pt(landmarks.leftMidJaw)
        let rightMidJawPt = pt(landmarks.rightMidJaw)
        let leftLowerJawPt = pt(landmarks.leftLowerJaw)
        let rightLowerJawPt = pt(landmarks.rightLowerJaw)
        let leftTemplePt = pt(landmarks.leftTemple)
        let rightTemplePt = pt(landmarks.rightTemple)

        shCtx.setLineCap(.round)
        shCtx.setLineJoin(.round)
        hlCtx.setLineCap(.round)
        hlCtx.setLineJoin(.round)

        // A. Nose Contour & Bridge Highlight (All styles, with nose style emphasized)
        let noseStrokeW = max(3.0, faceW * (style == "nose" ? 0.024 : 0.018))
        shCtx.setLineWidth(noseStrokeW)
        shCtx.setStrokeColor(gray: style == "nose" ? 1.0 : 0.75, alpha: 1.0)

        let noseOffset = faceW * 0.032
        // Left nose bridge side
        shCtx.move(to: CGPoint(x: noseBridgePt.x - noseOffset, y: noseBridgePt.y))
        shCtx.addLine(to: CGPoint(x: leftAlarPt.x * 0.7 + noseTipPt.x * 0.3, y: leftAlarPt.y))
        shCtx.strokePath()

        // Right nose bridge side
        shCtx.move(to: CGPoint(x: noseBridgePt.x + noseOffset, y: noseBridgePt.y))
        shCtx.addLine(to: CGPoint(x: rightAlarPt.x * 0.7 + noseTipPt.x * 0.3, y: rightAlarPt.y))
        shCtx.strokePath()

        // Nose Bridge Highlight Stripe
        let hlBridgeW = max(2.5, faceW * 0.014)
        hlCtx.setLineWidth(hlBridgeW)
        hlCtx.setStrokeColor(gray: 1.0, alpha: 1.0)
        let bridgeMid = CGPoint(x: (noseBridgePt.x + noseTipPt.x) * 0.5, y: (noseBridgePt.y + noseTipPt.y) * 0.5)
        hlCtx.move(to: CGPoint(x: noseBridgePt.x, y: noseBridgePt.y - faceH * 0.02))
        hlCtx.addLine(to: CGPoint(x: bridgeMid.x, y: bridgeMid.y))
        hlCtx.strokePath()

        // Nose Tip Highlight Dot
        let tipRad = max(2.0, faceW * 0.012)
        hlCtx.setFillColor(gray: 1.0, alpha: 1.0)
        hlCtx.fillEllipse(in: CGRect(x: noseTipPt.x - tipRad, y: noseTipPt.y - tipRad, width: tipRad * 2, height: tipRad * 2))

        // B. Cheek Hollow & Cheekbone Contouring (styles != "nose")
        if style != "nose" {
            let cheekShW = max(8.0, faceW * (style == "sculpted" ? 0.065 : 0.045))
            shCtx.setLineWidth(cheekShW)
            shCtx.setStrokeColor(gray: style == "sculpted" ? 1.0 : 0.80, alpha: 1.0)

            // Cheek hollow under zygoma (from ear forward toward mouth corner)
            let leftEarJaw = CGPoint(x: leftTemplePt.x * 0.6 + leftMidJawPt.x * 0.4, y: leftTemplePt.y * 0.4 + leftMidJawPt.y * 0.6)
            let rightEarJaw = CGPoint(x: rightTemplePt.x * 0.6 + rightMidJawPt.x * 0.4, y: rightTemplePt.y * 0.4 + rightMidJawPt.y * 0.6)

            shCtx.move(to: leftEarJaw)
            shCtx.addLine(to: CGPoint(x: leftCheekPt.x * 0.8 + leftLowerJawPt.x * 0.2, y: leftCheekPt.y - faceH * 0.03))
            shCtx.strokePath()

            shCtx.move(to: rightEarJaw)
            shCtx.addLine(to: CGPoint(x: rightCheekPt.x * 0.8 + rightLowerJawPt.x * 0.2, y: rightCheekPt.y - faceH * 0.03))
            shCtx.strokePath()

            // Cheekbone Highlighting (on the apple & crest above the contour)
            let hlCheekRad = max(5.0, faceW * 0.030)
            let leftCrest = CGPoint(x: leftCheekPt.x, y: leftCheekPt.y + faceH * 0.03)
            let rightCrest = CGPoint(x: rightCheekPt.x, y: rightCheekPt.y + faceH * 0.03)
            hlCtx.fillEllipse(in: CGRect(x: leftCrest.x - hlCheekRad * 1.5, y: leftCrest.y - hlCheekRad, width: hlCheekRad * 3.0, height: hlCheekRad * 2.0))
            hlCtx.fillEllipse(in: CGRect(x: rightCrest.x - hlCheekRad * 1.5, y: rightCrest.y - hlCheekRad, width: hlCheekRad * 3.0, height: hlCheekRad * 2.0))
        }

        // C. Jawline & Chin Shading
        if style == "vShape" || style == "sculpted" {
            let jawShW = max(6.0, faceW * (style == "vShape" ? 0.055 : 0.040))
            shCtx.setLineWidth(jawShW)
            shCtx.setStrokeColor(gray: 0.90, alpha: 1.0)

            // Mandibular jawline strokes
            shCtx.move(to: leftMidJawPt)
            shCtx.addLine(to: leftLowerJawPt)
            shCtx.addLine(to: CGPoint(x: chinTipPt.x - faceW * 0.04, y: chinTipPt.y))
            shCtx.strokePath()

            shCtx.move(to: rightMidJawPt)
            shCtx.addLine(to: rightLowerJawPt)
            shCtx.addLine(to: CGPoint(x: chinTipPt.x + faceW * 0.04, y: chinTipPt.y))
            shCtx.strokePath()

            // Sub-chin shadow
            shCtx.move(to: CGPoint(x: chinTipPt.x - faceW * 0.05, y: chinTipPt.y - faceH * 0.02))
            shCtx.addLine(to: CGPoint(x: chinTipPt.x + faceW * 0.05, y: chinTipPt.y - faceH * 0.02))
            shCtx.strokePath()

            // Center Chin Highlight
            let chinHlRad = max(3.0, faceW * 0.018)
            hlCtx.fillEllipse(in: CGRect(x: chinTipPt.x - chinHlRad, y: chinTipPt.y + faceH * 0.01 - chinHlRad, width: chinHlRad * 2, height: chinHlRad * 2))
        }

        // D. Forehead / Temple Contouring & Center Forehead Highlight
        if style == "sculpted" || style == "natural" || style == "vShape" {
            let templeShW = max(6.0, faceW * 0.040)
            shCtx.setLineWidth(templeShW)
            shCtx.setStrokeColor(gray: 0.70, alpha: 1.0)

            shCtx.move(to: leftTemplePt)
            shCtx.addLine(to: CGPoint(x: foreheadPt.x - faceW * 0.15, y: foreheadPt.y + faceH * 0.05))
            shCtx.strokePath()

            shCtx.move(to: rightTemplePt)
            shCtx.addLine(to: CGPoint(x: foreheadPt.x + faceW * 0.15, y: foreheadPt.y + faceH * 0.05))
            shCtx.strokePath()

            // Forehead Center Highlight
            let foreHlRad = max(6.0, faceW * 0.035)
            hlCtx.fillEllipse(in: CGRect(x: foreheadPt.x - foreHlRad * 1.2, y: foreheadPt.y - foreHlRad * 0.8, width: foreHlRad * 2.4, height: foreHlRad * 1.6))
        }

        guard let shBitmap = shCtx.makeImage(), let hlBitmap = hlCtx.makeImage() else { return image }
        var shMask = CIImage(cgImage: shBitmap).transformed(by: CGAffineTransform(translationX: faceBounds.minX, y: faceBounds.minY))
        var hlMask = CIImage(cgImage: hlBitmap).transformed(by: CGAffineTransform(translationX: faceBounds.minX, y: faceBounds.minY))

        // Feathering Gaussian Blur for seamless, diffused makeup blending
        let blurRad = max(5.0, Double(faceW * 0.040))
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(shMask, forKey: kCIInputImageKey)
            blurFilter.setValue(blurRad, forKey: kCIInputRadiusKey)
            if let out = blurFilter.outputImage?.cropped(to: extent) { shMask = out }

            blurFilter.setValue(hlMask, forKey: kCIInputImageKey)
            blurFilter.setValue(blurRad * 0.85, forKey: kCIInputRadiusKey)
            if let out = blurFilter.outputImage?.cropped(to: extent) { hlMask = out }
        }

        var result = image

        // Composite Contour Shading
        let shadowOpacity = CGFloat(makeup.contourOpacity * 0.55)
        let shadowColorImg = CIImage(color: CIColor(red: cR, green: cG, blue: cB, alpha: 1.0)).cropped(to: extent)
        if let softLight = CIFilter(name: "CISoftLightBlendMode") {
            softLight.setValue(shadowColorImg, forKey: kCIInputImageKey)
            softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
            if let tinted = softLight.outputImage {
                var effShMask = shMask
                if let matrix = CIFilter(name: "CIColorMatrix") {
                    matrix.setValue(shMask, forKey: kCIInputImageKey)
                    matrix.setValue(CIVector(x: shadowOpacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    matrix.setValue(CIVector(x: 0, y: shadowOpacity, z: 0, w: 0), forKey: "inputGVector")
                    matrix.setValue(CIVector(x: 0, y: 0, z: shadowOpacity, w: 0), forKey: "inputBVector")
                    if let out = matrix.outputImage { effShMask = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(tinted, forKey: kCIInputImageKey)
                    blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(effShMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { result = out }
                }
            }
        }

        // Composite Highlight
        let hlOpacity = CGFloat(makeup.contourOpacity * 0.45)
        let hlColorImg = CIImage(color: CIColor(red: hR, green: hG, blue: hB, alpha: 1.0)).cropped(to: extent)
        if let softLight = CIFilter(name: "CISoftLightBlendMode") {
            softLight.setValue(hlColorImg, forKey: kCIInputImageKey)
            softLight.setValue(result, forKey: kCIInputBackgroundImageKey)
            if let tinted = softLight.outputImage {
                var effHlMask = hlMask
                if let matrix = CIFilter(name: "CIColorMatrix") {
                    matrix.setValue(hlMask, forKey: kCIInputImageKey)
                    matrix.setValue(CIVector(x: hlOpacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    matrix.setValue(CIVector(x: 0, y: hlOpacity, z: 0, w: 0), forKey: "inputGVector")
                    matrix.setValue(CIVector(x: 0, y: 0, z: hlOpacity, w: 0), forKey: "inputBVector")
                    if let out = matrix.outputImage { effHlMask = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(tinted, forKey: kCIInputImageKey)
                    blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(effHlMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { result = out }
                }
            }
        }

        return result
    }

    // MARK: - Glass Skin / Làm Da Bóng Mịn (Dewy Specular Glow)
    /// Emulates Korean "Glass Skin" (mịn màng căng bóng tự nhiên).
    /// Places liquid dewy specular highlights across facial focal points
    /// (high cheekbones, nose bridge, tip, forehead center, and chin)
    /// strictly bounded to skin mask with soft, translucent radiance.
    private func applyGlassSkin(
        image: CIImage,
        intensity: Double,
        landmarks: FaceMeshLandmarks,
        extent: CGRect,
        skinMask: CIImage?
    ) -> CIImage {
        guard intensity > 0.01, landmarks.hasFace else { return image }

        let width = extent.width
        let height = extent.height
        let box = landmarks.boundingBox
        let faceW = max(50.0, box.width * width)
        let faceH = max(60.0, box.height * height)

        func pt(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x * width, y: (1.0 - p.y) * height)
        }

        let cheekAppleL = landmarks.leftCheekApple != .zero ? pt(landmarks.leftCheekApple) : pt(landmarks.leftCheekCenter)
        let cheekAppleR = landmarks.rightCheekApple != .zero ? pt(landmarks.rightCheekApple) : pt(landmarks.rightCheekCenter)
        let noseBridgePt = pt(landmarks.noseBridge)
        let noseTipPt = pt(landmarks.noseTip)
        let foreheadPt = pt(landmarks.foreheadCenter)
        let chinTipPt = pt(landmarks.chinTip)

        let faceBounds = CGRect(
            x: box.minX * width,
            y: (1.0 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        ).insetBy(dx: -faceW * 0.10, dy: -faceH * 0.10).intersection(extent).integral

        guard !faceBounds.isEmpty,
              let fbW = Int(exactly: faceBounds.width), let fbH = Int(exactly: faceBounds.height),
              fbW > 0, fbH > 0 else { return image }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: fbW, height: fbH, bitsPerComponent: 8, bytesPerRow: fbW,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }

        ctx.setFillColor(gray: 0.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: fbW, height: fbH))
        ctx.translateBy(x: -faceBounds.minX, y: -faceBounds.minY)

        // Draw specular dewy spots at high facial points
        func drawGlowSpot(center: CGPoint, rx: CGFloat, ry: CGFloat, alpha: CGFloat) {
            ctx.setFillColor(gray: alpha, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2.0, height: ry * 2.0))
        }

        // 1. Cheekbone high points (dewy liquid sheen)
        let cheekRx = faceW * 0.065
        let cheekRy = faceH * 0.045
        drawGlowSpot(center: CGPoint(x: cheekAppleL.x, y: cheekAppleL.y + faceH * 0.02), rx: cheekRx, ry: cheekRy, alpha: 0.75)
        drawGlowSpot(center: CGPoint(x: cheekAppleR.x, y: cheekAppleR.y + faceH * 0.02), rx: cheekRx, ry: cheekRy, alpha: 0.75)

        // 2. Nose bridge & tip (delicate specular reflection)
        let midBridge = CGPoint(x: (noseBridgePt.x + noseTipPt.x) * 0.5, y: (noseBridgePt.y + noseTipPt.y) * 0.5)
        drawGlowSpot(center: midBridge, rx: faceW * 0.016, ry: faceH * 0.035, alpha: 0.85)
        drawGlowSpot(center: noseTipPt, rx: faceW * 0.018, ry: faceW * 0.018, alpha: 0.90)

        // 3. Forehead center (subtle hydrated reflection)
        drawGlowSpot(center: foreheadPt, rx: faceW * 0.055, ry: faceH * 0.030, alpha: 0.55)

        // 4. Chin tip (youthful dewy point)
        drawGlowSpot(center: CGPoint(x: chinTipPt.x, y: chinTipPt.y + faceH * 0.015), rx: faceW * 0.022, ry: faceH * 0.018, alpha: 0.65)

        guard let spotBitmap = ctx.makeImage() else { return image }
        var sheenMask = CIImage(cgImage: spotBitmap).transformed(by: CGAffineTransform(translationX: faceBounds.minX, y: faceBounds.minY))

        // Blur for silky, seamless transition into skin
        let blurRad = max(4.0, Double(faceW * 0.035))
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(sheenMask, forKey: kCIInputImageKey)
            blurFilter.setValue(blurRad, forKey: kCIInputRadiusKey)
            if let out = blurFilter.outputImage?.cropped(to: extent) { sheenMask = out }
        }

        // Gate strictly by skinMask (or fullFaceSkinMask) to prevent any sheen outside skin
        if let mask = skinMask ?? createFullFaceSkinMask(landmarks: landmarks, extent: extent) {
            if let multiplyMask = CIFilter(name: "CIMultiplyCompositing") {
                multiplyMask.setValue(sheenMask, forKey: kCIInputImageKey)
                multiplyMask.setValue(mask, forKey: kCIInputBackgroundImageKey)
                if let out = multiplyMask.outputImage?.cropped(to: extent) { sheenMask = out }
            }
        }

        // Composite dewy sheen with CIScreenBlendMode
        let glowOpacity = CGFloat(intensity * 0.40)
        let sheenColor = CIImage(color: CIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)).cropped(to: extent)

        if let screenBlend = CIFilter(name: "CIScreenBlendMode") {
            screenBlend.setValue(sheenColor, forKey: kCIInputImageKey)
            screenBlend.setValue(image, forKey: kCIInputBackgroundImageKey)
            if let screened = screenBlend.outputImage {
                var effMask = sheenMask
                if let matrix = CIFilter(name: "CIColorMatrix") {
                    matrix.setValue(sheenMask, forKey: kCIInputImageKey)
                    matrix.setValue(CIVector(x: glowOpacity, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    matrix.setValue(CIVector(x: 0, y: glowOpacity, z: 0, w: 0), forKey: "inputGVector")
                    matrix.setValue(CIVector(x: 0, y: 0, z: glowOpacity, w: 0), forKey: "inputBVector")
                    if let out = matrix.outputImage { effMask = out }
                }
                if let blend = CIFilter(name: "CIBlendWithMask") {
                    blend.setValue(screened, forKey: kCIInputImageKey)
                    blend.setValue(image, forKey: kCIInputBackgroundImageKey)
                    blend.setValue(effMask, forKey: kCIInputMaskImageKey)
                    if let out = blend.outputImage { return out }
                }
            }
        }

        return image
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
