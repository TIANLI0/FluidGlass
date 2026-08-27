import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'backdrop.dart';
import 'backdrop_effect_scope.dart';
import 'backdrops/layer_backdrop.dart';
import 'glass_layer.dart';
import 'highlight/highlight.dart';
import 'internal/glass_painters.dart';
import 'internal/shader_programs.dart';
import 'quality/glass_device_tier.dart';
import 'quality/glass_quality.dart';
import 'shadow/shadow.dart';
import 'shapes/glass_outline.dart';
import 'shapes/rectangle_corner_radii.dart';
import 'shapes/rounded_rectangular_shape.dart';

/// Returns the shape of a glass element. Read once per paint, so it may depend
/// on animations.
typedef GlassShapeGetter = RoundedRectangularShape Function();

/// Declares the effects applied to a glass element's backdrop.
typedef BackdropEffectsBuilder = void Function(BackdropEffectScope scope);

/// Returns the rim of a glass element, or null for none.
typedef HighlightGetter = Highlight? Function();

/// Returns the drop shadow of a glass element, or null for none.
typedef GlassShadowGetter = GlassShadow? Function();

/// Returns the inner shadow of a glass element, or null for none.
typedef GlassInnerShadowGetter = GlassInnerShadow? Function();

/// Draws into a glass element, with the canvas origin at its top-left corner.
typedef GlassDrawCallback = void Function(Canvas canvas, Size size);

/// Wraps the drawing of the backdrop, so it can be transformed first.
typedef OnDrawBackdropCallback = void Function(
  BackdropDrawContext context,
  void Function() drawBackdrop,
);

Highlight? _defaultHighlight() => Highlight.standard;
GlassShadow? _defaultShadow() => GlassShadow.standard;

/// Renders [child] as a piece of liquid glass over [backdrop].
///
/// The Flutter analogue of `Modifier.drawBackdrop(...)` from `Backdrop`. The
/// drawing order is: drop shadow, [onDrawBehind], the
/// filtered backdrop, [onDrawSurface], [child], [onDrawFront], the highlight
/// rim, and finally the inner shadow. Everything from [onDrawBehind] through
/// [onDrawFront] is clipped to [shape].
///
/// [shape], [effects], [highlight], [shadow], [innerShadow] and [layerBlock]
/// are all evaluated during paint. Pass a [repaint] listenable (an
/// [Animation], a [ChangeNotifier], ...) so the element repaints when the values
/// they read change, without rebuilding the widget tree.
class DrawBackdrop extends StatelessWidget {
  const DrawBackdrop({
    super.key,
    required this.backdrop,
    required this.shape,
    required this.effects,
    this.highlight = _defaultHighlight,
    this.shadow = _defaultShadow,
    this.innerShadow,
    this.layerBlock,
    this.exportedBackdrop,
    this.onDrawBehind,
    this.onDrawBackdrop,
    this.onDrawSurface,
    this.onDrawFront,
    this.isolateSurface = true,
    this.quality,
    this.repaint,
    this.child,
  });

  /// A glass element with no rim, drop shadow or inner shadow.
  ///
  /// The analogue of `Modifier.drawPlainBackdrop(...)`.
  const DrawBackdrop.plain({
    super.key,
    required this.backdrop,
    required this.shape,
    required this.effects,
    this.layerBlock,
    this.exportedBackdrop,
    this.onDrawBehind,
    this.onDrawBackdrop,
    this.onDrawSurface,
    this.onDrawFront,
    this.isolateSurface = true,
    this.quality,
    this.repaint,
    this.child,
  })  : highlight = null,
        shadow = null,
        innerShadow = null;

  /// What the glass refracts.
  final Backdrop backdrop;

  /// The outline of the glass element.
  final GlassShapeGetter shape;

  /// The filters applied to the backdrop, in order.
  final BackdropEffectsBuilder effects;

  final HighlightGetter? highlight;
  final GlassShadowGetter? shadow;
  final GlassInnerShadowGetter? innerShadow;

  /// Transforms the element, and counter-transforms what it refracts.
  final GlassLayerBlock? layerBlock;

  /// A [LayerBackdrop] to fill in with this element's own drawing, so nested
  /// glass can refract it.
  final LayerBackdrop? exportedBackdrop;

  final GlassDrawCallback? onDrawBehind;
  final OnDrawBackdropCallback? onDrawBackdrop;
  final GlassDrawCallback? onDrawSurface;
  final GlassDrawCallback? onDrawFront;

  /// Whether [onDrawSurface] gets an isolating save-layer, so blend modes it
  /// uses composite against the refracted backdrop alone.
  ///
  /// A surface that only paints with [BlendMode.srcOver] produces identical
  /// pixels without the layer; pass false to skip an offscreen pass per paint.
  final bool isolateSurface;

  /// How much of the liquid-glass look to draw, pinned for this element alone.
  ///
  /// Null — the default — means the nearest [GlassQualityScope] decides, and
  /// failing that [GlassDeviceTier.instance], which classifies the device. Pin
  /// a tier here for an element that should keep its refraction whatever the
  /// rest of the app does, or give one up unconditionally.
  final GlassQuality? quality;

  /// Repaints the element whenever it notifies.
  final Listenable? repaint;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Widget core = _DrawBackdropCore(
      backdrop: backdrop,
      shape: shape,
      effects: effects,
      highlight: highlight,
      shadow: shadow,
      innerShadow: innerShadow,
      layerBlock: layerBlock,
      exportedBackdrop: exportedBackdrop,
      onDrawBehind: onDrawBehind,
      onDrawBackdrop: onDrawBackdrop,
      onDrawSurface: onDrawSurface,
      onDrawFront: onDrawFront,
      isolateSurface: isolateSurface,
      quality: quality ?? GlassQualityScope.maybeOf(context),
      repaint: repaint,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      // Sibling glass in the same `BackdropGroup` shares one read of the
      // backdrop instead of each taking its own. Only the native path can use
      // it; looking it up costs an inherited-widget dependency either way.
      backdropGroupKey: BackdropGroup.of(context)?.backdropKey,
      child: child,
    );
    if (layerBlock == null) return core;
    // The layer block lives in an ancestor render object so the element's
    // reported position already includes its transform, which is what the
    // backdrop sampling reads.
    return _GlassTransform(layerBlock: layerBlock!, repaint: repaint, child: core);
  }
}

class _GlassTransform extends SingleChildRenderObjectWidget {
  const _GlassTransform({required this.layerBlock, this.repaint, super.child});

  final GlassLayerBlock layerBlock;
  final Listenable? repaint;

  @override
  RenderGlassTransform createRenderObject(BuildContext context) {
    return RenderGlassTransform(layerBlock: layerBlock, repaint: repaint);
  }

  @override
  void updateRenderObject(BuildContext context, RenderGlassTransform renderObject) {
    renderObject
      ..layerBlock = layerBlock
      ..repaint = repaint;
  }
}

/// Applies a [GlassLayerBlock]'s transform and opacity to its child.
class RenderGlassTransform extends RenderProxyBox {
  RenderGlassTransform({required GlassLayerBlock layerBlock, Listenable? repaint})
      : _layerBlock = layerBlock,
        _repaint = repaint;

  GlassLayerBlock get layerBlock => _layerBlock;
  GlassLayerBlock _layerBlock;
  set layerBlock(GlassLayerBlock value) {
    if (_layerBlock == value) return;
    _layerBlock = value;
    markNeedsPaint();
  }

  Listenable? get repaint => _repaint;
  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (_repaint == value) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  final GlassLayer _layer = GlassLayer();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  GlassLayer _evaluate() {
    _layer.reset(hasSize ? size : Size.zero);
    _layerBlock(_layer);
    return _layer;
  }

  @override
  bool get alwaysNeedsCompositing => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final GlassLayer layer = _evaluate();
    final double alpha = layer.alpha.clamp(0.0, 1.0);
    if (alpha <= 0.0) return;

    void paintChild(PaintingContext context, Offset offset) {
      if (alpha >= 1.0) {
        super.paint(context, offset);
      } else {
        _opacityLayer.layer = context.pushOpacity(
          offset,
          (alpha * 255).round(),
          super.paint,
          oldLayer: _opacityLayer.layer,
        );
      }
    }

    if (!layer.hasTransform) {
      paintChild(context, offset);
      return;
    }
    // The transform has to become a real layer whenever the fade does.
    // `pushOpacity` appends a layer to the enclosing *container* layer, which
    // never sees a matrix that `pushTransform` applied straight to the canvas
    // — so an element that scaled and faded at the same time snapped to full
    // size the instant its alpha left 1.0, and snapped back when it returned.
    // A menu blooming out of its anchor flashed twice per open/close because
    // of it.
    _transformLayer.layer = context.pushTransform(
      needsCompositing || alpha < 1.0,
      offset,
      layer.toMatrix(),
      paintChild,
      oldLayer: _transformLayer.layer,
    );
  }

  final LayerHandle<TransformLayer> _transformLayer = LayerHandle<TransformLayer>();
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final GlassLayer layer = _evaluate();
    if (layer.hasTransform) {
      transform.multiply(layer.toMatrix());
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // As with RenderTransform: only the transformed child is asked, because the
    // untransformed bounds of this box are not meaningful.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final GlassLayer layer = _evaluate();
    if (!layer.hasTransform) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: layer.toMatrix(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    _opacityLayer.layer = null;
    super.dispose();
  }
}

class _DrawBackdropCore extends SingleChildRenderObjectWidget {
  const _DrawBackdropCore({
    required this.backdrop,
    required this.shape,
    required this.effects,
    required this.highlight,
    required this.shadow,
    required this.innerShadow,
    required this.layerBlock,
    required this.exportedBackdrop,
    required this.onDrawBehind,
    required this.onDrawBackdrop,
    required this.onDrawSurface,
    required this.onDrawFront,
    required this.isolateSurface,
    required this.quality,
    required this.repaint,
    required this.textDirection,
    required this.backdropGroupKey,
    super.child,
  });

  final Backdrop backdrop;
  final GlassShapeGetter shape;
  final BackdropEffectsBuilder effects;
  final HighlightGetter? highlight;
  final GlassShadowGetter? shadow;
  final GlassInnerShadowGetter? innerShadow;
  final GlassLayerBlock? layerBlock;
  final LayerBackdrop? exportedBackdrop;
  final GlassDrawCallback? onDrawBehind;
  final OnDrawBackdropCallback? onDrawBackdrop;
  final GlassDrawCallback? onDrawSurface;
  final GlassDrawCallback? onDrawFront;
  final bool isolateSurface;
  final GlassQuality? quality;
  final Listenable? repaint;
  final TextDirection textDirection;
  final BackdropKey? backdropGroupKey;

  @override
  RenderDrawBackdrop createRenderObject(BuildContext context) {
    return RenderDrawBackdrop(
      backdrop: backdrop,
      shape: shape,
      effects: effects,
      highlight: highlight,
      shadow: shadow,
      innerShadow: innerShadow,
      layerBlock: layerBlock,
      exportedBackdrop: exportedBackdrop,
      onDrawBehind: onDrawBehind,
      onDrawBackdrop: onDrawBackdrop,
      onDrawSurface: onDrawSurface,
      onDrawFront: onDrawFront,
      isolateSurface: isolateSurface,
      quality: quality,
      repaint: repaint,
      textDirection: textDirection,
      backdropGroupKey: backdropGroupKey,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderDrawBackdrop renderObject) {
    renderObject
      ..backdrop = backdrop
      ..shape = shape
      ..effects = effects
      ..highlight = highlight
      ..shadow = shadow
      ..innerShadow = innerShadow
      ..layerBlock = layerBlock
      ..exportedBackdrop = exportedBackdrop
      ..onDrawBehind = onDrawBehind
      ..onDrawBackdrop = onDrawBackdrop
      ..onDrawSurface = onDrawSurface
      ..onDrawFront = onDrawFront
      ..isolateSurface = isolateSurface
      ..quality = quality
      ..repaint = repaint
      ..textDirection = textDirection
      ..backdropGroupKey = backdropGroupKey
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

/// Paints a glass element: its shadows, its filtered backdrop, its child and
/// its highlight rim.
///
/// The shadows and the highlight rim are drawn here too, rather than by
/// separate render objects, since they all need the same resolved shape.
class RenderDrawBackdrop extends RenderProxyBox {
  RenderDrawBackdrop({
    required Backdrop backdrop,
    required GlassShapeGetter shape,
    required BackdropEffectsBuilder effects,
    required HighlightGetter? highlight,
    required GlassShadowGetter? shadow,
    required GlassInnerShadowGetter? innerShadow,
    required GlassLayerBlock? layerBlock,
    required LayerBackdrop? exportedBackdrop,
    required GlassDrawCallback? onDrawBehind,
    required OnDrawBackdropCallback? onDrawBackdrop,
    required GlassDrawCallback? onDrawSurface,
    required GlassDrawCallback? onDrawFront,
    required bool isolateSurface,
    required GlassQuality? quality,
    required Listenable? repaint,
    required TextDirection textDirection,
    required BackdropKey? backdropGroupKey,
    required double devicePixelRatio,
  })  : _backdrop = backdrop,
        _shape = shape,
        _effects = effects,
        _highlight = highlight,
        _shadow = shadow,
        _innerShadow = innerShadow,
        _layerBlock = layerBlock,
        _exportedBackdrop = exportedBackdrop,
        _onDrawBehind = onDrawBehind,
        _onDrawBackdrop = onDrawBackdrop,
        _onDrawSurface = onDrawSurface,
        _onDrawFront = onDrawFront,
        _isolateSurface = isolateSurface,
        _quality = quality,
        _repaint = repaint,
        _textDirection = textDirection,
        _backdropGroupKey = backdropGroupKey,
        _devicePixelRatio = devicePixelRatio;

  Backdrop get backdrop => _backdrop;
  Backdrop _backdrop;
  set backdrop(Backdrop value) {
    if (_backdrop == value) return;
    // Guarded like `repaint`: subscribing while detached would leave a second
    // listener behind once `attach` subscribes again, and `detach` removes
    // only one of them.
    if (attached) _unsubscribeBackdrop();
    _backdrop = value;
    if (attached) _subscribeBackdrop();
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  GlassShapeGetter get shape => _shape;
  GlassShapeGetter _shape;
  set shape(GlassShapeGetter value) {
    if (_shape == value) return;
    _shape = value;
    markNeedsPaint();
  }

  BackdropEffectsBuilder get effects => _effects;
  BackdropEffectsBuilder _effects;
  set effects(BackdropEffectsBuilder value) {
    if (_effects == value) return;
    _effects = value;
    markNeedsPaint();
  }

  HighlightGetter? get highlight => _highlight;
  HighlightGetter? _highlight;
  set highlight(HighlightGetter? value) {
    if (_highlight == value) return;
    _highlight = value;
    markNeedsPaint();
  }

  GlassShadowGetter? get shadow => _shadow;
  GlassShadowGetter? _shadow;
  set shadow(GlassShadowGetter? value) {
    if (_shadow == value) return;
    _shadow = value;
    markNeedsPaint();
  }

  GlassInnerShadowGetter? get innerShadow => _innerShadow;
  GlassInnerShadowGetter? _innerShadow;
  set innerShadow(GlassInnerShadowGetter? value) {
    if (_innerShadow == value) return;
    _innerShadow = value;
    markNeedsPaint();
  }

  GlassLayerBlock? get layerBlock => _layerBlock;
  GlassLayerBlock? _layerBlock;
  set layerBlock(GlassLayerBlock? value) {
    if (_layerBlock == value) return;
    _layerBlock = value;
    markNeedsPaint();
  }

  LayerBackdrop? get exportedBackdrop => _exportedBackdrop;
  LayerBackdrop? _exportedBackdrop;
  set exportedBackdrop(LayerBackdrop? value) {
    if (_exportedBackdrop == value) return;
    _exportedBackdrop?.detachSource(_pictureSource);
    _exportedBackdrop = value;
    _onModeMayHaveChanged();
  }

  GlassDrawCallback? get onDrawBehind => _onDrawBehind;
  GlassDrawCallback? _onDrawBehind;
  set onDrawBehind(GlassDrawCallback? value) {
    if (_onDrawBehind == value) return;
    _onDrawBehind = value;
    markNeedsPaint();
  }

  OnDrawBackdropCallback? get onDrawBackdrop => _onDrawBackdrop;
  OnDrawBackdropCallback? _onDrawBackdrop;
  set onDrawBackdrop(OnDrawBackdropCallback? value) {
    if (_onDrawBackdrop == value) return;
    _onDrawBackdrop = value;
    _onModeMayHaveChanged();
  }

  GlassDrawCallback? get onDrawSurface => _onDrawSurface;
  GlassDrawCallback? _onDrawSurface;
  set onDrawSurface(GlassDrawCallback? value) {
    if (_onDrawSurface == value) return;
    _onDrawSurface = value;
    markNeedsPaint();
  }

  GlassDrawCallback? get onDrawFront => _onDrawFront;
  GlassDrawCallback? _onDrawFront;
  set onDrawFront(GlassDrawCallback? value) {
    if (_onDrawFront == value) return;
    _onDrawFront = value;
    markNeedsPaint();
  }

  /// See [DrawBackdrop.isolateSurface].
  bool get isolateSurface => _isolateSurface;
  bool _isolateSurface;
  set isolateSurface(bool value) {
    if (_isolateSurface == value) return;
    _isolateSurface = value;
    markNeedsPaint();
  }

  Listenable? get repaint => _repaint;
  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (_repaint == value) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsPaint();
  }

  /// The [BackdropGroup] this element's native filter joins, if any.
  BackdropKey? get backdropGroupKey => _backdropGroupKey;
  BackdropKey? _backdropGroupKey;
  set backdropGroupKey(BackdropKey? value) {
    if (_backdropGroupKey == value) return;
    _backdropGroupKey = value;
    markNeedsPaint();
  }

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  final BackdropEffectScope _effectScope = BackdropEffectScope();
  final FragmentShaderCache _highlightShaders = FragmentShaderCache();
  final PictureBackdropSource _pictureSource = PictureBackdropSource();

  // The decorations, baked to textures and reused while their inputs hold
  // still, so an animating element does not re-blur its shadows every frame.
  // The shadows are baked; the highlight rim is not. Both shadows need a
  // save-layer anyway, because each punches its own shape back out with
  // BlendMode.clear, and both are soft enough that resampling a cached copy is
  // invisible. The rim is a hairline, where it would not be.
  final BakedDecoration _shadowBake = BakedDecoration();
  final BakedDecoration _innerShadowBake = BakedDecoration();

  /// How this element sat the last time it painted, so a move relative to the
  /// backdrop can be noticed.
  ///
  /// The whole transform rather than the origin: an element an ancestor scales
  /// or rotates samples different pixels without its top-left corner moving at
  /// all.
  Matrix4? _paintedTransform;
  bool _positionWatchPending = false;

  // The resolved shape, memoised across paints.
  //
  // A continuous-curvature outline is 12 cubics solved from scratch, and a
  // fresh Path every frame also misses Impeller's tessellation cache, so an
  // element that merely animates its opacity used to re-solve and re-tessellate
  // its squircle on every frame. RoundedRectangularShape is immutable and both
  // getters are pure, so a hit is bit-identical.
  RoundedRectangularShape? _outlineShape;
  Size? _outlineSize;
  TextDirection? _outlineDirection;
  GlassOutline? _outline;
  RectangleCorners? _corners;

  bool _outlineCacheHolds(RoundedRectangularShape shape, Size size) =>
      _outlineSize == size &&
      _outlineDirection == _textDirection &&
      _outlineShape == shape;

  void _rememberOutlineKey(RoundedRectangularShape shape, Size size) {
    if (_outlineCacheHolds(shape, size)) return;
    _outlineShape = shape;
    _outlineSize = size;
    _outlineDirection = _textDirection;
    _outline = null;
    _corners = null;
  }

  GlassOutline _outlineFor(RoundedRectangularShape shape, Size size) {
    _rememberOutlineKey(shape, size);
    return _outline ??= shape.createOutline(size, _textDirection);
  }

  RectangleCorners _cornersFor(RoundedRectangularShape shape, Size size) {
    _rememberOutlineKey(shape, size);
    return _corners ??= shape.corners(size, _textDirection);
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<ClipRRectLayer> _clipRRectLayer = LayerHandle<ClipRRectLayer>();
  final LayerHandle<ClipPathLayer> _clipPathLayer = LayerHandle<ClipPathLayer>();

  /// Repaints when the element moves relative to a coordinate-dependent
  /// backdrop, even though nothing about the element itself changed.
  ///
  /// Flutter has no "I moved" callback, and a glass element inside a lazy list
  /// sits in a RepaintBoundary whose layer is merely re-offset while scrolling,
  /// so without this the refraction would freeze and slide along with the item.
  ///
  /// The check rides on frames that are happening anyway: it re-arms itself
  /// from a post-frame callback, which never runs while the app is idle.
  void _watchPosition() {
    if (_positionWatchPending) return;
    if (!_backdrop.isCoordinatesDependent) return;
    _positionWatchPending = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _positionWatchPending = false;
      if (!attached || !_backdrop.isCoordinatesDependent) return;
      if (hasSize && _paintedTransform != null) {
        if (getTransformTo(null) != _paintedTransform) {
          markNeedsPaint();
        }
      }
      _watchPosition();
    });
  }

  /// Whether this element is currently subscribed to its backdrop.
  ///
  /// Not a constant: an element on the native path does not sample the capture
  /// at all, and staying subscribed would keep `LayerBackdrop.hasConsumers`
  /// true — which is what tells the source to go on capturing itself every
  /// frame. Dropping the subscription is what makes the fallback actually free.
  bool _subscribedToBackdrop = false;

  void _syncBackdropSubscription() {
    final bool wanted = attached && !_usesNativeFilter;
    if (wanted == _subscribedToBackdrop) return;
    _subscribedToBackdrop = wanted;
    if (wanted) {
      _backdrop.repaintNotifier?.addListener(markNeedsPaint);
    } else {
      _backdrop.repaintNotifier?.removeListener(markNeedsPaint);
    }
  }

  void _subscribeBackdrop() {
    _subscribedToBackdrop = false;
    _syncBackdropSubscription();
  }

  void _unsubscribeBackdrop() {
    if (!_subscribedToBackdrop) return;
    _subscribedToBackdrop = false;
    _backdrop.repaintNotifier?.removeListener(markNeedsPaint);
  }

  // ---------------------------------------------------------------------------
  // The cheap tier's second way of drawing a backdrop.
  //
  // Sampling costs a capture of the source — an `OffsetLayer.toImageSync` that
  // flushes the pipeline mid-frame, and for a backdrop that changes every frame
  // it is by a wide margin the most expensive thing here. Dropping the
  // refraction does nothing about it: the lens is a fragment pass over the
  // element's own texture, while the capture is the whole source.
  //
  // So the cheap tier does not sample at all. When the backdrop is content
  // already painted behind the element, the effect chain is handed to the
  // compositor as a `BackdropFilterLayer` — Flutter's own `BackdropFilter` —
  // and the engine filters what is behind in place. No capture, no stall, no
  // invalidation to get right, and the blur is the engine's own separable,
  // downsampled Gaussian.
  //
  // It cannot replace the liquid tier: a fragment shader in a backdrop filter
  // is handed the whole screen rather than the element's texture, so the lens
  // would have nothing to anchor its geometry to. Hence exactly the tier that
  // has given up the shaders is the tier that can use it.
  // ---------------------------------------------------------------------------

  /// Whether this element draws its backdrop with a [BackdropFilterLayer].
  ///
  /// Every condition here is something the compositor cannot do: transform the
  /// backdrop before filtering it ([onDrawBackdrop]), hand the drawing back as
  /// a picture ([exportedBackdrop]), or filter content that is not behind the
  /// element in the first place.
  bool get _usesNativeFilter {
    if (_resolvedQuality.hasShaders) return false;
    if (!_backdrop.isPaintedBehindConsumer) return false;
    if (_onDrawBackdrop != null) return false;
    if (_exportedBackdrop != null) return false;
    return true;
  }

  /// The tier pinned for this element, or null to follow the governor.
  GlassQuality? get quality => _quality;
  GlassQuality? _quality;
  set quality(GlassQuality? value) {
    if (_quality == value) return;
    _quality = value;
    _onModeMayHaveChanged();
  }

  /// The tier to draw at this frame.
  ///
  /// Resolved at paint time rather than at build time so an app installing a
  /// classifier, or pinning a tier, takes effect without rebuilding anything —
  /// the element is already listening for repaints.
  GlassQuality get _resolvedQuality {
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final GlassQuality? pinned = _quality;
    // The tier's own value is already clamped; an explicitly pinned tier still
    // has to be, since pinning cannot conjure a shader the backend has not got.
    return pinned == null ? tier.quality : pinned.atMost(tier.ceiling);
  }

  /// Moving between sampling and filtering in place changes what this element
  /// subscribes to and whether it needs a compositing layer.
  void _onModeMayHaveChanged() {
    _syncBackdropSubscription();
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _usesNativeFilter;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
    _subscribeBackdrop();
    FluidGlassPrograms.instance.addListener(markNeedsPaint);
    // A tier change has to reach the paint that reads it.
    GlassDeviceTier.instance.addListener(_onModeMayHaveChanged);
    _watchPosition();
  }

  @override
  void detach() {
    GlassDeviceTier.instance.removeListener(_onModeMayHaveChanged);
    FluidGlassPrograms.instance.removeListener(markNeedsPaint);
    _unsubscribeBackdrop();
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Size size = this.size;
    if (size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    final bool native = _usesNativeFilter;
    // Only a sampled backdrop cares where the element sits: the compositor
    // filters what is behind wherever the layer lands.
    if (_backdrop.isCoordinatesDependent && !native) {
      _paintedTransform = getTransformTo(null);
      _watchPosition();
    }

    final RoundedRectangularShape shape = _shape();
    final GlassOutline outline = _outlineFor(shape, size);
    final RectangleCorners corners = _cornersFor(shape, size);

    final GlassQuality quality = _resolvedQuality;
    _effectScope.beginUpdate(
      size: size,
      textDirection: _textDirection,
      shape: shape,
      devicePixelRatio: _devicePixelRatio,
      quality: quality,
    );
    _effects(_effectScope);
    final List<ui.ImageFilter> filters = _effectScope.resolve();
    final double padding = _effectScope.padding;

    // 1. The drop shadow, outside the clip.
    final GlassShadow? shadow = _shadow?.call();
    if (shadow != null) {
      paintGlassShadow(
        context.canvas,
        offset,
        size,
        outline,
        shadow,
        _devicePixelRatio,
        cache: _shadowBake,
        cacheKey: (
          size,
          shape,
          _textDirection,
          shadow.radius,
          shadow.offset,
          shadow.color,
          _devicePixelRatio,
        ),
      );
    }

    // 2. Everything the element is made of, clipped to its shape.
    //
    // The clip is not optional on the native path: a `BackdropFilterLayer` with
    // nothing clipping it filters the whole enclosing layer, so a rectangular
    // element that "clips nothing" would blur the entire screen.
    _paintClipped(context, offset, outline, padding, forceClip: native,
        (PaintingContext context, Offset offset) {
      final Canvas canvas = context.canvas;

      if (native) {
        _paintNativeBackdrop(context, offset, size, filters);
        super.paint(context, offset);
        final GlassDrawCallback? onDrawFrontNative = _onDrawFront;
        if (onDrawFrontNative != null) {
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          onDrawFrontNative(canvas, size);
          canvas.restore();
        }
        return;
      }

      // The backdrop and surface share an isolating layer so surface blend
      // modes composite against the refracted backdrop. With nothing drawn
      // over the backdrop there is nothing to isolate, and the layer is
      // skipped.
      // Only a surface drawn *over* the backdrop needs isolating. `onDrawBehind`
      // paints under it, and src-over is associative, so wrapping the two in a
      // layer provably changes nothing.
      final bool needsIsolation = _isolateSurface && _onDrawSurface != null;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      if (needsIsolation) {
        canvas.saveLayer(Offset.zero & size, Paint());
      }
      _onDrawBehind?.call(canvas, size);
      _paintBackdropStack(canvas, size, filters, padding);
      _onDrawSurface?.call(canvas, size);
      if (needsIsolation) {
        canvas.restore();
      }
      canvas.restore();

      super.paint(context, offset);

      final GlassDrawCallback? onDrawFront = _onDrawFront;
      if (onDrawFront != null) {
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        onDrawFront(canvas, size);
        canvas.restore();
      }
    });

    // 3. The highlight rim, then 4. the inner shadow, both on top.
    final Highlight? highlight = _highlight?.call();
    if (highlight != null) {
      paintGlassHighlight(
        context.canvas,
        offset,
        size,
        outline,
        highlight,
        corners,
        _highlightShaders,
        _devicePixelRatio,
        shadeRim: quality.hasShadedRim,
      );
    }

    final GlassInnerShadow? innerShadow = _innerShadow?.call();
    if (innerShadow != null) {
      paintGlassInnerShadow(
        context.canvas,
        offset,
        size,
        outline,
        innerShadow,
        _devicePixelRatio,
        cache: _innerShadowBake,
        cacheKey: (
          size,
          shape,
          _textDirection,
          innerShadow.radius,
          innerShadow.offset,
          innerShadow.color,
          _devicePixelRatio,
        ),
      );
    }

    _exportBackdrop(size, filters, padding);
  }

  void _paintClipped(
    PaintingContext context,
    Offset offset,
    GlassOutline outline,
    double padding,
    PaintingContextCallback painter, {
    bool forceClip = false,
  }) {
    final Rect bounds = Offset.zero & size;

    // A rectangular outline the size of the element clips nothing *of the
    // element* away — but the backdrop is drawn into a layer inflated by
    // [padding] so a blur has pixels to reach for, and without the clip that
    // layer bleeds `padding` logical pixels out on every side. The shortcut is
    // only sound when nothing is drawn outside the element at all.
    final bool rectangleClipsNothing = padding <= 0.0 && !forceClip;

    // With no compositing descendant the clip can go straight onto the canvas.
    // `PaintingContext.pushClipPath` shifts the path by `offset` first, which
    // copies the whole path engine-side every frame and hands Impeller a new
    // object each time, so its tessellation of the squircle can never be
    // reused. Translating the canvas instead keeps one stable Path.
    if (!needsCompositing) {
      _releaseClipLayers();
      final Canvas canvas = context.canvas;
      switch (outline) {
        case RectOutline(:final Rect rect):
          if (rectangleClipsNothing &&
              rect.contains(bounds.bottomRight - const Offset(0.01, 0.01)) &&
              rect.topLeft == Offset.zero) {
            painter(context, offset);
            return;
          }
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.clipRect(rect);
        case RRectOutline(:final RRect rrect):
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.clipRRect(rrect);
        case PathOutline(:final Path path):
          canvas.save();
          canvas.translate(offset.dx, offset.dy);
          canvas.clipPath(path);
      }
      canvas.translate(-offset.dx, -offset.dy);
      painter(context, offset);
      canvas.restore();
      return;
    }

    switch (outline) {
      case RectOutline(:final Rect rect):
        if (rectangleClipsNothing &&
            rect.contains(bounds.bottomRight - const Offset(0.01, 0.01)) &&
            rect.topLeft == Offset.zero) {
          _releaseClipLayers();
          painter(context, offset);
          return;
        }
        _clipRRectLayer.layer = null;
        _clipPathLayer.layer = null;
        _clipRectLayer.layer = context.pushClipRect(
          needsCompositing,
          offset,
          rect,
          painter,
          oldLayer: _clipRectLayer.layer,
        );
      case RRectOutline(:final RRect rrect):
        _clipRectLayer.layer = null;
        _clipPathLayer.layer = null;
        _clipRRectLayer.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          bounds,
          rrect,
          painter,
          oldLayer: _clipRRectLayer.layer,
        );
      case PathOutline(:final Path path):
        _clipRectLayer.layer = null;
        _clipRRectLayer.layer = null;
        _clipPathLayer.layer = context.pushClipPath(
          needsCompositing,
          offset,
          bounds,
          path,
          painter,
          oldLayer: _clipPathLayer.layer,
        );
    }
  }

  /// Drops every retained clip layer.
  ///
  /// The outline's own type changes when a radius animates through zero, and
  /// the layer for the shape it used to be would otherwise be retained for the
  /// element's lifetime.
  void _releaseClipLayers() {
    _clipRectLayer.layer = null;
    _clipRRectLayer.layer = null;
    _clipPathLayer.layer = null;
  }

  /// Hands the effect chain to the compositor instead of drawing the backdrop.
  ///
  /// The whole chain becomes one [BackdropFilterLayer]: on the cheap tier there
  /// are no fragment-shader stages, so what is left composes into a single
  /// [ui.ImageFilter] — in practice a colour matrix and the engine's own
  /// Gaussian blur, which downsamples and runs two separable passes rather than
  /// the per-pixel program a hand-written blur would need.
  ///
  /// An empty chain draws nothing at all, and is right: with no filter to
  /// apply, the backdrop already showing through the element *is* the answer.
  ///
  /// [_onDrawSurface] is painted as the layer's child so a tint using a blend
  /// mode still composites against the filtered backdrop and nothing else,
  /// which is what the isolating save-layer buys on the sampled path.
  void _paintNativeBackdrop(
    PaintingContext context,
    Offset offset,
    Size size,
    List<ui.ImageFilter> filters,
  ) {
    final GlassDrawCallback? onDrawSurface = _onDrawSurface;
    if (filters.isEmpty) {
      _backdropFilterLayer.layer = null;
      if (onDrawSurface != null) {
        final Canvas canvas = context.canvas;
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        onDrawSurface(canvas, size);
        canvas.restore();
      }
      return;
    }

    // `resolve` returns the stages in the order they were declared, and the
    // sampled path nests them innermost-first; composing them the same way
    // keeps one chain that behaves identically.
    ui.ImageFilter filter = filters.first;
    for (int i = 1; i < filters.length; i++) {
      filter = ui.ImageFilter.compose(outer: filters[i], inner: filter);
    }

    final BackdropFilterLayer layer =
        _backdropFilterLayer.layer ?? BackdropFilterLayer();
    layer
      ..filter = filter
      ..backdropKey = _backdropGroupKey;
    _backdropFilterLayer.layer = layer;

    context.pushLayer(
      layer,
      (PaintingContext context, Offset offset) {
        if (onDrawSurface == null) return;
        final Canvas canvas = context.canvas;
        canvas.save();
        canvas.translate(offset.dx, offset.dy);
        onDrawSurface(canvas, size);
        canvas.restore();
      },
      offset,
    );
  }

  final LayerHandle<BackdropFilterLayer> _backdropFilterLayer =
      LayerHandle<BackdropFilterLayer>();

  /// Draws the backdrop through the effect chain.
  ///
  /// Each filter gets its own save-layer, innermost first, so a fragment shader
  /// always receives the padded layer's exact bounds as its input texture.
  void _paintBackdropStack(
    Canvas canvas,
    Size size,
    List<ui.ImageFilter> filters,
    double padding,
  ) {
    final Rect layerRect = Rect.fromLTWH(
      -padding,
      -padding,
      size.width + padding * 2,
      size.height + padding * 2,
    );

    for (int i = filters.length - 1; i >= 0; i--) {
      canvas.saveLayer(layerRect, Paint()..imageFilter = filters[i]);
    }

    final BackdropDrawContext drawContext = BackdropDrawContext(
      canvas: canvas,
      size: size,
      textDirection: _textDirection,
      devicePixelRatio: _devicePixelRatio,
      consumer: _backdrop.isCoordinatesDependent ? this : null,
      layerBlock: _layerBlock,
      backdrop: _backdrop,
      sampleMargin: padding,
    );
    void drawBackdrop() => _backdrop.drawBackdrop(drawContext);
    final OnDrawBackdropCallback? onDrawBackdrop = _onDrawBackdrop;
    if (onDrawBackdrop != null) {
      onDrawBackdrop(drawContext, drawBackdrop);
    } else {
      drawBackdrop();
    }

    for (int i = 0; i < filters.length; i++) {
      canvas.restore();
    }
  }

  /// Records this element's own drawing so nested glass can refract it.
  ///
  /// Everything except the child content is re-recorded, so glass nested in
  /// this element refracts the glass around it and not itself.
  void _exportBackdrop(Size size, List<ui.ImageFilter> filters, double padding) {
    final LayerBackdrop? exported = _exportedBackdrop;
    if (exported == null) return;
    // Re-recording the whole backdrop stack is only worth it if something is
    // going to sample it.
    if (!exported.hasConsumers) return;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.saveLayer(Offset.zero & size, Paint());
    _onDrawBehind?.call(canvas, size);
    _paintBackdropStack(canvas, size, filters, padding);
    _onDrawSurface?.call(canvas, size);
    canvas.restore();
    _onDrawFront?.call(canvas, size);

    _pictureSource.update(
      picture: recorder.endRecording(),
      size: size,
      globalTransform: getTransformTo(null),
    );
    // attachSource notifies only when the source actually changes; notifying
    // on every paint would loop, because consumers of an exported backdrop
    // normally live inside the exporting element's own subtree.
    exported.attachSource(_pictureSource);
  }

  @override
  void dispose() {
    _backdropFilterLayer.layer = null;
    _clipRectLayer.layer = null;
    _clipRRectLayer.layer = null;
    _clipPathLayer.layer = null;
    _exportedBackdrop?.detachSource(_pictureSource);
    _pictureSource.dispose();
    _effectScope.dispose();
    _highlightShaders.clear();
    _shadowBake.dispose();
    _innerShadowBake.dispose();
    super.dispose();
  }
}
