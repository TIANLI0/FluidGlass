import 'package:flutter/rendering.dart';

import '../backdrop.dart';

/// Draws a backdrop with a plain canvas callback, for backgrounds that are
/// cheap to redraw (a solid fill, a gradient, ...).
class CanvasBackdrop extends Backdrop {
  const CanvasBackdrop(this.onDraw);

  final void Function(Canvas canvas, Size size) onDraw;

  @override
  bool get isCoordinatesDependent => false;

  @override
  void drawBackdrop(BackdropDrawContext context) {
    onDraw(context.canvas, context.size);
  }

  @override
  bool operator ==(Object other) => other is CanvasBackdrop && other.onDraw == onDraw;

  @override
  int get hashCode => onDraw.hashCode;
}
