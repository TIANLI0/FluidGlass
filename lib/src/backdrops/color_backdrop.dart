import 'package:flutter/rendering.dart';

import '../backdrop.dart';

/// A backdrop of one solid colour: what a control refracts when it sits on a
/// plain surface — a switch in a settings card, a slider on a sheet.
///
/// Such a control cannot be handed a live capture of the page it is part of
/// (that capture would contain the control itself), and [emptyBackdrop] gives
/// its lens nothing to bend, so the knob or thumb comes out flat. The colour of
/// the surface underneath is the honest source: the lens bends its edge, and a
/// press visibly squashes it.
///
/// Compared by colour, so building one inline on every frame is free. A
/// [CanvasBackdrop] with an inline closure is a new backdrop on every build —
/// it compares by callback identity — and a control rebuilt on every pointer
/// move resubscribed and repainted its glass on every one.
class ColorBackdrop extends Backdrop {
  const ColorBackdrop(this.color);

  final Color color;

  @override
  bool get isCoordinatesDependent => false;

  @override
  void drawBackdrop(BackdropDrawContext context) {
    context.canvas.drawRect(
      (Offset.zero & context.size).inflate(context.sampleMargin),
      Paint()..color = color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ColorBackdrop && other.color == color;

  @override
  int get hashCode => color.hashCode;
}
