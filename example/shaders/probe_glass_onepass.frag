#version 460 core

// Throwaway probe shader: refraction AND blur in one pass, for a
// BackdropFilter.
//
// Composing ImageFilter.blur with ImageFilter.shader inside a BackdropFilter
// silently drops the refraction (flutter/flutter#170820; the fix in #177687
// snapshots the shader's input, which is exactly why screen-space uniforms
// stop describing it). Doing both in one shader sidesteps the compose
// entirely -- the same reasoning shaders/fusion.frag already gives for its own
// nine-tap interior blur.
//
// Uniform layout is refraction.frag's, plus uBlur on the end, so the Dart side
// can share the setter code.

#include <flutter/runtime_effect.glsl>
#include <_sdf_probe.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered layer (the screen)
uniform vec2 uSize;         // logical size of the glass element
uniform vec2 uOffset;       // -elementTopLeft, in the layer's coordinates
uniform vec4 uCornerRadii;
uniform float uRefractionHeight;
uniform float uRefractionAmount;
uniform float uDepthEffect;
uniform float uBlur;        // tap spacing in logical pixels; 0 skips the blur

uniform sampler2D uContent;

out vec4 fragColor;

vec4 evalContent(vec2 coord) {
    return texture(uContent, coord / uLayerSize);
}

// Seventeen taps on two rings. Unlike the capture path's engine blur this is
// neither separable nor downsampled, but it reads the screen texture directly,
// so it has real pixels beyond the element's edge and needs no sample margin.
vec4 blurAt(vec2 p, float r) {
    float d = r * 0.7071;
    float r2 = r * 2.0;
    float d2 = d * 2.0;
    vec4 ring1 =
        evalContent(p + vec2(r, 0.0)) + evalContent(p + vec2(-r, 0.0)) +
        evalContent(p + vec2(0.0, r)) + evalContent(p + vec2(0.0, -r)) +
        evalContent(p + vec2(d, d)) + evalContent(p + vec2(-d, d)) +
        evalContent(p + vec2(d, -d)) + evalContent(p + vec2(-d, -d));
    vec4 ring2 =
        evalContent(p + vec2(r2, 0.0)) + evalContent(p + vec2(-r2, 0.0)) +
        evalContent(p + vec2(0.0, r2)) + evalContent(p + vec2(0.0, -r2)) +
        evalContent(p + vec2(d2, d2)) + evalContent(p + vec2(-d2, d2)) +
        evalContent(p + vec2(d2, -d2)) + evalContent(p + vec2(-d2, -d2));
    return evalContent(p) * 0.20 + ring1 * 0.0625 + ring2 * 0.0375;
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

    fragColor = uBlur > 0.0 ? blurAt(sampleAt, uBlur) : evalContent(sampleAt);
}
