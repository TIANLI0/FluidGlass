import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';
import '../internal/animated_translation.dart';
import '../internal/control_focus.dart';

/// A switch whose knob is a bead of liquid glass: it squashes as you press,
/// stretches with its velocity, and refracts the track underneath.
class LiquidToggle extends StatefulWidget {
  const LiquidToggle({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.backdrop,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final bool selected;

  /// Null disables pointer, keyboard and accessibility actions.
  final ValueChanged<bool>? onSelect;
  final Backdrop backdrop;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

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
  late Backdrop _knobBackdrop;

  /// Whether the arena gave the knob's gesture over as a drag (see
  /// [DragInspector.onClaim]). Short of that, the knob follows the finger but
  /// letting go commits nothing from here: a gesture still under the slop is a
  /// tap, and taps are [_onTap]'s.
  bool _didDrag = false;

  /// Whether a finger is on the knob. While it is, the finger owns [_fraction].
  bool _dragging = false;
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
      onDragStarted: (_) => _dragging = true,
      onDragStopped: _onDragStopped,
      onDrag: _onDrag,
    );
    _knobBackdrop = _combineKnobBackdrop();
  }

  Backdrop _combineKnobBackdrop() => CombinedBackdrop.of(
    widget.backdrop,
    WrappedBackdrop(_trackBackdrop, _drawScaledTrack),
  );

  /// Whether the platform asked for reduced motion, as of the last build.
  ///
  /// With it, a value the control moves to on its own — set by the caller,
  /// settled after a drag, chosen by a tap or a screen reader — jumps there
  /// instead of springing. A finger dragging the control still moves it: that
  /// is the control following the hand, not decoration.
  bool _reduceMotion = false;

  /// Moves to [value] as the reader's motion setting allows.
  void _settleTo(double value) {
    if (_reduceMotion) {
      _animation.snapToValue(value);
    } else {
      _animation.animateToValue(value);
    }
  }

  @override
  void didUpdateWidget(LiquidToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backdrop != oldWidget.backdrop) {
      _knobBackdrop = _combineKnobBackdrop();
    }
    if (widget.onSelect == null && oldWidget.onSelect != null) {
      _dragging = false;
      _didDrag = false;
      _fraction = widget.selected ? 1 : 0;
      _animation.cancelDrag();
      _animation.snapToValue(_fraction);
    }
    // Mid-drag the knob is wherever the finger has it. A parent rebuilding
    // for any reason of its own — a clock, a stream — used to find that
    // position different from `selected` and spring the knob back off the
    // finger, releasing the press while the finger was still down.
    if (_dragging) return;
    final double target = widget.selected ? 1 : 0;
    if (target != _fraction) {
      _fraction = target;
      _settleTo(target);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _trackBackdrop.dispose();
    super.dispose();
  }

  /// Springs on from where the finger left it, or jumps under reduced motion.
  void _springOrSnap(double value) {
    if (_reduceMotion) {
      _animation.snapToValue(value);
    } else {
      _animation.updateValue(value);
    }
  }

  void _setFraction(double value) {
    _fraction = value;
    _animation.updateValue(value);
  }

  void _onDrag(Size size, Offset dragAmount) {
    if (widget.onSelect == null || !_dragging) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = dragAmount.dx / _dragWidth;
    _setFraction(
      (isLtr ? _fraction + delta : _fraction - delta).clamp(0.0, 1.0),
    );
  }

  void _onDragStopped() {
    if (!_dragging) return;
    _dragging = false;
    final bool dragged = _didDrag;
    _didDrag = false;
    if (widget.onSelect == null) return;
    if (dragged) {
      _fraction = _animation.targetValue >= 0.5 ? 1 : 0;
      _springOrSnap(_fraction);
      // Only a change is reported, as Flutter's own switch does: a knob
      // nudged and let go on the side it started from was reported anyway,
      // and every caller had to compare against its own value to ignore it.
      final bool next = _fraction == 1;
      if (next != widget.selected) widget.onSelect?.call(next);
    } else {
      // A tap, or a wobble under the slop: back where it was. If the arena
      // gives the gesture to the tap recogniser, [_onTap] flips it from here
      // in the same frame.
      _fraction = widget.selected ? 1 : 0;
      _springOrSnap(_fraction);
    }
  }

  void _cancelDrag() {
    _dragging = false;
    _didDrag = false;
    _fraction = widget.selected ? 1 : 0;
    _animation.cancelDrag();
    _animation.snapToValue(_fraction);
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
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    final Color accentColor = colors.toggleAccent;
    final Color trackColor = colors.track;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    // One node for the whole switch, track and knob, that says whether it is on
    // and can be flipped: marked only on the knob before, with no action, a
    // screen reader heard its state and had no way to change it.
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      enabled: widget.onSelect != null,
      toggled: widget.selected,
      onTap: widget.onSelect != null
          ? () => widget.onSelect?.call(!widget.selected)
          : null,
      child: ControlFocus(
        enabled: widget.onSelect != null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onActivate: () => widget.onSelect?.call(!widget.selected),
        child: _buildSwitch(isLtr, trackColor, accentColor),
      ),
    );
  }

  /// A tap anywhere on the switch, knob included, flips it.
  void _onTap() {
    final ValueChanged<bool>? onSelect = widget.onSelect;
    if (onSelect == null) return;
    _fraction = widget.selected ? 0 : 1;
    _springOrSnap(_fraction);
    onSelect(!widget.selected);
  }

  Widget _buildSwitch(bool isLtr, Color trackColor, Color accentColor) {
    // **Every tap goes through this one recogniser, the knob's too.** It sits
    // round the whole switch, so it is in the arena under every finger that
    // lands on it, and as the innermost tap there it wins over any tap handler
    // above — the row a switch usually sits in. The knob used to commit its
    // own taps from its raw listener, which no arena could see: the tap went
    // on to the row's handler as well, the row flipped the switch a second
    // time, and it sprang straight back. Apps were each adding a dummy tap
    // handler round the switch to block that.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onSelect == null ? null : _onTap,
      child: _buildStack(isLtr, trackColor, accentColor),
    );
  }

  Widget _buildStack(bool isLtr, Color trackColor, Color accentColor) {
    return Stack(
      alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
      // Compose's Box does not clip: the knob grows past the track while
      // pressed and carries a shadow.
      clipBehavior: Clip.none,
      children: <Widget>[
        IgnorePointer(
          child: _ToggleTrack(
            backdrop: _trackBackdrop,
            animation: _animation,
            trackColor: trackColor,
            accentColor: accentColor,
          ),
        ),
        AnimatedTranslation(
          listenable: _animation,
          child: _animation.wrapGestures(
            onCancel: _cancelDrag,
            // The knob slides sideways; a list scrolling past must neither
            // drag it along nor take a sideways drag away from it.
            claimAxis: Axis.horizontal,
            onClaim: () {
              if (_dragging) _didDrag = true;
            },
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
                return GlassInnerShadow(radius: 4 * progress, alpha: progress);
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
          offset: () {
            final double fraction = _animation.value;
            final double translationX = isLtr
                ? lerpDouble(_knobPadding, _knobPadding + _dragWidth, fraction)!
                : lerpDouble(
                    -_knobPadding,
                    -(_knobPadding + _dragWidth),
                    fraction,
                  )!;
            return Offset(translationX, 0);
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
