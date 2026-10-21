import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';
import 'soft_selection_frame.dart';

/// The three states of a [SoftCheckbox].
enum SoftCheckboxState {
  off,
  on,

  /// Partly checked: a bar instead of a tick.
  indeterminate;

  /// [on] when [checked], otherwise [off].
  static SoftCheckboxState of(bool checked) => checked ? on : off;
}

/// The colours of a [SoftCheckbox].
@immutable
class SoftCheckboxColors {
  const SoftCheckboxColors({
    required this.checkedForeground,
    required this.disabledCheckedForeground,
    required this.checkedBackground,
    required this.uncheckedBackground,
    required this.disabledCheckedBackground,
    required this.disabledUncheckedBackground,
  });

  /// The reference roles: `onPrimary` marks on a `primary` fill, a
  /// `secondary` ring; `disabledOnPrimary`, `disabledPrimary` and
  /// `disabledSecondary` when disabled.
  factory SoftCheckboxColors.of(SoftColors c) => SoftCheckboxColors(
    checkedForeground: c.onPrimary,
    disabledCheckedForeground: c.disabledOnPrimary,
    checkedBackground: c.primary,
    uncheckedBackground: c.secondary,
    disabledCheckedBackground: c.disabledPrimary,
    disabledUncheckedBackground: c.disabledSecondary,
  );

  /// The tick and the bar.
  final Color checkedForeground;
  final Color disabledCheckedForeground;

  /// The checked fill.
  final Color checkedBackground;

  /// The unchecked ring.
  final Color uncheckedBackground;
  final Color disabledCheckedBackground;
  final Color disabledUncheckedBackground;

  Color mark(bool enabled) =>
      enabled ? checkedForeground : disabledCheckedForeground;

  Color fill(bool enabled) =>
      enabled ? checkedBackground : disabledCheckedBackground;

  Color ring(bool enabled) =>
      enabled ? uncheckedBackground : disabledUncheckedBackground;

  @override
  bool operator ==(Object other) =>
      other is SoftCheckboxColors &&
      other.checkedForeground == checkedForeground &&
      other.disabledCheckedForeground == disabledCheckedForeground &&
      other.checkedBackground == checkedBackground &&
      other.uncheckedBackground == uncheckedBackground &&
      other.disabledCheckedBackground == disabledCheckedBackground &&
      other.disabledUncheckedBackground == disabledUncheckedBackground;

  @override
  int get hashCode => Object.hash(
    checkedForeground,
    disabledCheckedForeground,
    checkedBackground,
    uncheckedBackground,
    disabledCheckedBackground,
    disabledUncheckedBackground,
  );
}

/// The checkbox geometry and timing.
abstract final class SoftCheckboxDefaults {
  /// The square the checkbox lays out in.
  static const double size = 24;

  /// The easing of every transition.
  static const Cubic ease = Cubic(0.3, 0, 0.1, 1);

  /// The longest transition: the tick drawing and the fill fading out.
  static const Duration duration = Duration(milliseconds: 300);

  /// The pop every state change plays: 1 → 1.08 → 1, 150 ms each way.
  static const double popScale = 1.08;
}

/// A checkbox with three states.
///
/// Unchecked is a 1.3 ring (16.4 square, corner 3.2); checked is an 18 square
/// (corner 4) with a tick that draws itself in over 300 ms while the fill
/// fades in over 150 ms; [SoftCheckboxState.indeterminate] reveals a 10 × 1.6
/// bar from the left. Every change pops the drawing 1 → 1.08 → 1, and a
/// press sinks it to 0.85.
///
/// [onTap] is called on a tap; the caller updates [state]. Without it the
/// checkbox is not tappable (a list row usually handles the tap instead).
class SoftCheckbox extends StatefulWidget {
  const SoftCheckbox({
    super.key,
    required this.state,
    required this.onTap,
    this.enabled = true,
    this.colors,
  });

  /// A two-state checkbox.
  SoftCheckbox.value({
    super.key,
    required bool checked,
    required this.onTap,
    this.enabled = true,
    this.colors,
  }) : state = SoftCheckboxState.of(checked);

  final SoftCheckboxState state;
  final VoidCallback? onTap;
  final bool enabled;

  /// Defaults to [SoftCheckboxColors.of] the theme's colours.
  final SoftCheckboxColors? colors;

  @override
  State<SoftCheckbox> createState() => _SoftCheckboxState();
}

class _SoftCheckboxState extends State<SoftCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: SoftCheckboxDefaults.duration,
    value: 1,
  );
  late final _CheckboxTimeline _timeline = _CheckboxTimeline(
    _clock,
    widget.state,
  );

  @override
  void didUpdateWidget(SoftCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _timeline.retarget(widget.state);
      if (softReduceMotion(context)) {
        _clock.value = 1;
      } else {
        _clock.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _handleTap() {
    final VoidCallback? onTap = widget.onTap;
    if (onTap == null) return;
    onTap();
    playSoftSelectionHaptic(switch (widget.state) {
      SoftCheckboxState.off => SoftSelectionHaptic.toggleOn,
      SoftCheckboxState.on => SoftSelectionHaptic.toggleOff,
      SoftCheckboxState.indeterminate => SoftSelectionHaptic.segmentTick,
    });
  }

  @override
  Widget build(BuildContext context) {
    final SoftCheckboxColors colors =
        widget.colors ?? SoftCheckboxColors.of(SoftTheme.colorsOf(context));
    final bool enabled = widget.enabled;
    final bool tappable = enabled && widget.onTap != null;
    return SoftMinTouchTarget(
      child: Semantics(
        container: true,
        enabled: enabled,
        checked: widget.state == SoftCheckboxState.on,
        mixed: widget.state == SoftCheckboxState.indeterminate,
        onTap: tappable ? _handleTap : null,
        child: SoftSelectionFrame(
          enabled: enabled,
          onTap: tappable ? _handleTap : null,
          builder: (BuildContext context, ValueListenable<double> sink) =>
              CustomPaint(
                painter: _CheckboxPainter(
                  timeline: _timeline,
                  sink: sink,
                  ring: colors.ring(enabled),
                  fill: colors.fill(enabled),
                  mark: colors.mark(enabled),
                ),
              ),
        ),
      ),
    );
  }
}

/// The value of each layer over one 300 ms transition, as the reference's
/// animated vector timelines define them.
class _CheckboxTimeline {
  _CheckboxTimeline(this.clock, SoftCheckboxState state)
    : _from = state,
      _to = state,
      _fill0 = state == SoftCheckboxState.off ? 0 : 1,
      _check0 = state == SoftCheckboxState.on ? 1 : 0,
      _bar0 = state == SoftCheckboxState.indeterminate ? 1 : 0;

  final AnimationController clock;
  SoftCheckboxState _from;
  SoftCheckboxState _to;
  double _fill0;
  double _check0;
  double _bar0;
  bool _pops = false;

  static const Cubic _e = SoftCheckboxDefaults.ease;

  double get _ms =>
      clock.value * SoftCheckboxDefaults.duration.inMilliseconds.toDouble();

  /// Starts a transition to [state] from wherever the layers are now.
  void retarget(SoftCheckboxState state) {
    _fill0 = fill;
    _check0 = check;
    _bar0 = bar;
    _from = _to;
    _to = state;
    _pops = true;
  }

  static double _tween(double from, double to, double ms, double duration) {
    if (ms >= duration) return to;
    return ui.lerpDouble(from, to, _e.transform(ms / duration))!;
  }

  /// Linear to [mid] at [at] ms, then eased to [to] by 300 ms.
  static double _keyframe(
    double from,
    double mid,
    double at,
    double to,
    double ms,
  ) {
    if (ms <= at) return ui.lerpDouble(from, mid, ms / at)!;
    return _tween(mid, to, ms - at, 300 - at);
  }

  double get fill {
    final double ms = _ms;
    return _to != SoftCheckboxState.off
        ? _tween(_fill0, 1, ms, 150)
        // Holds full for 150 ms, then fades out over the next 150.
        : _keyframe(_fill0, 1, 150, 0, ms);
  }

  double get check =>
      _tween(_check0, _to == SoftCheckboxState.on ? 1 : 0, _ms, 300);

  double get bar {
    final double ms = _ms;
    final double target = _to == SoftCheckboxState.indeterminate ? 1 : 0;
    if (_to == SoftCheckboxState.indeterminate &&
        _from == SoftCheckboxState.on) {
      // Waits for the tick to clear before the bar grows.
      return _keyframe(_bar0, 0, 100, target, ms);
    }
    if (_to == SoftCheckboxState.on) return _tween(_bar0, target, ms, 200);
    return _tween(_bar0, target, ms, 300);
  }

  double get pop {
    if (!_pops) return 1;
    final double ms = _ms;
    const double peak = SoftCheckboxDefaults.popScale;
    return ms < 150 ? _tween(1, peak, ms, 150) : _tween(peak, 1, ms - 150, 150);
  }
}

class _CheckboxPainter extends CustomPainter {
  _CheckboxPainter({
    required this.timeline,
    required this.sink,
    required this.ring,
    required this.fill,
    required this.mark,
  }) : super(repaint: Listenable.merge(<Listenable>[timeline.clock, sink]));

  final _CheckboxTimeline timeline;
  final ValueListenable<double> sink;
  final Color ring;
  final Color fill;
  final Color mark;

  // The geometry, in a 24 viewport.
  static const double _viewport = 24;
  static const Offset _checkStart = Offset(7.4835, 11.8935);
  static const Offset _checkMiddle = Offset(10.831, 15.3035);
  static const Offset _checkEnd = Offset(17.5165, 8.4925);

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.shortestSide;
    final double u = d / _viewport;
    final Offset centre = size.center(Offset.zero);
    final double scale = sink.value * timeline.pop;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(scale)
      ..translate(-d / 2, -d / 2);

    final double fillFraction = timeline.fill.clamp(0.0, 1.0);
    if (fillFraction < 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3.8 * u, 3.8 * u, 16.4 * u, 16.4 * u),
          Radius.circular(3.2 * u),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 * u
          ..color = ring,
      );
    }
    if (fillFraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3 * u, 3 * u, 18 * u, 18 * u),
          Radius.circular(4 * u),
        ),
        Paint()..color = fill.withValues(alpha: fill.a * fillFraction),
      );
    }

    final double check = timeline.check.clamp(0.0, 1.0);
    if (check > 0) {
      final Offset a = _checkStart * u;
      final Offset b = _checkMiddle * u;
      final Offset c = _checkEnd * u;
      final double first = (b - a).distance;
      final double second = (c - b).distance;
      final double end = (first + second) * check;
      final Path path = Path()..moveTo(a.dx, a.dy);
      if (end <= first) {
        final Offset p = Offset.lerp(a, b, end / first)!;
        path.lineTo(p.dx, p.dy);
      } else {
        final Offset p = Offset.lerp(
          b,
          c,
          ((end - first) / second).clamp(0.0, 1.0),
        )!;
        path
          ..lineTo(b.dx, b.dy)
          ..lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.38 * u
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.round
          ..color = mark,
      );
    }

    final double bar = timeline.bar.clamp(0.0, 1.0);
    if (bar > 0) {
      canvas.drawRect(
        Rect.fromLTWH(7 * u, (d - 1.6 * u) / 2, 10 * u * bar, 1.6 * u),
        Paint()..color = mark,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) =>
      old.timeline != timeline ||
      old.sink != sink ||
      old.ring != ring ||
      old.fill != fill ||
      old.mark != mark;
}
