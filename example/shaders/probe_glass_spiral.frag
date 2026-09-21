#version 460 core

// Throwaway probe shader: refraction + a *good* blur in one BackdropFilter pass.
//
// The first attempt blurred on two concentric rings of eight. That undersamples
// angularly as the radius grows -- at a sigma-8 reach the outer ring's samples
// sit ~19 px apart -- so widening it ghosted instead of blurring, and the
// picture moved AWAY from the capture path (vs capture: 11.51 at spacing 3.2,
// 23.34 at 6.4, 33.54 at 9.6).
//
// This samples a golden-angle spiral instead: equal-area points over a disk of
// 2.5 sigma, weighted by a true Gaussian, with the whole spiral rotated by a
// per-pixel hash so what banding remains becomes noise. Quality per tap is far
// higher, and the tap count is a uniform so it can be swept against cost.
//
// Rotation is carried incrementally by a constant mat2 rather than a sin/cos
// per tap.

#include <flutter/runtime_effect.glsl>
#include <_sdf_probe.glsl>

precision highp float;

uniform vec2 uTextureSize;
uniform vec2 uLayerSize;
uniform vec2 uSize;
uniform vec2 uOffset;
uniform vec4 uCornerRadii;
uniform float uRefractionHeight;
uniform float uRefractionAmount;
uniform float uDepthEffect;
uniform float uSigma;   // Gaussian sigma in logical pixels; 0 skips the blur
uniform float uTaps;    // spiral samples, clamped to MAX_TAPS
uniform float uDither;  // 1 = rotate the spiral by a per-pixel hash

uniform sampler2D uContent;

out vec4 fragColor;

const int MAX_TAPS = 48;
// Golden angle. Successive samples land as far from their predecessors as a
// turn can put them, which is what makes the spiral equidistributed.
const float GOLDEN = 2.39996323;
// Truncate the Gaussian here; beyond 2.5 sigma it contributes under 2%.
const float REACH = 2.5;

vec4 evalContent(vec2 coord) {
    return texture(uContent, coord / uLayerSize);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec4 blurAt(vec2 p, float sigma, int taps, float dither) {
    float maxR = sigma * REACH;
    float rot = dither > 0.5 ? hash12(p) * 6.2831853 : 0.0;
    vec2 dir = vec2(cos(rot), sin(rot));
    float cg = cos(GOLDEN);
    float sg = sin(GOLDEN);
    mat2 step = mat2(cg, -sg, sg, cg);

    vec4 acc = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < MAX_TAPS; i++) {
        if (i >= taps) break;
        // Equal-area radius: the i-th of n points in a disk sits at
        // sqrt((i+0.5)/n) of the radius.
        float r = maxR * sqrt((float(i) + 0.5) / float(taps));
        float w = exp(-0.5 * r * r / (sigma * sigma));
        acc += evalContent(p + dir * r) * w;
        wsum += w;
        dir = step * dir;
    }
    return acc / wsum;
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = (coord + uOffset) - halfSize;
    float radius = radiusAt(centeredCoord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    vec2 sampleAt = coord;
    if (-sd < uRefractionHeight) {
        float clamped = min(sd, 0.0);
        float travel =
            circleMap(1.0 - -clamped / uRefractionHeight) * uRefractionAmount;
        float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 grad = normalize(
            gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
            uDepthEffect * normalize(centeredCoord)
        );
        sampleAt = coord + travel * grad;
    }

    fragColor = uSigma > 0.0
        ? blurAt(sampleAt, uSigma, int(uTaps), uDither)
        : evalContent(sampleAt);
}
