#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Noise function
float lightRays_noise(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// Calculate ray strength
float lightRays_rayStrength(
    float2 raySource,
    float2 rayRefDirection,
    float2 coord,
    float seedA,
    float seedB,
    float speed,
    float iTime,
    float lightSpread,
    float rayLength,
    float2 iResolution,
    float fadeDistance,
    float pulsating,
    float distortion
) {
    float2 sourceToCoord = coord - raySource;
    float2 dirNorm = normalize(sourceToCoord);
    float cosAngle = dot(dirNorm, rayRefDirection);
    
    float distortedAngle = cosAngle + distortion * sin(iTime * 2.0 + length(sourceToCoord) * 0.01) * 0.2;
    
    float spreadFactor = pow(max(distortedAngle, 0.0), 1.0 / max(lightSpread, 0.001));
    
    float distance = length(sourceToCoord);
    float maxDistance = iResolution.x * rayLength;
    float lengthFalloff = clamp((maxDistance - distance) / maxDistance, 0.0, 1.0);
    
    float fadeFalloff = clamp((iResolution.x * fadeDistance - distance) / (iResolution.x * fadeDistance), 0.5, 1.0);
    float pulse = pulsating > 0.5 ? (0.8 + 0.2 * sin(iTime * speed * 3.0)) : 1.0;
    
    float baseStrength = clamp(
        (0.45 + 0.15 * sin(distortedAngle * seedA + iTime * speed)) +
        (0.3 + 0.2 * cos(-distortedAngle * seedB + iTime * speed)),
        0.0, 1.0
    );
    
    return baseStrength * lengthFalloff * fadeFalloff * spreadFactor * pulse;
}

vertex VertexOut vertex_light_rays(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.uv = (in.position + 1.0) * 0.5;
    return out;
}

fragment float4 fragment_light_rays(
    VertexOut in [[stage_in]],
    constant float &uTime [[buffer(0)]],
    constant float2 &uResolution [[buffer(1)]],
    constant float2 &uRayPos [[buffer(2)]],
    constant float2 &uRayDir [[buffer(3)]],
    constant float3 &uRaysColor [[buffer(4)]],
    constant float &uRaysSpeed [[buffer(5)]],
    constant float &uLightSpread [[buffer(6)]],
    constant float &uRayLength [[buffer(7)]],
    constant float &uPulsating [[buffer(8)]],
    constant float &uFadeDistance [[buffer(9)]],
    constant float &uSaturation [[buffer(10)]],
    constant float &uNoiseAmount [[buffer(11)]],
    constant float &uDistortion [[buffer(12)]]
) {
    // Convert UV to fragment coordinates (Metal has (0,0) at top-left, flip Y)
    float2 fragCoord = float2(in.uv.x * uResolution.x, (1.0 - in.uv.y) * uResolution.y);
    
    // Use ray direction directly
    float2 finalRayDir = uRayDir;
    
    // Calculate ray strength for two layers
    float4 rays1 = float4(1.0) * lightRays_rayStrength(
        uRayPos, finalRayDir, fragCoord, 36.2214, 21.11349,
        1.5 * uRaysSpeed, uTime, uLightSpread, uRayLength,
        uResolution, uFadeDistance, uPulsating, uDistortion
    );
    
    float4 rays2 = float4(1.0) * lightRays_rayStrength(
        uRayPos, finalRayDir, fragCoord, 22.3991, 18.0234,
        1.1 * uRaysSpeed, uTime, uLightSpread, uRayLength,
        uResolution, uFadeDistance, uPulsating, uDistortion
    );
    
    float4 fragColor = rays1 * 0.5 + rays2 * 0.4;
    
    // Apply noise if enabled
    if (uNoiseAmount > 0.0) {
        float n = lightRays_noise(fragCoord * 0.01 + uTime * 0.1);
        fragColor.rgb *= (1.0 - uNoiseAmount + uNoiseAmount * n);
    }
    
    // Apply brightness gradient based on Y position
    float brightness = 1.0 - (fragCoord.y / uResolution.y);
    fragColor.x *= 0.1 + brightness * 0.8;
    fragColor.y *= 0.3 + brightness * 0.6;
    fragColor.z *= 0.5 + brightness * 0.5;
    
    // Apply saturation
    if (uSaturation != 1.0) {
        float gray = dot(fragColor.rgb, float3(0.299, 0.587, 0.114));
        fragColor.rgb = mix(float3(gray), fragColor.rgb, uSaturation);
    }
    
    // Apply color
    fragColor.rgb *= uRaysColor;
    
    return fragColor;
}
