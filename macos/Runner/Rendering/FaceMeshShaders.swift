import Foundation

public enum FaceMeshShaders {
    public static let source: String = """
#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct MaskVertexInput {
    float2 position [[attribute(0)]];
    float skinWeight [[attribute(1)]];
};

struct MaskVertexOutput {
    float4 clipPosition [[position]];
    float skinWeight;
};

struct ReshapeUniforms {
    float slimFace;
    float smallFace;
    float vFace;
    float chinLength;
    float chinWidth;
    float eyeSize;
    float noseWidth;
    float smile;
    float2 leftEyeCenter;
    float2 rightEyeCenter;
    float2 noseCenter;
    float2 chinCenter;
    float2 faceCenter;
    float faceWidth;
    float faceHeight;
};

struct ReshapeVertexOutput {
    float4 clipPosition [[position]];
    float2 uv;
    float alpha;
};

struct MakeupUniforms {
    float4 lipColor;    // rgb + opacity
    float4 blushColor;  // rgb + opacity
    uint makeupMode;    // 0 = lip, 1 = blush
    float2 leftCheekCenter;
    float2 rightCheekCenter;
    float cheekRadius;
};

struct MakeupVertexOutput {
    float4 clipPosition [[position]];
    float2 uv;
    float2 normPos;
};

// MARK: - 1. Skin Mask Shaders

vertex MaskVertexOutput faceSkinMaskVertex(
    const device float2* positions [[buffer(0)]],
    const device float* skinWeights [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    MaskVertexOutput out;
    float2 pos = positions[vid];
    out.clipPosition = float4(pos.x * 2.0 - 1.0, (1.0 - pos.y) * 2.0 - 1.0, 0.0, 1.0);
    out.skinWeight = skinWeights[vid];
    return out;
}

fragment float4 faceSkinMaskFragment(MaskVertexOutput in [[stage_in]]) {
    float w = saturate(in.skinWeight);
    return float4(w, w, w, w);
}

// MARK: - 2. 3D Face Reshaping Shaders

vertex ReshapeVertexOutput faceReshapeVertex(
    const device float2* positions [[buffer(0)]],
    const device float2* origUVs [[buffer(1)]],
    const device float* weights [[buffer(2)]],
    const device uint* featureTypes [[buffer(3)]],
    constant ReshapeUniforms& uniforms [[buffer(4)]],
    uint vid [[vertex_id]]
) {
    ReshapeVertexOutput out;
    float2 pos = positions[vid];
    float2 uv = origUVs[vid];
    float w = weights[vid];
    uint fType = featureTypes[vid];

    float2 deformed = pos;

    // 1. Cheek and Jaw slimming (V-Face, Slim Face)
    if (fType == 1 && w > 0.0) {
        float factor = (uniforms.slimFace * 0.06 + uniforms.vFace * 0.07 + uniforms.smallFace * 0.04) * w;
        deformed.x += (uniforms.faceCenter.x - pos.x) * factor;
    }
    // 2. Chin length and width
    else if (fType == 2 && w > 0.0) {
        float dy = uniforms.chinLength * 0.035 * w;
        float dx = (uniforms.chinCenter.x - pos.x) * uniforms.chinWidth * 0.08 * w;
        deformed.y += dy;
        deformed.x += dx;
    }
    // 3. Left Eye Enlargement
    else if (fType == 3 && uniforms.eyeSize > 0.01) {
        float2 diff = pos - uniforms.leftEyeCenter;
        deformed += diff * uniforms.eyeSize * 0.22 * w;
    }
    // 4. Right Eye Enlargement
    else if (fType == 4 && uniforms.eyeSize > 0.01) {
        float2 diff = pos - uniforms.rightEyeCenter;
        deformed += diff * uniforms.eyeSize * 0.22 * w;
    }
    // 5. Nose Slimming
    else if (fType == 5 && abs(uniforms.noseWidth) > 0.01) {
        float dx = (uniforms.noseCenter.x - pos.x) * uniforms.noseWidth * 0.14 * w;
        deformed.x += dx;
    }
    // 6. Smile (Mouth corner lifting)
    else if (fType == 6 && uniforms.smile > 0.01) {
        float dy = -uniforms.smile * 0.022 * w;
        deformed.y += dy;
    }

    out.clipPosition = float4(deformed.x * 2.0 - 1.0, (1.0 - deformed.y) * 2.0 - 1.0, 0.0, 1.0);
    out.uv = uv;
    out.alpha = w;
    return out;
}

fragment float4 faceReshapeFragment(
    ReshapeVertexOutput in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 color = inputTexture.sample(textureSampler, in.uv);
    return color;
}

// MARK: - 3. 3D Makeup Overlay Shaders

vertex MakeupVertexOutput faceMakeupVertex(
    const device float2* positions [[buffer(0)]],
    const device float2* uvs [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    MakeupVertexOutput out;
    float2 pos = positions[vid];
    out.clipPosition = float4(pos.x * 2.0 - 1.0, (1.0 - pos.y) * 2.0 - 1.0, 0.0, 1.0);
    out.uv = uvs[vid];
    out.normPos = pos;
    return out;
}

fragment float4 faceMakeupFragment(
    MakeupVertexOutput in [[stage_in]],
    constant MakeupUniforms& uniforms [[buffer(0)]],
    texture2d<float> inputTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 baseColor = inputTexture.sample(textureSampler, in.uv);

    if (uniforms.makeupMode == 0) {
        // Lipstick overlay
        float opacity = uniforms.lipColor.a;
        if (opacity < 0.001) {
            return baseColor;
        }

        // Soft-light blending for natural lip texture preservation
        float3 lipRgb = uniforms.lipColor.rgb;
        float3 blendResult;
        for (int c = 0; c < 3; c++) {
            float b = baseColor[c];
            float s = lipRgb[c];
            if (s < 0.5) {
                blendResult[c] = 2.0 * b * s + b * b * (1.0 - 2.0 * s);
            } else {
                blendResult[c] = sqrt(b) * (2.0 * s - 1.0) + 2.0 * b * (1.0 - s);
            }
        }

        float3 finalRgb = mix(baseColor.rgb, blendResult, opacity * 0.75);
        return float4(finalRgb, 1.0);
    } else {
        // Blush overlay
        float opacity = uniforms.blushColor.a;
        if (opacity < 0.001) {
            return baseColor;
        }

        float dL = length(in.normPos - uniforms.leftCheekCenter) / max(0.001, uniforms.cheekRadius);
        float dR = length(in.normPos - uniforms.rightCheekCenter) / max(0.001, uniforms.cheekRadius);
        float dist = min(dL, dR);

        float radialFalloff = smoothstep(1.0, 0.0, dist);
        float effectiveAlpha = opacity * radialFalloff * 0.65;

        float3 blushRgb = uniforms.blushColor.rgb;
        float3 blendResult = 1.0 - (1.0 - baseColor.rgb) * (1.0 - blushRgb * 0.6);
        float3 finalRgb = mix(baseColor.rgb, blendResult, effectiveAlpha);

        return float4(finalRgb, 1.0);
    }
}
"""
}
