#version 460 core

// Refracts the backdrop through a signed-distance-field texture, so glass can
// take the shape of arbitrary artwork (the lock-screen clock).
//
// The texture packs the signed distance in red and the surface normal in
// green/blue.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered layer
uniform vec2 uSize;         // logical size of the glass element
uniform vec2 uSdfTexSize;
uniform float uRefractionHeight;
uniform float uLightAngle;  // degrees

uniform sampler2D uContent; // bound by the engine to the chain's output
uniform sampler2D uSdf;

out vec4 fragColor;

float circleMap(float x) {
    return 1.0 - sqrt(1.0 - x * x);
}

// smoothstep with the edges spelled out, since some are given decreasing.
float smoothRamp(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;

    vec2 p = coord / uSize * uSdfTexSize;
    if (p.x < 0.0 || p.y < 0.0 || p.x >= uSdfTexSize.x || p.y >= uSdfTexSize.y) {
        fragColor = vec4(0.0);
        return;
    }
    vec4 v = texture(uSdf, p / uSdfTexSize);
    float sd = v.r * 2.0 - 1.0;
    v.a = smoothRamp(0.5, 1.0, v.a);
    if (v.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    if (v.a < 1.0) {
        sd = 0.0;
    }
    vec2 normal = normalize(v.gb * 2.0 - 1.0);

    float intensity = circleMap(1.0 - min(1.0, -sd * 1.5));
    vec2 refractedCoord = coord - intensity * uRefractionHeight * normal;

    vec4 color = texture(uContent, refractedCoord / uLayerSize) * v.a;
    float rad = uLightAngle * 3.1415926 / 180.0;
    vec2 lightDir = vec2(cos(rad), sin(rad));
    float bevelIntensity = clamp(dot(normal, lightDir), 0.0, 1.0);
    color.rgb *= 1.0 + 0.5 * intensity * bevelIntensity;
    bevelIntensity = clamp(dot(normal, -lightDir), 0.0, 1.0);
    color.rgb *= 1.0 +
        0.5 * bevelIntensity * min(1.0, smoothRamp(1.0, 0.0, abs(intensity - 0.25) * 6.0));
    fragColor = color;
}
