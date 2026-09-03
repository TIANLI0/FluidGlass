import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../animation/spring.dart';
import '../gestures/drag_gesture_inspector.dart';
import '../internal/shader_programs.dart';
import '../quality/glass_device_tier.dart';
import '../quality/glass_quality.dart';

/// The press highlight that follows a finger across a liquid component: a soft
/// radial glow plus a flat brighten, both added over the glass surface.
class InteractiveHighlight extends ChangeNotifier {
  InteractiveHighlight({
    required TickerProvider vsync,
    this.position = _defaultPosition,
  })  : _pressProgressAnimation =
            SpringValue(vsync: vsync, value: 0.0, visibilityThreshold: 0.001),
        _positionAnimation =
            SpringOffset(vsync: vsync, value: Offset.zero, visibilityThreshold: 0.5) {
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
  /// [quality] is the tier to draw at; null follows the device.
  void paintOverlay(Canvas canvas, Size size, {GlassQuality? quality}) {
    _paintInteractiveHighlight(canvas, size, this, quality);
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

class _InteractiveHighlightOverlay extends StatelessWidget {
  const _InteractiveHighlightOverlay({required this.highlight, required this.child});

  final InteractiveHighlight highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InteractiveHighlightPainter(
        highlight,
        GlassQualityScope.maybeOf(context),
      ),
      child: child,
    );
  }
}

class _InteractiveHighlightPainter extends CustomPainter {
  _InteractiveHighlightPainter(this.highlight, this.pinnedQuality)
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

  @override
  void paint(Canvas canvas, Size size) =>
      _paintInteractiveHighlight(canvas, size, highlight, pinnedQuality);

  @override
  bool shouldRepaint(covariant _InteractiveHighlightPainter oldDelegate) => true;
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
) {
  final double progress = highlight.pressProgress;
  if (progress <= 0.0) return;

  final GlassDeviceTier tier = GlassDeviceTier.instance;
  final GlassQuality quality =
      pinnedQuality == null ? tier.quality : pinnedQuality.atMost(tier.ceiling);
  final ui.FragmentProgram? program =
      quality.hasShaders ? FluidGlassPrograms.instance.interactiveHighlight : null;
  if (program == null) {
    // The flat fallback: for a backend with no runtime shaders, and equally
    // for the cheap tier, which is defined as running no fragment programs at
    // all. A glow under the finger is not worth a shader pass on a device
    // that gave up the refraction to keep its frame budget.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25 * progress)
        ..blendMode = BlendMode.plus,
    );
    return;
  }

  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08 * progress)
      ..blendMode = BlendMode.plus,
  );

  final Offset position =
      highlight.position(size, highlight._positionAnimation.value);
  // White at 0.15 * progress, premultiplied: Skia premultiplies AGSL
  // layout(color) uniforms, and the shader's result has to stay a valid
  // premultiplied colour. Passing it un-premultiplied would add a full-white
  // disc under the finger instead of a soft glow.
  final double alpha = 0.15 * progress;
  final ui.FragmentShader shader =
      _highlightShaders[program] ??= program.fragmentShader();
  shader
    ..setFloat(0, alpha)
    ..setFloat(1, alpha)
    ..setFloat(2, alpha)
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
