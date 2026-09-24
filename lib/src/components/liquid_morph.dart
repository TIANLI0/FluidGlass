import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../shapes/rounded_rectangular_shape.dart';

/// Grows [child] out of [origin]: the thing that was pressed becomes the
/// surface it opens, instead of the surface fading in over it.
///
/// [child] is laid out at its own size from the first frame; what animates is
/// a clip, from [origin] — a rect in global coordinates, usually the button
/// that opened it — to the child's own bounds, with the corner radius going
/// from [originRadius] to [radius]. So nothing is laid out again while it
/// moves and nothing inside is squashed: the glass grows and uncovers what is
/// already in place. A frame costs one clip.
///
/// The two axes do not move together. Opening, the width leads and the height
/// follows, so the surface unfolds from its button
/// like something poured rather than scaled; closing — [progress] running
/// back — the height folds first and the width after, and the surface goes
/// back into the button the way it came out. Both read off the one
/// [progress], so a route can drive it with its own animation and a reversal
/// midway simply turns it round.
///
/// With [origin] null the surface grows out of its own centre. Under
/// [MediaQueryData.disableAnimations] there is no growing at all: the child
/// is shown as it is, and whatever drives [progress] only fades what is
/// around it.
class LiquidMorph extends SingleChildRenderObjectWidget {
  const LiquidMorph({
    super.key,
    required this.progress,
    this.origin,
    this.originFor,
    this.originRadius = 24,
    required this.radius,
    this.outset = 0,
    super.child,
  });

  /// 0 is [origin], 1 is the child's own bounds.
  final Animation<double> progress;

  /// Where the surface grows from, in global coordinates. Null is the child's
  /// centre.
  final Rect? origin;

  /// Where the surface grows from, worked out from where it ended up —
  /// [bounds] is the child's own rect in global coordinates.
  ///
  /// For a surface whose position is only settled by layout: a menu that
  /// opens above its anchor when there is room and below it when there is
  /// not grows out of whichever side it landed on. Wins over [origin].
  final Rect Function(Rect bounds)? originFor;

  /// The corner radius at [origin] — half the height for a capsule button.
  final double originRadius;

  /// The child's own corner radius, reached at the end.
  final double radius;

  /// How far past its own bounds the child paints — a drop shadow, a rim's
  /// bloom. The clip grows to cover it too, so it arrives with the surface
  /// instead of appearing whole on the last frame.
  final double outset;

  @override
  RenderLiquidMorph createRenderObject(BuildContext context) =>
      RenderLiquidMorph(
        progress: progress,
        origin: origin,
        originFor: originFor,
        originRadius: originRadius,
        radius: radius,
        outset: outset,
        still: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidMorph renderObject,
  ) {
    renderObject
      ..progress = progress
      ..origin = origin
      ..originFor = originFor
      ..originRadius = originRadius
      ..radius = radius
      ..outset = outset
      ..still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }
}

class RenderLiquidMorph extends RenderProxyBox {
  RenderLiquidMorph({
    required Animation<double> progress,
    Rect? origin,
    Rect Function(Rect bounds)? originFor,
    required double originRadius,
    required double radius,
    double outset = 0,
    required bool still,
  }) : _progress = progress,
       _origin = origin,
       _originFor = originFor,
       _originRadius = originRadius,
       _radius = radius,
       _outset = outset,
       _still = still;

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Rect? _origin;
  set origin(Rect? value) {
    if (value == _origin) return;
    _origin = value;
    markNeedsPaint();
  }

  Rect Function(Rect bounds)? _originFor;
  set originFor(Rect Function(Rect bounds)? value) {
    if (value == _originFor) return;
    _originFor = value;
    markNeedsPaint();
  }

  double _originRadius;
  set originRadius(double value) {
    if (value == _originRadius) return;
    _originRadius = value;
    markNeedsPaint();
  }

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  double _outset;
  set outset(double value) {
    if (value == _outset) return;
    _outset = value;
    markNeedsPaint();
  }

  bool _still;
  set still(bool value) {
    if (value == _still) return;
    _still = value;
    markNeedsPaint();
  }

  final LayerHandle<ClipPathLayer> _clip = LayerHandle<ClipPathLayer>();

  // Width leads, height follows. No overshoot: this is a clip, and a clip
  // that grows past the child's bounds uncovers nothing — the "lands a little
  // long" of a resized surface has no counterpart here.
  static const Curve _x = Interval(0, 0.78, curve: Curves.easeOutCubic);
  static const Curve _y = Interval(0.14, 1, curve: Curves.easeOutCubic);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  /// The clip at the current progress, in local coordinates, or null when
  /// the child is simply shown whole.
  @visibleForTesting
  Rect? get debugClipRect => _clipRect();

  Rect? _clipRect() {
    if (_still || !hasSize) return null;
    final double t = _progress.value.clamp(0.0, 1.0);
    if (t >= 1) return null;
    final Rect own = (Offset.zero & size).inflate(_outset);
    final Rect from = _originLocal();
    final double x = _x.transform(t);
    final double y = _y.transform(t);
    return Rect.fromLTRB(
      ui.lerpDouble(from.left, own.left, x)!,
      ui.lerpDouble(from.top, own.top, y)!,
      ui.lerpDouble(from.right, own.right, x)!,
      ui.lerpDouble(from.bottom, own.bottom, y)!,
    );
  }

  Rect _originLocal() {
    Rect? origin = _origin;
    final Rect Function(Rect bounds)? originFor = _originFor;
    if (originFor != null && attached) {
      origin = originFor(
        MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size),
      );
    }
    if (origin == null || !attached) {
      // From the centre: a small capsule, so the first frame is already a
      // shape and not a point.
      final double side = math.min(56.0, size.shortestSide);
      return Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      );
    }
    final Matrix4 toGlobal = getTransformTo(null);
    if (toGlobal.invert() == 0) return Offset.zero & size;
    return MatrixUtils.transformRect(toGlobal, origin);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final Rect? clip = _clipRect();
    if (clip != null && !clip.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    final Rect? clip = _clipRect();
    if (clip == null || clip.isEmpty) {
      _clip.layer = null;
      if (clip == null) context.paintChild(child, offset);
      return;
    }
    final double t = _progress.value.clamp(0.0, 1.0);
    final double r = math.min(
      ui.lerpDouble(
        _originRadius,
        _radius + _outset,
        math.min(_x.transform(t), _y.transform(t)).clamp(0.0, 1.0),
      )!,
      clip.shortestSide / 2,
    );
    final Path path = RoundedRectangle(
      r,
    ).createOutline(clip.size, TextDirection.ltr).toPath().shift(clip.topLeft);
    _clip.layer = context.pushClipPath(
      needsCompositing,
      offset,
      (Offset.zero & size).inflate(_outset),
      path,
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
      oldLayer: _clip.layer,
    );
  }
}
