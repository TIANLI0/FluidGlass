#version 460 core

// Several rounded rectangles drawn as one body of glass.
//
// Two things are shared, and they are the point:
//
//   * The shape. The shapes are combined by a smooth minimum of their signed
//     distances rather than a union of their outlines, so as two of them
//     approach, the field between them rises before they touch: the silhouette
//     reaches for its neighbour, grows a concave neck, and swallows it.
//   * The light. The rim is read along the fused normal, so it runs around the
//     whole body rather than around each part, and a press lights everything
//     the field covers, falling off with distance — so pressing one control
//     carries over to the ones beside it. The field is the mask, so the light
//     only ever lands on glass: it reaches across a gap onto a neighbour
//     without ever showing *in* the gap.
//
// Why this shader does everything (refraction, blur, tint and light) rather
// than stacking the library passes: a fused body has no rounded-rect outline
// to clip to, so it is drawn over its whole bounding box. Every pass in the
// chain would therefore cover that box, and a blurred rectangle around the
// controls is exactly what this is supposed to hide. Here the field is the
// mask.
//
// Outside the field the fragment is *transparent*, not a copy of the sampled
// backdrop. Handing back the sample looks identical on an empty page and is
// wrong the moment anything is drawn between the backdrop and this element — a
// scrim, a shadow — because the element covers its whole box and the copy
// paints over it. Transparent lets what is really behind come through, which
// is what a shape that only covers part of its box has to do.
//
// Coordinate spaces match refraction.frag — see the note there. All lengths
// are logical pixels.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uLayerSize;    // logical size of the filtered layer
uniform vec2 uOffset;       // layer space -> element space

// Up to eight shapes: xy = centre, zw = half size, with the matching corner
// radius in uRadii0/uRadii1. Eight is a toolbar; past that a caller wants a
// field of its own rather than a longer loop. Spelled out one uniform at a
// time rather than as an array, because that is what every backend agrees on.
uniform vec4 uShape0;
uniform vec4 uShape1;
uniform vec4 uShape2;
uniform vec4 uShape3;
uniform vec4 uShape4;
uniform vec4 uShape5;
uniform vec4 uShape6;
uniform vec4 uShape7;
uniform vec4 uRadii0;
uniform vec4 uRadii1;
uniform float uCount;

// How far apart two shapes start pulling on each other, in logical pixels.
uniform float uSmoothing;

uniform float uRefractionHeight;
uniform float uRefractionAmount;

// Half-extent of the interior blur taps. Zero skips them entirely.
uniform float uBlur;

uniform float uSaturation;
uniform vec4 uSurface;  // un-premultiplied tint, alpha = how much of it
uniform vec4 uRim;      // un-premultiplied rim colour, alpha = its strength
uniform float uRimWidth;
uniform float uLightAngle;

// The press: xy = where the finger is, z = the glow radius, w = how far the
// press has come on, 0..1.
uniform vec4 uGlow;

// How far the light carries past the control being pressed, in logical pixels.
//
// The glow itself is the size of that control — uGlow.z — and the reach is a
// wider, weaker falloff on top of it, so a press lights its neighbours too.
// Both are masked by the field, which is the part that matters: light lands on
// glass and never in the gaps between it, so it reaches *over* to a control
// without ever leaving one.
uniform float uReach;

uniform sampler2D uContent;

out vec4 fragColor;

#include <_sdf.glsl>

vec4 evalContent(vec2 coord) {
    return texture(uContent, coord / uLayerSize);
}

vec4 shapeAt(int i) {
    if (i == 0) return uShape0;
    if (i == 1) return uShape1;
    if (i == 2) return uShape2;
    if (i == 3) return uShape3;
    if (i == 4) return uShape4;
    if (i == 5) return uShape5;
    if (i == 6) return uShape6;
    return uShape7;
}

float radiusOf(int i) {
    if (i == 0) return uRadii0.x;
    if (i == 1) return uRadii0.y;
    if (i == 2) return uRadii0.z;
    if (i == 3) return uRadii0.w;
    if (i == 4) return uRadii1.x;
    if (i == 5) return uRadii1.y;
    if (i == 6) return uRadii1.z;
    return uRadii1.w;
}

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;
    vec2 p = coord + uOffset;

    // The fused field, and the normal that goes with it: the polynomial
    // smooth-min blends the two distances, and the same weight blends the two
    // gradients, so the normal turns through the neck instead of snapping from
    // one edge to the other.
    float sd = 0.0;
    vec2 grad = vec2(0.0, 1.0);
    int count = int(uCount);
    if (count == 0) {
        // Nothing to draw, and the fragment is emphatically not inside a shape
        // that does not exist. Without this the field is 0 everywhere, which is
        // *on the boundary* — the element box comes out as a flat rectangle,
        // which is precisely the bug this guard is named after.
        fragColor = vec4(0.0);
        return;
    }
    float k = max(uSmoothing, 0.0001);

    for (int i = 0; i < 8; ++i) {
        if (i >= count) break;
        vec4 s = shapeAt(i);
        float r = radiusOf(i);
        vec2 q = p - s.xy;
        vec2 halfSize = s.zw;
        float d = sdRoundedRect(q, halfSize, r);
        vec2 g = gradSdRoundedRect(
            q,
            halfSize,
            min(r * 1.5, min(halfSize.x, halfSize.y))
        );
        if (i == 0) {
            sd = d;
            grad = g;
        } else {
            float w = clamp(0.5 + 0.5 * (sd - d) / k, 0.0, 1.0);
            sd = mix(sd, d, w) - k * w * (1.0 - w);
            grad = normalize(mix(grad, g, w) + vec2(1e-6, 0.0));
        }
    }

    // One logical pixel of coverage, so the silhouette is not stair-stepped —
    // there is no path here for the canvas to anti-alias.
    float inside = 1.0 - smoothstep(-0.7, 0.7, sd);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Refraction: the closer to the edge, the further the sample is dragged in
    // along the normal, which is what bends the backdrop around the rim.
    float depth = -min(sd, 0.0);
    float travel = 0.0;
    if (uRefractionHeight > 0.0 && depth < uRefractionHeight) {
        travel = circleMap(1.0 - depth / uRefractionHeight) * uRefractionAmount;
    }
    vec2 sampleAt = coord - grad * travel;

    vec4 glass = evalContent(sampleAt);
    if (uBlur > 0.0) {
        // Nine taps: the sample, four on the axes and four on the diagonals,
        // weighted like a small tent. A true Gaussian belongs in the chain,
        // behind a shape that can be clipped — this one has to happen inside
        // the field, because outside it there is nothing to blur. Nine is what
        // it takes for chrome over running text: four leaves the type legible
        // through the glass, which is the one thing chrome must not do.
        float o = uBlur;
        float d = o * 0.7071;
        vec4 axis = evalContent(sampleAt + vec2(o, 0.0)) +
                    evalContent(sampleAt + vec2(-o, 0.0)) +
                    evalContent(sampleAt + vec2(0.0, o)) +
                    evalContent(sampleAt + vec2(0.0, -o));
        vec4 diag = evalContent(sampleAt + vec2(d, d)) +
                    evalContent(sampleAt + vec2(-d, d)) +
                    evalContent(sampleAt + vec2(d, -d)) +
                    evalContent(sampleAt + vec2(-d, -d));
        glass = glass * 0.2 + axis * 0.125 + diag * 0.075;
    }

    // Colour, in premultiplied terms throughout.
    //
    // The tint is a surface of its own composited *over* what was sampled, not
    // a blend towards it. The difference shows wherever the backdrop is
    // transparent — the strip of a list above its first row, which is exactly
    // where chrome sits — because a tint scaled by the sampled alpha vanishes
    // precisely where there is nothing behind it, and the glass comes out
    // invisible with no rim.
    if (uSaturation != 1.0) {
        float a0 = max(glass.a, 0.0001);
        vec3 straight = glass.rgb / a0;
        float luma = dot(straight, vec3(0.2126, 0.7152, 0.0722));
        glass.rgb = mix(vec3(luma), straight, uSaturation) * glass.a;
    }
    float tintAlpha = clamp(uSurface.a, 0.0, 1.0);
    glass.rgb = uSurface.rgb * tintAlpha + glass.rgb * (1.0 - tintAlpha);
    glass.a = tintAlpha + glass.a * (1.0 - tintAlpha);

    // The rim, along the fused normal, so it runs around the body rather than
    // around each part. It is the shape that is shared here, not the press.
    if (uRim.a > 0.0 && uRimWidth > 0.0) {
        float band = 1.0 - smoothstep(0.0, uRimWidth, depth);
        float facing = 0.5 +
            0.5 * dot(grad, vec2(cos(uLightAngle), sin(uLightAngle)));
        float rimAlpha = clamp(uRim.a * band * facing, 0.0, 1.0);
        glass.rgb = uRim.rgb * rimAlpha + glass.rgb * (1.0 - rimAlpha);
        glass.a = rimAlpha + glass.a * (1.0 - rimAlpha);
    }

    // The press. Two ranges of the same light: the glow, which is the size of
    // the control being pressed and is what that control answers a finger
    // with, and the reach, which is wider and weaker and is how the press
    // carries to the controls around it.
    //
    // Both are masked by the field — that is the whole rule. The light lands
    // on glass and nowhere else, so it reaches across to a neighbour without
    // ever appearing in the gap between them, and through a neck it simply
    // keeps going, because through a neck it is all one surface.
    float press = clamp(uGlow.w, 0.0, 1.0);
    if (press > 0.0) {
        float d = distance(p, uGlow.xy);

        // The core: the falloff interactive_highlight.frag uses, so the glow
        // on a fused control is the same glow as on a control drawn by itself.
        // Its plateau is the point — it fills the control under the finger.
        float core = clamp((uGlow.z - d) / max(uGlow.z * 0.5, 0.0001), 0.0, 1.0);
        core = core * core * (3.0 - 2.0 * core);

        // The reach: decaying from the finger, with no plateau of its own.
        // A plateau here is what puts the light in the wrong order — a wide
        // flat top hands the control next door the same brightness as the one
        // being pressed, and then nothing on screen says which one that is.
        float reach = 1.0 - smoothstep(0.0, max(uReach, 1.0), d);
        reach = reach * reach;

        glass.rgb += vec3(0.16 * press * core + 0.05 * press * reach) *
            glass.a;
    }

    // Premultiplied, so coverage is a straight multiply.
    fragColor = glass * inside;
}
