import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'demo_shaders.dart';
import 'drag_gesture_inspector.dart';
import 'spring.dart';

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
    DemoShaders.instance.addListener(notifyListeners);
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

  /// Attaches the pointer handling that drives the highlight.
  Widget wrapGestures({required Widget child}) {
    return DragInspector(
      behavior: HitTestBehavior.translucent,
      onDragStart: (Offset position, Size size) => _down(position),
      onDrag: (Offset position, Offset delta, Size size) => _move(position),
      onDragEnd: _up,
      onDragCancel: _up,
      child: child,
    );
  }

  @override
  void dispose() {
    DemoShaders.instance.removeListener(notifyListeners);
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
      painter: _InteractiveHighlightPainter(highlight),
      child: child,
    );
  }
}

class _InteractiveHighlightPainter extends CustomPainter {
  _InteractiveHighlightPainter(this.highlight) : super(repaint: highlight);

  final InteractiveHighlight highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = highlight.pressProgress;
    if (progress <= 0.0) return;

    final ui.FragmentProgram? program = DemoShaders.instance.interactiveHighlight;
    if (program == null) {
      // Unshaded fallback for backends without runtime shaders.
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
    final ui.FragmentShader shader = program.fragmentShader()
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
    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant _InteractiveHighlightPainter oldDelegate) => true;
}
