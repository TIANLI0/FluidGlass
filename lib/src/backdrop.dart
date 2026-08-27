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
    this.sampleMargin = 0.0,
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
  ///
  /// [LayerBackdrop] does not read it: the transform between a consumer and its
  /// source already contains this one, because the element's reported position
  /// is taken through the render object that applies it. It is here for a
  /// backdrop of your own that needs to know.
  final GlassLayerBlock? layerBlock;

  /// The backdrop being drawn, so an `onDrawBackdrop` callback can draw it a
  /// second time — into an offscreen canvas, for instance.
  final Backdrop backdrop;

  /// How far beyond the element, on every side, the effect chain will read.
  ///
  /// A blur reaches outwards for pixels, so it is handed a layer inflated by
  /// this much. A backdrop that only covers the element itself leaves the rest
  /// of that layer transparent, and the blur mixes the transparency in — a dark
  /// fringe along any edge where the glass meets the end of its source, which
  /// is every screen edge for a piece of app chrome. Fill the inflated area
  /// instead, by extending the edge pixels outwards.
  final double sampleMargin;

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
      sampleMargin: sampleMargin,
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

  /// Whether this backdrop's content is *already painted behind* the glass
  /// element, rather than being something the element has to draw for itself.
  ///
  /// When it is, the element has a second way to draw it: hand the effect chain
  /// to the compositor as a [BackdropFilterLayer] — Flutter's own
  /// `BackdropFilter` — and let the engine filter what is behind in place. That
  /// costs no capture at all, which is the whole cost of a live backdrop, and
  /// it is what [GlassQuality.plain] does.
  ///
  /// False for a backdrop the element draws itself — a `CanvasBackdrop`, a
  /// recorded picture, anything wrapped or combined — because there is nothing
  /// behind the element for the engine to filter.
  bool get isPaintedBehindConsumer => false;

  /// Whether this backdrop can *only* be filtered by the compositor.
  ///
  /// True means the backdrop hands the element no pixels of its own — see
  /// [NativeBackdrop] — so an element on it is pinned to [GlassQuality.plain]
  /// however capable the device is: there is no texture for the lens or the
  /// shaded rim to work on, and letting the element sample would draw nothing.
  bool get isCompositorOnly => false;
}
