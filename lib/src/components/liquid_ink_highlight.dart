import 'package:flutter/material.dart';

/// Install in ThemeData.splashFactory to give every Material ink control the
/// same soft press glow as the glass controls, without wrapping every button.
class LiquidInkHighlight extends InteractiveInkFeature {
  LiquidInkHighlight({
    required super.controller,
    required super.referenceBox,
    required super.color,
    required Offset position,
    required TextDirection textDirection,
    BorderRadius borderRadius = BorderRadius.zero,
    ShapeBorder? customBorder,
    RectCallback? rectCallback,
    super.onRemoved,
  }) : _position = position,
       _textDirection = textDirection,
       _borderRadius = borderRadius,
       _customBorder = customBorder,
       _rectCallback = rectCallback {
    _animation =
        AnimationController(
            vsync: controller.vsync,
            duration: const Duration(milliseconds: 90),
            reverseDuration: const Duration(milliseconds: 180),
          )
          ..addListener(controller.markNeedsPaint)
          ..addStatusListener((status) {
            if (status == AnimationStatus.dismissed) dispose();
          });
    controller.addInkFeature(this);
    _animation.forward();
  }
  static const InteractiveInkFeatureFactory splashFactory = _LiquidInkFactory();
  final Offset _position;
  final TextDirection _textDirection;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final RectCallback? _rectCallback;
  late final AnimationController _animation;
  @override
  void confirm() => _release();
  @override
  void cancel() => _release();
  void _release() {
    if (_animation.value == 0) {
      dispose();
    } else {
      _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final rect = _rectCallback?.call() ?? Offset.zero & referenceBox.size;
    canvas.save();
    canvas.transform(transform.storage);
    if (_customBorder != null) {
      canvas.clipPath(
        _customBorder.getOuterPath(rect, textDirection: _textDirection),
      );
    } else {
      canvas.clipRRect(_borderRadius.toRRect(rect));
    }
    final opacity = _animation.value;
    canvas.drawRect(
      rect,
      Paint()..color = color.withValues(alpha: color.a * opacity * 0.35),
    );
    canvas.drawCircle(
      _position,
      rect.longestSide,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                color.withValues(alpha: color.a * opacity),
                color.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: _position,
                radius: rect.shortestSide * 1.5,
              ),
            ),
    );
    canvas.restore();
  }
}

class _LiquidInkFactory extends InteractiveInkFeatureFactory {
  const _LiquidInkFactory();
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) => LiquidInkHighlight(
    controller: controller,
    referenceBox: referenceBox,
    position: position,
    color: color,
    textDirection: textDirection,
    rectCallback: rectCallback,
    borderRadius: borderRadius ?? BorderRadius.zero,
    customBorder: customBorder,
    onRemoved: onRemoved,
  );
}
