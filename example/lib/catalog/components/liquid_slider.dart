import 'dart:ui' show lerpDouble;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/damped_drag_animation.dart';

/// Fills the played part of the track, matching the capsule the old
/// width-animated Container produced: a capsule of the current fill width,
/// rounded at both ends.
class _TrackFillPainter extends CustomPainter {
  _TrackFillPainter({
    required this.animation,
    required this.color,
    required this.isLtr,
  }) : super(repaint: animation);

  final DampedDragAnimation animation;
  final Color color;
  final bool isLtr;

  @override
  void paint(Canvas canvas, Size size) {
    final double width =
        (size.width * animation.progress).roundToDouble().clamp(0.0, size.width);
    if (width <= 0) return;
    final Rect rect = isLtr
        ? Rect.fromLTWH(0, 0, width, size.height)
        : Rect.fromLTWH(size.width - width, 0, width, size.height);
    final GlassOutline outline =
        const Capsule().createOutline(rect.size, TextDirection.ltr);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    outline.draw(canvas, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackFillPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.color != color ||
      oldDelegate.isLtr != isLtr;
}

/// A slider whose thumb is a bead of liquid glass, refracting the track it
/// slides along.
class LiquidSlider extends StatefulWidget {
  const LiquidSlider({
    super.key,
    required this.value,
    required this.onValueChanged,
    required this.valueRange,
    required this.visibilityThreshold,
    required this.backdrop,
  });

  final double value;
  final ValueChanged<double> onValueChanged;
  final ({double start, double end}) valueRange;
  final double visibilityThreshold;
  final Backdrop backdrop;

  @override
  State<LiquidSlider> createState() => _LiquidSliderState();
}

class _LiquidSliderState extends State<LiquidSlider> with TickerProviderStateMixin {
  static const double _thumbWidth = 40;
  static const double _thumbHeight = 24;

  final LayerBackdrop _trackBackdrop = LayerBackdrop();

  late final DampedDragAnimation _animation;
  late final Backdrop _thumbBackdrop;

  bool _didDrag = false;
  double _trackWidth = 0;

  @override
  void initState() {
    super.initState();
    _animation = DampedDragAnimation(
      vsync: this,
      initialValue: widget.value,
      valueRange: widget.valueRange,
      visibilityThreshold: widget.visibilityThreshold,
      initialScale: 1,
      pressedScale: 1.5,
      onDragStopped: () {
        // didDrag stays latched; only the toggle clears it.
        if (_didDrag) {
          widget.onValueChanged(_animation.targetValue);
        }
      },
      onDrag: _onDrag,
    );
    _thumbBackdrop = CombinedBackdrop.of(
      widget.backdrop,
      WrappedBackdrop(_trackBackdrop, _drawScaledTrack),
    );
  }

  @override
  void didUpdateWidget(LiquidSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animation.targetValue != widget.value) {
      _animation.updateValue(widget.value);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _trackBackdrop.dispose();
    super.dispose();
  }

  double get _span => widget.valueRange.end - widget.valueRange.start;

  void _onDrag(Size size, Offset dragAmount) {
    if (!_didDrag) {
      _didDrag = dragAmount.dx != 0;
    }
    if (_trackWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = _span * (dragAmount.dx / _trackWidth);
    final double next = isLtr
        ? _animation.targetValue + delta
        : _animation.targetValue - delta;
    widget.onValueChanged(
      next.clamp(widget.valueRange.start, widget.valueRange.end),
    );
  }

  void _onTrackTap(Offset position) {
    if (_trackWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = _span * (position.dx / _trackWidth);
    final double target = (isLtr
            ? widget.valueRange.start + delta
            : widget.valueRange.end - delta)
        .clamp(widget.valueRange.start, widget.valueRange.end);
    _animation.animateToValue(target);
    widget.onValueChanged(target);
  }

  /// The track backdrop, squashed towards the thumb's centre while pressed.
  void _drawScaledTrack(BackdropDrawContext context, void Function() drawBackdrop) {
    final double progress = _animation.pressProgress;
    final double scaleX = lerpDouble(2 / 3, 1, progress)!;
    final double scaleY = lerpDouble(0, 1, progress)!;
    final Canvas canvas = context.canvas;
    final Offset center = Offset(context.size.width / 2, context.size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-center.dx, -center.dy);
    drawBackdrop();
    canvas.restore();
  }

  void _thumbLayerBlock(GlassLayer layer) {
    layer.scaleX = _animation.scaleX;
    layer.scaleY = _animation.scaleY;
    final double velocity = _animation.velocity / 10.0;
    layer.scaleX /= 1.0 - (velocity * 0.75).clamp(-0.2, 0.2);
    layer.scaleY *= 1.0 - (velocity * 0.25).clamp(-0.2, 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color accentColor =
        isLight ? const Color(0xFF0088FF) : const Color(0xFF0091FF);
    final Color trackColor = isLight
        ? const Color(0xFF787878).withValues(alpha: 0.2)
        : const Color(0xFF787880).withValues(alpha: 0.36);
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _trackWidth = constraints.maxWidth;
        return SizedBox(
          width: _trackWidth,
          height: _thumbHeight,
          child: Stack(
            alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
            // Compose's Box does not clip: the thumb grows past the track
            // while pressed and carries a shadow.
            clipBehavior: Clip.none,
            children: <Widget>[
              BackdropLayer(
                backdrop: _trackBackdrop,
                child: Stack(
                  alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    GestureDetector(
                      onTapUp: (TapUpDetails details) =>
                          _onTrackTap(details.localPosition),
                      child: ClipPath(
                        clipper: const GlassShapeClipper(Capsule()),
                        child: Container(
                          width: _trackWidth,
                          height: 6,
                          color: trackColor,
                        ),
                      ),
                    ),
                    // Drawn over the track, but taps must reach the track
                    // beneath it, so the fill takes no pointer input. Painted
                    // rather than laid out: a Container whose width changes
                    // every frame re-runs layout and rebuilds its element,
                    // when only pixels changed.
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(_trackWidth, 6),
                        painter: _TrackFillPainter(
                          animation: _animation,
                          color: accentColor,
                          isLtr: isLtr,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: _animation,
                builder: (BuildContext context, Widget? _) {
                  final double translationX =
                      (-_thumbWidth / 2 + _trackWidth * _animation.progress).clamp(
                            -_thumbWidth / 4,
                            _trackWidth - _thumbWidth * 3 / 4,
                          ) *
                          (isLtr ? 1 : -1);
                  return Transform.translate(
                    offset: Offset(translationX, 0),
                    child: _animation.wrapGestures(
                      child: DrawBackdrop(
                        backdrop: _thumbBackdrop,
                        shape: () => const Capsule(),
                        effects: (BackdropEffectScope scope) {
                          final double progress = _animation.pressProgress;
                          scope
                            ..blur(8 * (1 - progress))
                            ..lens(10 * progress, 14 * progress,
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
                        layerBlock: _thumbLayerBlock,
                        onDrawSurface: (Canvas canvas, Size size) {
                          final double progress = _animation.pressProgress;
                          canvas.drawRect(
                            Offset.zero & size,
                            Paint()
                              ..color = const Color(0xFFFFFFFF)
                                  .withValues(alpha: 1 - progress),
                          );
                        },
                        // Src-over only, so the isolating save-layer is pure
                        // cost.
                        isolateSurface: false,
                        repaint: _animation,
                        child: const SizedBox(
                          width: _thumbWidth,
                          height: _thumbHeight,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
