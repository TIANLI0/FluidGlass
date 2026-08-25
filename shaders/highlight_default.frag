#version 460 core

// Directional edge highlight, used as a Paint shader when stroking the glass
// outline.
//
// AGSL emits `color * intensity` with the colour's alpha forced to 1 and lets
// the paint's alpha modulate the result. Flutter paints ignore the colour when
// a shader is installed, so the style alpha is folded into the shader instead
// (uColor carries the un-premultiplied style colour).

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec2 uOrigin;       // canvas-space origin of the element
uniform vec4 uCornerRadii;  // topLeft, topRight, bottomRight, bottomLeft
uniform vec4 uColor;        // un-premultiplied
uniform float uAngle;       // radians
uniform float uFalloff;

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
    fragColor = vec4(uColor.rgb, 1.0) * (intensity * uColor.a);
}
