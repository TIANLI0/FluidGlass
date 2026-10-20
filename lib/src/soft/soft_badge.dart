import 'package:flutter/material.dart';

import 'soft_theme.dart';

/// An unread count (or a plain dot) pinned to the top-right corner of [child].
///
/// The count pill is 16 high and 16 / 20 / 26 wide for one, two and three
/// digits; from 1000 on it shows three dots in a 20 pill. It hangs 4 above the
/// child's corner and 6 / 9 / 10 to the right (a single digit too far out
/// reads as belonging to the neighbour, a wide one pulled in covers the icon).
/// It scales in and out (520 ms) as the count arrives and clears.
class SoftBadge extends StatelessWidget {
  const SoftBadge({super.key, required this.count, required this.child});

  /// 0 shows nothing, a negative value shows a dot, otherwise the number.
  final int count;
  final Widget child;

  static const double dotSize = 6;
  static const double height = 16;
  static const double _topOverflow = 4;

  static String labelFor(int count) => count > 99 ? '99+' : '$count';

  static double rightOverflow(int count) {
    if (count < 0) return 3;
    return switch (labelFor(count).length) {
      1 => 6,
      2 => 9,
      _ => 10,
    };
  }

  static double widthFor(int count) {
    if (count >= 1000) return 20;
    return switch ('$count'.length) {
      1 => 16,
      2 => 20,
      _ => 26,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          top: count < 0 ? -1 : -_topOverflow,
          right: -rightOverflow(count),
          child: IgnorePointer(
            child: ExcludeSemantics(child: SoftBadgeMark(count: count)),
          ),
        ),
      ],
    );
  }
}

/// The badge on its own (a dot or a count pill), scaling in and out.
class SoftBadgeMark extends StatelessWidget {
  const SoftBadgeMark({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget mark;
    if (count < 0) {
      mark = Container(
        width: SoftBadge.dotSize,
        height: SoftBadge.dotSize,
        decoration: BoxDecoration(color: theme.badge, shape: BoxShape.circle),
      );
    } else if (count == 0) {
      mark = const SizedBox.shrink();
    } else {
      mark = Container(
        width: SoftBadge.widthFor(count),
        height: SoftBadge.height,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: theme.badge,
          shape: const StadiumBorder(),
        ),
        child: count >= 1000
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 2,
                      height: 2,
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            : Text(
                SoftBadge.labelFor(count),
                textScaler: TextScaler.noScaling,
                style: theme.text(
                  10,
                  weight: FontWeight.w500,
                  color: const Color(0xFFFFFFFF),
                  height: 1,
                ),
              ),
      );
    }
    return AnimatedScale(
      scale: count == 0 ? 0 : 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 520),
      curve: SoftCurves.moveEase,
      child: mark,
    );
  }
}
