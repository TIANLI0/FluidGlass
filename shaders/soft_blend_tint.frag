#version 460 core

// Up to two tint layers composited over a blurred backdrop with the separable
// and non-separable blend modes of the W3C compositing spec — colour-dodge,
// overlay, luminosity — as the last stage of a backdrop filter.
//
// Painting those layers as ordinary paints over a BackdropFilter means asking
// the backend for advanced blends against the backdrop, which on some GLES
// configurations blanks the whole frame. Here the blend is plain arithmetic on
// the filter's own input, so it costs nothing extra and needs nothing from the
// backend. Each layer is applied as `(1 - a) * Cb + a * B(Cb, Cs)` over an
// opaque backdrop.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec4 uColor0;       // un-premultiplied
uniform float uMode0;       // 0 src-over, 1 colour-dodge, 2 luminosity, 3 overlay
uniform vec4 uColor1;
uniform float uMode1;
uniform float uCount;

uniform sampler2D uContent;

out vec4 fragColor;

float lum(vec3 c) {
    return dot(c, vec3(0.3, 0.59, 0.11));
}

vec3 clipColor(vec3 c) {
    float l = lum(c);
    float n = min(min(c.r, c.g), c.b);
    float x = max(max(c.r, c.g), c.b);
    if (n < 0.0) c = l + (c - l) * l / max(l - n, 1e-5);
    if (x > 1.0) c = l + (c - l) * (1.0 - l) / max(x - l, 1e-5);
    return c;
}

vec3 setLum(vec3 c, float l) {
    return clipColor(c + (l - lum(c)));
}

float dodge(float b, float s) {
    if (b <= 0.0) return 0.0;
    if (s >= 1.0) return 1.0;
    return min(1.0, b / (1.0 - s));
}

float hardLight(float b, float s) {
    // overlay(b, s) = hardLight(s, b)
    if (s <= 0.5) return b * 2.0 * s;
    float t = 2.0 * s - 1.0;
    return b + t - b * t;
}

vec3 blend(vec3 b, vec3 s, float mode) {
    if (mode < 0.5) return s;
    if (mode < 1.5) return vec3(dodge(b.r, s.r), dodge(b.g, s.g), dodge(b.b, s.b));
    if (mode < 2.5) return setLum(b, lum(s));
    return vec3(hardLight(s.r, b.r), hardLight(s.g, b.g), hardLight(s.b, b.b));
}

vec3 apply(vec3 b, vec4 layer, float mode) {
    return mix(b, blend(b, layer.rgb, mode), layer.a);
}

void main() {
    vec4 src = texture(uContent, FlutterFragCoord().xy / uTextureSize);
    if (src.a <= 0.000001) {
        fragColor = src;
        return;
    }
    vec3 c = src.rgb / src.a;
    if (uCount > 0.5) c = apply(c, uColor0, uMode0);
    if (uCount > 1.5) c = apply(c, uColor1, uMode1);
    fragColor = vec4(clamp(c, 0.0, 1.0) * src.a, src.a);
}
