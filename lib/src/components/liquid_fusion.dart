import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _build(context, style, constraints.biggest),
    );
  }

  /// What the element may not grow past, in this widget coordinates.
  ///
  /// The screen, not this widget own box. A fused body has every reason to
  /// reach outside the box it was laid out in — a control leans out of its row
  /// under a drag, two controls bulge towards each other — and clipping it to
  /// the box cuts exactly that. What it may *not* do is reach past the screen:
  /// the element layer is clipped there, and the shader maps fragments through
  /// uTextureSize and uLayerSize, so a texture that is no longer the size the
  /// element thinks it is puts the whole field somewhere else.
  ///
  /// Read from the last layout, which is a frame old and does not matter: this
  /// is where the widget sits, not what is moving inside it.
  Rect _limitFor(BuildContext context, Size box) {
    final RenderObject? self = context.findRenderObject();
    final Size screen = MediaQuery.sizeOf(context);
    if (self is! RenderBox || !self.hasSize || !self.attached) {
      return Offset.zero & box;
    }
    final Offset origin = self.localToGlobal(Offset.zero);
    return Rect.fromLTWH(-origin.dx, -origin.dy, screen.width, screen.height);
  }

  Widget _build(BuildContext context, _FusionStyle style, Size box) {
    // The element is a plain rectangle — a fused body has no rounded-rect
    // outline to clip to, and the shader is transparent outside the field, so
    // the rectangle never shows. It is kept tight around the shapes all the
    // same: the box is what gets captured from the backdrop and what the
    // shader runs over, so a group spanning the screen would read and shade
    // the screen to draw two controls.
    //
    // And it is kept on screen — see [_limitFor]. It may leave the box it was
    // laid out in, which is what lets a control lean out of a row under a
    // drag; it may not leave the screen, because there its layer is clipped
    // and the shader mapping goes with it.
    final Rect bounds = _clampToBox(
      _fusionBounds(blobs, smoothing, refractionAmount),
      _limitFor(context, box),
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
                  blurRadius: blurRadius,
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

  @override
  bool shouldRepaint(_FusionShadow old) => true;
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
  // A shape entirely outside the box leaves nothing to draw; the element still
  // needs a sane rectangle, so fall back to the box itself.
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
  const _FusionStyle(this.surface, this.rim, this.quality, this.program);

  static _FusionStyle resolve(
    BuildContext context, {
    required Color? surfaceColor,
    required Color? rimColor,
    required GlassQuality? quality,
  }) {
    final GlassQuality? pinned = quality ?? GlassQualityScope.maybeOf(context);
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final GlassQuality resolved = pinned == null
        ? tier.quality
        : pinned.atMost(tier.ceiling);
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    return _FusionStyle(
      surfaceColor ?? colors.container,
      rimColor ?? const Color(0xFFFFFFFF).withValues(alpha: 0.45),
      resolved,
      resolved.hasShaders ? FluidGlassPrograms.instance.fusion : null,
    );
  }

  final Color surface, rim;
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
  required double blurRadius,
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
  // The blur is a pass of its own now; the taps stay in the shader only as a
  // way to soften a sample the rim magnifies, and the chain does that better.
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
