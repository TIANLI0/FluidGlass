import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';
import '../internal/animated_translation.dart';
import '../internal/control_focus.dart';

/// A compact segmented picker whose selection thumb is a bead of liquid glass
/// that slides — or is dragged — between the segments.
///
/// The container is a [LiquidPanel] with a capsule shape; the thumb rides the
/// same damped-drag physics as the bottom-tabs pill: press to swell it,
/// velocity squashes it, and over-dragging past either end gives the whole
/// capsule a few pixels of give.
class LiquidSegmentedControl extends StatefulWidget {
  const LiquidSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.backdrop,
    required this.segments,
    this.height = 40,
    this.thumbColor,
    this.focusNode,
    this.autofocus = false,
  }) : assert(segments.length > 0, 'At least one segment is required.'),
       assert(selectedIndex >= 0 && selectedIndex < segments.length),
       assert(height > 6 && height < double.infinity);

  final int selectedIndex;

  /// Null disables selection by pointer, keyboard and assistive technology.
  final ValueChanged<int>? onSelected;
  final Backdrop backdrop;
  final List<Widget> segments;
  final double height;
  final FocusNode? focusNode;
  final bool autofocus;

  /// The wash painted over the thumb's refraction.
  ///
  /// Null keeps the white this control has always drawn — the iOS look, which
  /// reads as *raised* on any track without claiming a colour of its own.
  ///
  /// Give a colour when the design system marks a selection with one. A palette
  /// whose panel is already near-white leaves a white thumb with nothing to
  /// separate it from the track it rides on, and the control then says nothing
  /// about which segment is selected — the one thing it exists to say. The
  /// colour's own alpha is its resting alpha, and pressing thins it by the same
  /// amount it always did, so more of the refraction shows under the finger.
  final Color? thumbColor;

  @override
  State<LiquidSegmentedControl> createState() => _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl>
    with TickerProviderStateMixin {
  static const double _inset = 3.0;

  late final SpringValue _offsetAnimation = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.5,
  );
  late final DampedDragAnimation _animation;
  late final Listenable _repaint;

  double _segmentWidth = 0;
  double _maxWidth = 0;
  int _currentIndex = 0;
  bool _dragging = false;

  int get _count => widget.segments.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _animation = DampedDragAnimation(
      vsync: this,
      initialValue: widget.selectedIndex.toDouble(),
      valueRange: (start: 0, end: (_count - 1).toDouble()),
      visibilityThreshold: 0.001,
      initialScale: 1,
      pressedScale: (widget.height + 8) / widget.height,
      onDragStarted: (_) => _dragging = widget.onSelected != null,
      onDragStopped: _onDragStopped,
      onDrag: _onDrag,
    );
    _repaint = Listenable.merge(<Listenable>[_animation, _offsetAnimation]);
  }

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
  void didUpdateWidget(LiquidSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Both were fixed when the control was first built: a fourth segment could
    // not be selected (the thumb was clamped onto the third), and a new height
    // pressed to the old one's swell.
    _animation
      ..valueRange = (start: 0, end: (_count - 1).toDouble())
      ..pressedScale = (widget.height + 8) / widget.height;
    if (widget.onSelected == null && oldWidget.onSelected != null) {
      _dragging = false;
      _animation.cancelDrag();
      _animation.snapToValue(widget.selectedIndex.toDouble());
      _offsetAnimation.snapTo(0);
    }
    if (widget.selectedIndex != _currentIndex) {
      _currentIndex = widget.selectedIndex;
      _settleTo(_currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _offsetAnimation.dispose();
    _animation.dispose();
    super.dispose();
  }

  /// The few pixels of give the capsule takes on when dragged past an end.
  double get _panelOffset {
    if (_maxWidth == 0) return 0;
    final double fraction = (_offsetAnimation.value / _maxWidth).clamp(
      -1.0,
      1.0,
    );
    return 3.0 * fraction.sign * Curves.easeOut.transform(fraction.abs());
  }

  void _onDrag(Size size, Offset dragAmount) {
    if (!_dragging || widget.onSelected == null) return;
    if (_segmentWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    _animation.updateValue(
      (_animation.targetValue +
              dragAmount.dx / _segmentWidth * (isLtr ? 1 : -1))
          .clamp(0.0, (_count - 1).toDouble()),
    );
    _offsetAnimation.snapTo(_offsetAnimation.value + dragAmount.dx);
  }

  void _onDragStopped() {
    if (!_dragging || widget.onSelected == null) return;
    _dragging = false;
    final int targetIndex = _animation.targetValue.round().clamp(0, _count - 1);
    _select(targetIndex);
    _settleTo(targetIndex.toDouble());
    _offsetAnimation.animateTo(0, springOf(1.0, 300.0));
  }

  void _select(int index) {
    if (widget.onSelected == null) return;
    if (_currentIndex == index) return;
    // The labels are built with the layout, not on every tick, so the new
    // selection's weight needs a build of its own.
    setState(() => _currentIndex = index);
    widget.onSelected?.call(index);
  }

  /// A segment chosen without a drag — by a screen reader's tap.
  void _activate(int index) {
    if (widget.onSelected == null || index == _currentIndex) return;
    _select(index);
    _settleTo(index.toDouble());
  }

  void _cancelDrag() {
    _dragging = false;
    _animation.release();
    _settleTo(_currentIndex.toDouble());
    _offsetAnimation.animateTo(0, springOf(1.0, 300.0));
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
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor = LiquidGlassTheme.of(context).content;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    return ControlFocus(
      enabled: widget.onSelected != null,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onStep: (int direction) =>
          _activate((_currentIndex + direction).clamp(0, _count - 1)),
      onFirst: () => _activate(0),
      onLast: () => _activate(_count - 1),
      child: IgnorePointer(
        ignoring: widget.onSelected == null,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            _maxWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : _count * 100.0 + _inset * 2;
            _segmentWidth = math.max(0, _maxWidth - _inset * 2) / _count;

            // Built once per layout. Animation ticks update the three layers'
            // render transforms without rebuilding their widget subtrees or
            // laying the stack out again.
            final Widget panel = LiquidPanel(
              backdrop: widget.backdrop,
              shape: const Capsule(),
              blurRadius: 6,
              refractionHeight: 14,
              refractionAmount: 16,
              showShadow: false,
              repaint: _repaint,
              child: SizedBox(
                height: widget.height,
                width: _maxWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _inset),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < _count; i++)
                        Expanded(
                          child: LiquidInteraction(
                            child: DragInspector(
                              behavior: HitTestBehavior.opaque,
                              onDragStart: (position, size) {
                                _animation.handleDragStart(position);
                                _animation.updateValue(i.toDouble());
                              },
                              onDrag: (position, delta, size) =>
                                  _animation.handleDrag(size, delta),
                              onDragEnd: _animation.handleDragEnd,
                              onDragCancel: _cancelDrag,
                              // A press here slides the thumb across the
                              // segments, so it is a sideways drag a list
                              // must not take (see [DragInspector.claimAxis]).
                              claimAxis: Axis.horizontal,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );

            final Widget thumb = DragInspector(
              onDragStart: (Offset position, Size size) =>
                  _animation.handleDragStart(position),
              onDrag: (Offset position, Offset delta, Size size) =>
                  _animation.handleDrag(size, delta),
              onDragEnd: _animation.handleDragEnd,
              onDragCancel: _cancelDrag,
              claimAxis: Axis.horizontal,
              child: DrawBackdrop(
                backdrop: widget.backdrop,
                shape: () => const Capsule(),
                effects: (BackdropEffectScope scope) {
                  final double progress = _animation.pressProgress;
                  scope.lens(
                    6 * progress,
                    9 * progress,
                    chromaticAberration: true,
                  );
                },
                highlight: () => Highlight.standard.copyWith(
                  alpha: _animation.pressProgress,
                ),
                shadow: () => GlassShadow(
                  radius: 6,
                  color: const Color(0xFF000000).withValues(alpha: 0.1),
                ),
                innerShadow: null,
                layerBlock: _thumbLayerBlock,
                onDrawSurface: (Canvas canvas, Size size) {
                  final double progress = _animation.pressProgress;
                  // Written as a subtraction from a resting alpha, not a
                  // multiplication, so that the default path stays bit-identical
                  // to the alphas this control shipped with. A supplied colour
                  // brings its own resting alpha and is thinned by the same
                  // amount.
                  final Color wash =
                      widget.thumbColor ?? const Color(0xFFFFFFFF);
                  final double restingAlpha =
                      widget.thumbColor?.a ?? (isLight ? 0.85 : 0.18);
                  canvas.drawRect(
                    Offset.zero & size,
                    Paint()
                      ..color = wash.withValues(
                        alpha:
                            restingAlpha - (isLight ? 0.45 : 0.06) * progress,
                      ),
                  );
                },
                isolateSurface: false,
                repaint: _repaint,
                child: SizedBox(
                  height: widget.height - _inset * 2,
                  width: _segmentWidth,
                ),
              ),
            );

            // The labels, painted over the thumb and transparent to touch — the
            // tap targets live in the panel, the drags on the thumb.
            final Widget labels = SizedBox(
              height: widget.height,
              width: _maxWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _inset),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < _count; i++)
                      Expanded(
                        // Where a screen reader finds a segment: one of a set,
                        // selected or not, activated as a tap would. The tap
                        // targets underneath carry nothing to read.
                        child: Semantics(
                          container: true,
                          button: true,
                          inMutuallyExclusiveGroup: true,
                          selected: i == _currentIndex,
                          enabled: widget.onSelected != null,
                          onTap: widget.onSelected != null
                              ? () => _activate(i)
                              : null,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: _reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                color: contentColor,
                                fontSize: 14,
                                fontWeight: i == _currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              child: widget.segments[i],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );

            return SizedBox(
              width: _maxWidth,
              height: widget.height,
              child: Stack(
                alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
                clipBehavior: Clip.none,
                children: <Widget>[
                  // The capsule itself: the reusable panel, capsule-shaped,
                  // holding the invisible tap targets. The labels are painted
                  // last, over the thumb — a label must never sink under it.
                  AnimatedTranslation(
                    listenable: _repaint,
                    offset: () => Offset(_panelOffset, 0),
                    child: panel,
                  ),
                  // The thumb, moved by a transform: a transformed child is hit
                  // tested where it is drawn, so it keeps receiving touches
                  // wherever it sits.
                  Positioned(
                    left: isLtr ? _inset : null,
                    right: isLtr ? null : _inset,
                    top: _inset,
                    child: AnimatedTranslation(
                      listenable: _repaint,
                      offset: () {
                        final double travel = _animation.value * _segmentWidth;
                        return Offset(
                          (isLtr ? travel : -travel) + _panelOffset,
                          0,
                        );
                      },
                      child: thumb,
                    ),
                  ),
                  // Transparent to touch, not to the screen reader: an
                  // `IgnorePointer` would also block the segments' semantic taps.
                  _HitTransparent(
                    child: AnimatedTranslation(
                      listenable: _repaint,
                      offset: () => Offset(_panelOffset, 0),
                      child: labels,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Passes pointers through to whatever is beneath, and keeps its subtree's
/// semantics — actions included — which an `IgnorePointer` would block.
class _HitTransparent extends SingleChildRenderObjectWidget {
  const _HitTransparent({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitTransparent();
}

class _RenderHitTransparent extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;
}
