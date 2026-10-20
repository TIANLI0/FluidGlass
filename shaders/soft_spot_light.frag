#version 460 core

// The press spotlight of the soft components: a point light hovering above
// the surface, shaded (ambient + diffuse · lambert) and cut off by
// smoothstep(1, 0, dist / radius) so it dies exactly at the radius. The
// noise and dither post passes are kept, gated by step() as in the original.
//
// GLSL leaves smoothstep with decreasing edges undefined, so the attenuation
// is written as 1 - smoothstep(0, 1, x).

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec4 u_lightPosAndHeight;    // light x, y (local px), radius, intensity
uniform vec4 u_lightColorAndAmbient; // rgb, ambient
uniform vec4 u_lightingParams;       // diffuse, light height, noise, dither

out vec4 fragColor;

float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float max3(vec3 v) { return max(max(v.r, v.g), v.b); }

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float softLight(float A, float B) {
    float l = B - (1.0 - 2.0 * A) * B * (1.0 - B);
    float h = B + (2.0 * A - 1.0) * (sqrt(B) - B);
    return mix(l, h, step(0.5, A));
}

float dither(vec2 coord, float ditherN) {
    float n1 = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
    float n2 = fract(sin(dot(coord + vec2(1.0), vec2(12.9898, 78.233))) * 43758.5453);
    return (n1 + n2 - 1.0) * ditherN / 255.0;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 lightP = u_lightPosAndHeight.xy;
    float radius = u_lightPosAndHeight.z;
    float intensity = u_lightPosAndHeight.w;
    vec3 lightCol = u_lightColorAndAmbient.rgb;
    float ambientStr = u_lightColorAndAmbient.w;
    float diffuseStr = u_lightingParams.x;
    float lightH = u_lightingParams.y;
    float noise_exp = u_lightingParams.z;
    float ditherN = u_lightingParams.w;
    const float lightIntensity = 1.5;

    vec2 delta = fragCoord - lightP;
    vec3 L = vec3(delta, lightH);
    float dist = length(L);
    if (radius <= 0.0 || dist >= radius) {
        fragColor = vec4(0.0);
        return;
    }
    L = normalize(L);
    vec3 N = vec3(0.0, 0.0, 1.0);
    float diff = max(dot(N, L), 0.0);
    vec3 lighting = (ambientStr + diffuseStr * diff) * lightCol;

    float att = 1.0 - smoothstep(0.0, 1.0, dist / radius);
    lighting *= att * lightIntensity * intensity;
    float alpha = clamp(luminance(lighting), 0.0, 1.0);

    float postOn = max(step(0.001, noise_exp), step(0.001, ditherN));
    vec3 postLighting = lighting;
    float postAlpha = alpha;

    float noiseOn = step(0.001, noise_exp);
    vec2 uv_pos = fragCoord * 9.259e-4;
    float n = clamp((noise(uv_pos) - 0.5) * noise_exp + 0.5, 0.0, 1.0);
    float mask = max3(postLighting);
    float fadeAlpha = clamp(softLight(n, mask), 0.0, 1.0);
    float noiseDelta = clamp(abs(fadeAlpha - mask), 0.0, 1.0);
    postLighting += vec3(noiseDelta) * noiseOn;

    float ditherOn = step(0.001, ditherN);
    float d = dither(fragCoord, ditherN);
    postLighting += vec3(d) * ditherOn;
    postAlpha = mix(postAlpha, clamp(postAlpha + d, 0.0, 1.0), ditherOn);

    lighting = mix(lighting, postLighting, postOn);
    alpha = mix(alpha, postAlpha, postOn);
    fragColor = vec4(lighting, alpha);
}
