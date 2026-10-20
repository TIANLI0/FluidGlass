import 'dart:async';

import 'package:flutter/widgets.dart';

import 'soft_motion.dart';
import 'soft_squircle.dart';
import 'soft_theme.dart';

/// The press feedback of a [SoftPressable].
enum SoftPressFeedback {
  /// None.
  none,

  /// A state layer laid over the surface while pressed (list rows, cards).
  tint,

  /// The whole surface sinks to 0.94.
  sink,
}

/// A tappable area with the reference's press feedback.
///
/// The press shows 150 ms after the finger lands, so a touch that becomes a
/// scroll never flashes; a tap quicker than that shows nothing at all, as in
/// the original. [tint] lays the theme's state layer (black at 12 %, white at
/// 20 % in the dark theme) over [child], clipped to [borderRadius], on a
/// critically damped spring.
class SoftPressable extends StatefulWidget {
  const SoftPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.feedback = SoftPressFeedback.tint,
    this.borderRadius,
    this.enabled = true,
    this.holdDown = false,
    this.semanticsButton = true,
    this.onPressedChanged,
  });

  /// Called when the (delayed) press starts and ends. A tap quicker than the
  /// delay reports a press and its release back to back.
  final ValueChanged<bool>? onPressedChanged;

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final SoftPressFeedback feedback;

  /// Clips the tint layer.
  final BorderRadius? borderRadius;
  final bool enabled;

  /// Keeps the press shown after the finger lifts — for a row whose popup is
  /// open.
  final bool holdDown;

  final bool semanticsButton;

  @override
  State<SoftPressable> createState() => _SoftPressableState();
}

class _SoftPressableState extends State<SoftPressable>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _layer = SoftSpring(vsync: this);
  Timer? _delay;
  bool _pressed = false;

  static final SpringDescription _sink = softSpringStiffness(
    damping: 0.8,
    stiffness: 600,
  );

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void didUpdateWidget(SoftPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDown != widget.holdDown) _sync();
  }

  @override
  void dispose() {
    _delay?.cancel();
    _layer.dispose();
    super.dispose();
  }

  void _sync() {
    final bool on = _pressed || widget.holdDown;
    final SpringDescription spring = widget.feedback == SoftPressFeedback.sink
        ? _sink
        : SoftMotion.stateLayer;
    _layer.animateTo(on ? 1 : 0, spring);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    _sync();
    widget.onPressedChanged?.call(value);
  }

  void _onDown(PointerDownEvent _) {
    if (!_active) return;
    _delay?.cancel();
    _delay = Timer(SoftMotion.tapIndicationDelay, () {
      _delay = null;
      _setPressed(true);
    });
  }

  /// Ends the press. A tap that lands before the delay ran out still reports
  /// its press first, the way a click inside a scrolling container does.
  void _end({bool tapped = false}) {
    final bool pending = _delay != null;
    _delay?.cancel();
    _delay = null;
    if (tapped && pending) _setPressed(true);
    _setPressed(false);
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    Widget result = widget.child;
    switch (widget.feedback) {
      case SoftPressFeedback.none:
        break;
      case SoftPressFeedback.tint:
        result = CustomPaint(
          foregroundPainter: _TintPainter(
            layer: _layer,
            color: theme.colors.stateLayer,
            alpha: theme.colors.pressAlpha,
            radius: widget.borderRadius,
            smooth: theme.smoothCorners,
          ),
          child: result,
        );
      case SoftPressFeedback.sink:
        result = AnimatedBuilder(
          animation: _layer,
          builder: (BuildContext context, Widget? child) =>
              Transform.scale(scale: 1 - 0.06 * _layer.value, child: child),
          child: result,
        );
    }
    return Semantics(
      button: widget.semanticsButton && widget.onTap != null,
      enabled: widget.enabled,
      child: Listener(
        onPointerDown: _onDown,
        onPointerCancel: (_) => _end(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _active && widget.onTap != null
              ? () {
                  _end(tapped: true);
                  widget.onTap!();
                }
              : null,
          onTapCancel: _end,
          onTapUp: (TapUpDetails _) => _end(tapped: true),
          onLongPress: _active ? widget.onLongPress : null,
          onLongPressEnd: (LongPressEndDetails _) => _end(),
          child: result,
        ),
      ),
    );
  }
}

class _TintPainter extends CustomPainter {
  _TintPainter({
    required this.layer,
    required this.color,
    required this.alpha,
    required this.radius,
    required this.smooth,
  }) : super(repaint: layer);

  final SoftSpring layer;
  final Color color;
  final double alpha;
  final BorderRadius? radius;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = layer.value.clamp(0.0, 1.0);
    if (t <= 0) return;
    final Paint paint = Paint()..color = color.withValues(alpha: alpha * t);
    final BorderRadius? r = radius;
    if (r == null) {
      canvas.drawRect(Offset.zero & size, paint);
    } else {
      drawSoftSquircle(canvas, Offset.zero & size, r, paint, smooth: smooth);
    }
  }

  @override
  bool shouldRepaint(_TintPainter old) =>
      old.color != color ||
      old.alpha != alpha ||
      old.radius != radius ||
      old.smooth != smooth;
}
