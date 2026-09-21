#version 460 core

// The alpha ramp that fades one band of a progressive blur into the band
// beneath it.
//
// `ProgressiveBlur` stacks native Gaussian blurs of increasing sigma, each
// clipped to a shorter run from the blurred end. Painted alone, every band
// would end on a line where the blur amount steps. This shader runs *inside*
// each band's filter chain, before its blur: it multiplies the band's input by
// a linear alpha ramp — opaque towards the blurred end, clear at the band's
// far edge — so the band's output fades over the previous band's output, and
// the step becomes a slope. The blur then softens the ramp itself as well.
//
// Both images being mixed are blurred by similar amounts (consecutive bands
// differ by a bounded ratio), which is what keeps the mix from reading as a
// double exposure: that artefact needs a sharp image under a soft one.
//
// Coordinates are the input texture's own device pixels, which for a backdrop
// filter's innermost stage is the clipped band itself: the caller passes the
// two ends of the ramp as distances from the blurred end, and `uFlip` says
// which end of the texture that is.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform vec2 uRamp;         // (full, clear): distance from the blurred end where
                            // alpha is still 1, and where it has reached 0
uniform float uFlip;        // 0 = blurred end is y 0, 1 = blurred end is y max
uniform float uDebug;       // >0.5 paints the ramp instead of applying it

uniform sampler2D uContent;

out vec4 fragColor;

void main() {
    vec2 fc = FlutterFragCoord().xy;
    float d = uFlip > 0.5 ? uTextureSize.y - fc.y : fc.y;
    float alpha =
        1.0 - clamp((d - uRamp.x) / max(uRamp.y - uRamp.x, 1e-4), 0.0, 1.0);

    if (uDebug > 0.5) {
        // Diagnostic: where this band's ramp landed. Red is opaque, green is
        // clear; the band boundary is where the colour ends.
        fragColor = vec4(alpha, 1.0 - alpha, 0.0, 1.0);
        return;
    }

    // Premultiplied in, premultiplied out: scaling the whole vector is the
    // alpha multiply.
    fragColor = texture(uContent, fc / uTextureSize) * alpha;
}
