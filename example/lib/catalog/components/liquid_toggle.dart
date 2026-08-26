import 'dart:ui' show lerpDouble;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/damped_drag_animation.dart';

/// A switch whose knob is a bead of liquid glass: it squashes as you press,
/// stretches with its velocity, and refracts the track underneath.
class LiquidToggle extends StatefulWidget {
  const LiquidToggle({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.backdrop,
  });

  final bool selected;
  final ValueChanged<bool> onSelect;
  final Backdrop backdrop;

  @override
  State<LiquidToggle> createState() => _LiquidToggleState();
}

class _LiquidToggleState extends State<LiquidToggle> with TickerProviderStateMixin {
  static const double _dragWidth = 20;
  static const double _knobPadding = 2;

  final LayerBackdrop _trackBackdrop = LayerBackdrop();

  late final DampedDragAnimation _animation;
  late final Backdrop _knobBackdrop;

  bool _didDrag = false;
  double _fraction = 0;

  @override
  void initState() {
    super.initState();
    _fraction = widget.selected ? 1 : 0;
    _animation = DampedDragAnimation(
      vsync: this,
      initialValue: _fraction,
      valueRange: (start: 0, end: 1),
      visibilityThreshold: 0.001,
      initialScale: 1,
      pressedScale: 1.5,
      onDragStopped: _onDragStopped,
      onDrag: _onDrag,
    );
    _knobBackdrop = CombinedBackdrop.of(
      widget.backdrop,
      WrappedBackdrop(_trackBackdrop, _drawScaledTrack),
    );
  }

  @override
  void didUpdateWidget(LiquidToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double target = widget.selected ? 1 : 0;
    if (target != _fraction) {
      _fraction = target;
      _animation.animateToValue(target);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _trackBackdrop.dispose();
    super.dispose();
  }

  void _setFraction(double value) {
    _fraction = value;
    _animation.updateValue(value);
  }

  void _onDrag(Size size, Offset dragAmount) {
    if (!_didDrag) {
      _didDrag = dragAmount.dx != 0;
    }
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = dragAmount.dx / _dragWidth;
    _setFraction(
      (isLtr ? _fraction + delta : _fraction - delta).clamp(0.0, 1.0),
    );
  }

  void _onDragStopped() {
    if (_didDrag) {
      _fraction = _animation.targetValue >= 0.5 ? 1 : 0;
      _animation.updateValue(_fraction);
      widget.onSelect(_fraction == 1);
      _didDrag = false;
    } else {
      _fraction = widget.selected ? 0 : 1;
      _animation.updateValue(_fraction);
      widget.onSelect(_fraction == 1);
    }
  }

  /// The track backdrop, squashed towards the knob's centre while pressed.
  void _drawScaledTrack(BackdropDrawContext context, void Function() drawBackdrop) {
    final double progress = _animation.pressProgress;
    final double scaleX = lerpDouble(2 / 3, 0.75, progress)!;
    final double scaleY = lerpDouble(0, 0.75, progress)!;
    final Canvas canvas = context.canvas;
    final Offset center =
        Offset(context.size.width / 2, context.size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-center.dx, -center.dy);
    drawBackdrop();
    canvas.restore();
  }

  void _knobLayerBlock(GlassLayer layer) {
    layer.scaleX = _animation.scaleX;
    layer.scaleY = _animation.scaleY;
    final double velocity = _animation.velocity / 50.0;
    layer.scaleX /= 1.0 - (velocity * 0.75).clamp(-0.2, 0.2);
    layer.scaleY *= 1.0 - (velocity * 0.25).clamp(-0.2, 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color accentColor =
        isLight ? const Color(0xFF34C759) : const Color(0xFF30D158);
    final Color trackColor = isLight
        ? const Color(0xFF787878).withValues(alpha: 0.2)
        : const Color(0xFF787880).withValues(alpha: 0.36);
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    return Stack(
      alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
      // Compose's Box does not clip: the knob grows past the track while
      // pressed and carries a shadow.
      clipBehavior: Clip.none,
      children: <Widget>[
        BackdropLayer(
          backdrop: _trackBackdrop,
          child: ClipPath(
            clipper: const GlassShapeClipper(Capsule()),
            child: CustomPaint(
              painter: _TrackPainter(_animation, trackColor, accentColor),
              size: const Size(64, 28),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _animation,
          builder: (BuildContext context, Widget? _) {
            final double fraction = _animation.value;
            final double translationX = isLtr
                ? lerpDouble(_knobPadding, _knobPadding + _dragWidth, fraction)!
                : lerpDouble(-_knobPadding, -(_knobPadding + _dragWidth), fraction)!;
            return Transform.translate(
              offset: Offset(translationX, 0),
              child: Semantics(
                toggled: widget.selected,
                child: _animation.wrapGestures(
                  child: DrawBackdrop(
                    backdrop: _knobBackdrop,
                    shape: () => const Capsule(),
                    effects: (BackdropEffectScope scope) {
                      final double progress = _animation.pressProgress;
                      scope
                        ..blur(8 * (1 - progress))
                        ..lens(5 * progress, 10 * progress,
                            chromaticAberration: true);
                    },
                    highlight: () {
                      final double progress = _animation.pressProgress;
                      return Highlight.ambient.copyWith(
                        width: Highlight.ambient.width / 1.5,
                        blurRadius: Highlight.ambient.blurRadius / 1.5,
                        alpha: progress,
                      );
                    },
                    shadow: () => GlassShadow(
                      radius: 4,
                      color: const Color(0xFF000000).withValues(alpha: 0.05),
                    ),
                    innerShadow: () {
                      final double progress = _animation.pressProgress;
                      return GlassInnerShadow(
                        radius: 4 * progress,
                        alpha: progress,
                      );
                    },
                    layerBlock: _knobLayerBlock,
                    onDrawSurface: (Canvas canvas, Size size) {
                      final double progress = _animation.pressProgress;
                      canvas.drawRect(
                        Offset.zero & size,
                        Paint()
                          ..color = const Color(0xFFFFFFFF)
                              .withValues(alpha: 1 - progress),
                      );
                    },
                    // Src-over only, so the isolating save-layer is pure cost.
                    isolateSurface: false,
                    repaint: _animation,
                    child: const SizedBox(width: 40, height: 24),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.animation, this.trackColor, this.accentColor)
      : super(repaint: animation);

  final DampedDragAnimation animation;
  final Color trackColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(trackColor, accentColor, animation.value)!,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.trackColor != trackColor || oldDelegate.accentColor != accentColor;
}
