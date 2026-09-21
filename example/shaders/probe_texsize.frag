#version 460 core

// Throwaway probe shader: reports the size of the texture the engine binds.
//
// `ImageFilter.shader` overwrites the first vec2 uniform with the size of the
// bound input texture, in device pixels. This shader does nothing with the
// content — it encodes that size into the output colour so a framebuffer
// read-back can recover it exactly:
//
//   x = r * 256 + g      (16-bit, exact)
//   y = b / 255 * 2048   (8-bit, +/-4 px)
//
// The question it answers: inside a BackdropFilter, is that texture the whole
// screen, or the element's own (clipped) bounds?

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uTextureSize;  // set by the engine to the input texture size
uniform sampler2D uContent;

out vec4 fragColor;

void main() {
  float x = uTextureSize.x;
  float y = uTextureSize.y;
  float xhi = floor(x / 256.0);
  float xlo = x - xhi * 256.0;
  fragColor = vec4(xhi / 255.0, xlo / 255.0, clamp(y / 2048.0, 0.0, 1.0), 1.0);
}
