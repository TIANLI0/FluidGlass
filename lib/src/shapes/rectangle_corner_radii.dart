import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';

/// Per-corner radii of a rectangle, in logical pixels, expressed in
/// start/end terms so they can be resolved against a text direction.
@immutable
class RectangleCornerRadii {
  const RectangleCornerRadii({
    required this.topStart,
    required this.topEnd,
    required this.bottomEnd,
    required this.bottomStart,
  });

  const RectangleCornerRadii.all(double radius)
      : topStart = radius,
        topEnd = radius,
        bottomEnd = radius,
        bottomStart = radius;

  final double topStart;
  final double topEnd;
  final double bottomEnd;
  final double bottomStart;

  static RectangleCornerRadii lerp(
    RectangleCornerRadii start,
    RectangleCornerRadii stop,
    double fraction,
  ) {
    return RectangleCornerRadii(
      topStart: lerpDouble(start.topStart, stop.topStart, fraction)!,
      topEnd: lerpDouble(start.topEnd, stop.topEnd, fraction)!,
      bottomEnd: lerpDouble(start.bottomEnd, stop.bottomEnd, fraction)!,
      bottomStart: lerpDouble(start.bottomStart, stop.bottomStart, fraction)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RectangleCornerRadii &&
      other.topStart == topStart &&
      other.topEnd == topEnd &&
      other.bottomEnd == bottomEnd &&
      other.bottomStart == bottomStart;

  @override
  int get hashCode => Object.hash(topStart, topEnd, bottomEnd, bottomStart);

  @override
  String toString() => 'RectangleCornerRadii($topStart, $topEnd, $bottomEnd, $bottomStart)';
}

/// The four resolved corner radii of a rounded rectangle, in logical pixels,
/// ordered clockwise from the top-left.
@immutable
class RectangleCorners {
  const RectangleCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  @override
  bool operator ==(Object other) =>
      other is RectangleCorners &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'RectangleCorners($topLeft, $topRight, $bottomRight, $bottomLeft)';
}
