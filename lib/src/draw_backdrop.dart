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
      repaint: repaint,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
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
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
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
    required this.repaint,
    required this.textDirection,
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
  final Listenable? repaint;
  final TextDirection textDirection;

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
      repaint: repaint,
      textDirection: textDirection,
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
      ..repaint = repaint
      ..textDirection = textDirection
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
    required Listenable? repaint,
    required TextDirection textDirection,
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
        _repaint = repaint,
        _textDirection = textDirection,
        _devicePixelRatio = devicePixelRatio;

  Backdrop get backdrop => _backdrop;
  Backdrop _backdrop;
  set backdrop(Backdrop value) {
    if (_backdrop == value) return;
    _unsubscribeBackdrop();
    _backdrop = value;
    _subscribeBackdrop();
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
    markNeedsPaint();
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
    markNeedsPaint();
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

  /// Where this element sat the last time it painted, so a move relative to the
  /// backdrop can be noticed.
  Offset? _paintedGlobalOffset;
  bool _positionWatchPending = false;

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
      if (hasSize && _paintedGlobalOffset != null) {
        final Offset now = localToGlobal(Offset.zero);
        if (now != _paintedGlobalOffset) {
          markNeedsPaint();
        }
      }
      _watchPosition();
    });
  }

  void _subscribeBackdrop() {
    _backdrop.repaintNotifier?.addListener(markNeedsPaint);
  }

  void _unsubscribeBackdrop() {
    _backdrop.repaintNotifier?.removeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint?.addListener(markNeedsPaint);
    _subscribeBackdrop();
    FluidGlassPrograms.instance.addListener(markNeedsPaint);
    _watchPosition();
  }

  @override
  void detach() {
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

    if (_backdrop.isCoordinatesDependent) {
      _paintedGlobalOffset = localToGlobal(Offset.zero);
      _watchPosition();
    }

    final RoundedRectangularShape shape = _shape();
    final GlassOutline outline = shape.createOutline(size, _textDirection);
    final RectangleCorners corners = shape.corners(size, _textDirection);

    _effectScope.beginUpdate(
      size: size,
      textDirection: _textDirection,
      shape: shape,
      devicePixelRatio: _devicePixelRatio,
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
      );
    }

    // 2. Everything the element is made of, clipped to its shape.
    _paintClipped(context, offset, outline, (PaintingContext context, Offset offset) {
      final Canvas canvas = context.canvas;

      // The backdrop and surface share an isolating layer so surface blend
      // modes composite against the refracted backdrop. With nothing drawn
      // over the backdrop there is nothing to isolate, and the layer is
      // skipped.
      final bool needsIsolation =
          _onDrawBehind != null || _onDrawSurface != null;
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
      );
    }

    _exportBackdrop(size, filters, padding);
  }

  void _paintClipped(
    PaintingContext context,
    Offset offset,
    GlassOutline outline,
    PaintingContextCallback painter,
  ) {
    final Rect bounds = Offset.zero & size;
    switch (outline) {
      case RectOutline(:final Rect rect):
        if (rect.contains(bounds.bottomRight - const Offset(0.01, 0.01)) &&
            rect.topLeft == Offset.zero) {
          // A plain rectangle covering the element clips nothing away.
          painter(context, offset);
          return;
        }
        _clipRectLayer.layer = context.pushClipRect(
          needsCompositing,
          offset,
          rect,
          painter,
          oldLayer: _clipRectLayer.layer,
        );
      case RRectOutline(:final RRect rrect):
        _clipRRectLayer.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          bounds,
          rrect,
          painter,
          oldLayer: _clipRRectLayer.layer,
        );
      case PathOutline(:final Path path):
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
      globalOffset: localToGlobal(Offset.zero),
    );
    // attachSource notifies only when the source actually changes; notifying
    // on every paint would loop, because consumers of an exported backdrop
    // normally live inside the exporting element's own subtree.
    exported.attachSource(_pictureSource);
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    _clipRRectLayer.layer = null;
    _clipPathLayer.layer = null;
    _exportedBackdrop?.detachSource(_pictureSource);
    _pictureSource.dispose();
    _effectScope.dispose();
    _highlightShaders.clear();
    super.dispose();
  }
}
