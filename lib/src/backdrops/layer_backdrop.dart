import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../backdrop.dart';

/// Something a [LayerBackdrop] can sample: a captured region of the screen,
/// with a known size and position.
abstract class LayerBackdropSource {
  /// The size of the captured content, in logical pixels.
  Size get sourceSize;

  /// Where the captured content's top-left corner sits, in global coordinates.
  ///
  /// Only consulted for a source that is not a [RenderObject]; one that is has
  /// a full paint transform, which is read instead so that a source an ancestor
  /// scales, rotates or zooms still lines up. See
  /// [LayerBackdrop.consumerToSourceTransform].
  Offset get sourceGlobalOffset;

  /// Whether the source currently has content to draw.
  bool get hasContent;

  /// Draws the captured content with its top-left corner at the canvas origin.
  ///
  /// [clampMargin] is how far past the content's own bounds the caller's effect
  /// chain will read; a source that can should extend its edge pixels that far
  /// rather than leave transparency there. See
  /// [BackdropDrawContext.sampleMargin].
  ///
  /// [region] is the part of the content, in the content's own coordinates,
  /// that the caller will actually read — already inflated by [clampMargin].
  /// A source free to capture less should capture only that. Null means "no
  /// idea, give me everything".
  void drawSource(Canvas canvas, double devicePixelRatio,
      {double clampMargin, Rect? region});

  /// Discards any cached capture, so the next [drawSource] takes a fresh one.
  void invalidateSnapshot();
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

  /// Whether any glass element is currently sampling this backdrop.
  ///
  /// A consumer subscribes to [repaintNotifier], which is this object, so its
  /// listeners are exactly its consumers.
  bool get hasConsumers => hasListeners;

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

  /// Discards the captured snapshot and tells consumers to repaint, now.
  ///
  /// The source's own `paint` cannot be relied on to notice that its content
  /// changed: `RenderViewport.isRepaintBoundary` is true, so a list scrolling
  /// inside a [BackdropLayer] repaints without its ancestors repainting at all.
  /// The glass over it was left drawing a stale capture — a frozen backdrop
  /// under moving content.
  ///
  /// Called from outside the paint phase (a scroll notification, a
  /// [BackdropLayer.liveness] tick), so consumers can be marked dirty
  /// immediately and repaint in the same frame rather than a frame late.
  void invalidateSource() {
    _source?.invalidateSnapshot();
    if (hasListeners) notifyListeners();
  }

  /// True while a [BackdropLayer] is the source.
  ///
  /// The source subtree is painted into the scene where it sits, and the
  /// documented composition puts the glass over it as a sibling, so what the
  /// compositor has behind the glass *is* this backdrop. A source filled in by
  /// a glass element instead — `DrawBackdrop.exportedBackdrop`, a recorded
  /// picture — is not painted behind anything, so it is false there.
  @override
  bool get isPaintedBehindConsumer => _source is RenderBackdropLayer;

  /// Tells consumers to repaint, keeping the capture.
  ///
  /// For a source whose *content* is unchanged but whose *placement* moved — an
  /// `InteractiveViewer` panning a photo, a page sliding in — where every
  /// consumer has to re-place what it samples but nobody has to re-capture it.
  void notifyConsumers() {
    if (hasListeners) notifyListeners();
  }

  /// The transform from [consumer]'s local coordinates into the source's own.
  ///
  /// The capture is taken in the source's coordinates, so this is what places
  /// it. A plain offset would do for a source that merely sits somewhere, and
  /// that is all this used to compute; a matrix also survives the source (or
  /// the consumer) being scaled or rotated by an ancestor, which is the
  /// difference between glass over an `InteractiveViewer` refracting the photo
  /// and refracting a wrongly-magnified copy of it.
  ///
  /// Null when there is nothing to sample, or when the mapping is degenerate.
  Matrix4? consumerToSourceTransform(RenderBox consumer) {
    final LayerBackdropSource? source = _source;
    if (source == null || !consumer.attached) return null;
    final Matrix4 globalToSource = _sourceToGlobal(source);
    if (globalToSource.invert() == 0.0) return null;
    return globalToSource..multiply(consumer.getTransformTo(null));
  }

  /// How the source's own coordinates map into global ones.
  ///
  /// A source backed by a render object has a real paint transform; anything
  /// else — a recorded picture, a test double — only knows where it sits.
  static Matrix4 _sourceToGlobal(LayerBackdropSource source) {
    // Via `Object` because `RenderObject` is not a subtype of
    // `LayerBackdropSource`, so `is` alone does not promote.
    final Object object = source;
    if (object is RenderObject && object.attached) {
      return object.getTransformTo(null);
    }
    if (object is PictureBackdropSource) {
      return object.globalTransform;
    }
    final Offset offset = source.sourceGlobalOffset;
    return Matrix4.translationValues(offset.dx, offset.dy, 0);
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

    // The glass element's coordinates, expressed in the source's space. This
    // subsumes the element's own layer transform: `getTransformTo` walks
    // through `RenderGlassTransform`, so a scaled or rotated element already
    // has that scale undone here rather than needing a second correction.
    final Matrix4? toSource = consumerToSourceTransform(consumer);
    if (toSource == null) return;
    final Matrix4 toConsumer = Matrix4.copy(toSource);
    if (toConsumer.invert() == 0.0) return;

    // What this element will actually read, in the source's coordinates.
    // Capturing the whole source when a pinned bar samples one strip of it is
    // the single largest cost in a live backdrop, so it is worth telling the
    // source. Under a rotation this is the bounding box, which over-captures a
    // little and stays correct.
    final Rect element = Offset.zero & context.size;
    final Rect region =
        MatrixUtils.transformRect(toSource, element.inflate(context.sampleMargin));

    // A glass element that merely sits somewhere over its source — which is
    // most of them — maps to it by a translation, and both the canvas and the
    // margin have a cheaper, exact answer in that case.
    final Offset? translation = MatrixUtils.getAsTranslation(toConsumer);

    // The clamp margin is quoted in the element's pixels; the source's may be a
    // different size entirely. Take it from what the padding grew to.
    double margin = context.sampleMargin;
    if (margin > 0.0 && translation == null) {
      final Rect unpadded = MatrixUtils.transformRect(toSource, element);
      margin = math.max(
        (region.width - unpadded.width) / 2,
        (region.height - unpadded.height) / 2,
      );
    }

    final Canvas canvas = context.canvas;
    canvas.save();
    if (translation != null) {
      canvas.translate(translation.dx, translation.dy);
    } else {
      canvas.transform(toConsumer.storage);
    }
    source.drawSource(
      canvas,
      context.devicePixelRatio,
      clampMargin: margin,
      region: region,
    );
    canvas.restore();
  }
}

/// Marks its subtree as the source of a [LayerBackdrop].
///
/// Wrap **only what the glass should refract** — the page, the wallpaper, the
/// feed — and put the glass over it as a sibling:
///
/// ```dart
/// Stack(children: [
///   Positioned.fill(child: BackdropLayer(backdrop: backdrop, child: page)),
///   DrawBackdrop(backdrop: backdrop, ...),
/// ])
/// ```
///
/// Glass placed *inside* the subtree would be part of what it is trying to
/// refract, which cannot work and is reported as an error rather than drawn
/// wrong.
///
/// The subtree may be as live as it likes. It is re-captured when it repaints,
/// when a scroll moves inside it, and when anything behind a repaint boundary
/// of its own repaints — the last of those by watching the captured layers,
/// which needs nothing declared. What Flutter does not draw itself, it also
/// cannot capture: a video texture, a camera preview or a native map inside the
/// subtree comes out as a hole.
class BackdropLayer extends StatelessWidget {
  const BackdropLayer({
    super.key,
    required this.backdrop,
    this.pixelRatio,
    this.liveness,
    this.child,
  });

  final LayerBackdrop backdrop;

  /// Resolution to capture the source at, relative to logical pixels.
  ///
  /// Defaults to the device's pixel ratio. Capturing a large, animating source
  /// costs a full-resolution rasterisation every frame it changes, so this is
  /// the lever to trade sharpness for speed — 0.5 quarters the pixels, and
  /// glass that blurs or shrinks what it samples hides the difference well.
  ///
  /// It is a separate decision from [GlassQuality], on purpose. The tier
  /// governs what each *element* draws — dropping to [GlassQuality.plain]
  /// removes the refraction, a fragment pass over the element's own texture —
  /// while this governs what the *source* costs to capture, which for a
  /// backdrop that changes every frame is the larger of the two by a wide
  /// margin. A slow device wants both, and only this one is left to the app,
  /// because halving the capture is a visible choice on a still backdrop where
  /// it buys nothing per frame:
  ///
  /// ```dart
  /// BackdropLayer(
  ///   backdrop: backdrop,
  ///   pixelRatio: GlassDeviceTier.instance.quality == GlassQuality.plain
  ///       ? MediaQuery.devicePixelRatioOf(context) * 0.5
  ///       : null,
  ///   child: feed,
  /// )
  /// ```
  final double? pixelRatio;

  /// Something that ticks whenever the source's content changes.
  ///
  /// Optional, and rarely needed. A source made of ordinary widgets is handled
  /// on its own: its repaints reach this render object, a scroll inside it is
  /// picked up from the notifications it sends, and anything that repaints
  /// behind a repaint boundary of its own — a `RepaintBoundary`-wrapped
  /// animation, a custom painter with its own ticker — is caught by watching
  /// the captured layers themselves.
  ///
  /// That watch costs a frame of latency, though, because it can only run once
  /// a frame has been drawn. Pass whatever already knows the content is about
  /// to change — an `AnimationController`, a `ValueNotifier`,
  /// a `Listenable.merge` — and the capture is dropped *before* the frame is
  /// built instead, so the glass and its backdrop move together on the very
  /// first frame rather than the second.
  final Listenable? liveness;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget? content = child;
    if (content != null) {
      // Inside the render object, so the capture still includes the child, but
      // above the child, so notifications from it bubble through here.
      //
      // A scrolling source is the case that made this necessary:
      // `RenderViewport` is a repaint boundary, so it repaints without its
      // ancestors repainting, and the capture would never be invalidated.
      content = NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification ||
              notification is OverscrollNotification) {
            backdrop.invalidateSource();
          }
          // Never absorbed: an ancestor may well want these too.
          return false;
        },
        child: content,
      );
    }
    return _BackdropLayerHost(
      backdrop: backdrop,
      pixelRatio: pixelRatio,
      liveness: liveness,
      child: content,
    );
  }
}

class _BackdropLayerHost extends SingleChildRenderObjectWidget {
  const _BackdropLayerHost({
    required this.backdrop,
    required this.pixelRatio,
    required this.liveness,
    super.child,
  });

  final LayerBackdrop backdrop;
  final double? pixelRatio;
  final Listenable? liveness;

  @override
  RenderBackdropLayer createRenderObject(BuildContext context) {
    return RenderBackdropLayer(
      backdrop: backdrop,
      pixelRatio: pixelRatio,
      liveness: liveness,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBackdropLayer renderObject) {
    renderObject
      ..backdrop = backdrop
      ..pixelRatio = pixelRatio
      ..liveness = liveness;
  }
}

/// Captures its subtree into a texture that [LayerBackdrop] consumers sample.
class RenderBackdropLayer extends RenderProxyBox implements LayerBackdropSource {
  RenderBackdropLayer({
    required LayerBackdrop backdrop,
    double? pixelRatio,
    Listenable? liveness,
  })  : _backdrop = backdrop,
        _pixelRatio = pixelRatio,
        _liveness = liveness;

  /// See [BackdropLayer.liveness].
  Listenable? get liveness => _liveness;
  Listenable? _liveness;
  set liveness(Listenable? value) {
    if (_liveness == value) return;
    if (attached) _liveness?.removeListener(_onLiveness);
    _liveness = value;
    if (attached) _liveness?.addListener(_onLiveness);
  }

  void _onLiveness() => _backdrop.invalidateSource();

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
    _watchSubtree();
    markNeedsPaint();
  }

  // Captured lazily on first request per frame, then reused by every consumer.
  /// Captures taken since the last invalidation, newest last.
  ///
  /// Keyed by the region they cover: a consumer is served by any capture that
  /// contains what it needs.
  final List<_Capture> _captures = <_Capture>[];

  /// Past this many distinct regions in one frame, capturing the whole source
  /// once is cheaper than capturing each region.
  ///
  /// A screen of app chrome asks for two or three strips. A screen made of
  /// twenty glass tiles would otherwise pay twenty pipeline flushes, which is
  /// the thing being avoided in the first place.
  static const int _maxRegions = 3;

  /// How many times this source has been rasterised, in debug builds.
  ///
  /// Each one is an `OffsetLayer.toImageSync` — a synchronous rasterisation
  /// that flushes the pipeline mid-frame, and by a wide margin the most
  /// expensive thing a live backdrop does. Tests watch it to pin that a
  /// scrolling source is captured once per region per frame and no more.
  @visibleForTesting
  int debugCaptureCount = 0;

  /// Latched once [_maxRegions] is exceeded, so the decision survives the
  /// frame that discovered it. Cleared when the source is resized.
  bool _captureWholeSource = false;
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
    _liveness?.addListener(_onLiveness);
    _backdrop.attachSource(this);
    _watchSubtree();
  }

  @override
  void detach() {
    _liveness?.removeListener(_onLiveness);
    _backdrop.detachSource(this);
    super.detach();
  }

  Size _lastCapturedSize = Size.zero;

  /// True while this render object is inside its own `paint`, so a consumer
  /// asking for the capture from in there is asking from inside the subtree
  /// being captured. See [_reportNestedConsumer].
  bool _painting = false;

  /// Latched once a consumer has been caught painting inside the source, to
  /// stop the two from driving each other for the lifetime of the app.
  bool _hasNestedConsumer = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size != _lastCapturedSize) {
      _lastCapturedSize = size;
      _captureWholeSource = false;
    }
    _releaseSnapshot();
    _painting = true;
    try {
      super.paint(context, offset);
    } finally {
      _painting = false;
    }
    _painted = true;
    _paintedThisFrame = true;
    if (!_hasNestedConsumer) _backdrop.scheduleNotification();
    _watchSubtree();
  }

  void _releaseSnapshot() {
    for (final _Capture capture in _captures) {
      capture.image.dispose();
    }
    _captures.clear();
  }

  @override
  void invalidateSnapshot() {
    _invalidatedBySignal = true;
    _releaseSnapshot();
  }

  // ---------------------------------------------------------------------------
  // Noticing that the source changed without this render object repainting.
  //
  // `markNeedsPaint` stops at the nearest repaint boundary, so anything inside
  // the source that has one of its own — an explicit `RepaintBoundary`, a
  // viewport, a widget that wraps its animation in one — repaints while this
  // object sleeps through it. Scrolling is caught by `BackdropLayer`'s
  // notification listener and a source that knows when it changes can say so
  // through `liveness`; everything else used to leave the glass showing a
  // frozen capture of a moving background.
  //
  // So the layers themselves are asked. A repaint replaces the `ui.Picture` of
  // every `PictureLayer` it touches, and a retained subtree keeps the same ones
  // — which makes a walk of the captured layer tree an exact answer to "did
  // anything in here repaint", for the price of visiting a few dozen layers on
  // frames that were happening anyway.
  // ---------------------------------------------------------------------------

  bool _subtreeWatchPending = false;

  /// The identities of the pictures in the captured layer tree, last frame.
  List<int> _layerFingerprint = <int>[];
  List<int> _nextFingerprint = <int>[];
  /// False until the first check has recorded a baseline; there is nothing to
  /// compare a first reading against.
  bool _watchInitialised = false;

  /// Whether something already told the consumers about this frame.
  ///
  /// A scroll notification, a [BackdropLayer.liveness] tick or this render
  /// object's own repaint all reach the consumers *before* or *during* the
  /// frame, so they sampled the new content in it. Noticing the same change
  /// again afterwards would only mark them dirty for a frame that has nothing
  /// new in it — and would keep the tree permanently dirty, one repaint behind
  /// a scroll that has already finished.
  bool _invalidatedBySignal = false;
  bool _paintedThisFrame = false;

  /// Where the source sat last frame, so a source that *moves* under pinned
  /// glass — a page sliding in, an `InteractiveViewer` panning — re-places what
  /// its consumers sample without re-capturing anything.
  Matrix4? _lastSourceTransform;

  /// Re-arms the check for the next frame.
  ///
  /// Rides on frames that are happening anyway: a post-frame callback does not
  /// schedule a frame, so an idle app stays idle and stops checking.
  void _watchSubtree() {
    if (_subtreeWatchPending || !attached || _hasNestedConsumer) return;
    if (!_backdrop.hasConsumers) return;
    _subtreeWatchPending = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _subtreeWatchPending = false;
      if (!attached) return;
      _checkSubtree();
      _watchSubtree();
    });
  }

  void _checkSubtree() {
    // Consumed whether or not the rest of the check runs, so a frame that was
    // already accounted for cannot suppress a later one.
    final bool alreadyHandled = _invalidatedBySignal || _paintedThisFrame;
    _invalidatedBySignal = false;
    _paintedThisFrame = false;
    if (!_backdrop.hasConsumers || _hasNestedConsumer) return;

    // The children, not this layer itself: its own offset is where the source
    // *sits*, which is placement rather than content and is tracked separately
    // — counting it would throw the capture away every time the source moved.
    final List<int> next = _nextFingerprint..clear();
    for (Layer? child = layer?.firstChild; child != null; child = child.nextSibling) {
      _collectFingerprint(child, next);
    }
    final bool first = !_watchInitialised;
    bool contentChanged = !first && next.length != _layerFingerprint.length;
    if (!first && !contentChanged) {
      for (int i = 0; i < next.length; i++) {
        if (next[i] != _layerFingerprint[i]) {
          contentChanged = true;
          break;
        }
      }
    }
    // Swap rather than copy: two lists that keep their capacity, so a source
    // watched for the life of the app allocates nothing per frame.
    _nextFingerprint = _layerFingerprint;
    _layerFingerprint = next;

    final Matrix4? transform = attached ? getTransformTo(null) : null;
    final bool moved = !first && _lastSourceTransform != transform;
    _lastSourceTransform = transform;
    _watchInitialised = true;

    if (contentChanged && !alreadyHandled) {
      _backdrop.invalidateSource();
      // Our own invalidation is not the signal that suppresses the next check.
      _invalidatedBySignal = false;
    } else if (moved) {
      // The capture is taken in the source's own coordinates, so it survives
      // the source moving; only the consumers' placement of it is stale.
      _backdrop.notifyConsumers();
    }
  }

  /// Appends an identity for every picture in [layer]'s subtree.
  ///
  /// Container boundaries go in too, so a layer appearing or disappearing reads
  /// as a change even when no picture was touched.
  static void _collectFingerprint(Layer? layer, List<int> out) {
    if (layer == null) return;
    if (layer is PictureLayer) {
      out.add(identityHashCode(layer.picture));
      return;
    }
    if (layer is ContainerLayer) {
      out.add(_containerMark);
      // What the layer itself does, as well as what is under it. A repaint
      // boundary that repaints hands `pushOpacity` and friends the layer they
      // used last time, so an animated opacity or transform between two
      // boundaries can change with every picture underneath it staying put.
      switch (layer) {
        case OpacityLayer(:final int? alpha):
          out.add(alpha ?? -1);
        case TransformLayer(:final Matrix4? transform):
          out.add(transform?.hashCode ?? 0);
        case ClipRectLayer(:final Rect? clipRect):
          out.add(clipRect?.hashCode ?? 0);
        case ClipRRectLayer(:final RRect? clipRRect):
          out.add(clipRRect?.hashCode ?? 0);
        case ColorFilterLayer(:final ColorFilter? colorFilter):
          out.add(colorFilter?.hashCode ?? 0);
        case OffsetLayer(:final Offset offset):
          out.add(offset.hashCode);
        default:
          break;
      }
      for (Layer? child = layer.firstChild; child != null; child = child.nextSibling) {
        _collectFingerprint(child, out);
      }
      out.add(_containerEnd);
      return;
    }
    // A texture or platform view: content the engine owns, which can change
    // without any Flutter-side repaint. `toImageSync` cannot rasterise it
    // either, so there is nothing useful to do beyond saying so.
    out.add(identityHashCode(layer.runtimeType));
    assert(_warnUncapturable(layer));
  }

  static const int _containerMark = -1;
  static const int _containerEnd = -2;

  static bool _warnedUncapturable = false;

  static bool _warnUncapturable(Layer layer) {
    if (layer is! TextureLayer && layer is! PlatformViewLayer) return true;
    if (_warnedUncapturable) return true;
    _warnedUncapturable = true;
    FlutterError.reportError(FlutterErrorDetails(
      exception: FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A BackdropLayer contains content Flutter cannot capture.'),
        ErrorDescription(
          'The source subtree holds a ${layer.runtimeType}, which is drawn by '
          'the platform rather than by Flutter — a video texture, a camera '
          'preview, a native map or web view. Capturing a layer tree does not '
          'include those, so glass over this source refracts a hole where they '
          'are.',
        ),
        ErrorHint(
          'Put the glass over something Flutter draws, or place the platform '
          'view outside the BackdropLayer and accept that the glass will not '
          'refract it.',
        ),
      ]),
      library: 'fluid_glass',
      context: ErrorDescription('while watching a BackdropLayer source'),
    ));
    return true;
  }

  /// Reports a consumer that sits inside the very subtree it is sampling.
  ///
  /// `BackdropLayer(child: everything)`, with the glass somewhere in
  /// `everything`, is the natural thing to write and cannot work: the capture
  /// is taken while the source is halfway through painting, so the layer holds
  /// no finished picture yet, and the glass marking itself dirty marks the
  /// source dirty too — the two then repaint each other every frame, forever.
  void _reportNestedConsumer() {
    if (_hasNestedConsumer) return;
    _hasNestedConsumer = true;
    FlutterError.reportError(FlutterErrorDetails(
      exception: FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A glass element is sampling a BackdropLayer it is '
            'inside of.'),
        ErrorDescription(
          'DrawBackdrop asked this BackdropLayer for its capture while the '
          'BackdropLayer was painting, which means the glass is part of the '
          'subtree it is trying to refract. Glass cannot refract itself: the '
          'capture would contain the glass, and the two would repaint each '
          'other on every frame.',
        ),
        ErrorHint(
          'Wrap only the content the glass should refract in the '
          'BackdropLayer, and put the glass over it as a sibling:\n'
          '  Stack(children: [\n'
          '    Positioned.fill(child: BackdropLayer(backdrop: b, child: page)),\n'
          '    DrawBackdrop(backdrop: b, ...),\n'
          '  ])',
        ),
      ]),
      library: 'fluid_glass',
      context: ErrorDescription('while drawing a glass element'),
    ));
  }

  @override
  void drawSource(Canvas canvas, double devicePixelRatio,
      {double clampMargin = 0.0, Rect? region}) {
    if (_painting) {
      _reportNestedConsumer();
      return;
    }
    // Someone is sampling, so keep watching for changes this render object's
    // own paint would not notice.
    _watchSubtree();
    final double ratio = _pixelRatio ?? devicePixelRatio;
    final _Capture? capture = _obtainCapture(ratio, region);
    if (capture == null) return;

    final ui.Image image = capture.image;
    final Rect dst = capture.region;
    final double iw = image.width.toDouble();
    final double ih = image.height.toDouble();
    final Paint paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), dst, paint);
    if (clampMargin <= 0.0) return;

    // Extend the outermost row and column outwards, which is what
    // `TileMode.clamp` would do if this were a shader. Without it a blur
    // reading past the capture mixes in transparency, and a bar flush with the
    // top of the screen gets a dark fringe instead of blurred content.
    //
    // Only where the *source itself* ends, though. An edge of the capture that
    // sits inside the source has real neighbours, already included because the
    // requested region was inflated by this same margin — stretching there
    // would smear over them.
    final Rect bounds = Offset.zero & size;
    final double m = clampMargin;
    final double sx = iw / dst.width;
    final double sy = ih / dst.height;
    void strip(Rect src, Rect at) => canvas.drawImageRect(image, src, at, paint);

    final bool atLeft = dst.left <= bounds.left;
    final bool atTop = dst.top <= bounds.top;
    final bool atRight = dst.right >= bounds.right;
    final bool atBottom = dst.bottom >= bounds.bottom;

    if (atTop) {
      strip(Rect.fromLTWH(0, 0, iw, sy),
          Rect.fromLTRB(dst.left, dst.top - m, dst.right, dst.top));
    }
    if (atBottom) {
      strip(Rect.fromLTWH(0, ih - sy, iw, sy),
          Rect.fromLTRB(dst.left, dst.bottom, dst.right, dst.bottom + m));
    }
    if (atLeft) {
      strip(Rect.fromLTWH(0, 0, sx, ih),
          Rect.fromLTRB(dst.left - m, dst.top, dst.left, dst.bottom));
    }
    if (atRight) {
      strip(Rect.fromLTWH(iw - sx, 0, sx, ih),
          Rect.fromLTRB(dst.right, dst.top, dst.right + m, dst.bottom));
    }
    if (atTop && atLeft) {
      strip(Rect.fromLTWH(0, 0, sx, sy),
          Rect.fromLTRB(dst.left - m, dst.top - m, dst.left, dst.top));
    }
    if (atTop && atRight) {
      strip(Rect.fromLTWH(iw - sx, 0, sx, sy),
          Rect.fromLTRB(dst.right, dst.top - m, dst.right + m, dst.top));
    }
    if (atBottom && atLeft) {
      strip(Rect.fromLTWH(0, ih - sy, sx, sy),
          Rect.fromLTRB(dst.left - m, dst.bottom, dst.left, dst.bottom + m));
    }
    if (atBottom && atRight) {
      strip(Rect.fromLTWH(iw - sx, ih - sy, sx, sy),
          Rect.fromLTRB(dst.right, dst.bottom, dst.right + m, dst.bottom + m));
    }
  }

  /// A capture covering [region], reusing one from this frame when possible.
  _Capture? _obtainCapture(double devicePixelRatio, Rect? region) {
    final OffsetLayer? offsetLayer = layer as OffsetLayer?;
    if (offsetLayer == null || !hasSize || size.isEmpty) return null;
    final Rect bounds = Offset.zero & size;

    Rect wanted = bounds;
    if (region != null && !_captureWholeSource) {
      final Rect clipped = region.intersect(bounds);
      if (clipped.isEmpty) return null;
      wanted = clipped;
    }

    for (final _Capture capture in _captures) {
      if (capture.pixelRatio == devicePixelRatio &&
          capture.region.contains(wanted.topLeft) &&
          capture.region.contains(wanted.bottomRight - const Offset(0.01, 0.01))) {
        return capture;
      }
    }

    if (_captures.length >= _maxRegions && wanted != bounds) {
      // Too many distinct regions: stop splitting and take the whole thing.
      // The latch is what matters — from the next frame there is one capture
      // instead of many.
      //
      // The captures already taken this frame are deliberately *not* disposed
      // here. They have been recorded into the canvas by the consumers that
      // asked for them, and disposing an image mid-frame makes those draws
      // render as nothing: the first consumers on screen went black while the
      // later ones were fine.
      _captureWholeSource = true;
      wanted = bounds;
    }

    try {
      final ui.Image image =
          offsetLayer.toImageSync(wanted, pixelRatio: devicePixelRatio);
      assert(() {
        debugCaptureCount += 1;
        return true;
      }());
      final _Capture capture = _Capture(
        image: image,
        region: wanted,
        pixelRatio: devicePixelRatio,
      );
      _captures.add(capture);
      return capture;
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
  Matrix4 _globalTransform = Matrix4.identity();

  @override
  Size get sourceSize => _size;

  @override
  Offset get sourceGlobalOffset =>
      MatrixUtils.transformPoint(_globalTransform, Offset.zero);

  /// How the recorded picture's own coordinates map into global ones.
  ///
  /// The whole transform, not just where the exporting element sits: an
  /// element that scales itself records its picture unscaled, so glass nested
  /// inside it has to undo exactly the scale between the two or it refracts a
  /// wrongly-sized copy.
  Matrix4 get globalTransform => _globalTransform;

  @override
  bool get hasContent => _picture != null && !_size.isEmpty;

  /// Replaces the recorded content.
  void update({
    required ui.Picture picture,
    required Size size,
    required Matrix4 globalTransform,
  }) {
    _picture?.dispose();
    _picture = picture;
    _size = size;
    _globalTransform = globalTransform;
  }

  @override
  void drawSource(Canvas canvas, double devicePixelRatio,
      {double clampMargin = 0.0, Rect? region}) {
    final ui.Picture? picture = _picture;
    if (picture == null) return;
    // A recorded picture has no edge pixels to extend; whatever it drew is all
    // there is.
    canvas.drawPicture(picture);
  }

  @override
  void invalidateSnapshot() {
    // Nothing to invalidate: the picture *is* the content, replaced wholesale
    // by [update] rather than cached from something else.
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}

/// One capture of a [RenderBackdropLayer], and the region of it that covers.
class _Capture {
  _Capture({
    required this.image,
    required this.region,
    required this.pixelRatio,
  });

  final ui.Image image;

  /// The part of the source this covers, in the source's own coordinates.
  final Rect region;

  final double pixelRatio;
}
