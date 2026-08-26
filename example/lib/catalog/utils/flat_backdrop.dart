import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/painting.dart';

/// A [CanvasBackdrop] that fills itself with [color], cached per colour.
///
/// [CanvasBackdrop] compares by callback identity, so building one from an
/// inline closure hands every consumer a backdrop that is never `==` to the
/// last one. `RenderDrawBackdrop.backdrop`'s setter then unsubscribes,
/// resubscribes and marks itself dirty on every rebuild — which, for a
/// component rebuilt on each pointer move, is every frame of a drag.
CanvasBackdrop flatBackdrop(Color color) {
  return _cache[color] ??= CanvasBackdrop(
    (Canvas canvas, Size size) =>
        canvas.drawRect(Offset.zero & size, Paint()..color = color),
  );
}

// Bounded by the handful of surface colours the catalog uses.
final Map<Color, CanvasBackdrop> _cache = <Color, CanvasBackdrop>{};
