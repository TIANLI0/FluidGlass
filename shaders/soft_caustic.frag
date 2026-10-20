#version 460 core

// The caustic light a soft floating bar casts beneath itself: a bright band
// hugging the lower part of the silhouette, shifted down by a "bottom" offset
// and faded upward steeply, weaker over a light background. Drawn per shape,
// additively, before the bar.
//
// Local coordinates: the rect drawn spans the shape's box plus the offset
// below it, with the origin at the box's top-left.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 in_half;
uniform float in_corner;
uniform float in_bottom;
uniform float in_sdf;
uniform vec4 in_color;       // rgb, alpha
uniform vec3 in_background;

out vec4 fragColor;

float ramp(float e0, float e1, float x) {
    float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float RBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 posOptics = pos - in_half - vec2(0.0, in_bottom * 0.5);
    vec2 halfOptics = in_half + vec2(0.0, in_bottom * 0.5);
    float sdf = min(in_sdf, min(in_half.x, in_half.y));
    if (in_color.a <= 0.001 || sdf <= 0.0 || abs(posOptics.x) > halfOptics.x || abs(posOptics.y) > halfOptics.y) {
        fragColor = vec4(0.0);
        return;
    }
    halfOptics = max(halfOptics - sdf, vec2(0.0));
    float cornerOptics = min(in_corner, min(halfOptics.x, halfOptics.y));
    float opticsSdf = RBox(posOptics, halfOptics, cornerOptics);
    float value = ramp(sdf, 0.0, opticsSdf);
    value *= pow(ramp(halfOptics.y + sdf, -halfOptics.y - sdf, -posOptics.y), 18.0);
    value = pow(value, 0.6) * 0.6 + 0.4 * value;
    float gray = clamp((dot(vec3(0.2126, 0.7152, 0.0722), in_background) - 0.45) * 0.6, 0.0, 1.0);
    float alpha = in_color.a * value * (1.0 - gray) * (1.0 - gray);
    fragColor = vec4(in_color.rgb * alpha, alpha);
}
