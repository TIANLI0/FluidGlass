#version 460 core

// The radial press highlight of the interactive components.
//
// Two things are spelled out that AGSL handles implicitly:
//   * smoothstep, whose edges are given in decreasing order there, which GLSL
//     leaves undefined;
//   * uColor, which must be supplied *premultiplied*. AGSL's `layout(color)`
//     uniforms are premultiplied by Skia so a shader's result stays a valid
//     premultiplied colour; passing it straight through would add a full-white
//     disc instead of a `0.15 * progress` glow.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec4 uColor;  // premultiplied
uniform float uRadius;
uniform vec2 uPosition;

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy;
    float dist = distance(coord, uPosition);
    float t = clamp((dist - uRadius) / (uRadius * 0.5 - uRadius), 0.0, 1.0);
    float intensity = t * t * (3.0 - 2.0 * t);
    fragColor = uColor * intensity;
}
