import 'package:flutter/material.dart';

import '../../fluid_glass.dart';
import '../internal/drag_deformation.dart';

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

  void _layerBlock(GlassLayer layer) => applyDragDeformation(
        layer,
        offset: _interactiveHighlight.offset,
        pressProgress: _interactiveHighlight.pressProgress,
      );

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
      // The tap is reported by the same slop-free inspector that drives the
      // press highlight, so pushing the glass around under a finger and then
      // releasing still counts as a press, as it does in Compose. A
      // GestureDetector would enter the arena and self-reject past kTouchSlop.
      content = _interactiveHighlight.wrapOverlay(
        child: _interactiveHighlight.wrapGestures(
          child: content,
          onTap: widget.onPressed,
        ),
      );
    } else {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: widget.onPressed, child: content),
      );
    }

    // Filtering an empty backdrop produces nothing but still costs the filter
    // save-layers; the Back button on every catalog screen sits on one.
    final bool refractsNothing = identical(widget.backdrop, emptyBackdrop);

    return DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => const Capsule(),
      effects: refractsNothing
          ? (BackdropEffectScope scope) {}
          : (BackdropEffectScope scope) => scope
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

