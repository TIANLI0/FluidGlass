#version 460 core

// Rounded-rectangle refraction with chromatic dispersion.

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
uniform float uChromaticAberration;

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
    float dispersionIntensity = uChromaticAberration *
        ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
    vec2 dispersedCoord = d * grad * dispersionIntensity;

    vec4 color = vec4(0.0);

    vec4 red = evalContent(refractedCoord + dispersedCoord);
    color.r += red.r / 3.5;
    color.a += red.a / 7.0;

    vec4 orange = evalContent(refractedCoord + dispersedCoord * (2.0 / 3.0));
    color.r += orange.r / 3.5;
    color.g += orange.g / 7.0;
    color.a += orange.a / 7.0;

    vec4 yellow = evalContent(refractedCoord + dispersedCoord * (1.0 / 3.0));
    color.r += yellow.r / 3.5;
    color.g += yellow.g / 3.5;
    color.a += yellow.a / 7.0;

    vec4 green = evalContent(refractedCoord);
    color.g += green.g / 3.5;
    color.a += green.a / 7.0;

    vec4 cyan = evalContent(refractedCoord - dispersedCoord * (1.0 / 3.0));
    color.g += cyan.g / 3.5;
    color.b += cyan.b / 3.0;
    color.a += cyan.a / 7.0;

    vec4 blue = evalContent(refractedCoord - dispersedCoord * (2.0 / 3.0));
    color.b += blue.b / 3.0;
    color.a += blue.a / 7.0;

    vec4 purple = evalContent(refractedCoord - dispersedCoord);
    color.r += purple.r / 7.0;
    color.b += purple.b / 3.0;
    color.a += purple.a / 7.0;

    fragColor = color;
}
