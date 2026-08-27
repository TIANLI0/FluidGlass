import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

/// A decoration baked into a cached GPU texture, redrawn as a single image
/// until its inputs change.
///
/// Skia caches blurred masks by path and sigma, so redrawing the same soft
/// shadow every frame was nearly free; Impeller has no such cache and runs the
/// full Gaussian pass per frame. Baking the decoration once — at full opacity,
/// so an animating alpha only modulates the cached image — restores that
/// behaviour on any backend.
class BakedDecoration {
  ui.Image? _image;
  Object? _key;

  /// How many paints in a row arrived with a different key.
  ///
  /// Re-baking costs a picture recording plus a synchronous `toImageSync`, so
  /// a decoration whose geometry animates every frame — an inner shadow whose
  /// radius follows a press, say — is strictly cheaper drawn directly. Past
  /// [_thrashLimit] the cache steps aside until the key holds still again.
  int _misses = 0;
  int _hits = 0;
  bool _thrashing = false;

  static const int _thrashLimit = 3;
  static const int _recoverLimit = 2;

  /// Whether the last [paint] call actually drew.
  ///
  /// False means the key is churning and the caller should draw the decoration
  /// itself this frame.
  bool get isBypassed => _thrashing;

  /// Draws the decoration at [offset], re-baking it via [bake] when [key]
  /// differs from the cached one.
  ///
  /// [bake] draws in element space at full opacity; [bounds] is the
  /// element-space rectangle the drawing covers, and must be derivable from
  /// [key]. [alpha] and [blendMode] are applied when the cached image is
  /// composited, exactly as the save-layer they replace did.
  ///
  /// Returns false when the cache has stepped aside — see [isBypassed] — in
  /// which case nothing was drawn.
  bool paint(
    Canvas canvas,
    Offset offset,
    Object key,
    Rect bounds,
    double devicePixelRatio, {
    required double alpha,
    required BlendMode blendMode,
    required void Function(Canvas canvas) bake,
  }) {
    final bool keyHeld = _key == key;
    if (keyHeld) {
      _misses = 0;
      if (_thrashing && ++_hits >= _recoverLimit) {
        _thrashing = false;
        _hits = 0;
      }
    } else {
      _hits = 0;
      if (!_thrashing && ++_misses >= _thrashLimit) {
        _thrashing = true;
        _image?.dispose();
        _image = null;
      }
      // The key is tracked even while bypassed, so a run of equal keys can be
      // noticed and the cache brought back.
      if (_thrashing) {
        _key = key;
        return false;
      }
    }

    if (_image == null || !keyHeld) {
      _image?.dispose();
      _image = null;
      _key = null;

      final int width = (bounds.width * devicePixelRatio).ceil();
      final int height = (bounds.height * devicePixelRatio).ceil();
      if (width <= 0 || height <= 0) return true;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas bakeCanvas = Canvas(recorder);
      bakeCanvas.scale(devicePixelRatio);
      bakeCanvas.translate(-bounds.left, -bounds.top);
      bake(bakeCanvas);
      final ui.Picture picture = recorder.endRecording();
      try {
        _image = picture.toImageSync(width, height);
        _key = key;
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'fluid_glass',
            context: ErrorDescription('while baking a glass decoration'),
          ),
        );
      } finally {
        picture.dispose();
      }
    }

    final ui.Image? image = _image;
    // A bake that threw leaves nothing to draw; the direct path is the
    // fallback, so report the miss rather than silently dropping the
    // decoration.
    if (image == null) return false;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        offset.dx + bounds.left,
        offset.dy + bounds.top,
        image.width / devicePixelRatio,
        image.height / devicePixelRatio,
      ),
      _layerPaint(alpha, blendMode)..filterQuality = FilterQuality.low,
    );
    return true;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _key = null;
  }
}

/// Draws the drop shadow of a glass element.
///
/// The shape is blurred at [GlassShadow.offset], then the un-offset shape is
/// punched back out so the shadow never darkens the glass it belongs to.
///
/// With [cache] and [cacheKey], the blurred shadow is baked once and reused
/// until the key changes; [GlassShadow.alpha] modulates the cached image, so
/// animating it costs nothing.
void paintGlassShadow(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  GlassShadow shadow,
  double devicePixelRatio, {
  BakedDecoration? cache,
  Object? cacheKey,
}) {
  // A fully transparent shadow still costs a save-layer and a blur; skip it.
  if (shadow.alpha <= 0.0 || shadow.color.a <= 0.0) return;

  final double radius = shadow.radius;
  final Rect localBounds = (Offset.zero & size)
      .inflate(radius * 2.0 + shadow.offset.distance + 1.0);

  void drawContent(Canvas canvas) {
    final Paint shadowPaint = Paint()..color = shadow.color;
    final double sigma =
        blurRadiusToSigma(radius, devicePixelRatio: devicePixelRatio);
    if (sigma > 0.0) {
      shadowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    canvas.save();
    canvas.translate(shadow.offset.dx, shadow.offset.dy);
    outline.draw(canvas, shadowPaint);
    canvas.restore();

    outline.draw(canvas, _clearPaint);
  }

  if (cache != null &&
      cacheKey != null &&
      cache.paint(
        canvas,
        offset,
        cacheKey,
        localBounds,
        devicePixelRatio,
        alpha: shadow.alpha,
        blendMode: shadow.blendMode,
        bake: drawContent,
      )) {
    return;
  }

  canvas.saveLayer(
    localBounds.shift(offset),
    _layerPaint(shadow.alpha, shadow.blendMode),
  );
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  drawContent(canvas);
  canvas.restore();
  canvas.restore();
}

/// Draws the bright rim just inside a glass element's edge.
///
/// The outline is stroked at twice the requested width and clipped to itself,
/// leaving an inner border of exactly [Highlight.width].
///
/// The rim is deliberately neither baked into a texture nor stripped of its
/// save-layer. It is a hairline whose crispness depends on being rasterised at
/// the element's true sub-pixel position, and both shortcuts were measured to
/// change its pixels: baking resamples it, and compositing its pixels
/// individually rather than as one layer changes how the clip's antialiasing
/// combines with the stroke's.
void paintGlassHighlight(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  Highlight highlight,
  RectangleCorners corners,
  FragmentShaderCache shaderCache,
  double devicePixelRatio, {
  bool shadeRim = true,
}) {
  if (highlight.width <= 0.0 || highlight.alpha <= 0.0) return;

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

  // [shadeRim] false is the cheap tier: the rim keeps its width, blur and
  // blend mode and only loses its directional shading, which is one fragment
  // program's worth of work per frame.
  final ui.FragmentShader? shader = shadeRim
      ? highlight.style.createShader(
          size: size,
          corners: corners,
          // The canvas is translated to the element below, so fragment
          // coordinates already arrive in element space.
          origin: Offset.zero,
          cache: shaderCache,
        )
      : null;
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
///
/// With [cache] and [cacheKey], the blurred crescent is baked once and reused
/// until the key changes; [GlassInnerShadow.alpha] modulates the cached image.
void paintGlassInnerShadow(
  Canvas canvas,
  Offset offset,
  Size size,
  GlassOutline outline,
  GlassInnerShadow shadow,
  double devicePixelRatio, {
  BakedDecoration? cache,
  Object? cacheKey,
}) {
  // A fully transparent inner shadow still costs a save-layer; skip it.
  if (shadow.alpha <= 0.0 || shadow.color.a <= 0.0) return;

  void drawContent(Canvas canvas, Paint layerPaint) {
    canvas.save();
    outline.clip(canvas);

    final double sigma =
        blurRadiusToSigma(shadow.radius, devicePixelRatio: devicePixelRatio);
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

  if (cache != null &&
      cacheKey != null &&
      cache.paint(
        canvas,
        offset,
        cacheKey,
        Offset.zero & size,
        devicePixelRatio,
        alpha: shadow.alpha,
        blendMode: shadow.blendMode,
        bake: (Canvas canvas) => drawContent(canvas, Paint()),
      )) {
    return;
  }

  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  drawContent(canvas, _layerPaint(shadow.alpha, shadow.blendMode));
  canvas.restore();
}
