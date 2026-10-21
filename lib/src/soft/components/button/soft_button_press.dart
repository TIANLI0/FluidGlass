import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';

/// The press feedback the buttons and chips share: the surface shrinks
/// towards an area-dependent end scale while the fill darkens with the
/// theme's state layer, both on the critically damped state-layer spring.
abstract final class SoftButtonPressDefaults {
  /// The end scale of surfaces up to 48 × 48.
  static const double smallestScale = 0.92;

  /// The end scale of surfaces from 328 × 220 up.
  static const double largestScale = 0.98;

  /// The area below which a surface shrinks to [smallestScale].
  static const double minArea = 48.0 * 48.0;

  /// The area above which a surface shrinks to [largestScale].
  static const double maxArea = 328.0 * 220.0;

  /// A release before the tint reaches this progress keeps pressing in until
  /// it does, so a quick tap still flashes.
  static const double minVisibleTint = 0.7;

  /// The scale a [size] surface shrinks to when fully pressed: eased from
  /// [smallestScale] to [largestScale] by area on the entering curve.
  static double endScale(Size size) {
    final double area = size.width * size.height;
    if (area <= minArea) return smallestScale;
    if (area >= maxArea) return largestScale;
    final double t = SoftMotion.inEase.transform(
      (area - minArea) / (maxArea - minArea),
    );
    return smallestScale + (largestScale - smallestScale) * t;
  }
}

/// Drives the scale and tint progress of a pressed button or chip.
class SoftButtonPress {
  SoftButtonPress({required TickerProvider vsync})
    : scale = SoftSpring(vsync: vsync),
      tint = SoftSpring(vsync: vsync);

  /// 0 at rest, 1 fully shrunk.
  final SoftSpring scale;

  /// 0 at rest, 1 fully tinted.
  final SoftSpring tint;

  bool _pressed = false;
  bool _enabled = true;
  bool _scaleEnabled = true;
  bool _disposed = false;

  /// Updates the press state.
  void update({
    required bool pressed,
    required bool enabled,
    bool scaleEnabled = true,
  }) {
    if (pressed == _pressed &&
        enabled == _enabled &&
        scaleEnabled == _scaleEnabled) {
      return;
    }
    _pressed = pressed;
    _enabled = enabled;
    _scaleEnabled = scaleEnabled;
    scale.animateTo(
      enabled && pressed && scaleEnabled ? 1 : 0,
      SoftMotion.stateLayer,
    );
    _syncTint();
  }

  Future<void> _syncTint() async {
    if (!_enabled) {
      tint.snapTo(0);
      return;
    }
    if (_pressed) {
      await tint.animateTo(1, SoftMotion.stateLayer);
      return;
    }
    if (tint.value <= 0) return;
    if (tint.value < SoftButtonPressDefaults.minVisibleTint) {
      // Keep pressing in until the tint is clearly visible, then fade from
      // there with the velocity it has.
      final Completer<void> visible = Completer<void>();
      void listener() {
        if (tint.value >= SoftButtonPressDefaults.minVisibleTint &&
            !visible.isCompleted) {
          visible.complete();
        }
      }

      tint.addListener(listener);
      tint
          .animateTo(1, SoftMotion.stateLayer)
          .orCancel
          .then((_) {}, onError: (Object _) {})
          .whenComplete(() {
            if (!visible.isCompleted) visible.complete();
          });
      await visible.future;
      if (_disposed) return;
      tint.removeListener(listener);
      if (_pressed || !_enabled) return;
    }
    tint.animateTo(0, SoftMotion.stateLayer);
  }

  void dispose() {
    _disposed = true;
    scale.dispose();
    tint.dispose();
  }
}

/// Scales its child about its centre by
/// `1 - (1 - endScale(size)) * progress`, repainting on [progress] without a
/// rebuild or relayout.
class SoftAreaPressScale extends SingleChildRenderObjectWidget {
  const SoftAreaPressScale({
    super.key,
    required this.progress,
    this.endScale = SoftButtonPressDefaults.endScale,
    super.child,
  });

  final ValueListenable<double> progress;

  /// The fully pressed scale of a surface of a given size.
  final double Function(Size size) endScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAreaPressScale(progress: progress, endScale: endScale);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderAreaPressScale)
      ..progress = progress
      ..endScale = endScale;
  }
}

class _RenderAreaPressScale extends RenderProxyBox {
  _RenderAreaPressScale({
    required ValueListenable<double> progress,
    required double Function(Size size) endScale,
  }) : _progress = progress,
       _endScale = endScale;

  ValueListenable<double> _progress;
  set progress(ValueListenable<double> value) {
    if (identical(value, _progress)) return;
    if (attached) _progress.removeListener(_changed);
    _progress = value;
    if (attached) _progress.addListener(_changed);
    _changed();
  }

  double Function(Size size) _endScale;
  set endScale(double Function(Size size) value) {
    if (identical(value, _endScale)) return;
    _endScale = value;
    _changed();
  }

  void _changed() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(_changed);
  }

  @override
  void detach() {
    _progress.removeListener(_changed);
    super.detach();
  }

  Matrix4? get _transform {
    final double t = _progress.value;
    if (t == 0 || !hasSize) return null;
    final double s = 1 - (1 - _endScale(size)) * t;
    if (s == 1) return null;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final Matrix4? transform = _transform;
    if (transform == null) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Matrix4? transform = _transform;
    if (child == null || transform == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Matrix4? matrix = _transform;
    if (matrix != null) transform.multiply(matrix);
  }
}

/// Paints a button's smooth-cornered fill with the press tint composited
/// over it, repainting on the tint (and an optional colour transition)
/// without a rebuild.
class SoftButtonFillPainter extends CustomPainter {
  SoftButtonFillPainter({
    required this.color,
    required this.tint,
    required this.pressColor,
    required this.radius,
    required this.smooth,
    this.fromColor,
    this.colorProgress,
  }) : super(
         repaint: colorProgress == null
             ? tint
             : Listenable.merge(<Listenable>[tint, colorProgress]),
       );

  /// The resting fill (the target of a colour transition).
  final Color color;

  /// Where a colour transition started; null for none.
  final Color? fromColor;

  /// The progress of the colour transition from [fromColor] to [color].
  final ValueListenable<double>? colorProgress;

  final ValueListenable<double> tint;

  /// The full press tint (the state layer at the press alpha).
  final Color pressColor;
  final BorderRadius radius;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    Color fill = color;
    final Color? from = fromColor;
    final ValueListenable<double>? progress = colorProgress;
    if (from != null && progress != null) {
      fill = Color.lerp(from, color, progress.value.clamp(0.0, 1.0))!;
    }
    final double t = tint.value.clamp(0.0, 1.0);
    if (t > 0) {
      fill = Color.alphaBlend(
        pressColor.withValues(alpha: pressColor.a * t),
        fill,
      );
    }
    if (fill.a == 0) return;
    drawSoftSquircle(
      canvas,
      Offset.zero & size,
      radius,
      Paint()..color = fill,
      smooth: smooth,
    );
  }

  @override
  bool shouldRepaint(SoftButtonFillPainter old) =>
      old.color != color ||
      old.fromColor != fromColor ||
      old.colorProgress != colorProgress ||
      old.tint != tint ||
      old.pressColor != pressColor ||
      old.radius != radius ||
      old.smooth != smooth;
}
