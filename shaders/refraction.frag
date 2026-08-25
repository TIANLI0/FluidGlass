#version 460 core

// Rounded-rectangle refraction ("lens") effect.
//
// Coordinate spaces
// -----------------
// The AGSL original receives `coord` in the coordinate space of the padded
// graphics layer it filters. Flutter's ImageFilter.shader overwrites the first
// vec2 uniform with the size of the bound input texture (device pixels), so the
// layer-space coordinate is recovered as
//     coord = FlutterFragCoord() / uTextureSize * uLayerSize
// which keeps every length uniform below in logical pixels, exactly like AGSL.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered (padded) layer
uniform vec2 uSize;         // logical size of the glass element
uniform vec2 uOffset;       // (-padding, -padding)
uniform vec4 uCornerRadii;  // topLeft, topRight, bottomRight, bottomLeft
uniform float uRefractionHeight;
uniform float uRefractionAmount;
uniform float uDepthEffect;

uniform sampler2D uContent;

out vec4 fragColor;

#include <_sdf.glsl>

vec4 evalContent(vec2 coord) {
    // No y flip: verified on Impeller's GLES backend (where
    // IMPELLER_TARGET_OPENGLES *is* defined) that ImageFilter.shader hands the
    // input texture over in the same orientation as FlutterFragCoord().
    return texture(uContent, coord / uLayerSize);
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = (coord + uOffset) - halfSize;
    float radius = radiusAt(coord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);
    if (-sd >= uRefractionHeight) {
        fragColor = evalContent(coord);
        return;
    }
    sd = min(sd, 0.0);

    float d = circleMap(1.0 - -sd / uRefractionHeight) * uRefractionAmount;
    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = normalize(
        gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
        uDepthEffect * normalize(centeredCoord)
    );

    vec2 refractedCoord = coord + d * grad;
    fragColor = evalContent(refractedCoord);
}
