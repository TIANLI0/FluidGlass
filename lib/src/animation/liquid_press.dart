import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// How far a fully pressed element swells, in logical pixels of its short axis.
const double _pressSwellPixels = 4.0;

/// How hard a drag stretches an element along the axis it is pulling, per
/// element-length of travel, in the same units.
const double _dragStretchPixels = 4.0;

/// How closely the element follows the finger.
///
/// Deliberately shallow: the element leans towards the pointer, it does not
/// chase it. `tanh` is what keeps the lean itself bounded — it can never fall
/// more than the element's own short side behind the pointer.
const double _travelSlope = 0.05;

/// The displacement law the pressable liquid components share, as four plain
/// numbers: the element swells while it is held, leans towards the finger, and
/// stretches along the axis being pulled.
///
/// [LiquidButton] and [LiquidButtonGroup] resolve this and write it onto their
/// glass layer. It is public because the motion is not made of glass — a
/// Material button, a card, an icon can move by exactly the same law through a
/// [Transform], and sharing the law is what keeps the feel from drifting
/// between the two:
///
/// ```dart
/// final LiquidPressDeformation press = LiquidPressDeformation.resolve(
///   size,
///   offset: highlight.offset,
///   pressProgress: highlight.pressProgress,
/// );
///
/// Transform(
///   alignment: Alignment.center,
///   transform: press.transform,
///   child: child,
/// );
/// ```
///
/// Feed it from springs, not from raw pointer values: the squash and the
/// ring-down are the springs' doing, not this law's. [InteractiveHighlight]
/// carries the pair the components use — a press progress and the pointer's
/// travel since it went down.
@immutable
class LiquidPressDeformation {
  const LiquidPressDeformation({
    required this.scaleX,
    required this.scaleY,
    required this.translationX,
    required this.translationY,
  });

  /// The element at rest: no swell, no lean, no stretch.
  static const LiquidPressDeformation none = LiquidPressDeformation(
    scaleX: 1.0,
    scaleY: 1.0,
    translationX: 0.0,
    translationY: 0.0,
  );

  /// Resolves the law for an element of [size].
  ///
  /// [offset] is how far the pointer has travelled since it went down, and the
  /// stretch tracks it for as long as the drag goes on. Capping the travel was
  /// tried and taken back out: it does bound the deformation, and it also makes
  /// the drag stop feeling like a drag — the element parts company with the
  /// finger and the gesture goes dead in the hand.
  ///
  /// [pressProgress] runs 0 to 1 and drives the swell alone.
  factory LiquidPressDeformation.resolve(
    Size size, {
    required Offset offset,
    required double pressProgress,
  }) {
    final double width = size.width;
    final double height = size.height;
    if (width == 0 || height == 0) return none;

    final double scale = lerpDouble(
      1.0,
      1.0 + _pressSwellPixels / height,
      pressProgress,
    )!;

    final double maxTravel = size.shortestSide;
    final double dragStretch = _dragStretchPixels / height;
    final double angle = math.atan2(offset.dy, offset.dx);
    final double longest = size.longestSide;

    return LiquidPressDeformation(
      scaleX:
          scale +
          dragStretch *
              (math.cos(angle) * offset.dx / longest).abs() *
              math.min(width / height, 1.0),
      scaleY:
          scale +
          dragStretch *
              (math.sin(angle) * offset.dy / longest).abs() *
              math.min(height / width, 1.0),
      translationX: maxTravel * _tanh(_travelSlope * offset.dx / maxTravel),
      translationY: maxTravel * _tanh(_travelSlope * offset.dy / maxTravel),
    );
  }

  /// The swell and stretch across the element.
  final double scaleX;

  /// The swell and stretch down the element.
  final double scaleY;

  /// The lean towards the finger, in logical pixels.
  final double translationX;

  /// The lean towards the finger, in logical pixels.
  final double translationY;

  /// Whether this moves the element at all.
  bool get isIdentity =>
      scaleX == 1.0 &&
      scaleY == 1.0 &&
      translationX == 0.0 &&
      translationY == 0.0;

  /// The matrix form, for a [Transform] whose `alignment` is
  /// [Alignment.center] — the scale is about the element's centre, as it is on
  /// a glass layer, and only `alignment` can say so.
  Matrix4 get transform => Matrix4.identity()
    ..translateByDouble(translationX, translationY, 0, 1)
    ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidPressDeformation &&
          other.scaleX == scaleX &&
          other.scaleY == scaleY &&
          other.translationX == translationX &&
          other.translationY == translationY;

  @override
  int get hashCode => Object.hash(scaleX, scaleY, translationX, translationY);

  @override
  String toString() =>
      'LiquidPressDeformation(scale: ($scaleX, $scaleY), '
      'translation: ($translationX, $translationY))';
}

/// `tanh`, with the tails short-circuited before `exp` overflows.
double _tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final double e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}
