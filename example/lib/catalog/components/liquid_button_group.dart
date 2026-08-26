import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/drag_gesture_inspector.dart';
import '../utils/interactive_highlight.dart';

/// One tappable segment of a [LiquidButtonGroup].
@immutable
class LiquidGroupAction {
  const LiquidGroupAction({
    this.icon,
    this.label,
    required this.onPressed,
  }) : assert(icon != null || label != null, 'an action needs a face');

  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;
}

/// A capsule of glass holding several actions — a back cluster, a toolbar
/// pair, a Cancel/OK bar — with hairline separators between them.
///
/// The whole capsule is one piece of liquid, and it carries the same
/// drag-and-spring-back physics as [LiquidButton]: the glass follows your
/// finger through a `tanh` so it never runs away, stretches along the
/// direction of travel, and springs home when you let go. The press glow
/// tracks the finger across it.
class LiquidButtonGroup extends StatefulWidget {
  const LiquidButtonGroup({
    super.key,
    required this.backdrop,
    required this.actions,
    this.height = 48,
    this.showDividers = true,
  });

  final Backdrop backdrop;
  final List<LiquidGroupAction> actions;
  final double height;
  final bool showDividers;

  @override
  State<LiquidButtonGroup> createState() => _LiquidButtonGroupState();
}

class _LiquidButtonGroupState extends State<LiquidButtonGroup>
    with TickerProviderStateMixin {
  /// Drives the press glow, the swell, and — through [InteractiveHighlight.offset]
  /// — how far the capsule has been dragged. The offset is itself a spring, so
  /// releasing springs the glass home rather than snapping it.
  late final InteractiveHighlight _highlight = InteractiveHighlight(vsync: this);

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  /// The same displacement law as `LiquidButton`: `tanh` keeps the travel
  /// bounded, and the stretch grows along whichever axis is being pulled.
  void _layerBlock(GlassLayer layer) {
    final double width = layer.size.width;
    final double height = layer.size.height;
    if (width == 0 || height == 0) return;

    final double progress = _highlight.pressProgress;
    final double scale = lerpDouble(1.0, 1.0 + 4.0 / height, progress)!;

    final double maxOffset = layer.size.shortestSide;
    const double initialDerivative = 0.05;
    final Offset offset = _highlight.offset;
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

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color containerColor = isLight
        ? const Color(0xFFFAFAFA).withValues(alpha: 0.4)
        : const Color(0xFF121212).withValues(alpha: 0.4);
    final Color separatorColor = contentColor.withValues(alpha: 0.12);

    return DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => const Capsule(),
      effects: (BackdropEffectScope scope) => scope
        ..vibrancy()
        ..blur(2)
        ..lens(12, 24),
      layerBlock: _layerBlock,
      onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = containerColor,
      ),
      // Src-over only, so the isolating save-layer would be pure cost.
      isolateSurface: false,
      repaint: _highlight,
      child: _highlight.wrapOverlay(
        // The whole capsule is one drag surface: this inspector reports the
        // press and the travel that the layer block above reads.
        child: _highlight.wrapGestures(
          child: SizedBox(
            height: widget.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < widget.actions.length; i++) ...<Widget>[
                  if (i > 0 && widget.showDividers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: 0.5,
                        height: double.infinity,
                        child: ColoredBox(color: separatorColor),
                      ),
                    ),
                  _GroupSegment(
                    action: widget.actions[i],
                    contentColor: contentColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupSegment extends StatelessWidget {
  const _GroupSegment({
    required this.action,
    required this.contentColor,
  });

  final LiquidGroupAction action;
  final Color contentColor;

  @override
  Widget build(BuildContext context) {
    // No pressed wash here by design: the group's own feedback is the
    // finger-following glow, the swell and the drag, and a flat bar on top of
    // that read as an artifact.
    return DragInspector(
      // Translucent, so the capsule-wide inspector behind still sees the same
      // pointer and keeps driving the drag.
      behavior: HitTestBehavior.translucent,
      onTap: action.onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: <Widget>[
            if (action.icon != null)
              Icon(action.icon, size: 20, color: contentColor),
            if (action.label != null)
              Text(
                action.label!,
                style: TextStyle(color: contentColor, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}

double _tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final double e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}
