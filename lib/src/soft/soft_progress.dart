import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// An indeterminate spinner: a round-capped accent arc running round a faint
/// accent ring, one turn a second, its sweep breathing between 60° and 120°.
class SoftSpinner extends StatefulWidget {
  const SoftSpinner({super.key, this.large = false, this.color});

  /// 26 with a 3.33 stroke instead of 18 with 2.67.
  final bool large;

  /// The arc colour; the theme accent by default (the ring is it at 15%).
  final Color? color;

  @override
  State<SoftSpinner> createState() => _SoftSpinnerState();
}

class _SoftSpinnerState extends State<SoftSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (softReduceMotion(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color arc = widget.color ?? theme.accent;
    final double size = widget.large ? 26 : 18;
    return Semantics(
      label: 'Loading',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SpinnerPainter(
            turn: _turn,
            arc: arc,
            ring: arc.withValues(alpha: theme.isDark ? 0.25 : 0.15),
            stroke: widget.large ? 3.33 : 2.67,
          ),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.turn,
    required this.arc,
    required this.ring,
    required this.stroke,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final Color arc;
  final Color ring;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final double p = turn.value * 360;
    final double sweep = (2 - (180 - p).abs() / 180) * 60;
    final double start = p - 30 - 90;
    canvas.drawArc(
      rect,
      start * math.pi / 180,
      sweep * math.pi / 180,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.arc != arc ||
      oldDelegate.ring != ring ||
      oldDelegate.stroke != stroke;
}

/// Determinate circular progress: a round-capped arc from twelve o'clock over
/// a track ring, moving on a slow, critically damped spring.
class SoftCircularProgress extends StatefulWidget {
  const SoftCircularProgress({
    super.key,
    required this.value,
    this.medium = false,
    this.followAccent = false,
  });

  /// 0..1.
  final double value;

  /// 30 with a 3 stroke instead of 40 with 5.
  final bool medium;

  /// Accent arc on an accent-35% track instead of the neutral pair.
  final bool followAccent;

  @override
  State<SoftCircularProgress> createState() => _SoftCircularProgressState();
}

class _SoftCircularProgressState extends State<SoftCircularProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: widget.value.clamp(0.0, 1.0),
  );

  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 50,
    damping: 2 * 7.0710678,
  );

  @override
  void didUpdateWidget(SoftCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value.springTo(
        widget.value.clamp(0.0, 1.0),
        _spring,
        reduceMotion: softReduceMotion(context),
      );
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double size = widget.medium ? 30 : 40;
    return Semantics(
      value: '${(widget.value * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CustomPaint(
            painter: _RingPainter(
              value: _value,
              arc: widget.followAccent ? theme.accentText : theme.labelTertiary,
              track: widget.followAccent
                  ? theme.accent.withValues(alpha: 0.35)
                  : theme.divider,
              stroke: widget.medium ? 3 : 5,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.arc,
    required this.track,
    required this.stroke,
  }) : super(repaint: value);

  final Animation<double> value;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    final double v = value.value.clamp(0.0001, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * v,
      false,
      paint..color = arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.arc != arc ||
      oldDelegate.track != track ||
      oldDelegate.stroke != stroke;
}

/// A horizontal progress bar: a pill track with the accent fill clipped to it.
class SoftLinearProgress extends StatelessWidget {
  const SoftLinearProgress({super.key, required this.value, this.height = 4});

  /// 0..1.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double v = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: theme.divider),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: theme.accent,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
