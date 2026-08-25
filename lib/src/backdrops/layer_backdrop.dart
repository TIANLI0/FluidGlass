import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../backdrop.dart';
import '../glass_layer.dart';

/// Something a [LayerBackdrop] can sample: a captured region of the screen,
/// with a known size and position.
abstract class LayerBackdropSource {
  /// The size of the captured content, in logical pixels.
  Size get sourceSize;

  /// Where the captured content's top-left corner sits, in global coordinates.
  Offset get sourceGlobalOffset;

  /// Whether the source currently has content to draw.
  bool get hasContent;

  /// Draws the captured content with its top-left corner at the canvas origin.
  void drawSource(Canvas canvas, double devicePixelRatio);
}

/// A backdrop backed by a live capture of another part of the screen.
///
/// Wrap the source content in a [BackdropLayer] and hand the same
/// [LayerBackdrop] to any number of glass elements; each one samples the
/// capture at its own position. A [LayerBackdrop] can also be filled in by a
/// glass element itself, via `DrawBackdrop.exportedBackdrop`.
///
/// The source's compositing layer is captured with [OffsetLayer.toImageSync]
/// and the resulting texture is drawn wherever it is sampled, so the capture
/// happens once per frame no matter how many elements consume it.
class LayerBackdrop extends Backdrop with ChangeNotifier {
  LayerBackdrop();

  LayerBackdropSource? _source;

  @override
  bool get isCoordinatesDependent => true;

  @override
  Listenable? get repaintNotifier => this;

  /// Whether a source is currently attached.
  bool get hasSource => _source != null;

  /// Attaches [source] as the content of this backdrop.
  ///
  /// Called by [BackdropLayer] and by glass elements that export themselves.
  void attachSource(LayerBackdropSource source) {
    if (_source != source) {
      _source = source;
      scheduleNotification();
    }
  }

  /// Detaches [source], if it is the current one.
  void detachSource(LayerBackdropSource source) {
    if (_source == source) {
      _source = null;
      scheduleNotification();
    }
  }

  bool _notificationScheduled = false;

  /// Tells consumers that the source repainted, so they pick up the new
  /// content on the next frame.
  ///
  /// Deferred to a post-frame callback because consumers respond by marking
  /// themselves dirty, which is illegal during the paint phase.
  void scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void drawBackdrop(BackdropDrawContext context) {
    final RenderBox? consumer = context.consumer;
    final LayerBackdropSource? source = _source;
    if (consumer == null || source == null) return;
    if (!consumer.attached || !source.hasContent) return;

    // The glass element's origin, expressed in the source's coordinate space.
    final Offset offset = consumer.localToGlobal(Offset.zero) - source.sourceGlobalOffset;

    final Canvas canvas = context.canvas;
    canvas.save();
    final GlassLayerBlock? layerBlock = context.layerBlock;
    if (layerBlock != null) {
      final GlassLayer layer = GlassLayer()..reset(context.size);
      layerBlock(layer);
      final Matrix4? inverse = layer.inverseLinearTransformAtTopLeft();
      if (inverse != null) {
        canvas.transform(inverse.storage);
      }
    }
    canvas.translate(-offset.dx, -offset.dy);
    source.drawSource(canvas, context.devicePixelRatio);
    canvas.restore();
  }
}

/// Marks its subtree as the source of a [LayerBackdrop].
class BackdropLayer extends SingleChildRenderObjectWidget {
  const BackdropLayer({
    super.key,
    required this.backdrop,
    this.pixelRatio,
    super.child,
  });

  final LayerBackdrop backdrop;

  /// Resolution to capture the source at, relative to logical pixels.
  ///
  /// Defaults to the device's pixel ratio. Capturing a large, animating source
  /// costs a full-resolution rasterisation every frame it changes, so this is
  /// the lever to trade sharpness for speed — 0.5 quarters the pixels, and
  /// glass that blurs or shrinks what it samples hides the difference well.
  final double? pixelRatio;

  @override
  RenderBackdropLayer createRenderObject(BuildContext context) {
    return RenderBackdropLayer(backdrop: backdrop, pixelRatio: pixelRatio);
  }

  @override
  void updateRenderObject(BuildContext context, RenderBackdropLayer renderObject) {
    renderObject
      ..backdrop = backdrop
      ..pixelRatio = pixelRatio;
  }
}

/// Captures its subtree into a texture that [LayerBackdrop] consumers sample.
class RenderBackdropLayer extends RenderProxyBox implements LayerBackdropSource {
  RenderBackdropLayer({required LayerBackdrop backdrop, double? pixelRatio})
      : _backdrop = backdrop,
        _pixelRatio = pixelRatio;

  /// See [BackdropLayer.pixelRatio].
  double? get pixelRatio => _pixelRatio;
  double? _pixelRatio;
  set pixelRatio(double? value) {
    if (_pixelRatio == value) return;
    _pixelRatio = value;
    _releaseSnapshot();
    markNeedsPaint();
  }

  LayerBackdrop get backdrop => _backdrop;
  LayerBackdrop _backdrop;
  set backdrop(LayerBackdrop value) {
    if (_backdrop == value) return;
    if (attached) _backdrop.detachSource(this);
    _backdrop = value;
    if (attached) _backdrop.attachSource(this);
    markNeedsPaint();
  }

  // Captured lazily on first request per frame, then reused by every consumer.
  ui.Image? _snapshot;
  double _snapshotPixelRatio = 0.0;
  bool _painted = false;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size get sourceSize => hasSize ? size : Size.zero;

  @override
  Offset get sourceGlobalOffset => localToGlobal(Offset.zero);

  @override
  bool get hasContent => attached && _painted && hasSize && !size.isEmpty;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _backdrop.attachSource(this);
  }

  @override
  void detach() {
    _backdrop.detachSource(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _releaseSnapshot();
    super.paint(context, offset);
    _painted = true;
    _backdrop.scheduleNotification();
  }

  void _releaseSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
    _snapshotPixelRatio = 0.0;
  }

  @override
  void drawSource(Canvas canvas, double devicePixelRatio) {
    final ui.Image? snapshot = _obtainSnapshot(_pixelRatio ?? devicePixelRatio);
    if (snapshot == null) return;
    canvas.drawImageRect(
      snapshot,
      Rect.fromLTWH(0, 0, snapshot.width.toDouble(), snapshot.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  ui.Image? _obtainSnapshot(double devicePixelRatio) {
    if (_snapshot != null && _snapshotPixelRatio == devicePixelRatio) {
      return _snapshot;
    }
    final OffsetLayer? offsetLayer = layer as OffsetLayer?;
    if (offsetLayer == null || !hasSize || size.isEmpty) return null;

    _releaseSnapshot();
    try {
      _snapshot = offsetLayer.toImageSync(
        Offset.zero & size,
        pixelRatio: devicePixelRatio,
      );
      _snapshotPixelRatio = devicePixelRatio;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluid_glass',
          context: ErrorDescription('while capturing a BackdropLayer snapshot'),
        ),
      );
      return null;
    }
    return _snapshot;
  }

  @override
  void dispose() {
    _releaseSnapshot();
    super.dispose();
  }
}

/// A [LayerBackdropSource] fed by a recorded picture rather than a widget
/// subtree, used for `DrawBackdrop.exportedBackdrop`.
class PictureBackdropSource implements LayerBackdropSource {
  ui.Picture? _picture;
  Size _size = Size.zero;
  Offset _globalOffset = Offset.zero;

  @override
  Size get sourceSize => _size;

  @override
  Offset get sourceGlobalOffset => _globalOffset;

  @override
  bool get hasContent => _picture != null && !_size.isEmpty;

  /// Replaces the recorded content.
  void update({required ui.Picture picture, required Size size, required Offset globalOffset}) {
    _picture?.dispose();
    _picture = picture;
    _size = size;
    _globalOffset = globalOffset;
  }

  @override
  void drawSource(Canvas canvas, double devicePixelRatio) {
    final ui.Picture? picture = _picture;
    if (picture == null) return;
    canvas.drawPicture(picture);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
