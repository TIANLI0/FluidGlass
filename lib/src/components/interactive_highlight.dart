import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../animation/spring.dart';
import '../gestures/drag_gesture_inspector.dart';
import '../internal/shader_programs.dart';
import '../light/glass_light.dart';
import '../quality/glass_device_tier.dart';
import '../quality/glass_quality.dart';
import '../theme/liquid_glass_theme.dart';

/// The press highlight that follows a finger across a liquid component: a soft
/// radial glow plus a flat brighten, both added over the glass surface.
class InteractiveHighlight extends ChangeNotifier {
  InteractiveHighlight({
    required TickerProvider vsync,
    this.position = _defaultPosition,
  }) : _pressProgressAnimation = SpringValue(
         vsync: vsync,
         value: 0.0,
         visibilityThreshold: 0.001,
       ),
       _positionAnimation = SpringOffset(
         vsync: vsync,
         value: Offset.zero,
         visibilityThreshold: 0.5,
       ) {
    _pressProgressAnimation.addListener(notifyListeners);
    _positionAnimation.addListener(notifyListeners);
    FluidGlassPrograms.instance.addListener(notifyListeners);
  }

  static Offset _defaultPosition(Size size, Offset offset) => offset;

  /// Maps the raw pointer position to where the glow should sit.
  final Offset Function(Size size, Offset offset) position;

  final SpringValue _pressProgressAnimation;
  final SpringOffset _positionAnimation;

  Offset _startPosition = Offset.zero;

  double get pressProgress => _pressProgressAnimation.value;

  /// How far the pointer has travelled since it went down.
  Offset get offset => _positionAnimation.value - _startPosition;

  /// Where the glow sits on an element of [size], in that element own
  /// coordinates — the spring-followed pointer, through [position].
  ///
  /// [paintOverlay] uses this to draw the glow itself. It is public for the
  /// case where something else draws it: a fused body lights every control in
  /// it from one glow, so the glow has to be read out of the control that owns
  /// the press and handed over.
  Offset glowPosition(Size size) => position(size, _positionAnimation.value);

  late final _pressProgressSpec = springOf(0.5, 300.0);
  late final _positionSpec = springOf(0.5, 300.0);

  /// The pointer went down.
  void handleDown(Offset position) => _down(position);

  /// The pointer moved; the glow snaps to it.
  void handleMove(Offset position) => _move(position);

  /// The pointer went up or the gesture was taken over.
  void handleUp() => _up();

  void _down(Offset position) {
    _startPosition = position;
    _pressProgressAnimation.animateTo(1.0, _pressProgressSpec);
    _positionAnimation.snapTo(position);
  }

  void _move(Offset position) {
    _positionAnimation.snapTo(position);
  }

  void _up() {
    _pressProgressAnimation.animateTo(0.0, _pressProgressSpec);
    _positionAnimation.animateTo(_startPosition, _positionSpec);
  }

  /// Draws the highlight behind [child].
  Widget wrapOverlay({required Widget child}) {
    return _InteractiveHighlightOverlay(highlight: this, child: child);
  }

  /// Paints the highlight directly, over a [size]-sized area at the canvas
  /// origin — what [wrapOverlay] draws, for a caller composing its own picture.
  ///
  /// [quality] is the tier to draw at; null follows the device. [color] is
  /// the colour of the light, white by default — pass
  /// `LiquidGlassTheme.of(context).glow` to follow the theme.
  void paintOverlay(
    Canvas canvas,
    Size size, {
    GlassQuality? quality,
    Color color = const Color(0xFFFFFFFF),
  }) {
    _paintInteractiveHighlight(canvas, size, this, quality, color);
  }

  /// Attaches the pointer handling that drives the highlight.
  ///
  /// [onTap] fires on release however far the pointer travelled, matching
  /// Compose's slop-free `clickable`.
  Widget wrapGestures({required Widget child, VoidCallback? onTap}) {
    return DragInspector(
      behavior: HitTestBehavior.translucent,
      onDragStart: (Offset position, Size size) => _down(position),
      onDrag: (Offset position, Offset delta, Size size) => _move(position),
      onDragEnd: _up,
      onDragCancel: _up,
      onTap: onTap,
      child: child,
    );
  }

  @override
  void dispose() {
    FluidGlassPrograms.instance.removeListener(notifyListeners);
    _pressProgressAnimation.dispose();
    _positionAnimation.dispose();
    super.dispose();
  }
}

/// Draws the glow, and — inside a [GlassLightScope] — lends it to the field so
/// it lands on the glass around this element too.
class _InteractiveHighlightOverlay extends StatefulWidget {
  const _InteractiveHighlightOverlay({
    required this.highlight,
    required this.child,
  });

  final InteractiveHighlight highlight;
  final Widget child;

  @override
  State<_InteractiveHighlightOverlay> createState() =>
      _InteractiveHighlightOverlayState();
}

class _InteractiveHighlightOverlayState
    extends State<_InteractiveHighlightOverlay> {
  GlassLightField? _field;
  _HighlightLightSource? _source;
  Color _glow = const Color(0xFFFFFFFF);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _glow = LiquidGlassTheme.of(context).glow;
    _source?.color = _glow;
    final GlassLightField? field = GlassLightScope.maybeOf(context);
    if (field != _field) {
      _unregister();
      _field = field;
      _register();
    }
  }

  @override
  void didUpdateWidget(_InteractiveHighlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      _unregister();
      _register();
    }
  }

  void _register() {
    final GlassLightField? field = _field;
    if (field == null) return;
    final _HighlightLightSource source = _HighlightLightSource(
      widget.highlight,
      this,
      _glow,
    );
    _source = source;
    field.add(source);
  }

  void _unregister() {
    final _HighlightLightSource? source = _source;
    if (source != null) _field?.remove(source);
    _source = null;
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InteractiveHighlightPainter(
        widget.highlight,
        GlassQualityScope.maybeOf(context),
        _glow,
      ),
      child: widget.child,
    );
  }
}

/// A press glow, as a light the field can hand to other glass.
class _HighlightLightSource implements GlassLightSource {
  _HighlightLightSource(this.highlight, this.state, this.color);

  final InteractiveHighlight highlight;
  final State<StatefulWidget> state;
  Color color;

  @override
  void addListener(VoidCallback listener) => highlight.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      highlight.removeListener(listener);

  @override
  GlassLight? resolve() {
    final double strength = highlight.pressProgress;
    if (strength <= 0 || !state.mounted) return null;
    final RenderObject? object = state.context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    final Size size = object.size;
    // About three times the control's own size, within bounds: far enough to
    // reach the next control over, not so far that a large panel lights the
    // whole screen.
    final double radius = (size.shortestSide * 3).clamp(140.0, 240.0);
    return GlassLight(
      position: object.localToGlobal(highlight.glowPosition(size)),
      strength: strength,
      radius: radius,
      color: color,
    );
  }
}

class _InteractiveHighlightPainter extends CustomPainter {
  _InteractiveHighlightPainter(this.highlight, this.pinnedQuality, this.color)
    : super(
        // The tier is read at paint time, so a change to it has to reach the
        // paint that reads it — the same subscription every glass element
        // makes.
        repaint: Listenable.merge(<Listenable>[
          highlight,
          GlassDeviceTier.instance,
        ]),
      );

  final InteractiveHighlight highlight;

  /// The tier pinned by an enclosing [GlassQualityScope], or null to follow the
  /// device.
  final GlassQuality? pinnedQuality;

  /// The colour of the light.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      _paintInteractiveHighlight(canvas, size, highlight, pinnedQuality, color);

  @override
  bool shouldRepaint(covariant _InteractiveHighlightPainter oldDelegate) =>
      true;
}

/// One shader per program, reused across frames: uniforms are cheap to re-set,
/// creating and compiling a fresh instance every paint is not.
final Expando<ui.FragmentShader> _highlightShaders =
    Expando<ui.FragmentShader>();

/// Draws the glow for [highlight] over a [size]-sized area at the canvas
/// origin.
///
/// [pinnedQuality] is resolved the same way [DrawBackdrop] resolves it, so a
/// component's glow and its glass never disagree about which tier they are
/// drawing at.
void _paintInteractiveHighlight(
  Canvas canvas,
  Size size,
  InteractiveHighlight highlight,
  GlassQuality? pinnedQuality,
  Color color,
) {
  final double progress = highlight.pressProgress;
  if (progress <= 0.0) return;

  final GlassDeviceTier tier = GlassDeviceTier.instance;
  final GlassQuality quality = pinnedQuality == null
      ? tier.quality
      : pinnedQuality.atMost(tier.ceiling);
  final ui.FragmentProgram? program = quality.hasShaders
      ? FluidGlassPrograms.instance.interactiveHighlight
      : null;
  if (program == null) {
    // The flat fallback: for a backend with no runtime shaders, and equally
    // for the cheap tier, which is defined as running no fragment programs at
    // all. A glow under the finger is not worth a shader pass on a device
    // that gave up the refraction to keep its frame budget.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.25 * progress)
        ..blendMode = BlendMode.plus,
    );
    return;
  }

  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = color.withValues(alpha: color.a * 0.08 * progress)
      ..blendMode = BlendMode.plus,
  );

  final Offset position = highlight.position(
    size,
    highlight._positionAnimation.value,
  );
  // White at 0.15 * progress, premultiplied: Skia premultiplies AGSL
  // layout(color) uniforms, and the shader's result has to stay a valid
  // premultiplied colour. Passing it un-premultiplied would add a full-white
  // disc under the finger instead of a soft glow.
  final double alpha = 0.15 * progress * color.a;
  final ui.FragmentShader shader = _highlightShaders[program] ??= program
      .fragmentShader();
  shader
    ..setFloat(0, color.r * alpha)
    ..setFloat(1, color.g * alpha)
    ..setFloat(2, color.b * alpha)
    ..setFloat(3, alpha)
    ..setFloat(4, size.shortestSide * 1.5)
    ..setFloat(5, position.dx.clamp(0.0, size.width))
    ..setFloat(6, position.dy.clamp(0.0, size.height));

  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus,
  );
}
