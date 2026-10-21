import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';
import 'soft_dialog.dart';

/// The loading-dialog defaults.
abstract final class SoftLoadingDialogDefaults {
  /// The card width.
  static const double cardWidth = 152;

  /// The card's minimum height.
  static const double cardMinHeight = 120;

  /// The card's corners, smaller than a dialog panel's.
  static const double cornerRadius = 9;

  /// The spinner's view box.
  static const double spinnerSize = 36;

  /// The spinner's stroke.
  static const double spinnerStrokeWidth = 2.67;

  /// The gap above the spinner when a message follows it.
  static const double spinnerMarginTop = 28;

  /// The gap between the spinner and the message.
  static const double spinnerMarginBottom = 12;

  /// The message's side margins.
  static const double textMarginHorizontal = 16;

  /// The gap below the message.
  static const double textMarginBottom = 28;

  /// One spinner cycle.
  static const Duration spinnerCycle = Duration(milliseconds: 1250);

  /// The message colour: `onBackground`.
  static Color textColor(SoftColors colors) => colors.onBackground;

  /// The spinner colour: `onBackground`.
  static Color spinnerColor(SoftColors colors) => colors.onBackground;
}

/// The progress-dialog defaults.
abstract final class SoftProgressDialogDefaults {
  /// The card width, the loading card's.
  static const double cardWidth = SoftLoadingDialogDefaults.cardWidth;

  /// The card's minimum height, the loading card's.
  static const double cardMinHeight = SoftLoadingDialogDefaults.cardMinHeight;

  /// The card's corners, the loading card's.
  static const double cornerRadius = SoftLoadingDialogDefaults.cornerRadius;

  /// The card's side padding around the bar.
  static const double contentHorizontalPadding = 16;

  /// The bar's height.
  static const double barHeight = 4;

  /// The gap between the bar and the message.
  static const double textMarginTop = 12;

  /// One indeterminate sweep.
  static const Duration indeterminateCycle = Duration(milliseconds: 1250);

  /// The width of the indeterminate segment, as a fraction of the bar.
  static const double indeterminateSegment = 0.45;

  /// The message colour: `onBackground`.
  static Color textColor(SoftColors colors) => colors.onBackground;

  /// The bar's fill: `primary`.
  static Color barColor(SoftColors colors) => colors.primary;

  /// The bar's track: `dividerLine`.
  static Color trackColor(SoftColors colors) => colors.dividerLine;
}

/// Shows a small centred card with a rotating spinner and an optional
/// [text] below it.
///
/// It is not dismissible by default: pop it with `Navigator.pop` when the
/// work is done. It enters and leaves with the centred dialog transitions.
Future<void> showSoftLoadingDialog({
  required BuildContext context,
  String? text,
  Color? textColor,
  Color? spinnerColor,
  Color? backgroundColor,
  bool dismissible = false,
  bool enableWindowDim = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  VoidCallback? onDismissFinished,
}) {
  return pushSoftDialogRoute<void>(
    context,
    SoftDialogRoute<void>(
      backgroundColor: backgroundColor,
      dismissible: dismissible,
      enableWindowDim: enableWindowDim,
      largeScreen: true,
      cornerRadius: SoftLoadingDialogDefaults.cornerRadius,
      insideMargin: Size.zero,
      fillWidth: false,
      barrierLabel: barrierLabel,
      settings: routeSettings,
      builder: (BuildContext context) => SoftLoadingDialogCard(
        text: text,
        textColor: textColor,
        spinnerColor: spinnerColor,
      ),
    ),
    useRootNavigator: useRootNavigator,
    onDismissFinished: onDismissFinished,
  );
}

/// Shows a small centred card with a horizontal progress bar and an
/// optional message below it.
///
/// The bar follows [progress]: a fraction from 0 to 1, or null for an
/// indeterminate sweep. The message is [text], or [textBuilder]'s answer
/// for the current progress when given. It is not dismissible by default:
/// pop it with `Navigator.pop` when the work is done.
Future<void> showSoftProgressDialog({
  required BuildContext context,
  required ValueListenable<double?> progress,
  String? text,
  String? Function(double? progress)? textBuilder,
  Color? textColor,
  Color? barColor,
  Color? trackColor,
  Color? backgroundColor,
  bool dismissible = false,
  bool enableWindowDim = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  VoidCallback? onDismissFinished,
}) {
  return pushSoftDialogRoute<void>(
    context,
    SoftDialogRoute<void>(
      backgroundColor: backgroundColor,
      dismissible: dismissible,
      enableWindowDim: enableWindowDim,
      largeScreen: true,
      cornerRadius: SoftProgressDialogDefaults.cornerRadius,
      insideMargin: Size.zero,
      fillWidth: false,
      barrierLabel: barrierLabel,
      settings: routeSettings,
      builder: (BuildContext context) => ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (BuildContext context, double? value, Widget? _) =>
            SoftProgressDialogCard(
              progress: value,
              text: textBuilder == null ? text : textBuilder(value),
              textColor: textColor,
              barColor: barColor,
              trackColor: trackColor,
            ),
      ),
    ),
    useRootNavigator: useRootNavigator,
    onDismissFinished: onDismissFinished,
  );
}

/// The loading dialog's content: a 152-wide card (at least 120 tall) with a
/// 36 spinner, and [text] below it when given.
class SoftLoadingDialogCard extends StatelessWidget {
  const SoftLoadingDialogCard({
    super.key,
    this.text,
    this.textColor,
    this.spinnerColor,
  });

  final String? text;
  final Color? textColor;
  final Color? spinnerColor;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color spinner =
        spinnerColor ?? SoftLoadingDialogDefaults.spinnerColor(theme.colors);
    final String? message = text;
    return SizedBox(
      width: SoftLoadingDialogDefaults.cardWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SoftLoadingDialogDefaults.cardMinHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (message == null)
              SoftDialogSpinner(color: spinner)
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  top: SoftLoadingDialogDefaults.spinnerMarginTop,
                  bottom: SoftLoadingDialogDefaults.spinnerMarginBottom,
                ),
                child: SoftDialogSpinner(color: spinner),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SoftLoadingDialogDefaults.textMarginHorizontal,
                  0,
                  SoftLoadingDialogDefaults.textMarginHorizontal,
                  SoftLoadingDialogDefaults.textMarginBottom,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textStyles.body2.copyWith(
                    color:
                        textColor ??
                        SoftLoadingDialogDefaults.textColor(theme.colors),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The progress dialog's content: a 152-wide card (at least 120 tall) with
/// a 4-high bar and [text] below it when given.
class SoftProgressDialogCard extends StatelessWidget {
  const SoftProgressDialogCard({
    super.key,
    this.progress,
    this.text,
    this.textColor,
    this.barColor,
    this.trackColor,
  });

  /// 0 to 1, or null for an indeterminate sweep.
  final double? progress;
  final String? text;
  final Color? textColor;
  final Color? barColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final String? message = text;
    return SizedBox(
      width: SoftProgressDialogDefaults.cardWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SoftProgressDialogDefaults.cardMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SoftProgressDialogDefaults.contentHorizontalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SoftDialogProgressBar(
                progress: progress,
                color:
                    barColor ??
                    SoftProgressDialogDefaults.barColor(theme.colors),
                trackColor:
                    trackColor ??
                    SoftProgressDialogDefaults.trackColor(theme.colors),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: SoftProgressDialogDefaults.textMarginTop,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textStyles.body2.copyWith(
                      color:
                          textColor ??
                          SoftProgressDialogDefaults.textColor(theme.colors),
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

/// The loading dialog's spinner: one bare arc with flat caps whose sweep
/// pulses (274° → 50° → 274°) while it spins two turns per 1.25 s cycle.
///
/// It spins for as long as it is shown, inside its own repaint boundary.
class SoftDialogSpinner extends StatefulWidget {
  const SoftDialogSpinner({
    super.key,
    required this.color,
    this.size = SoftLoadingDialogDefaults.spinnerSize,
    this.strokeWidth = SoftLoadingDialogDefaults.spinnerStrokeWidth,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  State<SoftDialogSpinner> createState() => _SoftDialogSpinnerState();
}

class _SoftDialogSpinnerState extends State<SoftDialogSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: SoftLoadingDialogDefaults.spinnerCycle,
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerPainter(
          cycle: _cycle,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.cycle,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: cycle);

  final Animation<double> cycle;
  final Color color;
  final double strokeWidth;

  /// The time of the shortest arc (keyframe 37 of 75).
  static const double _breakpoint = 37 / 75;
  static const Cubic _standard = Cubic(0.167, 0.167, 0.833, 0.833);
  static const Cubic _trimGrow = Cubic(0.167, 0.167, 0.833, 1);
  static const Cubic _trimShrink = Cubic(0.167, 0, 0.833, 0.833);
  static const double _trimMin = 24 / 100 * 360;
  static const double _trimMax = 86 / 100 * 360;
  static const double _offsetStart = -90;
  static const double _offsetMid = -41;
  static const double _offsetEnd = 270;

  static double _degrees(double t) => t * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = cycle.value;
    final bool first = t < _breakpoint;
    final double local = first
        ? t / _breakpoint
        : (t - _breakpoint) / (1 - _breakpoint);
    // The arc's trailing edge is pinned; its leading edge (trim start)
    // swings, and the trim offset spins the whole arc.
    final double trim = first
        ? lerpDouble(_trimMin, _trimMax, _trimGrow.transform(local))!
        : lerpDouble(_trimMax, _trimMin, _trimShrink.transform(local))!;
    final double offset = first
        ? lerpDouble(_offsetStart, _offsetMid, _standard.transform(local))!
        : lerpDouble(_offsetMid, _offsetEnd, _standard.transform(local))!;
    final double start = -90 + 360 * t + offset + trim;
    final double diameter = size.shortestSide - strokeWidth;
    final Rect rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: diameter,
      height: diameter,
    );
    canvas.drawArc(
      rect,
      _degrees(start),
      _degrees(360 - trim),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.cycle != cycle ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// The progress dialog's bar: a capsule track with a fill clipped to it, or
/// — when [progress] is null — a 45 % capsule sweeping across and wrapping
/// round every 1.25 s, inside its own repaint boundary.
class SoftDialogProgressBar extends StatefulWidget {
  const SoftDialogProgressBar({
    super.key,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.height = SoftProgressDialogDefaults.barHeight,
  });

  final double? progress;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  State<SoftDialogProgressBar> createState() => _SoftDialogProgressBarState();
}

class _SoftDialogProgressBarState extends State<SoftDialogProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: SoftProgressDialogDefaults.indeterminateCycle,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoftDialogProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.progress == null) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else if (_sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? value = widget.progress?.clamp(0.0, 1.0);
    final Widget bar = CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _BarPainter(
        progress: value,
        sweep: _sweep,
        color: widget.color,
        trackColor: widget.trackColor,
      ),
    );
    if (value == null) return RepaintBoundary(child: bar);
    return Semantics(value: '${(value * 100).round()}%', child: bar);
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.progress,
    required this.sweep,
    required this.color,
    required this.trackColor,
  }) : super(repaint: progress == null ? sweep : null);

  final double? progress;
  final Animation<double> sweep;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Radius radius = Radius.circular(size.height / 2);
    final Paint fill = Paint()..color = color;
    final double? value = progress;
    if (value != null) {
      // A square-edged fill, rounded only by the track it is clipped to.
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
      canvas.drawRect(Offset.zero & size, Paint()..color = trackColor);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * value, size.height),
        fill,
      );
      canvas.restore();
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );
    const double segment = SoftProgressDialogDefaults.indeterminateSegment;
    final double position = sweep.value % 1;
    final double w = size.width;
    final double h = size.height;
    if (position < 1 - segment) {
      canvas.drawRRect(
        RRect.fromLTRBR(w * position, 0, w * (position + segment), h, radius),
        fill,
      );
      return;
    }
    canvas.drawRRect(RRect.fromLTRBR(w * position, 0, w, h, radius), fill);
    final double wrapped = position + segment - 1;
    if (wrapped > 0) {
      canvas.drawRRect(RRect.fromLTRBR(0, 0, w * wrapped, h, radius), fill);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.sweep != sweep ||
      old.color != color ||
      old.trackColor != trackColor;
}
