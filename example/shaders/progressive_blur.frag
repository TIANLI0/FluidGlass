#version 460 core

// Fades a blur out towards the top of the element and mixes in a tint.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered layer
uniform vec2 uSize;         // logical size of the glass element
uniform vec4 uTint;
uniform float uTintIntensity;

uniform sampler2D uContent;

out vec4 fragColor;

float smoothRamp(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;

    float blurAlpha = smoothRamp(uSize.y, uSize.y * 0.5, coord.y);
    float tintAlpha = smoothRamp(uSize.y, uSize.y * 0.5, coord.y);
    fragColor = mix(
        texture(uContent, coord / uLayerSize) * blurAlpha,
        uTint * tintAlpha,
        uTintIntensity
    );
}
