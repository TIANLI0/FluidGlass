import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../backdrop.dart';

/// Wraps another backdrop so its drawing can be transformed or decorated.
///
/// [onDraw] is handed a callback that draws the wrapped backdrop; it may set up
/// the canvas around that call, which is how a slider or toggle squashes the
/// track its thumb refracts.
class WrappedBackdrop extends Backdrop {
  const WrappedBackdrop(this.backdrop, this.onDraw);

  final Backdrop backdrop;

  final void Function(BackdropDrawContext context, void Function() drawBackdrop)
  onDraw;

  @override
  bool get isCoordinatesDependent => backdrop.isCoordinatesDependent;

  @override
  Listenable? get repaintNotifier => backdrop.repaintNotifier;

  // Never: [onDraw] sets up the canvas around the wrapped backdrop, and a
  // compositor filtering the scene in place cannot be told to do that.
  @override
  bool get isPaintedBehindConsumer => false;

  @override
  void drawBackdrop(BackdropDrawContext context) {
    final Matrix4 before = Matrix4.fromFloat64List(
      context.canvas.getTransform(),
    );
    if (before.invert() == 0) return;
    onDraw(context, () {
      // The source capture must include everything the transformed drawing
      // reads. Cropping first and then shrinking the canvas exposes rectangular
      // capture edges inside the toggle's otherwise round track.
      final Matrix4 inverse = Matrix4.copy(before)
        ..multiply(Matrix4.fromFloat64List(context.canvas.getTransform()));
      if (inverse.invert() == 0) return; // A zero-height track draws nothing.
      final Rect bounds =
          context.sampleBounds ??
          (Offset.zero & context.size).inflate(context.sampleMargin);
      backdrop.drawBackdrop(
        context.copyWith(
          sampleBounds: MatrixUtils.transformRect(inverse, bounds),
        ),
      );
    });
  }

  @override
  bool operator ==(Object other) =>
      other is WrappedBackdrop &&
      other.backdrop == backdrop &&
      other.onDraw == onDraw;

  @override
  int get hashCode => Object.hash(backdrop, onDraw);
}
