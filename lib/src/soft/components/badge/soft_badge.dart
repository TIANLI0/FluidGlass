import 'package:flutter/widgets.dart';

import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The badge defaults.
abstract final class SoftBadgeDefaults {
  /// The plain dot.
  static const double dotDiameter = 6;

  /// The count capsule's height.
  static const double height = 16;

  /// The capsule width for counts under 10.
  static const double smallWidth = 16;

  /// Under 100, and the 1000+ ellipsis.
  static const double mediumWidth = 20;

  /// Under 1000.
  static const double largeWidth = 26;

  static const double textSize = 10;
  static const double strokeWidth = 1;
  static const double ellipsisDotDiameter = 2;
  static const double ellipsisSpacing = 2;

  /// Counts at or above this show the ellipsis.
  static const int overflowCount = 1000;

  static const Color redLight = Color(0xFFEB3B2F);
  static const Color redDark = Color(0xFFEB493D);

  /// The width change on a new count: 517 ms on the move easing.
  static const Duration widthDuration = Duration(milliseconds: 517);
  static const Duration countFadeDuration = Duration(milliseconds: 150);
  static const Cubic moveEase = Cubic(0.3, 0, 0.1, 1);

  static double widthFor(int count, double height) {
    final double base = count < 10
        ? smallWidth
        : count < 100
        ? mediumWidth
        : count < overflowCount
        ? largeWidth
        : mediumWidth;
    return base > height ? base : height;
  }
}

/// A red badge: a 6 dot when [count] is 0 or less, otherwise a 16-high
/// capsule with the number (three dots from 1000 on). With [stroke] it is
/// ringed in white.
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    this.count = 0,
    this.stroke = false,
    this.color,
    this.textColor = const Color(0xFFFFFFFF),
    this.strokeColor = const Color(0xFFFFFFFF),
    this.dotDiameter = SoftBadgeDefaults.dotDiameter,
    this.height = SoftBadgeDefaults.height,
  });

  final int count;
  final bool stroke;

  /// The red; follows the theme by default.
  final Color? color;
  final Color textColor;
  final Color strokeColor;
  final double dotDiameter;
  final double height;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color red =
        color ??
        (theme.isDark ? SoftBadgeDefaults.redDark : SoftBadgeDefaults.redLight);
    if (count <= 0) {
      return SizedBox.square(
        dimension: dotDiameter,
        child: CustomPaint(
          painter: _DotPainter(red, stroke ? strokeColor : null),
        ),
      );
    }
    final double radius = height / 2;
    final double width = SoftBadgeDefaults.widthFor(count, height);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: width),
      duration: SoftBadgeDefaults.widthDuration,
      curve: SoftBadgeDefaults.moveEase,
      builder: (BuildContext context, double w, Widget? child) {
        return Container(
          width: w,
          height: height,
          decoration: ShapeDecoration(
            color: stroke ? strokeColor : red,
            shape: SoftSquircleBorder.all(radius, smooth: theme.smoothCorners),
          ),
          padding: EdgeInsets.all(stroke ? SoftBadgeDefaults.strokeWidth : 0),
          child: stroke
              ? DecoratedBox(
                  decoration: ShapeDecoration(
                    color: red,
                    shape: SoftSquircleBorder.all(
                      radius - SoftBadgeDefaults.strokeWidth,
                      smooth: theme.smoothCorners,
                    ),
                  ),
                  child: child,
                )
              : child,
        );
      },
      child: AnimatedSwitcher(
        duration: SoftBadgeDefaults.countFadeDuration,
        child: Center(
          key: ValueKey<int>(count),
          child: count < SoftBadgeDefaults.overflowCount
              ? Text(
                  '$count',
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: SoftBadgeDefaults.textSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    color: textColor,
                  ),
                )
              : CustomPaint(
                  size: const Size(
                    SoftBadgeDefaults.ellipsisDotDiameter * 3 +
                        SoftBadgeDefaults.ellipsisSpacing * 2,
                    SoftBadgeDefaults.ellipsisDotDiameter,
                  ),
                  painter: _EllipsisPainter(textColor),
                ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter(this.color, this.stroke);

  final Color color;
  final Color? stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    final Color? s = stroke;
    if (s != null) {
      canvas
        ..drawCircle(c, r, Paint()..color = s)
        ..drawCircle(
          c,
          r - SoftBadgeDefaults.strokeWidth,
          Paint()..color = color,
        );
    } else {
      canvas.drawCircle(c, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.color != color || old.stroke != stroke;
}

class _EllipsisPainter extends CustomPainter {
  const _EllipsisPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.height / 2;
    const double step =
        SoftBadgeDefaults.ellipsisDotDiameter +
        SoftBadgeDefaults.ellipsisSpacing;
    final Paint paint = Paint()..color = color;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(r + step * i, r), r, paint);
    }
  }

  @override
  bool shouldRepaint(_EllipsisPainter old) => old.color != color;
}
