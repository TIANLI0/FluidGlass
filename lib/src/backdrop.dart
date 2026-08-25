import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'glass_layer.dart';

/// Everything a [Backdrop] needs in order to draw itself into a glass element.
class BackdropDrawContext {
  BackdropDrawContext({
    required this.canvas,
    required this.size,
    required this.textDirection,
    required this.devicePixelRatio,
    required this.consumer,
    required this.layerBlock,
    required this.backdrop,
  });

  /// The canvas to draw into. Its origin is the glass element's top-left
  /// corner.
  final Canvas canvas;

  /// The size of the glass element, in logical pixels.
  final Size size;

  final TextDirection textDirection;

  final double devicePixelRatio;

  /// The render object of the glass element that is consuming this backdrop, or
  /// null when the backdrop does not depend on coordinates.
  final RenderBox? consumer;

  /// The transform applied to the glass element, so coordinate-dependent
  /// backdrops can counteract it.
  final GlassLayerBlock? layerBlock;

  /// The backdrop being drawn, so an `onDrawBackdrop` callback can draw it a
  /// second time — into an offscreen canvas, for instance.
  final Backdrop backdrop;

  /// A copy of this context that draws into [canvas] instead.
  BackdropDrawContext copyWith({Canvas? canvas}) {
    return BackdropDrawContext(
      canvas: canvas ?? this.canvas,
      size: size,
      textDirection: textDirection,
      devicePixelRatio: devicePixelRatio,
      consumer: consumer,
      layerBlock: layerBlock,
      backdrop: backdrop,
    );
  }
}

/// A source of pixels that a glass element refracts, blurs and tints.
abstract class Backdrop {
  const Backdrop();

  /// Whether this backdrop needs to know where the glass element sits in order
  /// to draw itself. Coordinate-dependent backdrops are handed a
  /// [BackdropDrawContext.consumer].
  bool get isCoordinatesDependent;

  /// Draws the backdrop with its origin aligned to the glass element's
  /// top-left corner.
  void drawBackdrop(BackdropDrawContext context);

  /// Notifies when this backdrop's content changes, so glass elements sampling
  /// it can repaint. Null for backdrops that never change on their own.
  Listenable? get repaintNotifier => null;
}
