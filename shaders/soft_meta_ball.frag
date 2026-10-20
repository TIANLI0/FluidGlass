#version 460 core

// The merged silhouette of the soft floating bars: up to four rounded boxes
// (a capsule and the round views beside it) joined by a smooth minimum whose
// reach depends on the direction between them, so two of them melt together
// as they approach. Inside the silhouette the blurred backdrop is tinted and
// its rim is lit with the near/far perimeter ramps of the reference's capsule
// edge; outside it the fragment is transparent, so what is really behind the
// box comes through.
//
// Runs as the last stage of a backdrop effect chain, after the blur. Layer
// coordinates are recovered as in refraction.frag; the field itself is
// evaluated in device pixels, the space the reference's numbers are in.
//
// GLSL leaves smoothstep with edge0 >= edge1 undefined, and the ramps below
// run both ways, so they use ramp() instead.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered layer
uniform vec2 uOffset;       // layer space -> element space
uniform float uDpr;

// Per shape: centre and half size (device px), then corner, scale x, scale y,
// alpha, then the edge's near/far line bands and its four fade fractions.
uniform vec4 uShape0;
uniform vec4 uParam0;
uniform vec4 uLine0;
uniform vec4 uFade0;
uniform vec4 uShape1;
uniform vec4 uParam1;
uniform vec4 uLine1;
uniform vec4 uFade1;
uniform vec4 uShape2;
uniform vec4 uParam2;
uniform vec4 uLine2;
uniform vec4 uFade2;
uniform vec4 uShape3;
uniform vec4 uParam3;
uniform vec4 uLine3;
uniform vec4 uFade3;

uniform float uCount;
uniform float uExtension;   // device px
uniform vec2 uFactor;
uniform vec2 uLineAlpha;    // near, far
uniform vec2 uLinePara;     // para1, para2
uniform float uAngle;
uniform vec4 uTint;         // rgb, mix amount
uniform vec4 uRim;          // rgb, unused
uniform float uRimBottom;

uniform sampler2D uContent;

out vec4 fragColor;

float ramp(float e0, float e1, float x) {
    float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float smin(float a, float b, float k) {
    float kk = max(k, 0.0001);
    float h = clamp(0.5 + 0.5 * (b - a) / kk, 0.0, 1.0);
    return mix(b, a, h) - kk * h * (1.0 - h);
}

float getDis(vec2 pos, vec2 halfsize) {
    vec2 rect = abs(pos - halfsize);
    return rect.x + rect.y;
}

float edgeAlpha(vec2 pos, vec2 halfSize, float d, vec4 line, vec4 fade) {
    vec2 near = line.xy;
    vec2 far = line.zw;
    if (d < -max(near.y, far.y)) {
        return 0.0;
    }
    float distanceAll = (halfSize.x + halfSize.y) * 2.0;
    float ratio = fract(uAngle + halfSize.x / distanceAll * 0.5 + 0.5);
    vec2 dirPos = normalize(pos);
    vec2 dirAbs = abs(dirPos);
    vec2 posN = min(dirAbs.xy * halfSize.yx / max(vec2(0.001), dirAbs.yx), halfSize) * sign(dirPos);
    vec2 halfSym = vec2(-halfSize.y, halfSize.x);
    float flag = mix(-1.0, 1.0, step(ratio, 0.5)) * dot(halfSym, posN);
    float disPoint = distanceAll * min(ratio, 1.0 - ratio) * 2.0;
    float disPos = getDis(posN, halfSize);
    float distanceNear = mix(disPoint + disPos, abs(disPoint - disPos), step(0.0, flag));
    distanceNear = min(2.0 * distanceAll - distanceNear, distanceNear);
    float nearAlpha = uLineAlpha.x * ramp(fade.y * distanceAll, fade.x * distanceAll, distanceNear);
    float farAlpha = uLineAlpha.y * ramp(fade.w * distanceAll, fade.z * distanceAll, distanceAll - distanceNear);
    float nearSdf = ramp(-near.y, -near.x, d);
    float farSdf = ramp(-far.y, -far.x, d);
    if (uLinePara.y > 0.001) {
        nearSdf = pow(nearSdf, uLinePara.x) * uLinePara.y + (1.0 - uLinePara.y) * nearSdf;
        farSdf = pow(farSdf, uLinePara.x) * uLinePara.y + (1.0 - uLinePara.y) * farSdf;
    }
    return clamp(nearAlpha * nearSdf + farAlpha * farSdf, 0.0, 1.0);
}

vec3 edgeBlend(vec3 materialColor, vec3 rawColor, vec3 lineColor, float lineAlpha) {
    float gray = clamp(dot(vec3(0.2126, 0.7152, 0.0722), rawColor) * 1.2, 0.0, 1.0);
    float improve = (1.0 - gray) * (1.0 - gray);
    improve *= improve;
    improve *= 0.1;
    vec3 improved = clamp(rawColor + vec3(improve), 0.0, 1.0);
    vec3 edgeColor = mix(2.0 * improved * lineColor,
        1.0 - 2.0 * (1.0 - improved) * (1.0 - lineColor), step(lineColor, vec3(0.5)));
    return mix(materialColor, edgeColor, lineAlpha);
}

// The running state of the union.
float gD;
vec2 gNearest;
vec2 gHalf;
vec2 gScale;
float gOpacity;
vec4 gLine;
vec4 gFade;
float gHas;

void accumulate(vec2 xy, vec4 shape, vec4 param, vec4 line, vec4 fade) {
    vec2 c = shape.xy;
    vec2 hs = shape.zw;
    vec2 scale = max(param.yz, vec2(0.001));
    float di = sdRoundBox((xy - c) / scale, hs, min(param.x, min(hs.x, hs.y)));
    if (gHas < 0.5) {
        gD = di;
        gNearest = c;
        gHalf = hs;
        gScale = scale;
        gOpacity = param.w;
        gLine = line;
        gFade = fade;
        gHas = 1.0;
        return;
    }
    vec2 delta = c - gNearest;
    float len = length(delta);
    vec2 u = len > 0.001 ? delta / len : vec2(0.7071, 0.7071);
    float k = uExtension * length(uFactor * u);
    float prev = gD;
    gD = smin(gD, di, k);
    if (di < prev) {
        gNearest = c;
        gHalf = hs;
        gScale = scale;
        gOpacity = param.w;
        gLine = line;
        gFade = fade;
    }
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;
    vec2 xy = (coord + uOffset) * uDpr;

    gD = 1e6;
    gHas = 0.0;
    gOpacity = 0.0;
    if (uCount > 0.5) accumulate(xy, uShape0, uParam0, uLine0, uFade0);
    if (uCount > 1.5) accumulate(xy, uShape1, uParam1, uLine1, uFade1);
    if (uCount > 2.5) accumulate(xy, uShape2, uParam2, uLine2, uFade2);
    if (uCount > 3.5) accumulate(xy, uShape3, uParam3, uLine3, uFade3);
    if (gHas < 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    float aa = 0.6;
    float cover = (1.0 - ramp(-aa, aa, gD)) * gOpacity;
    if (cover <= 0.003) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 localPos = (xy - gNearest) / gScale;

    vec4 inputColor = texture(uContent, coord / uLayerSize);
    if (inputColor.a <= 0.000001) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 rawColor = inputColor.rgb / inputColor.a;
    vec3 materialColor = mix(rawColor, uTint.rgb, uTint.a);
    float bottomWeight = localPos.y > 0.0 ? uRimBottom : 1.0;
    float lineAlpha = edgeAlpha(vec2(localPos.x, -localPos.y), gHalf, gD, gLine, gFade) * bottomWeight;
    vec3 result = edgeBlend(materialColor, rawColor, uRim.rgb, lineAlpha);
    float a = inputColor.a * cover;
    fragColor = vec4(result * a, a);
}
