import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';

/// The page indicator defaults.
abstract final class SoftPageIndicatorDefaults {
  /// A dot's diameter; also the indicator's height.
  static const double dotSize = 6;

  /// A dot at the edge of a sliding window, next to a hidden page.
  static const double dotSizeMedium = 4.5;

  /// The smallest dot of the reference's size ladder; not used.
  static const double dotSizeSmall = 2.5;

  /// Half the gap between two dots: the centre-to-centre pitch is
  /// `dotSize + 2 × dotSpacing`, 12.
  static const double dotSpacing = 3;

  /// The most dots drawn at once.
  static const int maxVisibleDots = 6;
}

/// A centred row of dots, one per page: the current one in the theme's
/// `onSurface`, the others in `disabledOnSurface`.
///
/// At most six dots show; with more pages they slide as a window that keeps
/// the current page near the middle, and the end dots next to a hidden page
/// shrink to 4.5. Display only: it does not react to taps.
class SoftPageIndicator extends StatelessWidget {
  const SoftPageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.activeColor,
    this.inactiveColor,
  });

  /// The number of pages; nothing is drawn for 0 or less.
  final int count;

  /// Clamped to the pages.
  final int currentIndex;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    const int maxVisible = SoftPageIndicatorDefaults.maxVisibleDots;
    const double dot = SoftPageIndicatorDefaults.dotSize;
    const double pitch = dot + SoftPageIndicatorDefaults.dotSpacing * 2;
    final int visible = count <= maxVisible ? count : maxVisible;
    final int active = currentIndex.clamp(0, count - 1);
    final int start = count <= maxVisible
        ? 0
        : (active - (maxVisible - 1) ~/ 2).clamp(0, count - maxVisible);
    final SoftColors colors = SoftTheme.colorsOf(context);
    return CustomPaint(
      size: Size(pitch * (visible - 1) + dot, dot),
      painter: _DotsPainter(
        count: count,
        visible: visible,
        start: start,
        active: active,
        activeColor: activeColor ?? colors.onSurface,
        inactiveColor: inactiveColor ?? colors.disabledOnSurface,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({
    required this.count,
    required this.visible,
    required this.start,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int visible;
  final int start;
  final int active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double dot = SoftPageIndicatorDefaults.dotSize;
    const double pitch = dot + SoftPageIndicatorDefaults.dotSpacing * 2;
    final Paint paint = Paint();
    for (int slot = 0; slot < visible; slot++) {
      final int index = start + slot;
      final bool edge =
          (slot == 0 && start > 0) ||
          (slot == visible - 1 && start + visible < count);
      final double diameter = edge
          ? SoftPageIndicatorDefaults.dotSizeMedium
          : dot;
      paint.color = index == active ? activeColor : inactiveColor;
      canvas.drawCircle(
        Offset(slot * pitch + dot / 2, size.height / 2),
        diameter / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.count != count ||
      old.visible != visible ||
      old.start != start ||
      old.active != active ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}
