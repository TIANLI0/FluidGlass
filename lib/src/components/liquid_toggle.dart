import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';

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

class _LiquidToggleState extends State<LiquidToggle>
    with TickerProviderStateMixin {
  static const double _dragWidth = 20;
  static const double _knobPadding = 2;

  // Replay the track's capsule drawing into the lens. A solid shape needs no
  // texture capture, and its transparent exterior must not be edge-extended.
  final LayerBackdrop _trackBackdrop = LayerBackdrop(extendEdges: false);

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
  void _drawScaledTrack(
    BackdropDrawContext context,
    void Function() drawBackdrop,
  ) {
    final double progress = _animation.pressProgress;
    final double scaleX = lerpDouble(2 / 3, 0.75, progress)!;
    final double scaleY = lerpDouble(0, 0.75, progress)!;
    final Canvas canvas = context.canvas;
    final Offset center = Offset(
      context.size.width / 2,
      context.size.height / 2,
    );
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
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    final Color accentColor = colors.toggleAccent;
    final Color trackColor = colors.track;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    return Stack(
      alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
      // Compose's Box does not clip: the knob grows past the track while
      // pressed and carries a shadow.
      clipBehavior: Clip.none,
      children: <Widget>[
        _ToggleTrack(
          backdrop: _trackBackdrop,
          animation: _animation,
          trackColor: trackColor,
          accentColor: accentColor,
        ),
        ListenableBuilder(
          listenable: _animation,
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
                    ..lens(
                      5 * progress,
                      10 * progress,
                      chromaticAberration: true,
                    );
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
                      ..color = const Color(
                        0xFFFFFFFF,
                      ).withValues(alpha: 1 - progress),
                  );
                },
                // Src-over only, so the isolating save-layer is pure cost.
                isolateSurface: false,
                repaint: _animation,
                child: const SizedBox(width: 40, height: 24),
              ),
            ),
          ),
          builder: (BuildContext context, Widget? child) {
            final double fraction = _animation.value;
            final double translationX = isLtr
                ? lerpDouble(_knobPadding, _knobPadding + _dragWidth, fraction)!
                : lerpDouble(
                    -_knobPadding,
                    -(_knobPadding + _dragWidth),
                    fraction,
                  )!;
            return Transform.translate(
              offset: Offset(translationX, 0),
              child: child,
            );
          },
        ),
      ],
    );
  }
}

class _ToggleTrack extends LeafRenderObjectWidget {
  const _ToggleTrack({
    required this.backdrop,
    required this.animation,
    required this.trackColor,
    required this.accentColor,
  });
  final LayerBackdrop backdrop;
  final DampedDragAnimation animation;
  final Color trackColor;
  final Color accentColor;

  @override
  _RenderToggleTrack createRenderObject(BuildContext context) =>
      _RenderToggleTrack(backdrop, animation, trackColor, accentColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderToggleTrack renderObject,
  ) {
    renderObject.update(backdrop, animation, trackColor, accentColor);
  }
}

/// A solid capsule is cheaper to draw twice than to capture into an image.
/// Keeping a real render object as the source preserves LayerBackdrop's full
/// source/consumer transform mapping (including RTL and ancestor transforms).
class _RenderToggleTrack extends RenderBox implements LayerBackdropSource {
  _RenderToggleTrack(
    this._backdrop,
    this._animation,
    this._trackColor,
    this._accentColor,
  );

  LayerBackdrop _backdrop;
  DampedDragAnimation _animation;
  Color _trackColor;
  Color _accentColor;
  Path? _path;
  final Paint _paint = Paint();

  void update(
    LayerBackdrop backdrop,
    DampedDragAnimation animation,
    Color trackColor,
    Color accentColor,
  ) {
    if (_backdrop != backdrop) {
      if (attached) _backdrop.detachSource(this);
      _backdrop = backdrop;
      if (attached) _backdrop.attachSource(this);
    }
    if (_animation != animation) {
      if (attached) _animation.removeListener(markNeedsPaint);
      _animation = animation;
      if (attached) _animation.addListener(markNeedsPaint);
    }
    if (_trackColor != trackColor || _accentColor != accentColor) {
      _trackColor = trackColor;
      _accentColor = accentColor;
      _backdrop.scheduleNotification();
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _backdrop.attachSource(this);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _backdrop.detachSource(this);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(const Size(64, 28));

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    _path = const Capsule().createOutline(size, TextDirection.ltr).toPath();
  }

  void _draw(Canvas canvas) {
    // Same clip + fill as the old track; replay it before the knob's filters.
    canvas.save();
    canvas.clipPath(_path!);
    canvas.drawRect(
      Offset.zero & size,
      _paint..color = Color.lerp(_trackColor, _accentColor, _animation.value)!,
    );
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _draw(context.canvas);
    context.canvas.restore();
  }

  @override
  Size get sourceSize => size;
  @override
  Offset get sourceGlobalOffset => localToGlobal(Offset.zero);
  @override
  bool get hasContent => attached && hasSize && !size.isEmpty;
  @override
  void invalidateSnapshot() {}
  @override
  void drawSource(
    Canvas canvas,
    double devicePixelRatio, {
    double clampMargin = 0,
    Rect? region,
  }) => _draw(canvas);
}
