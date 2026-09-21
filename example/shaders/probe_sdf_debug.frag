#version 460 core

// Throwaway probe shader: where does the lens think the element is?
//
// Same uniform layout as refraction.frag, and it recomputes the SDF exactly
// the way refraction.frag does -- but instead of refracting, it paints the
// answer:
//
//   green  the refraction band (sd < 0 and -sd < uRefractionHeight)
//   blue   the interior that takes the early-out (-sd >= uRefractionHeight)
//   red    outside the shape entirely (sd >= 0)
//
// Anchored correctly, an element shows a green ring hugging its own rim with
// blue in the middle. Anything else locates the mis-anchoring directly.

#include <flutter/runtime_effect.glsl>
#include <_sdf_probe.glsl>

precision highp float;

uniform vec2 uTextureSize;
uniform vec2 uLayerSize;
uniform vec2 uSize;
uniform vec2 uOffset;
uniform vec4 uCornerRadii;
uniform float uRefractionHeight;
uniform float uRefractionAmount;
uniform float uDepthEffect;

uniform sampler2D uContent;

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy / uTextureSize * uLayerSize;

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = (coord + uOffset) - halfSize;
    float radius = radiusAt(coord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    if (sd >= 0.0) {
        fragColor = vec4(1.0, 0.0, 0.0, 1.0);          // outside
    } else if (-sd >= uRefractionHeight) {
        fragColor = vec4(0.0, 0.0, 1.0, 1.0);          // early-out interior
    } else {
        fragColor = vec4(0.0, 1.0, 0.0, 1.0);          // refraction band
    }
}
