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
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    required this.children,
  });

  /// Null disables the button: no gestures, no press deformation, no highlight.
  ///
  /// The *appearance* of a disabled button is the caller's — dim the
  /// [children], as a disabled icon or label would be dimmed anywhere else. A
  /// disabled button is also inert rather than absorbing: a tap over it reaches
  /// whatever is behind, which is what a disabled control does elsewhere in
  /// Flutter.
  final VoidCallback? onPressed;

  final Backdrop backdrop;
  final bool isInteractive;
  final Color? tint;
  final Color? surfaceColor;

  /// The button's height. Its width comes from [children] plus [padding].
  ///
  /// A square button — [height] with children that measure the same across —
  /// is a circle, since the shape is a capsule.
  final double height;

  /// Inset around [children]. Pass [EdgeInsets.zero] for an icon-only button
  /// that should stay as wide as it is tall.
  final EdgeInsetsGeometry padding;

  /// The gap between [children].
  final double spacing;

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
      height: widget.height,
      child: Padding(
        padding: widget.padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: widget.spacing,
          children: widget.children,
        ),
      ),
    );

    final VoidCallback? onPressed = widget.onPressed;
    final bool isEnabled = onPressed != null;

    if (!isEnabled) {
      // Nothing wrapped: no gesture arena entry, no press animation to leave
      // running, and no InkWell that would swallow the tap without acting on it.
    } else if (widget.isInteractive) {
      // The tap is reported by the same slop-free inspector that drives the
      // press highlight, so pushing the glass around under a finger and then
      // releasing still counts as a press, as it does in Compose. A
      // GestureDetector would enter the arena and self-reject past kTouchSlop.
      content = _interactiveHighlight.wrapOverlay(
        child: _interactiveHighlight.wrapGestures(
          child: content,
          onTap: onPressed,
        ),
      );
    } else {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onPressed, child: content),
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
      layerBlock: widget.isInteractive && isEnabled ? _layerBlock : null,
      onDrawSurface: _drawSurface,
      repaint: _interactiveHighlight,
      child: content,
    );
  }
}

