import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';

import '../glass_layer.dart';

/// How far a fully pressed element swells, in logical pixels of its short axis.
const double _pressSwellPixels = 4.0;

/// How hard a drag stretches an element along the axis it is pulling, per
/// element-length of travel, in the same units.
const double _dragStretchPixels = 4.0;

/// How closely the glass follows the finger.
///
/// Deliberately shallow: the element leans towards the pointer, it does not
/// chase it. `tanh` is what keeps the lean itself bounded — it can never fall
/// more than the element's own short side behind the pointer.
const double _travelSlope = 0.05;

/// The displacement law the pressable liquid components share: the glass leans
/// towards the finger and stretches along the axis being pulled.
///
/// [offset] is how far the pointer has travelled since it went down, and the
/// stretch tracks it for as long as the drag goes on. Capping the travel was
/// tried and taken back out: it does bound the deformation, and it also makes
/// the drag stop feeling like a drag — the glass parts company with the finger
/// and the gesture goes dead in the hand. `LiquidButton` and
/// `LiquidButtonGroup` had character-identical copies of this; they share it
/// now so the feel cannot drift between them.
void applyDragDeformation(
  GlassLayer layer, {
  required Offset offset,
  required double pressProgress,
}) {
  final double width = layer.size.width;
  final double height = layer.size.height;
  if (width == 0 || height == 0) return;

  final double scale =
      lerpDouble(1.0, 1.0 + _pressSwellPixels / height, pressProgress)!;

  final double maxTravel = layer.size.shortestSide;
  layer.translationX = maxTravel * tanh(_travelSlope * offset.dx / maxTravel);
  layer.translationY = maxTravel * tanh(_travelSlope * offset.dy / maxTravel);

  final double dragStretch = _dragStretchPixels / height;
  final double angle = math.atan2(offset.dy, offset.dx);
  final double longest = layer.size.longestSide;
  layer.scaleX = scale +
      dragStretch *
          (math.cos(angle) * offset.dx / longest).abs() *
          math.min(width / height, 1.0);
  layer.scaleY = scale +
      dragStretch *
          (math.sin(angle) * offset.dy / longest).abs() *
          math.min(height / width, 1.0);
}

/// `tanh`, with the tails short-circuited before `exp` overflows.
double tanh(double x) {
  if (x > 20) return 1.0;
  if (x < -20) return -1.0;
  final double e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}
