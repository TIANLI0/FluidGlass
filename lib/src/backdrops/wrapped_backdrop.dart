import 'package:flutter/foundation.dart';

import '../backdrop.dart';

/// Wraps another backdrop so its drawing can be transformed or decorated.
///
/// [onDraw] is handed a callback that draws the wrapped backdrop; it may set up
/// the canvas around that call, which is how a slider or toggle squashes the
/// track its thumb refracts.
class WrappedBackdrop extends Backdrop {
  const WrappedBackdrop(this.backdrop, this.onDraw);

  final Backdrop backdrop;

  final void Function(BackdropDrawContext context, void Function() drawBackdrop) onDraw;

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
    onDraw(context, () => backdrop.drawBackdrop(context));
  }

  @override
  bool operator ==(Object other) =>
      other is WrappedBackdrop && other.backdrop == backdrop && other.onDraw == onDraw;

  @override
  int get hashCode => Object.hash(backdrop, onDraw);
}
