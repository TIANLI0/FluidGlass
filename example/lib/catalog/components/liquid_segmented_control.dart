import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/damped_drag_animation.dart';
import '../utils/drag_gesture_inspector.dart';
import '../utils/spring.dart';
import 'liquid_panel.dart';

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
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Backdrop backdrop;
  final List<Widget> segments;
  final double height;

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
      onDragStopped: _onDragStopped,
      onDrag: _onDrag,
    );
    _repaint = Listenable.merge(<Listenable>[_animation, _offsetAnimation]);
  }

  @override
  void didUpdateWidget(LiquidSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      _currentIndex = widget.selectedIndex;
      _animation.animateToValue(_currentIndex.toDouble());
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
    final double fraction =
        (_offsetAnimation.value / _maxWidth).clamp(-1.0, 1.0);
    return 3.0 * fraction.sign * Curves.easeOut.transform(fraction.abs());
  }

  void _onDrag(Size size, Offset dragAmount) {
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
    final int targetIndex =
        _animation.targetValue.round().clamp(0, _count - 1);
    _select(targetIndex);
    _animation.animateToValue(targetIndex.toDouble());
    _offsetAnimation.animateTo(0, springOf(1.0, 300.0));
  }

  void _select(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    widget.onSelected(index);
  }

  void _onSegmentTap(int index) {
    _select(index);
    _animation.animateToValue(index.toDouble());
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
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth;
        _segmentWidth = (_maxWidth - _inset * 2) / _count;

        return SizedBox(
          width: _maxWidth,
          height: widget.height,
          child: ListenableBuilder(
            listenable: _repaint,
            builder: (BuildContext context, Widget? _) {
              final double panelOffset = _panelOffset;
              return Stack(
                alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
                clipBehavior: Clip.none,
                children: <Widget>[
                  // The capsule itself: the reusable panel, capsule-shaped,
                  // holding the invisible tap targets. The labels are painted
                  // last, over the thumb — a label must never sink under it.
                  Transform.translate(
                    offset: Offset(panelOffset, 0),
                    child: LiquidPanel(
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: _inset,
                          ),
                          child: Row(
                            children: <Widget>[
                              for (int i = 0; i < _count; i++)
                                Expanded(
                                  child: DragInspector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _onSegmentTap(i),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // The thumb. Positioned, not transformed, so it keeps
                  // receiving touches wherever it sits.
                  Positioned(
                    left: isLtr
                        ? _inset +
                            _animation.value * _segmentWidth +
                            panelOffset
                        : null,
                    right: isLtr
                        ? null
                        : _inset +
                            _animation.value * _segmentWidth -
                            panelOffset,
                    top: _inset,
                    child: DragInspector(
                      onDragStart: (Offset position, Size size) =>
                          _animation.handleDragStart(position),
                      onDrag: (Offset position, Offset delta, Size size) =>
                          _animation.handleDrag(size, delta),
                      onDragEnd: _animation.handleDragEnd,
                      onDragCancel: _animation.handleDragEnd,
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
                          color:
                              const Color(0xFF000000).withValues(alpha: 0.1),
                        ),
                        innerShadow: null,
                        layerBlock: _thumbLayerBlock,
                        onDrawSurface: (Canvas canvas, Size size) {
                          final double progress = _animation.pressProgress;
                          canvas.drawRect(
                            Offset.zero & size,
                            Paint()
                              ..color = const Color(0xFFFFFFFF).withValues(
                                alpha: isLight
                                    ? 0.85 - 0.45 * progress
                                    : 0.18 - 0.06 * progress,
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
                    ),
                  ),

                  // The labels, painted over the thumb and transparent to
                  // touch — the tap targets live in the panel, the drags on
                  // the thumb.
                  IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(panelOffset, 0),
                      child: SizedBox(
                        height: widget.height,
                        width: _maxWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _inset,
                          ),
                          child: Row(
                            children: <Widget>[
                              for (int i = 0; i < _count; i++)
                                Expanded(
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 160),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
