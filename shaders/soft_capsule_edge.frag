#version 460 core

// The lit edge of a single frosted capsule: the near/far perimeter ramps of
// the reference's capsule edge, the same model soft_meta_ball.frag lights the
// merged body with, drawn on its own over a plain frosted surface. Output is
// premultiplied [uColor] at the edge's alpha, for source-over compositing.
//
// The field is evaluated in device pixels, the space the reference's numbers
// are in. GLSL leaves smoothstep with edge0 >= edge1 undefined, and the ramps
// below run both ways, so they use ramp() instead.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;         // logical size of the surface
uniform float uDpr;
uniform float uCorner;      // logical corner radius
uniform vec4 uLine;         // near and far line bands, device px
uniform vec4 uFade;         // the four fade fractions
uniform vec2 uLineAlpha;    // near, far
uniform vec2 uLinePara;     // para1, para2
uniform float uAngle;
uniform vec4 uColor;        // straight rgb, alpha

out vec4 fragColor;

float ramp(float e0, float e1, float x) {
    float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float getDis(vec2 pos, vec2 halfsize) {
    vec2 rect = abs(pos - halfsize);
    return rect.x + rect.y;
}

float edgeAlpha(vec2 pos, vec2 halfSize, float d) {
    vec2 near = uLine.xy;
    vec2 far = uLine.zw;
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
    float nearAlpha = uLineAlpha.x * ramp(uFade.y * distanceAll, uFade.x * distanceAll, distanceNear);
    float farAlpha = uLineAlpha.y * ramp(uFade.w * distanceAll, uFade.z * distanceAll, distanceAll - distanceNear);
    float nearSdf = ramp(-near.y, -near.x, d);
    float farSdf = ramp(-far.y, -far.x, d);
    if (uLinePara.y > 0.001) {
        nearSdf = pow(nearSdf, uLinePara.x) * uLinePara.y + (1.0 - uLinePara.y) * nearSdf;
        farSdf = pow(farSdf, uLinePara.x) * uLinePara.y + (1.0 - uLinePara.y) * farSdf;
    }
    return clamp(nearAlpha * nearSdf + farAlpha * farSdf, 0.0, 1.0);
}

void main() {
    vec2 halfSize = uSize * 0.5 * uDpr;
    vec2 p = FlutterFragCoord().xy * uDpr - halfSize;
    float corner = min(uCorner * uDpr, min(halfSize.x, halfSize.y));
    float d = sdRoundBox(p, halfSize, corner);
    float cover = 1.0 - ramp(-0.6, 0.6, d);
    float a = edgeAlpha(vec2(p.x, -p.y), halfSize, d) * cover * uColor.a;
    fragColor = vec4(uColor.rgb * a, a);
}
