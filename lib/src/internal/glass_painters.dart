import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../highlight/highlight.dart';
import '../shadow/shadow.dart';
import '../shapes/glass_outline.dart';
import '../shapes/rectangle_corner_radii.dart';
import 'blur_sigma.dart';
import 'shader_programs.dart';

/// A paint that scales a save-layer's contents by [alpha].
Paint _layerPaint(double alpha, BlendMode blendMode) {
  return Paint()
    ..blendMode = blendMode
    ..color = Color.fromARGB((alpha.clamp(0.0, 1.0) * 255).round(), 255, 255, 255);
}

final Paint _clearPaint = Paint()..blendMode = BlendMode.clear;

/// Draws the drop shadow of a glass element.
///
/// The shape is blurred at [GlassShadow.offset], then the un-offset shape is
/// punched back out so the shadow never darkens the glass it belongs to.
void paintGlassShadow(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  GlassShadow shadow,
  double devicePixelRatio,
) {
  final double radius = shadow.radius;
  final Rect bounds = (offset & size).inflate(radius * 2.0 + shadow.offset.distance + 1.0);

  canvas.saveLayer(bounds, _layerPaint(shadow.alpha, shadow.blendMode));

  final Paint shadowPaint = Paint()..color = shadow.color;
  final double sigma =
      blurRadiusToSigma(radius, devicePixelRatio: devicePixelRatio);
  if (sigma > 0.0) {
    shadowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  }

  canvas.save();
  canvas.translate(offset.dx + shadow.offset.dx, offset.dy + shadow.offset.dy);
  outline.draw(canvas, shadowPaint);
  canvas.restore();

  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  outline.draw(canvas, _clearPaint);
  canvas.restore();

  canvas.restore();
}

/// Draws the bright rim just inside a glass element's edge.
///
/// The outline is stroked at twice the requested width and clipped to itself,
/// leaving an inner border of exactly [Highlight.width].
void paintGlassHighlight(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  Highlight highlight,
  RectangleCorners corners,
  FragmentShaderCache shaderCache,
  double devicePixelRatio,
) {
  if (highlight.width <= 0.0) return;

  // The stroke is rounded up to a whole device pixel before being doubled.
  final double widthPx =
      math.min(highlight.width, size.shortestSide / 2.0) * devicePixelRatio;
  final double strokeWidth = widthPx.ceilToDouble() / devicePixelRatio * 2.0;

  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  final double sigma = blurRadiusToSigma(
    highlight.blurRadius,
    devicePixelRatio: devicePixelRatio,
  );
  if (sigma > 0.0) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  }

  final ui.FragmentShader? shader = highlight.style.createShader(
    size: size,
    corners: corners,
    // The canvas is translated to the element below, so fragment coordinates
    // already arrive in element space.
    origin: Offset.zero,
    cache: shaderCache,
  );
  if (shader != null) {
    paint.shader = shader;
  } else {
    paint.color = highlight.style.color;
  }

  canvas.saveLayer(
    (offset & size).inflate(1.0),
    _layerPaint(highlight.alpha, highlight.style.blendMode),
  );
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  outline.clip(canvas);
  outline.draw(canvas, paint);
  canvas.restore();
  canvas.restore();
}

/// Draws the shadow cast inside a glass element.
///
/// The shape is filled, the same shape offset by [GlassInnerShadow.offset] is
/// punched out, the remaining crescent is blurred, and the result is clipped
/// back to the shape.
void paintGlassInnerShadow(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  GlassInnerShadow shadow,
  double devicePixelRatio,
) {
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  outline.clip(canvas);

  final double sigma =
      blurRadiusToSigma(shadow.radius, devicePixelRatio: devicePixelRatio);
  final Paint layerPaint = _layerPaint(shadow.alpha, shadow.blendMode);
  if (sigma > 0.0) {
    layerPaint.imageFilter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.decal,
    );
  }
  canvas.saveLayer(Offset.zero & size, layerPaint);

  canvas.save();
  outline.clip(canvas);
  outline.draw(canvas, Paint()..color = shadow.color);
  canvas.translate(shadow.offset.dx, shadow.offset.dy);
  outline.draw(canvas, _clearPaint);
  canvas.restore();

  canvas.restore();
  canvas.restore();
}
