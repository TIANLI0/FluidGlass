import 'package:flutter/rendering.dart';

import '../animation/liquid_press.dart';
import '../glass_layer.dart';

/// Writes [LiquidPressDeformation] onto a glass layer: the glass leans towards
/// the finger and stretches along the axis being pulled.
///
/// `LiquidButton` and `LiquidButtonGroup` had character-identical copies of the
/// law. It lives in [LiquidPressDeformation] now, where a caller outside the
/// library can resolve the same numbers for something that is *not* made of
/// glass and move it by the same law, so the feel cannot drift between them.
void applyDragDeformation(
  GlassLayer layer, {
  required Offset offset,
  required double pressProgress,
}) {
  final LiquidPressDeformation press = LiquidPressDeformation.resolve(
    layer.size,
    offset: offset,
    pressProgress: pressProgress,
  );
  layer
    ..translationX = press.translationX
    ..translationY = press.translationY
    ..scaleX = press.scaleX
    ..scaleY = press.scaleY;
}
