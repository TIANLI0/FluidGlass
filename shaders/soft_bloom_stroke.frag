#version 460 core

// The lit rim of the soft glass surfaces: a thin stroke along the silhouette
// plus two directional lights shading a rounded "bevel" just inside it. The
// silhouette's corners are the same Lp superellipse (n = cornerExponent) the
// surface path traces, so the rim lies on the outline instead of parting
// from it along the corner diagonal.
//
// Colours are supplied premultiplied. GLSL leaves smoothstep with decreasing
// edges undefined, so those are written as 1 - smoothstep(...).

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 halfView;
uniform vec2 halfViewFloor;
uniform vec4 cornerRadii;      // TL, TR, BL, BR
uniform float cornerExponent;
uniform float strokeWidth;
uniform float innerBlurRadius;
uniform float highlightAlpha;
uniform vec4 strokeColor;      // rgb, alpha multiplier in a
uniform vec3 lightDir1;
uniform vec4 lightColor1;      // rgb, intensity in a
uniform vec3 lightDir2;
uniform vec4 lightColor2;      // rgb, intensity in a
uniform vec2 axis1;
uniform vec2 axis2;

out vec4 fragColor;

float pickRadius(vec2 fragCoord, vec4 radii) {
    vec2 up = fragCoord.y < halfView.y ? radii.xy : radii.zw;
    return fragCoord.x < halfView.x ? up.x : up.y;
}

float superellipseCornerSDF(vec2 q, float radius) {
    float n = cornerExponent;
    return pow(pow(q.x, n) + pow(q.y, n), 1.0 / n) - radius;
}

float roundedBoxSDF(vec2 pos, vec2 halfSize, float radius) {
    radius = min(radius, min(halfSize.x, halfSize.y));
    vec2 d = pos - halfSize + radius;
    vec2 q = max(d, 0.0);
    if (q.x > 0.0 && q.y > 0.0) {
        return superellipseCornerSDF(q, radius);
    }
    return max(d.x, d.y) - radius;
}

vec3 getNormal(vec2 fragCoord, float sdf, float R) {
    vec2 xy = fragCoord - halfViewFloor;
    vec2 xy_a = abs(xy);
    float t = smoothstep(-innerBlurRadius, 0.0, sdf);
    float z = sqrt(max(innerBlurRadius * innerBlurRadius - t * t, 0.0));
    vec3 coord = vec3(xy_a, -z);

    vec2 corner = halfView - R;
    corner.x = min(corner.x, xy_a.x);
    corner.y = min(corner.y, xy_a.y);

    vec2 dir = normalize(coord.xy - corner.xy);
    corner += dir * (R - innerBlurRadius);

    if (xy_a.x < corner.x || xy_a.y < corner.y) {
        return vec3(0.0, 0.0, -1.0);
    }

    vec2 signal = sign(xy);
    vec3 n = normalize(coord - vec3(corner, 0.0));
    n.xy *= signal;
    return n;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 xy = abs(fragCoord - halfView);

    float originRadius = pickRadius(fragCoord, cornerRadii);
    float R = max(originRadius, innerBlurRadius);

    if (xy.x < halfView.x - R && xy.y < halfView.y - R) {
        fragColor = vec4(0.0);
        return;
    }

    float sdf = roundedBoxSDF(xy, halfView, originRadius);
    float outMask = 1.0 - smoothstep(-1.0, 0.0, sdf);
    float strokeAlpha = smoothstep(-strokeWidth, -strokeWidth + 1.0, sdf);

    vec3 rgb = strokeColor.rgb * (strokeColor.a * strokeAlpha * strokeAlpha);

    vec3 n = getNormal(fragCoord, sdf, R);
    float rimLightMask = smoothstep(-max(innerBlurRadius, 0.001), 0.0, sdf);
    n *= rimLightMask;

    float falloff1 = max(dot(vec3(axis1, 0.0), n), 0.0);
    float light1 = clamp(dot(n, lightDir1) * falloff1, 0.0, 1.0);
    rgb += (light1 * light1 * lightColor1.a) * lightColor1.rgb;

    float falloff2 = max(dot(vec3(axis2, 0.0), n), 0.0);
    float light2 = clamp(dot(n, lightDir2) * falloff2, 0.0, 1.0);
    rgb += (light2 * light2 * lightColor2.a) * lightColor2.rgb;

    fragColor = vec4(rgb * highlightAlpha, 1.0) * outMask;
}
