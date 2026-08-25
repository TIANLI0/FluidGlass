#version 460 core

// Ambient edge highlight: white on the lit side, black on the shadowed side.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uOrigin;       // canvas-space origin of the element
uniform vec4 uCornerRadii;  // topLeft, topRight, bottomRight, bottomLeft
uniform float uAngle;       // radians
uniform float uFalloff;
uniform float uAlpha;       // alpha of the style colour, applied by the paint in AGSL

out vec4 fragColor;

#include <_sdf.glsl>

void main() {
    vec2 coord = FlutterFragCoord().xy - uOrigin;

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = coord - halfSize;
    float radius = radiusAt(coord, uCornerRadii);

    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
    vec2 normal = vec2(cos(uAngle), sin(uAngle));
    float d = dot(grad, normal);
    float intensity = pow(abs(d), uFalloff);
    float t = step(0.0, d);
    fragColor = vec4(t, t, t, 1.0) * (intensity * uAlpha);
}
