import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../draw_backdrop.dart';
import '../internal/rim_path.dart';

/// One light at one instant, in global (screen) coordinates.
@immutable
class GlassLight {
  const GlassLight({
    required this.position,
    required this.strength,
    required this.radius,
    required this.color,
  });

  /// Where the light is, in global logical pixels.
  final Offset position;

  /// 0..1 — how far the light has come on.
  final double strength;

  /// How far it carries, in logical pixels. Past this it lights nothing.
  final double radius;

  final Color color;
}

/// Something that gives off light: a press glow, most often.
///
/// Resolved lazily, during the paint of whatever it lights, so its position
/// is read out of the render tree at the moment it is drawn — a light that
/// rides a scrolling list or a page mid-transition is never a frame behind the
/// glass it lands on.
abstract class GlassLightSource implements Listenable {
  /// The light as it is right now, or null when it is dark.
  GlassLight? resolve();
}

/// Every light on a page, and the one thing every receiver listens to.
///
/// It notifies when any of its sources does — which is only while a press is
/// coming on, moving or going out. With nothing pressed nothing notifies, and
/// nothing lit by it is painted again.
class GlassLightField extends ChangeNotifier {
  final List<GlassLightSource> _sources = <GlassLightSource>[];

  /// The sources that gave off light the last time [lights] was read.
  final Set<GlassLightSource> _lit = <GlassLightSource>{};

  void add(GlassLightSource source) {
    if (_sources.contains(source)) return;
    _sources.add(source);
    source.addListener(notifyListeners);
  }

  void remove(GlassLightSource source) {
    if (!_sources.remove(source)) return;
    source.removeListener(notifyListeners);
    // A source leaving while lit takes its light with it, and everything it
    // lit has to be drawn again without it. One leaving dark changes nothing:
    // notifying anyway repainted every receiver on the page for each glass
    // element disposed in the scope — every list row scrolled away, every
    // element of a page popped.
    if (_lit.remove(source)) notifyListeners();
  }

  /// The lights that are on.
  Iterable<GlassLight> get lights sync* {
    for (final GlassLightSource source in _sources) {
      final GlassLight? light = source.resolve();
      if (light != null && light.strength > 0) {
        _lit.add(source);
        yield light;
      } else {
        _lit.remove(source);
      }
    }
  }

  @override
  void dispose() {
    for (final GlassLightSource source in _sources) {
      source.removeListener(notifyListeners);
    }
    _sources.clear();
    _lit.clear();
    super.dispose();
  }
}

/// Lets the light glass gives off land on the glass around it.
///
/// Inside a scope, a press on one element lights the rims of its neighbours on
/// the side facing it, falling off with distance, and follows the finger as it
/// moves; outside one, every press lights only the control it is on, as
/// before. Put one around a page, not around each control — the light has to
/// be able to reach from one element to the next.
///
/// **What it costs.** Each glass element inside the scope gets one extra
/// repaint boundary, over its content, that draws a few strokes when a light
/// is in reach and nothing otherwise. The glass itself is never repainted by a
/// moving light, which matters on the sampled tier, where a repaint of the
/// glass is a fresh read of the backdrop. And a light only moves while a press
/// is animating, which is when frames are being drawn anyway: a still page
/// costs nothing.
class GlassLightScope extends StatefulWidget {
  const GlassLightScope({super.key, this.field, required this.child});

  /// A field of your own, to add sources the library does not know about.
  /// Null makes one.
  final GlassLightField? field;

  final Widget child;

  /// The nearest field, or null outside any scope.
  static GlassLightField? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassLightInherited>()?.field;

  @override
  State<GlassLightScope> createState() => _GlassLightScopeState();
}

class _GlassLightScopeState extends State<GlassLightScope> {
  GlassLightField? _own;

  GlassLightField get _field => widget.field ?? (_own ??= GlassLightField());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _GlassLightInherited(field: _field, child: widget.child);
}

class _GlassLightInherited extends InheritedWidget {
  const _GlassLightInherited({required this.field, required super.child});

  final GlassLightField field;

  @override
  bool updateShouldNotify(_GlassLightInherited oldWidget) =>
      oldWidget.field != field;
}

/// Draws the light of the nearest [GlassLightScope] where it lands on [shape]:
/// along the rim, brightest where the rim is nearest the light, with a faint
/// wash over the face.
///
/// [DrawBackdrop] puts one over its content by itself inside a scope; use this
/// directly only for a surface that is not a [DrawBackdrop].
class GlassLightReceiver extends StatelessWidget {
  const GlassLightReceiver({
    super.key,
    required this.shape,
    required this.child,
  });

  final GlassShapeGetter shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GlassLightField? field = GlassLightScope.maybeOf(context);
    if (field == null) return child;
    return Stack(
      // The element's constraints reach its content exactly as they would
      // without the light: a loosened constraint would let content that
      // expects to fill the glass shrink inside it.
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _LightLanding(field: field, shape: shape),
            ),
          ),
        ),
      ],
    );
  }
}

class _LightLanding extends LeafRenderObjectWidget {
  const _LightLanding({required this.field, required this.shape});

  final GlassLightField field;
  final GlassShapeGetter shape;

  @override
  _RenderLightLanding createRenderObject(BuildContext context) =>
      _RenderLightLanding(
        field,
        shape,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLightLanding renderObject,
  ) {
    renderObject
      ..field = field
      ..shape = shape
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

class _RenderLightLanding extends RenderBox {
  _RenderLightLanding(this._field, this.shape, this._textDirection);

  /// Resolves start/end corners the way the glass under the light did.
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  GlassLightField _field;
  set field(GlassLightField value) {
    if (value == _field) return;
    if (attached) _field.removeListener(markNeedsPaint);
    _field = value;
    if (attached) _field.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GlassShapeGetter shape;

  final RimPathCache _cache = RimPathCache();

  // Roughly inverse-square: bright close in, a long faint tail.
  static const List<double> _stops = <double>[0, 0.22, 0.55, 1];
  static const List<double> _falloff = <double>[1, 0.5, 0.16, 0];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _field.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _field.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    Matrix4? toLocal;
    RimPath? rim;
    for (final GlassLight light in _field.lights) {
      toLocal ??= _inverseTransform();
      if (toLocal == null) return;
      final Offset local = MatrixUtils.transformPoint(toLocal, light.position);
      // Nothing to draw if the light cannot reach any part of this element.
      final double dx = local.dx.clamp(0.0, size.width) - local.dx;
      final double dy = local.dy.clamp(0.0, size.height) - local.dy;
      if (dx * dx + dy * dy > light.radius * light.radius) continue;

      rim ??= _cache.of(shape(), size, _textDirection);
      final Canvas canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);

      ui.Gradient gradient(double alpha) =>
          ui.Gradient.radial(local, light.radius, <Color>[
            for (final double f in _falloff)
              light.color.withValues(
                alpha: (light.color.a * alpha * f * light.strength).clamp(
                  0.0,
                  1.0,
                ),
              ),
          ], _stops);

      canvas.drawPath(
        rim.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..shader = gradient(0.5)
          ..blendMode = BlendMode.plus,
      );
      canvas.drawPath(
        rim.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..shader = gradient(0.9)
          ..blendMode = BlendMode.plus,
      );
      canvas.clipPath(rim.path);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = gradient(0.12)
          ..blendMode = BlendMode.plus,
      );
      canvas.restore();
    }
  }

  /// Global to local, through every transform above — a scroll offset, a page
  /// sliding in, a press deformation.
  Matrix4? _inverseTransform() {
    final Matrix4 toGlobal = getTransformTo(null);
    final double det = toGlobal.invert();
    return det == 0 ? null : toGlobal;
  }
}
