import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';
import '../internal/shader_programs.dart';

/// One shape of a fused body: a rounded rectangle in the group's coordinates.
///
/// A circle is a square with [radius] at half its side; a capsule is a
/// rectangle with [radius] at half its height.
@immutable
class LiquidBlob {
  const LiquidBlob(this.rect, {this.radius = double.infinity});

  /// Where it sits, in the fused group's coordinates.
  final Rect rect;

  /// Corner radius, clamped to half the shorter side — so the default,
  /// infinity, is "as round as this rectangle goes".
  final double radius;

  double get _radius => math.min(radius, math.min(rect.width, rect.height) / 2);

  @override
  bool operator ==(Object other) =>
      other is LiquidBlob && other.rect == rect && other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// A press being felt by a fused body: where the finger is, how far the press
/// has come on, and how wide its glow is.
@immutable
class LiquidFusionPress {
  const LiquidFusionPress({
    required this.position,
    required this.progress,
    required this.radius,
    this.reach,
    this.owner,
  });

  /// Whatever the caller uses to say which of its controls is being pressed,
  /// so it can tell its own press from someone else's when it clears one.
  final Object? owner;

  /// Where the finger is, in the fused group's coordinates.
  final Offset position;

  /// 0 at rest, 1 fully pressed.
  final double progress;

  /// How far the glow itself carries, in logical pixels — the size of the
  /// control being pressed, so it answers a finger the way that control would
  /// on its own.
  final double radius;

  /// How far the *light* carries, in logical pixels. Defaults to three times
  /// [radius].
  ///
  /// This is the wider, weaker falloff that reaches the controls around the
  /// one being pressed. It is masked by the field like everything else, so it
  /// lands on them and never in the gaps between them — it reaches over to a
  /// control without ever leaving one.
  final double? reach;
}

/// Several shapes drawn as one body of glass: fused where they come close, and
/// lit as one thing everywhere.
///
/// Two things are shared, and both matter:
///
/// * **The shape.** The silhouette is a field, not an outline. Each shape
///   contributes a signed distance, the shader takes their smooth minimum, and
///   the result bulges towards its neighbour before the two touch, grows a
///   concave neck as it arrives, and swallows it. A union of two paths gives
///   none of that. [smoothing] is how far apart that reaching starts.
/// * **The light.** The rim runs around the *body*, not around each part, and
///   a press is not confined to the control that was pressed: the glow is
///   masked by the field, so it spills through a neck into whatever the body
///   has merged with, and the rim answers the press across the whole group, so
///   pressing one control lights the facing edges of its neighbours. Shapes
///   that are still far apart therefore share the light long before they share
///   an outline — which is what makes a spread-out group read as one piece of
///   glass at all.
///
/// It is also one glass element rather than one per shape — a single capture
/// of the backdrop and a single shader pass — and its box is kept tight around
/// the shapes, because that box is what gets captured and shaded.
///
/// The caller owns the geometry: hand it the shapes in its own coordinates and
/// stack whatever goes on top of them as [children]. Geometry arrives by
/// value, not by measuring the widgets that happen to be there — a field that
/// reads its shapes out of other render objects while it paints is a field
/// that draws last frame positions the moment anything moves.
class LiquidFusion extends StatelessWidget {
  const LiquidFusion({
    super.key,
    required this.backdrop,
    required this.blobs,
    this.press,
    this.pressSource,
    this.smoothing = 10,
    this.surfaceColor,
    this.saturation = 1.25,
    this.blurRadius = 2,
    this.refractionHeight = 12,
    this.refractionAmount = 24,
    this.rimColor,
    this.rimWidth = 1.5,
    this.lightAngle = -math.pi / 2,
    this.quality,
    this.repaint,
    this.shadowColor,
    this.shadowOffset = const Offset(0, 2),
    this.shadowBlur = 8,
    this.children = const <Widget>[],
  }) : assert(blobs.length > 0, 'Nothing to fuse.'),
       assert(blobs.length <= maxBlobs, 'At most maxBlobs shapes.'),
       assert(smoothing >= 0);

  /// How many shapes one fused body can hold — what the shader has uniforms
  /// for. A toolbar worth.
  static const int maxBlobs = 8;

  /// What the glass refracts.
  ///
  /// Not [emptyBackdrop]: the whole body — tint, rim and light as well as the
  /// refraction — is what the shader makes of the pixels it is handed, and
  /// filtering nothing produces nothing. A body over a flat page takes a
  /// [CanvasBackdrop] that fills with the page colour; with an opaque
  /// [surfaceColor] that costs a rectangle and captures nothing.
  final Backdrop backdrop;

  /// The shapes to fuse, in this widget's coordinate space.
  final List<LiquidBlob> blobs;

  /// The press the body is under, if any. Null is at rest.
  final LiquidFusionPress? press;

  /// A press that changes without rebuilding, read when the field paints.
  ///
  /// The geometry is deliberately not like this — shapes arrive by value, so
  /// the field can never draw last frame positions. A press is different: it
  /// is a point and a number, it changes every frame a finger is down, and
  /// nothing about the layout depends on it. Wire [repaint] to the same
  /// notifier.
  final ValueListenable<LiquidFusionPress?>? pressSource;

  /// How far apart two shapes start reaching for each other, in logical
  /// pixels.
  ///
  /// The default is measured, not chosen. A fused field closes over a gap of
  /// about half the smoothing — at the midpoint of a gap both distances are
  /// `gap / 2` and the smooth-min pulls that down by `k / 4` — which puts 10 at
  /// five logical pixels. A row of controls sits eight apart, so at rest it
  /// still reads as a row, and it takes something moving to bridge it.
  ///
  /// Raise it and the group merges standing still; drop it below about four
  /// and nothing short of an overlap joins them.
  final double smoothing;

  /// The tint over the refracted backdrop. Defaults to the palette container
  /// colour.
  final Color? surfaceColor;

  /// How much the glass lifts the colour of what it refracts. 1 leaves it.
  final double saturation;

  /// How hard the body blurs what it sits over, as a real Gaussian in the
  /// effect chain.
  ///
  /// 2 is what a button blurs at, over a photograph it is meant to be seen
  /// through; 8 is what a panel blurs at, over text it has to be legible
  /// against.
  final double blurRadius;

  /// How far in from the edge the refraction reaches, and how far it drags the
  /// sample. Together they are the thickness of the glass.
  final double refractionHeight, refractionAmount;

  /// The lit edge. Defaults to white at the usual strength; the alpha is how
  /// strong it is.
  final Color? rimColor;

  /// How wide the lit band is, in logical pixels.
  final double rimWidth;

  /// Where the light comes from, in radians. The default is from above.
  final double lightAngle;

  /// Pins the tier for this element alone, as on [DrawBackdrop].
  final GlassQuality? quality;

  /// Repaints the body whenever it notifies — pass the animation moving the
  /// shapes, so the field follows without rebuilding the widget.
  final Listenable? repaint;

  /// Painted over the glass, in the same coordinate space as [blobs].
  final List<Widget> children;

  /// The shadow the body casts. Null is the palette default; transparent is
  /// none.
  ///
  /// A fused body has no outline to hand to the canvas, so the shadow is drawn
  /// per shape and the shapes are then punched out of it — blurred shadows
  /// that overlap read as one shadow, which is what a merged body casts. It is
  /// not decoration: without it the body has nothing lifting it off the page
  /// and reads flat next to a control that draws its own.
  final Color? shadowColor;

  /// How far the shadow falls, and how soft it is.
  final Offset shadowOffset;
  final double shadowBlur;

  @override
  Widget build(BuildContext context) {
    // Which body to build — the shader's or the plain fallback — depends on
    // two things that change without anything here being rebuilt: the fragment
    // programs finishing their asynchronous load, and the device tier. Read
    // once, a first screen built before the load drew three separate panels
    // until something unrelated rebuilt it, and then swapped the whole body
    // mid-press.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        FluidGlassPrograms.instance,
        GlassDeviceTier.instance,
      ]),
      builder: _buildForTier,
    );
  }

  Widget _buildForTier(BuildContext context, Widget? _) {
    final _FusionStyle style = _FusionStyle.resolve(
      context,
      surfaceColor: surfaceColor,
      rimColor: rimColor,
      quality: quality,
    );
    if (style.program == null) {
      return _PlainFusion(
        backdrop: backdrop,
        blobs: blobs,
        surface: style.surface,
        blurRadius: blurRadius,
        repaint: repaint,
        children: children,
      );
    }

    return _MeasuredFusion(owner: this, style: style);
  }

  Widget _build(
    BuildContext context,
    _FusionStyle style,
    Size box,
    Rect? limit,
  ) {
    // The element is a plain rectangle — a fused body has no rounded-rect
    // outline to clip to, and the shader is transparent outside the field, so
    // the rectangle never shows. It is kept tight around the shapes all the
    // same: the box is what gets captured from the backdrop and what the
    // shader runs over, so a group spanning the screen would read and shade
    // the screen to draw two controls.
    //
    // And it is kept on screen and inside any clip around it — see
    // [_MeasuredFusion]. It may leave the box it was laid out in, which is what
    // lets a control lean out of a row under a drag; it may not leave what is
    // visible, because there its layer is clipped and the shader mapping goes
    // with it.
    final Rect bounds = _clampToBox(
      _fusionBounds(blobs, smoothing, refractionAmount),
      // Until the watcher has painted once there is nothing better than the
      // box, which for one frame loses only the headroom outside it.
      //
      // **And never tighter than the box.** A limit can be stale or measured
      // somewhere the body is not going to stay — a page is first painted,
      // and snapshotted for its transition, while it is still sliding in from
      // off-screen. Clamped to that, the body was cut with a straight edge
      // and a shape at its far end was simply not drawn. The limit is only
      // there to take away the room *around* the shapes; the shapes are laid
      // out in the box, and the box is always kept.
      limit == null
          ? Offset.zero & box
          : limit.expandToInclude(Offset.zero & box),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // The shadow is its own layer *behind* the element, not something the
        // element draws: everything drawn inside it is covered by the pass the
        // shader makes over the whole box, which hands back the untouched
        // backdrop outside the field — including over a shadow drawn there.
        Positioned.fromRect(
          rect: bounds,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FusionShadow(
                blobs: blobs,
                origin: bounds.topLeft,
                color: shadowColor ?? const Color(0x1A000000),
                offset: shadowOffset,
                blur: shadowBlur,
                repaint: repaint,
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: bounds,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            isolateSurface: false,
            // The element is the body's bounding box, not its silhouette; the
            // shader lights the fused rim itself.
            receivesLight: false,
            quality: style.quality,
            repaint: repaint,
            effects: (BackdropEffectScope scope) {
              // A real Gaussian, from the chain, not taps inside the shader.
              // It covers the whole box — which is exactly what made this look
              // impossible before — but the shader is transparent outside the
              // field, so the blurred rectangle is never drawn. What reaches
              // the screen is a proper blur with a fused silhouette cut out of
              // it, and that is what makes chrome legible over running text.
              if (blurRadius > 0) scope.blur(blurRadius);
              scope.fragmentShaderEffect('Fusion', style.program, (
                ui.FragmentShader shader,
                BackdropEffectGeometry geometry,
              ) {
                _configureFusion(
                  shader,
                  geometry,
                  bounds.topLeft,
                  blobs,
                  press: pressSource?.value ?? press,
                  style: style,
                  smoothing: smoothing,
                  saturation: saturation,
                  refractionHeight: refractionHeight,
                  refractionAmount: refractionAmount,
                  rimWidth: rimWidth,
                  lightAngle: lightAngle,
                );
              });
            },
            child: const SizedBox.expand(),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Room for what a press does outside a control box: the swell is four logical
/// pixels on the short axis, and the lean rides on top of it.
const double _pressHeadroom = 12;

/// Draws what the fused body casts: one shadow per shape, with every shape
/// punched back out, so shapes that overlap cast a single shadow and none of
/// them sits on its own.
class _FusionShadow extends CustomPainter {
  _FusionShadow({
    required this.blobs,
    required this.origin,
    required this.color,
    required this.offset,
    required this.blur,
    super.repaint,
  });

  final List<LiquidBlob> blobs;
  final Offset origin;
  final Color color;
  final Offset offset;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0 || blur <= 0) return;
    final Paint paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final LiquidBlob blob in blobs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          blob.rect.shift(-origin + offset),
          Radius.circular(blob._radius),
        ),
        paint,
      );
    }
    final Paint clear = Paint()..blendMode = BlendMode.clear;
    for (final LiquidBlob blob in blobs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          blob.rect.shift(-origin),
          Radius.circular(blob._radius),
        ),
        clear,
      );
    }
    canvas.restore();
  }

  // Its own animation reaches it through `repaint`; a rebuild of the parent
  // with the same shapes is not a reason to blur them all again.
  @override
  bool shouldRepaint(_FusionShadow old) =>
      !listEquals(old.blobs, blobs) ||
      old.origin != origin ||
      old.color != color ||
      old.offset != offset ||
      old.blur != blur;
}

/// Keeps a fused body's screen limit current.
///
/// The limit — the screen, in the body's own coordinates — is what stops the
/// element growing past the edge of the display, where its layer would be
/// clipped and the shader's mapping would go with it. Working it out needs the
/// body's paint transform, and **that transform changes without the body ever
/// rebuilding**: a route slides its whole page across the screen with one
/// `Transform`, and nothing inside the page is laid out or built again for it.
///
/// Reading the transform once, from inside the layout callback, is therefore a
/// trap with a long fuse. A bar measured on the frame its page was still 79
/// pixels off-screen keeps a limit 79 pixels short **for the life of that
/// page** — the body ends in a straight vertical cut through whatever island
/// happens to be there, and any island further out is simply not drawn. That
/// is invisible on a page you cold-start into and obvious on one you navigate
/// to, which is exactly the kind of bug that survives a demo.
///
/// So the transform is read where it is known to be current: in `paint`, which
/// is what a moving page does every frame. A change is reported after the
/// frame, the body rebuilds with the new limit, and a body that is not moving
/// reports nothing and rebuilds never.
class _MeasuredFusion extends StatefulWidget {
  const _MeasuredFusion({required this.owner, required this.style});

  final LiquidFusion owner;
  final _FusionStyle style;

  @override
  State<_MeasuredFusion> createState() => _MeasuredFusionState();
}

class _MeasuredFusionState extends State<_MeasuredFusion> {
  Rect? _limit;

  void _onLimit(Rect limit) {
    if (!mounted || _limit == limit) return;
    setState(() => _limit = limit);
  }

  @override
  Widget build(BuildContext context) {
    return _LimitWatcher(
      screen: MediaQuery.sizeOf(context),
      onLimit: _onLimit,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => widget
            .owner
            ._build(context, widget.style, constraints.biggest, _limit),
      ),
    );
  }
}

class _LimitWatcher extends SingleChildRenderObjectWidget {
  const _LimitWatcher({
    required this.screen,
    required this.onLimit,
    required Widget super.child,
  });

  final Size screen;
  final ValueChanged<Rect> onLimit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLimitWatcher(screen, onLimit);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLimitWatcher renderObject,
  ) {
    renderObject
      ..screen = screen
      ..onLimit = onLimit;
  }
}

class _RenderLimitWatcher extends RenderProxyBox {
  _RenderLimitWatcher(this._screen, this.onLimit);

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    _reported = null;
  }

  ValueChanged<Rect> onLimit;

  /// The last limit handed over, so a body that is standing still reports
  /// nothing at all.
  Rect? _reported;

  /// Pending report of a limit that changed, fired once the body has been
  /// still for [_settle].
  Timer? _settling;

  /// How long a changed limit has to hold before it is reported.
  ///
  /// **The first limit is reported straight away**, from the first paint:
  /// until then the body has nothing but its own box, which cuts its shadow
  /// square. **After that, a limit is only worth reporting once it has stopped
  /// changing.** Every report costs a rebuild of the whole body — the layout
  /// callback, the shapes, the shader's uniforms — and during a page
  /// transition or a scroll the limit is different on every frame, which is
  /// the one time the frame budget is already spent.
  ///
  /// It used to wait for two consecutive paints to agree. That never happens
  /// for a body that is painted exactly once more at rest — a page that slides
  /// in inside a snapshot is painted live once, when it lands — and the limit
  /// from before the move stayed for the life of the page. So a change starts
  /// a short timer instead, restarted by every paint that moves the limit
  /// again, and when it fires the limit is measured afresh: the body is
  /// wherever it came to rest, whether or not anything painted there twice.
  static const Duration _settle = Duration(milliseconds: 100);

  static bool _same(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.5 &&
      (a.top - b.top).abs() < 0.5 &&
      (a.right - b.right).abs() < 0.5 &&
      (a.bottom - b.bottom).abs() < 0.5;

  @override
  void detach() {
    _settling?.cancel();
    _settling = null;
    super.detach();
  }

  /// The limit as things stand: the visible region in this body's own
  /// coordinates, or null while it is out of view or not invertible.
  Rect? _measure() {
    final Matrix4? toLocal = Matrix4.tryInvert(getTransformTo(null));
    if (toLocal == null) return null;
    final Rect visible = _visibleRegion();
    // Scrolled or slid entirely out of view: nothing it could draw is seen, and
    // the last limit is as good as any until it comes back.
    if (visible.width <= 0 || visible.height <= 0) return null;
    return MatrixUtils.transformRect(toLocal, visible);
  }

  /// Hands [limit] over — from paint after the frame, because it ends in a
  /// `setState`; from the settle timer directly, because a post-frame
  /// callback added outside a frame waits for a frame that, on a page where
  /// nothing moves, nobody schedules.
  void _report(Rect limit, {required bool fromPaint}) {
    _reported = limit;
    if (!fromPaint) {
      onLimit(limit);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onLimit(limit);
    });
  }

  /// The screen, cut down by every clip an ancestor paints this body under,
  /// in global coordinates.
  ///
  /// **A clip is the screen edge again, closer in.** A layer cut short by one
  /// hands the shader a smaller texture than the element it was told about,
  /// and the body comes out shifted and stretched off the content drawn on it
  /// — a card that ends a few pixels under the button it holds is enough.
  /// Walking the ancestors is a handful of virtual calls per paint, and only a
  /// clipping ancestor costs a transform.
  Rect _visibleRegion() {
    Rect region = Offset.zero & _screen;
    RenderObject child = this;
    RenderObject? ancestor = parent;
    while (ancestor != null) {
      final Rect? clip = ancestor.describeApproximatePaintClip(child);
      if (clip != null) {
        region = region.intersect(
          MatrixUtils.transformRect(ancestor.getTransformTo(null), clip),
        );
      }
      child = ancestor;
      ancestor = ancestor.parent;
    }
    return region;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final Rect? limit = _measure();
    if (limit == null) return;
    final Rect? reported = _reported;
    if (reported == null) {
      _report(limit, fromPaint: true);
      return;
    }
    if (_same(reported, limit)) {
      _settling?.cancel();
      _settling = null;
      return;
    }
    _settling?.cancel();
    _settling = Timer(_settle, () {
      _settling = null;
      if (!attached) return;
      final Rect? now = _measure();
      final Rect? last = _reported;
      if (now == null || (last != null && _same(last, now))) return;
      _report(now, fromPaint: false);
    });
  }
}

/// Keeps [bounds] inside [limit], so the element never hangs where its layer
/// would be clipped out from under the shader.
///
/// Losing headroom at the screen edge costs the bulge room it would have had
/// there, which is invisible: there is nothing past the edge to bulge into.
Rect _clampToBox(Rect bounds, Rect limit) {
  if (!limit.width.isFinite || !limit.height.isFinite) return bounds;
  final Rect clamped = Rect.fromLTRB(
    math.max(bounds.left, limit.left),
    math.max(bounds.top, limit.top),
    math.min(bounds.right, limit.right),
    math.min(bounds.bottom, limit.bottom),
  );
  // Shapes entirely outside the limit leave nothing to draw; the element still
  // needs a sane rectangle, so it falls back to the limit itself — the visible
  // region, not the body's own box.
  if (clamped.width <= 0 || clamped.height <= 0) return limit;
  return clamped;
}

/// The union of [blobs], with room for what the field does outside them: the
/// smoothing reaches beyond an edge, and the refraction drags samples from a
/// little further still.
Rect _fusionBounds(
  List<LiquidBlob> blobs,
  double smoothing,
  double refractionAmount,
) {
  Rect union = blobs.first.rect;
  for (int i = 1; i < blobs.length; i++) {
    union = union.expandToInclude(blobs[i].rect);
  }
  return union.inflate(smoothing + refractionAmount + _pressHeadroom);
}

/// The colours and tier a fused body draws with, resolved once per build.
class _FusionStyle {
  const _FusionStyle(
    this.surface,
    this.rim,
    this.glow,
    this.quality,
    this.program,
  );

  static _FusionStyle resolve(
    BuildContext context, {
    required Color? surfaceColor,
    required Color? rimColor,
    required GlassQuality? quality,
  }) {
    final GlassQuality? pinned = quality ?? GlassQualityScope.maybeOf(context);
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    GlassQuality resolved = pinned == null
        ? tier.quality
        : pinned.atMost(tier.ceiling);
    // As on [DrawBackdrop]: a reader who asked for more contrast has asked the
    // refraction to stop, and only a tier pinned on this widget itself
    // overrules that. The resolved tier is what the element is then pinned
    // to, so without this the fused body kept its lens — and its capture — to
    // paint an opaque tint.
    if (quality == null && (MediaQuery.maybeHighContrastOf(context) ?? false)) {
      resolved = resolved.atMost(GlassQuality.plain);
    }
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    return _FusionStyle(
      surfaceColor ?? colors.container,
      rimColor ?? const Color(0xFFFFFFFF).withValues(alpha: 0.45),
      colors.glow,
      resolved,
      resolved.hasShaders ? FluidGlassPrograms.instance.fusion : null,
    );
  }

  final Color surface, rim, glow;
  final GlassQuality quality;
  final ui.FragmentProgram? program;
}

/// Writes one fused body worth of uniforms.
void _configureFusion(
  ui.FragmentShader shader,
  BackdropEffectGeometry geometry,
  Offset origin,
  List<LiquidBlob> blobs, {
  required LiquidFusionPress? press,
  required _FusionStyle style,
  required double smoothing,
  required double saturation,
  required double refractionHeight,
  required double refractionAmount,
  required double rimWidth,
  required double lightAngle,
}) {
  final Size layerSize = geometry.layerSize;
  final Offset offset = geometry.offset;
  int i = 0;
  void put(double value) => shader.setFloat(i++, value);

  // Floats 0..1 are uTextureSize, which the engine overwrites.
  put(0);
  put(0);
  put(layerSize.width);
  put(layerSize.height);
  put(offset.dx);
  put(offset.dy);

  for (int slot = 0; slot < LiquidFusion.maxBlobs; slot++) {
    final LiquidBlob? blob = slot < blobs.length ? blobs[slot] : null;
    // Shape coordinates are the caller's; the shader works in the element's,
    // which starts at the tight box origin.
    final Rect rect = (blob?.rect ?? Rect.zero).shift(-origin);
    put(rect.center.dx);
    put(rect.center.dy);
    put(rect.width / 2);
    put(rect.height / 2);
  }
  for (int slot = 0; slot < LiquidFusion.maxBlobs; slot++) {
    put(slot < blobs.length ? blobs[slot]._radius : 0);
  }
  put(blobs.length.toDouble());
  put(smoothing);
  put(refractionHeight);
  put(refractionAmount);
  // `uBlur`, always zero: the blur is a real Gaussian in the effect chain,
  // ahead of this shader (`scope.blur(blurRadius)` above), and the shader's own
  // taps are skipped.
  put(0);
  put(saturation);

  void putColor(Color color) {
    put(color.r);
    put(color.g);
    put(color.b);
    put(color.a);
  }

  putColor(style.surface);
  putColor(style.rim);
  put(rimWidth);
  put(lightAngle);

  final Offset glow = (press?.position ?? Offset.zero) - origin;
  put(glow.dx);
  put(glow.dy);
  put(press?.radius ?? 0);
  put(press?.progress ?? 0);
  put(press?.reach ?? (press?.radius ?? 0) * 3);
  put(style.glow.r);
  put(style.glow.g);
  put(style.glow.b);
}

/// What a device with no runtime shaders draws: each shape on its own, over
/// the same backdrop. They do not fuse — there is no field to fuse them with —
/// but they are still glass, and still in the right places.
class _PlainFusion extends StatelessWidget {
  const _PlainFusion({
    required this.backdrop,
    required this.blobs,
    required this.surface,
    required this.blurRadius,
    required this.repaint,
    required this.children,
  });

  final Backdrop backdrop;
  final List<LiquidBlob> blobs;
  final Color surface;
  final double blurRadius;
  final Listenable? repaint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final LiquidBlob blob in blobs)
          Positioned.fromRect(
            rect: blob.rect,
            child: LiquidPanel(
              backdrop: backdrop,
              shape: RoundedRectangle(blob._radius),
              surfaceColor: surface,
              blurRadius: math.max(blurRadius, 8),
              repaint: repaint,
              child: const SizedBox.expand(),
            ),
          ),
        ...children,
      ],
    );
  }
}
