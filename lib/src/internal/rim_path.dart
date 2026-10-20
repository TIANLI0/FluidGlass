import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../shapes/rounded_rectangular_shape.dart';

/// An element's outline, addressed by arc length.
///
/// Light that travels along an outline has to move by arc length rather than
/// by angle. Seen from the centre of a wide capsule, the two long sides cover
/// almost every angle and the round ends almost none, so a light moved by
/// angle races round the ends and crawls along the sides.
///
/// Positions are arc lengths from wherever the path happens to start; the
/// helpers here speak in "clockwise on screen" so callers never have to know
/// which way the outline was wound.
class RimPath {
  RimPath(this.shape, this.size, [this.textDirection = TextDirection.ltr])
    : path = shape.createOutline(size, textDirection).toPath() {
    final Iterator<ui.PathMetric> metrics = path.computeMetrics().iterator;
    metrics.moveNext();
    metric = metrics.current;
    length = metric.length;
  }

  final RoundedRectangularShape shape;
  final Size size;

  /// Resolves a shape whose corners are given by start and end, so the rim
  /// traces the same corners the glass under it was drawn with.
  final TextDirection textDirection;

  final Path path;
  late final ui.PathMetric metric;
  late final double length;

  /// The arc length of the top centre of the outline, where a progress rim
  /// starts filling and an unanchored sweep leaves from.
  ///
  /// Found on first use: light landing from a neighbour needs only [path],
  /// and this is a search of over a hundred points along the outline.
  late final double topCentre = nearest(Offset(size.width / 2, 0));

  late final bool _clockwise =
      metric.getTangentForOffset((topCentre + 2) % length)!.position.dx >=
      size.width / 2;

  /// The arc length [distance] clockwise from [from]; negative goes back.
  double advance(double from, double distance) =>
      (_clockwise ? from + distance : from - distance) % length;

  /// The arc length of the outline point nearest [point], in element space.
  ///
  /// A coarse search then a fine one: exact to a 768th of the outline's
  /// length — well under a pixel for a control, a pixel or two round a
  /// dialog-sized panel — without sampling the whole outline finely. Callers
  /// cache the answer: it is asked once per gesture, not per frame.
  double nearest(Offset point) {
    const int coarse = 96;
    double best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < coarse; i++) {
      final double s = length * i / coarse;
      final double d = (_at(s) - point).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = s;
      }
    }
    final double step = length / coarse;
    for (int i = -8; i <= 8; i++) {
      final double s = (best + step * i / 8) % length;
      final double d = (_at(s) - point).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = s;
      }
    }
    return best;
  }

  Offset _at(double s) => metric.getTangentForOffset(s % length)!.position;

  /// The point at arc length [s].
  Offset pointAt(double s) => _at(s);

  /// The outline from [from], [distance] clockwise, as one path — in two
  /// pieces if it crosses the point where the outline starts.
  Path segment(double from, double distance) {
    final double d = math.min(math.max(distance, 0.0), length);
    final Path out = Path();
    if (d <= 0) return out;
    double a;
    double b;
    if (_clockwise) {
      a = from % length;
      b = a + d;
    } else {
      b = from % length;
      a = b - d;
    }
    if (a < 0) {
      out.addPath(metric.extractPath(a + length, length), Offset.zero);
      out.addPath(metric.extractPath(0, b), Offset.zero);
    } else if (b > length) {
      out.addPath(metric.extractPath(a, length), Offset.zero);
      out.addPath(metric.extractPath(0, b - length), Offset.zero);
    } else {
      out.addPath(metric.extractPath(a, b), Offset.zero);
    }
    return out;
  }
}

/// Holds one [RimPath], rebuilt only when the shape or size changes — the
/// metric is the one non-trivial part of drawing light along an outline, and
/// a resting element's outline never changes.
class RimPathCache {
  RimPath? _last;

  RimPath of(
    RoundedRectangularShape shape,
    Size size, [
    TextDirection textDirection = TextDirection.ltr,
  ]) {
    final RimPath? last = _last;
    if (last != null &&
        last.size == size &&
        last.textDirection == textDirection &&
        last.shape == shape) {
      return last;
    }
    return _last = RimPath(shape, size, textDirection);
  }
}
