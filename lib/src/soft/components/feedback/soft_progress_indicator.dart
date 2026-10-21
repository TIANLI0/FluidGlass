import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';

/// The progress indicator defaults.
abstract final class SoftProgressIndicatorDefaults {
  /// The linear bar's height.
  static const double linearHeight = 4;

  /// The circular ring's stroke and diameter.
  static const double circularStrokeWidth = 3;
  static const double circularSize = 30;

  /// The large circular tier.
  static const double largeCircularStrokeWidth = 5;
  static const double largeCircularSize = 40;

  /// The accent spinner's stroke and box.
  static const double infiniteStrokeWidth = 2.67;
  static const double infiniteSize = 18;

  /// The large accent spinner tier.
  static const double largeInfiniteStrokeWidth = 3.33;
  static const double largeInfiniteSize = 26;

  /// The rotating spinner's box, ring diameter and stroke.
  static const double rotatingSize = 26;
  static const double rotatingRingDiameter = 24.14;
  static const double rotatingStrokeWidth = 1.857;

  /// The small rotating spinner tier.
  static const double smallRotatingSize = 16;
  static const double smallRotatingRingDiameter = 12.68;
  static const double smallRotatingStrokeWidth = 1.811;

  /// The largest rotating spinner the design supports.
  static const double maxRotatingSize = 40;

  /// One sweep of the indeterminate linear bar.
  static const Duration linearCycle = Duration(milliseconds: 1250);

  /// One turn of the circular loading arc.
  static const Duration circularCycle = Duration(milliseconds: 1000);

  /// One loop of the rotating spinner: 76 frames at 60 fps.
  static const Duration rotatingCycle = Duration(milliseconds: 1250);
}

/// A thin capsule bar: the theme's `primary` filling a `dividerLine` track
/// to [progress], or, when [progress] is null, a 45 % segment sweeping
/// across it every 1.25 s.
class SoftLinearProgressIndicator extends StatefulWidget {
  const SoftLinearProgressIndicator({
    super.key,
    this.progress,
    this.height = SoftProgressIndicatorDefaults.linearHeight,
    this.color,
    this.trackColor,
    this.semanticsLabel,
  });

  /// 0–1, or null for indeterminate.
  final double? progress;
  final double height;

  /// `primary` by default.
  final Color? color;

  /// `dividerLine` by default.
  final Color? trackColor;
  final String? semanticsLabel;

  @override
  State<SoftLinearProgressIndicator> createState() =>
      _SoftLinearProgressIndicatorState();
}

class _SoftLinearProgressIndicatorState
    extends State<SoftLinearProgressIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _cycle;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoftLinearProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.progress == null) {
      _cycle ??= AnimationController(
        vsync: this,
        duration: SoftProgressIndicatorDefaults.linearCycle,
      )..repeat();
    } else {
      _cycle?.dispose();
      _cycle = null;
    }
  }

  @override
  void dispose() {
    _cycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.colorsOf(context);
    final double? progress = widget.progress?.clamp(0.0, 1.0);
    final Widget bar = CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _LinearPainter(
        progress: progress,
        cycle: _cycle,
        color: widget.color ?? colors.primary,
        track: widget.trackColor ?? colors.dividerLine,
      ),
    );
    return Semantics(
      label: widget.semanticsLabel,
      value: progress == null ? null : '${(progress * 100).round()}%',
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: progress == null ? RepaintBoundary(child: bar) : bar,
      ),
    );
  }
}

class _LinearPainter extends CustomPainter {
  _LinearPainter({
    required this.progress,
    required this.cycle,
    required this.color,
    required this.track,
  }) : super(repaint: cycle);

  final double? progress;
  final Animation<double>? cycle;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Radius radius = Radius.circular(size.height / 2);
    final RRect capsule = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final Paint paint = Paint();
    final double? p = progress;
    if (p != null) {
      // The fill is a square-ended rectangle cut by the capsule track, so
      // only the track's own ends round it.
      canvas.save();
      canvas.clipRRect(capsule);
      canvas.drawRect(Offset.zero & size, paint..color = track);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * p, size.height),
        paint..color = color,
      );
      canvas.restore();
      return;
    }
    canvas.drawRRect(capsule, paint..color = track);
    paint.color = color;
    final double t = cycle?.value ?? 0;
    const double segment = 0.45;
    // The reference stacks three segments one full cycle apart, which all
    // land on the same spot.
    for (int i = 0; i < 3; i++) {
      final double position = ((t - i) % 1 + 1) % 1;
      if (position < 1 - segment) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * position,
              0,
              size.width * segment,
              size.height,
            ),
            radius,
          ),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * position,
              0,
              size.width * (1 - position),
              size.height,
            ),
            radius,
          ),
          paint,
        );
        final double remaining = position + segment - 1;
        if (remaining > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, size.width * remaining, size.height),
              radius,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LinearPainter old) =>
      old.progress != progress ||
      old.cycle != cycle ||
      old.color != color ||
      old.track != track;
}

/// The state of a [SoftCircularProgressIndicator].
enum SoftCircularProgressState {
  /// An arc spinning once a second while its sweep pulses 60°–120°–60°.
  loading,

  /// The arc swept clockwise from 12 o'clock to the progress.
  determinate,

  /// A filled error disc with an exclamation mark.
  error,

  /// A full ring with a pause mark.
  paused,
}

/// A ring: the progress arc (round caps) over a `dividerLine` track, in the
/// theme's `onSurfaceContainerHigh` by default.
///
/// [state] defaults to [SoftCircularProgressState.loading] when [progress]
/// is null and [SoftCircularProgressState.determinate] otherwise.
class SoftCircularProgressIndicator extends StatefulWidget {
  const SoftCircularProgressIndicator({
    super.key,
    this.progress,
    this.state,
    this.size = SoftProgressIndicatorDefaults.circularSize,
    this.strokeWidth = SoftProgressIndicatorDefaults.circularStrokeWidth,
    this.color,
    this.trackColor,
    this.errorColor,
    this.onErrorColor,
    this.semanticsLabel,
  });

  /// 0–1, or null for loading.
  final double? progress;
  final SoftCircularProgressState? state;
  final double size;
  final double strokeWidth;

  /// `onSurfaceContainerHigh` by default.
  final Color? color;

  /// `dividerLine` by default.
  final Color? trackColor;

  /// `error` by default.
  final Color? errorColor;

  /// `onError` by default.
  final Color? onErrorColor;
  final String? semanticsLabel;

  SoftCircularProgressState get resolvedState =>
      state ??
      (progress == null
          ? SoftCircularProgressState.loading
          : SoftCircularProgressState.determinate);

  @override
  State<SoftCircularProgressIndicator> createState() =>
      _SoftCircularProgressIndicatorState();
}

class _SoftCircularProgressIndicatorState
    extends State<SoftCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  AnimationController? _cycle;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoftCircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.resolvedState == SoftCircularProgressState.loading) {
      _cycle ??= AnimationController(
        vsync: this,
        duration: SoftProgressIndicatorDefaults.circularCycle,
      )..repeat();
    } else {
      _cycle?.dispose();
      _cycle = null;
    }
  }

  @override
  void dispose() {
    _cycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftColors colors = SoftTheme.colorsOf(context);
    final SoftCircularProgressState state = widget.resolvedState;
    final double progress = (widget.progress ?? 0).clamp(0.0, 1.0);
    final Widget ring = CustomPaint(
      size: Size.square(widget.size),
      painter: _CircularPainter(
        state: state,
        progress: progress,
        cycle: _cycle,
        strokeWidth: widget.strokeWidth,
        color: widget.color ?? colors.onSurfaceContainerHigh,
        track: widget.trackColor ?? colors.dividerLine,
        error: widget.errorColor ?? colors.error,
        onError: widget.onErrorColor ?? colors.onError,
      ),
    );
    return Semantics(
      label: widget.semanticsLabel,
      value: state == SoftCircularProgressState.determinate
          ? '${(progress * 100).round()}%'
          : null,
      child: state == SoftCircularProgressState.loading
          ? RepaintBoundary(child: ring)
          : ring,
    );
  }
}

class _CircularPainter extends CustomPainter {
  _CircularPainter({
    required this.state,
    required this.progress,
    required this.cycle,
    required this.strokeWidth,
    required this.color,
    required this.track,
    required this.error,
    required this.onError,
  }) : super(repaint: cycle);

  final SoftCircularProgressState state;
  final double progress;
  final Animation<double>? cycle;
  final double strokeWidth;
  final Color color;
  final Color track;
  final Color error;
  final Color onError;

  static const double _degree = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double diameter = size.shortestSide;
    final Offset center = size.center(Offset.zero);
    final double radius = (diameter - strokeWidth) / 2;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    switch (state) {
      case SoftCircularProgressState.error:
        canvas.drawCircle(center, diameter / 2, Paint()..color = error);
        _errorGlyph(canvas, center, diameter);
      case SoftCircularProgressState.paused:
        canvas.drawCircle(center, radius, ring..color = track);
        canvas.drawCircle(center, radius, ring..color = color);
        _pauseGlyph(canvas, center, diameter);
      case SoftCircularProgressState.loading:
      case SoftCircularProgressState.determinate:
        final double start;
        final double sweep;
        if (state == SoftCircularProgressState.loading) {
          final double turn = (cycle?.value ?? 0) * 360;
          sweep = (2 - (180 - turn).abs() / 180) * 60;
          start = turn - 30 - 90;
        } else {
          start = -90;
          sweep = math.max(1e-4, progress * 360);
        }
        // The arc replaces the track under it instead of stacking on it:
        // both colours are translucent.
        canvas.saveLayer(Offset.zero & size, Paint());
        canvas.drawCircle(center, radius, ring..color = track);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start * _degree,
          sweep * _degree,
          false,
          ring
            ..color = color
            ..strokeCap = StrokeCap.round
            ..blendMode = BlendMode.src,
        );
        canvas.restore();
    }
  }

  void _errorGlyph(Canvas canvas, Offset center, double diameter) {
    final Paint paint = Paint()..color = onError;
    final double barWidth = diameter * 0.10;
    final double barHeight = diameter * 0.32;
    final double barTop = center.dy - diameter * 0.20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - barWidth / 2, barTop, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      ),
      paint,
    );
    final double dot = barWidth * 0.65;
    canvas.drawCircle(
      Offset(center.dx, barTop + barHeight + dot * 1.8),
      dot,
      paint,
    );
  }

  void _pauseGlyph(Canvas canvas, Offset center, double diameter) {
    final Paint paint = Paint()..color = color;
    final double barWidth = diameter * 0.10;
    final double barHeight = diameter * 0.34;
    final double gap = diameter * 0.10;
    final double top = center.dy - barHeight / 2;
    final Radius r = Radius.circular(barWidth / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - gap / 2 - barWidth, top, barWidth, barHeight),
        r,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + gap / 2, top, barWidth, barHeight),
        r,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircularPainter old) =>
      old.state != state ||
      old.progress != progress ||
      old.cycle != cycle ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.track != track ||
      old.error != error ||
      old.onError != onError;
}

/// The bare spinner: a single flat-capped arc with no track whose sweep
/// pulses 274°–50°–274° while it spins, looping every 1.25 s. In the theme's
/// `onSurfaceContainer` by default.
class SoftRotatingProgressIndicator extends StatefulWidget {
  const SoftRotatingProgressIndicator({
    super.key,
    this.color,
    this.size = SoftProgressIndicatorDefaults.rotatingSize,
    this.ringDiameter = SoftProgressIndicatorDefaults.rotatingRingDiameter,
    this.strokeWidth = SoftProgressIndicatorDefaults.rotatingStrokeWidth,
    this.semanticsLabel,
  });

  /// The small tier: 16 box, 12.68 ring, 1.811 stroke.
  const SoftRotatingProgressIndicator.small({
    super.key,
    this.color,
    this.semanticsLabel,
  }) : size = SoftProgressIndicatorDefaults.smallRotatingSize,
       ringDiameter = SoftProgressIndicatorDefaults.smallRotatingRingDiameter,
       strokeWidth = SoftProgressIndicatorDefaults.smallRotatingStrokeWidth;

  final Color? color;

  /// The square box.
  final double size;

  /// The diameter of the stroke's centre line, centred in the box.
  final double ringDiameter;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  State<SoftRotatingProgressIndicator> createState() =>
      _SoftRotatingProgressIndicatorState();
}

class _SoftRotatingProgressIndicatorState
    extends State<SoftRotatingProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: SoftProgressIndicatorDefaults.rotatingCycle,
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _RotatingPainter(
            cycle: _cycle,
            color:
                widget.color ?? SoftTheme.colorsOf(context).onSurfaceContainer,
            ringDiameter: widget.ringDiameter,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

/// The accent spinner for waits inside dialogs and inline content: the
/// rotating spinner in the theme's `primary`, 18 box, 2.67 stroke.
class SoftInfiniteProgressIndicator extends StatelessWidget {
  const SoftInfiniteProgressIndicator({
    super.key,
    this.color,
    this.size = SoftProgressIndicatorDefaults.infiniteSize,
    this.strokeWidth = SoftProgressIndicatorDefaults.infiniteStrokeWidth,
    this.semanticsLabel,
  });

  final Color? color;
  final double size;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SoftRotatingProgressIndicator(
      color: color ?? SoftTheme.colorsOf(context).primary,
      size: size,
      ringDiameter: size - strokeWidth,
      strokeWidth: strokeWidth,
      semanticsLabel: semanticsLabel,
    );
  }
}

class _RotatingPainter extends CustomPainter {
  _RotatingPainter({
    required this.cycle,
    required this.color,
    required this.ringDiameter,
    required this.strokeWidth,
  }) : super(repaint: cycle);

  final Animation<double> cycle;
  final Color color;
  final double ringDiameter;
  final double strokeWidth;

  /// The keyframe where the arc is shortest (37 of 75).
  static const double _breakpoint = 37 / 75;
  static const Cubic _standard = Cubic(0.167, 0.167, 0.833, 0.833);
  static const Cubic _trimGrow = Cubic(0.167, 0.167, 0.833, 1);
  static const Cubic _trimShrink = Cubic(0.167, 0, 0.833, 0.833);
  static const double _trimMin = 24 / 100 * 360;
  static const double _trimMax = 86 / 100 * 360;
  static const double _offsetStart = -90;
  static const double _offsetMid = -41;
  static const double _offsetEnd = 270;
  static const double _degree = math.pi / 180;

  /// The trim start in degrees: 24 % → 86 % → 24 % with the end pinned at
  /// 100 %.
  static double trimStart(double t) {
    if (t < _breakpoint) {
      return lerpDouble(
        _trimMin,
        _trimMax,
        _trimGrow.transform(t / _breakpoint),
      )!;
    }
    return lerpDouble(
      _trimMax,
      _trimMin,
      _trimShrink.transform((t - _breakpoint) / (1 - _breakpoint)),
    )!;
  }

  /// The arc's start angle in degrees from 3 o'clock: the layer's turn, the
  /// trim offset (−90 → −41 → 270) and the trim start.
  static double startAngle(double t, double trim) {
    final double offset = t < _breakpoint
        ? lerpDouble(
            _offsetStart,
            _offsetMid,
            _standard.transform(t / _breakpoint),
          )!
        : lerpDouble(
            _offsetMid,
            _offsetEnd,
            _standard.transform((t - _breakpoint) / (1 - _breakpoint)),
          )!;
    return -90 + 360 * t + offset + trim;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = cycle.value;
    final double trim = trimStart(t);
    final Offset center = size.center(Offset.zero);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringDiameter / 2),
      startAngle(t, trim) * _degree,
      (360 - trim) * _degree,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_RotatingPainter old) =>
      old.cycle != cycle ||
      old.color != color ||
      old.ringDiameter != ringDiameter ||
      old.strokeWidth != strokeWidth;
}
