import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// Press feedback shared by every tappable soft component: the element sinks
/// under the finger, a press tint fades in over it, and on release it springs
/// back past rest.
///
/// **How far it sinks** depends on its size: the area is placed between 20²
/// and 150² and eased from 0.85 to 0.97 — a small chip moves visibly, a wide
/// button only a hair. Long, thin shapes (more than 2:1) are pulled further
/// towards 1, since a full-width bar sinking reads as a jolt.
///
/// **The springs** depend on the shape too: roughly square things press on
/// (0.25, 0) and release on (0.5, 0.6), a lively jelly; long ones on (0.3, 0)
/// and (0.5, 0.5).
///
/// With [follow] the element also leans towards a finger dragged across it, on
/// a rubber band capped at 28 (buttons and the floating action button do).
///
/// Taps go through a real [GestureDetector], so a press that turns into a
/// scroll of the list it sits in is cancelled by the list, as any Flutter
/// button's is.
class SoftPressable extends StatefulWidget {
  const SoftPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.shape,
    this.overlay = true,
    this.scales = true,
    this.follow = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// The outline the press tint is clipped to; a rectangle by default.
  final ShapeBorder? shape;

  /// Lay the press tint over the child.
  final bool overlay;

  /// False keeps the size and shows the press with the tint only — for rows of
  /// a list, which do not sink.
  final bool scales;

  /// Lean towards a finger dragged across the element.
  final bool follow;
  final HitTestBehavior behavior;

  /// The scale an element of [size] sinks to.
  static double pressedScale(Size size) {
    const double minArea = 20.0 * 20.0;
    const double maxArea = 150.0 * 150.0;
    const Curve bezier = Cubic(0, 0, 0, 1);
    final double area = (size.width * size.height).clamp(minArea, maxArea);
    final double t = (area - minArea) / (maxArea - minArea);
    final double areaScale = 0.85 + bezier.transform(t) * (0.97 - 0.85);
    final double shortest = math.max(1, size.shortestSide);
    final double ratio = size.longestSide / shortest;
    double target = areaScale;
    if (ratio > 2) {
      final double u = ((ratio - 2) / (15 - 2)).clamp(0.0, 1.0);
      final double aspectScale = 0.85 + bezier.transform(u) * (1.0 - 0.85);
      target = (areaScale + aspectScale) / 2;
    }
    return target.clamp(0.4, 1.0);
  }

  @override
  State<SoftPressable> createState() => _SoftPressableState();
}

class _SoftPressableState extends State<SoftPressable>
    with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _tint = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _followX = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _followY = AnimationController.unbounded(
    vsync: this,
  );

  static final SpringDescription _jellyPress = softSpring(0.25);
  static final SpringDescription _jellyRelease = softSpring(0.5, bounce: 0.6);
  static final SpringDescription _candyPress = softSpring(0.3);
  static final SpringDescription _candyRelease = softSpring(0.5, bounce: 0.5);
  static final SpringDescription _tintSpring = softSpring(0.3);
  static final SpringDescription _followSpring = softSpring(0.15, bounce: 0.15);
  static final SpringDescription _followRelease = softSpring(
    0.42,
    bounce: 0.65,
  );

  bool _long = false;
  Offset? _downAt;

  @override
  void dispose() {
    _scale.dispose();
    _tint.dispose();
    _followX.dispose();
    _followY.dispose();
    super.dispose();
  }

  bool get _active =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _down(Offset local) {
    if (!_active) return;
    final bool reduce = softReduceMotion(context);
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    double target = 0.95;
    if (box != null && box.hasSize) {
      target = SoftPressable.pressedScale(box.size);
      _long = box.size.longestSide / math.max(1, box.size.shortestSide) > 2;
    }
    _downAt = local;
    if (widget.scales) {
      _scale.springTo(
        target,
        _long ? _candyPress : _jellyPress,
        reduceMotion: reduce,
      );
    }
    if (widget.overlay) _tint.springTo(1, _tintSpring, reduceMotion: reduce);
  }

  void _move(Offset local) {
    final Offset? start = _downAt;
    if (!widget.follow || start == null || softReduceMotion(context)) return;
    double rubber(double d) {
      const double maxDistance = 28;
      const double c = 0.05;
      return d.sign * maxDistance * (1 - 1 / (c * d.abs() / maxDistance + 1));
    }

    final Offset delta = local - start;
    _followX.springTo(rubber(delta.dx), _followSpring);
    _followY.springTo(rubber(delta.dy), _followSpring);
  }

  void _up() {
    final bool reduce = softReduceMotion(context);
    _downAt = null;
    _scale.springTo(
      1,
      _long ? _candyRelease : _jellyRelease,
      reduceMotion: reduce,
    );
    _tint.springTo(0, _tintSpring, reduceMotion: reduce);
    if (widget.follow) {
      _followX.springTo(0, _followRelease, reduceMotion: reduce);
      _followY.springTo(0, _followRelease, reduceMotion: reduce);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.overlay) {
      final Color tint = SoftTheme.of(context).press;
      child = Stack(
        children: <Widget>[
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _tint,
                builder: (BuildContext context, _) {
                  final double t = _tint.value.clamp(0.0, 1.0);
                  if (t == 0) return const SizedBox.shrink();
                  return DecoratedBox(
                    decoration: ShapeDecoration(
                      color: tint.withValues(alpha: tint.a * t),
                      shape: widget.shape ?? const RoundedRectangleBorder(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
    if (widget.scales || widget.follow) {
      child = AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_scale, _followX, _followY]),
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(_followX.value, _followY.value),
          child: Transform.scale(scale: _scale.value, child: child),
        ),
        child: child,
      );
    }
    return Listener(
      onPointerDown: _active
          ? (PointerDownEvent e) => _down(e.localPosition)
          : null,
      onPointerMove: _active
          ? (PointerMoveEvent e) => _move(e.localPosition)
          : null,
      onPointerUp: _active ? (_) => _up() : null,
      onPointerCancel: _active ? (_) => _up() : null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.enabled ? widget.onTap : null,
        onTapCancel: _active ? _up : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: child,
      ),
    );
  }
}
