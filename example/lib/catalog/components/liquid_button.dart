import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/interactive_highlight.dart';

/// A capsule of liquid glass that squashes and slides under the finger.
class LiquidButton extends StatefulWidget {
  const LiquidButton({
    super.key,
    required this.onPressed,
    required this.backdrop,
    this.isInteractive = true,
    this.tint,
    this.surfaceColor,
    required this.children,
  });

  final VoidCallback onPressed;
  final Backdrop backdrop;
  final bool isInteractive;
  final Color? tint;
  final Color? surfaceColor;
  final List<Widget> children;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with TickerProviderStateMixin {
  late final InteractiveHighlight _interactiveHighlight =
      InteractiveHighlight(vsync: this);

  @override
  void dispose() {
    _interactiveHighlight.dispose();
    super.dispose();
  }

  void _layerBlock(GlassLayer layer) {
    final double width = layer.size.width;
    final double height = layer.size.height;
    if (width == 0 || height == 0) return;

    final double progress = _interactiveHighlight.pressProgress;
    final double scale = lerpDouble(1.0, 1.0 + 4.0 / height, progress)!;

    final double maxOffset = layer.size.shortestSide;
    const double initialDerivative = 0.05;
    final Offset offset = _interactiveHighlight.offset;
    layer.translationX =
        maxOffset * _tanh(initialDerivative * offset.dx / maxOffset);
    layer.translationY =
        maxOffset * _tanh(initialDerivative * offset.dy / maxOffset);

    final double maxDragScale = 4.0 / height;
    final double offsetAngle = math.atan2(offset.dy, offset.dx);
    final double maxDimension = layer.size.longestSide;
    layer.scaleX = scale +
        maxDragScale *
            (math.cos(offsetAngle) * offset.dx / maxDimension).abs() *
            math.min(width / height, 1.0);
    layer.scaleY = scale +
        maxDragScale *
            (math.sin(offsetAngle) * offset.dy / maxDimension).abs() *
            math.min(height / width, 1.0);
  }

  void _drawSurface(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color? tint = widget.tint;
    if (tint != null) {
      canvas.drawRect(rect, Paint()..color = tint..blendMode = BlendMode.hue);
      canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.75));
    }
    final Color? surfaceColor = widget.surfaceColor;
    if (surfaceColor != null) {
      canvas.drawRect(rect, Paint()..color = surfaceColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: widget.children,
        ),
      ),
    );

    if (widget.isInteractive) {
      content = _interactiveHighlight.wrapOverlay(
        child: _interactiveHighlight.wrapGestures(child: content),
      );
      // The tap target is the whole capsule, not just the text.
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: content,
      );
    } else {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: widget.onPressed, child: content),
      );
    }

    return DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => const Capsule(),
      effects: (BackdropEffectScope scope) => scope
        ..vibrancy()
        ..blur(2)
        ..lens(12, 24),
      layerBlock: widget.isInteractive ? _layerBlock : null,
      onDrawSurface: _drawSurface,
      repaint: _interactiveHighlight,
      child: content,
    );
  }
}

double _tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final double e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}
