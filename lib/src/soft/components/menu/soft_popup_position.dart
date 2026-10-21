import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where a popup sits relative to its anchor, for positioners that honour
/// it (the context menu); the dropdown positioner centres on the anchor and
/// ignores it.
///
/// Start and end follow the text direction.
enum SoftPopupAlign { start, end, topStart, topEnd, bottomStart, bottomEnd }

extension on SoftPopupAlign {
  SoftPopupAlign resolve(TextDirection direction) {
    if (direction == TextDirection.ltr) return this;
    return switch (this) {
      SoftPopupAlign.start => SoftPopupAlign.end,
      SoftPopupAlign.end => SoftPopupAlign.start,
      SoftPopupAlign.topStart => SoftPopupAlign.topEnd,
      SoftPopupAlign.topEnd => SoftPopupAlign.topStart,
      SoftPopupAlign.bottomStart => SoftPopupAlign.bottomEnd,
      SoftPopupAlign.bottomEnd => SoftPopupAlign.bottomStart,
    };
  }
}

/// Places a popup of a measured size against its anchor inside the window's
/// safe area.
@immutable
abstract class SoftPopupPositioner {
  const SoftPopupPositioner();

  /// Below the anchor, centred on it; above when there is no room below.
  static const SoftPopupPositioner dropdown = SoftDropdownPositioner();

  /// Against a corner of the anchor chosen by the [SoftPopupAlign].
  static const SoftPopupPositioner contextMenu = SoftContextMenuPositioner();

  /// The extra margins kept around the popup.
  EdgeInsets get margins;

  /// The popup's top-left corner, in the coordinates of [anchor] and
  /// [window].
  ///
  /// [window] is the safe area the popup may occupy; [margin] is [margins]
  /// resolved for the text direction.
  Offset position({
    required Rect anchor,
    required Rect window,
    required TextDirection textDirection,
    required Size popupSize,
    required EdgeInsets margin,
    required SoftPopupAlign alignment,
  });
}

/// The dropdown placement: centred on the anchor and clamped into the
/// window inset by [horizontalMargin] on both sides, [verticalMargin] below
/// the anchor — or above it when the popup does not fit below, or at the top
/// of the window when it fits neither way.
///
/// An anchor collapsed to a point (a recorded touch) drops the vertical gap,
/// so the popup opens right at the finger.
class SoftDropdownPositioner extends SoftPopupPositioner {
  const SoftDropdownPositioner({
    this.verticalMargin = 8,
    this.horizontalMargin = 16,
  });

  /// The gap between the popup and its anchor.
  final double verticalMargin;

  /// The gap the popup keeps from the window's sides.
  final double horizontalMargin;

  @override
  EdgeInsets get margins => EdgeInsets.symmetric(
    horizontal: horizontalMargin,
    vertical: verticalMargin,
  );

  @override
  Offset position({
    required Rect anchor,
    required Rect window,
    required TextDirection textDirection,
    required Size popupSize,
    required EdgeInsets margin,
    required SoftPopupAlign alignment,
  }) {
    final double availableLeft = window.left + margin.left;
    final double availableRight = window.right - margin.right;
    final double available = availableRight - availableLeft;
    final bool pointAnchored = anchor.width == 0 && anchor.height == 0;
    final double belowGap = pointAnchored ? 0 : margin.bottom;
    final double aboveGap = pointAnchored ? 0 : margin.top;
    final double w = popupSize.width;
    final double h = popupSize.height;
    final double x = w > available
        ? availableLeft + (available - w) / 2
        : anchor.center.dx - w / 2;
    final double y;
    if (window.bottom - anchor.bottom > h) {
      y = anchor.bottom + belowGap;
    } else if (anchor.top - window.top > h) {
      y = anchor.top - h - aboveGap;
    } else {
      y = window.top + margin.top;
    }
    final double maxY = window.bottom - h - margin.bottom;
    return Offset(
      x.clamp(availableLeft, math.max(availableRight - w, availableLeft)),
      y.clamp(math.min(window.top + margin.top, maxY), maxY),
    );
  }
}

/// The context-menu placement: the popup hangs from a corner of the anchor
/// chosen by the [SoftPopupAlign]; `start` / `end` fall back to below the
/// anchor (above when there is no room, centred on it when it fits neither
/// way).
class SoftContextMenuPositioner extends SoftPopupPositioner {
  const SoftContextMenuPositioner();

  @override
  EdgeInsets get margins => EdgeInsets.zero;

  @override
  Offset position({
    required Rect anchor,
    required Rect window,
    required TextDirection textDirection,
    required Size popupSize,
    required EdgeInsets margin,
    required SoftPopupAlign alignment,
  }) {
    final double w = popupSize.width;
    final double h = popupSize.height;
    final SoftPopupAlign align = alignment.resolve(textDirection);
    double x;
    double y;
    switch (align) {
      case SoftPopupAlign.topStart:
        x = anchor.left + margin.left;
        y = anchor.bottom + margin.top;
      case SoftPopupAlign.topEnd:
        x = anchor.right - w - margin.right;
        y = anchor.bottom + margin.top;
      case SoftPopupAlign.bottomStart:
        x = anchor.left + margin.left;
        y = anchor.top - h - margin.bottom;
      case SoftPopupAlign.bottomEnd:
        x = anchor.right - w - margin.right;
        y = anchor.top - h - margin.bottom;
      case SoftPopupAlign.start:
      case SoftPopupAlign.end:
        x = align == SoftPopupAlign.end
            ? anchor.right - w - margin.right
            : anchor.left + margin.left;
        if (window.bottom - anchor.bottom > h) {
          y = anchor.bottom + margin.bottom;
        } else if (anchor.top - window.top > h) {
          y = anchor.top - h - margin.top;
        } else {
          y = anchor.center.dy - h / 2;
        }
    }
    final double maxY = window.bottom - h - margin.bottom;
    return Offset(
      x.clamp(
        window.left,
        math.max(window.right - w - margin.right, window.left),
      ),
      y.clamp(math.min(window.top + margin.top, maxY), maxY),
    );
  }
}

/// The tuning of the arc a popup flies in along, from its anchor to its
/// resting place.
///
/// The distances are in physical pixels, like the reference's; the popup
/// converts them with the device pixel ratio.
@immutable
class SoftPopupGravityMotion {
  const SoftPopupGravityMotion({
    this.gravityDistanceMinPx = 30,
    this.gravityDistanceMaxPx = 400,
    this.gravityArcMaxPx = 130,
    this.p1T = 0.35,
    this.p2T = 0.65,
    this.pathAnchorEdgeOffsetY = 0,
  });

  /// The reference tuning.
  static const SoftPopupGravityMotion standard = SoftPopupGravityMotion();

  /// The shortest anchor-to-centre distance that still sags; at or below it
  /// the path is straight.
  final double gravityDistanceMinPx;

  /// The distance at which the sag reaches [gravityArcMaxPx].
  final double gravityDistanceMaxPx;

  /// The largest sag.
  final double gravityArcMaxPx;

  /// The first control point's position along the chord.
  final double p1T;

  /// The second control point's position along the chord.
  final double p2T;

  /// Pushes the path's start away from the anchor along the placement axis.
  final double pathAnchorEdgeOffsetY;
}

/// The cubic Bézier a popup travels along: start `A`, two control points
/// pushed off the chord by the gravity sag, and end `B`.
@immutable
class SoftGravityPath {
  const SoftGravityPath(
    this.ax,
    this.ay,
    this.p1x,
    this.p1y,
    this.p2x,
    this.p2y,
    this.bx,
    this.by,
  );

  /// A path that stays at the origin.
  static const SoftGravityPath none = SoftGravityPath(0, 0, 0, 0, 0, 0, 0, 0);

  final double ax;
  final double ay;
  final double p1x;
  final double p1y;
  final double p2x;
  final double p2y;
  final double bx;
  final double by;

  /// The point at [t]; an underdamped spring may push [t] past 1.
  Offset pointAt(double t) {
    final double inv = 1 - t;
    final double inv2 = inv * inv;
    final double t2 = t * t;
    final double w1 = inv2 * 3 * t;
    final double w2 = inv * 3 * t2;
    return Offset(
      ax * inv2 * inv + p1x * w1 + p2x * w2 + bx * t2 * t,
      ay * inv2 * inv + p1y * w1 + p2y * w2 + by * t2 * t,
    );
  }

  /// The arc sag: it ramps from 0 at [dMin] to [gMax] at [dMax] and shrinks
  /// as the chord nears an axis, so a diagonal hop sags most.
  static double adaptiveGravity(
    double dx,
    double dy,
    double length, {
    required double dMin,
    required double dMax,
    required double gMax,
  }) {
    final double span = dMax - dMin;
    final double fraction;
    if (span > 1e-4) {
      fraction = ((length - dMin) / span).clamp(0.0, 1.0);
    } else {
      fraction = length <= dMin ? 0 : 1;
    }
    final double ax = dx.abs();
    final double ay = dy.abs();
    return gMax * fraction * (math.min(ax, ay) / (math.max(ax, ay) + 1e-4));
  }

  /// Builds the arc from [start] to [end]. Both control points sit at their
  /// (clamped, ordered, at least 0.08 apart) chord positions and are pushed
  /// off the chord by the same perpendicular, flipped to point down so the
  /// arc always sags.
  static SoftGravityPath between(
    Offset start,
    Offset end, {
    required double dMin,
    required double dMax,
    required double gMax,
    double p1T = 0.35,
    double p2T = 0.65,
  }) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) {
      return SoftGravityPath(
        start.dx,
        start.dy,
        start.dx,
        start.dy,
        end.dx,
        end.dy,
        end.dx,
        end.dy,
      );
    }
    double larger = p1T.clamp(0.05, 0.95);
    double smaller = p2T.clamp(0.05, 0.95);
    if (larger <= smaller) {
      final double swap = larger;
      larger = smaller;
      smaller = swap;
    }
    if (larger - smaller < 0.08) {
      final double mid = ((larger + smaller) * 0.5).clamp(0.09, 0.91);
      smaller = (mid - 0.04).clamp(0.05, 0.95);
      larger = (mid + 0.04).clamp(0.05, 0.95);
    }
    final double gravity = adaptiveGravity(
      dx,
      dy,
      length,
      dMin: dMin,
      dMax: dMax,
      gMax: gMax,
    );
    double nx = -dy / length;
    double ny = dx / length;
    if (ny < 0) {
      nx = -nx;
      ny = -ny;
    }
    final double ox;
    final double oy;
    if (ny.abs() >= 0.001) {
      ox = nx * gravity;
      oy = ny * gravity;
    } else {
      ox = 0;
      oy = gravity;
    }
    return SoftGravityPath(
      start.dx,
      start.dy,
      start.dx + smaller * dx + ox,
      start.dy + smaller * dy + oy,
      start.dx + larger * dx + ox,
      start.dy + larger * dy + oy,
      end.dx,
      end.dy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftGravityPath &&
      other.ax == ax &&
      other.ay == ay &&
      other.p1x == p1x &&
      other.p1y == p1y &&
      other.p2x == p2x &&
      other.p2y == p2y &&
      other.bx == bx &&
      other.by == by;

  @override
  int get hashCode => Object.hash(ax, ay, p1x, p1y, p2x, p2y, bx, by);
}
