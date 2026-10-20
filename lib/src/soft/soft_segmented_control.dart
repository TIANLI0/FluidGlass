import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// A pill track of equal segments with a raised pill marking the selected one.
///
/// 40 high (32 when [small]), the indicator inset 4 (2) from the track. On a
/// change the indicator glides across on a (0.4, 0.1) spring while it stretches
/// out and settles in width (0.6, 0.5, starting outwards) and briefly squashes
/// to 90% of its height — a drop of liquid moving, not a box sliding. It can
/// be dragged from segment to segment; pressing a segment sinks it a little.
/// Each change gives a light haptic tick.
class SoftSegmentedControl extends StatefulWidget {
  const SoftSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    this.small = false,
  }) : assert(segments.length >= 2);

  final List<String> segments;
  final int selectedIndex;

  /// Null disables the control.
  final ValueChanged<int>? onSelected;
  final bool small;

  @override
  State<SoftSegmentedControl> createState() => _SoftSegmentedControlState();
}

class _SoftSegmentedControlState extends State<SoftSegmentedControl>
    with TickerProviderStateMixin {
  late final AnimationController _center = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  /// Width stretch around 1 (1 = the segment's own width).
  late final AnimationController _stretch = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  /// Height squash around 1.
  late final AnimationController _squash = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  /// Press sink of the pressed segment (and the indicator under it).
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static final SpringDescription _centerSpring = softSpring(0.4, bounce: 0.1);
  static final SpringDescription _shapeSpring = softSpring(0.6, bounce: 0.5);

  int? _pressed;
  bool _dragging = false;
  double _segmentWidth = 0;

  bool get _reduce => softReduceMotion(context);

  @override
  void didUpdateWidget(SoftSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex && !_dragging) {
      _glideTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _center.dispose();
    _stretch.dispose();
    _squash.dispose();
    _press.dispose();
    super.dispose();
  }

  void _glideTo(int index) {
    _center.springTo(index.toDouble(), _centerSpring, reduceMotion: _reduce);
    if (_reduce) return;
    // Kick the shape: wider and flatter for a moment, then settle.
    _stretch.animateWith(
      SpringSimulation(
        _shapeSpring,
        _stretch.value,
        1,
        1000 / math.max(1, _segmentWidth),
      ),
    );
    _squash.animateWith(SpringSimulation(_shapeSpring, _squash.value, 1, -3.5));
  }

  void _select(int index) {
    if (index == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onSelected?.call(index);
  }

  int _indexAt(double dx) => _segmentWidth <= 0
      ? 0
      : (dx / _segmentWidth).floor().clamp(0, widget.segments.length - 1);

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = widget.onSelected != null;
    final double height = widget.small ? 32 : 40;
    final double inset = widget.small ? 2 : 4;
    final TextStyle style = theme.text(
      14,
      weight: FontWeight.w500,
      color: enabled ? theme.labelPrimary : theme.labelTertiary,
    );
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double minWidth = widget.segments.length * 52 + inset * 2;
          final double width = constraints.hasBoundedWidth
              ? math.max(constraints.maxWidth, minWidth)
              : math.max(minWidth, widget.segments.length * 96.0);
          final double inner = width - inset * 2;
          _segmentWidth = inner / widget.segments.length;
          double localX(double dx) => rtl ? width - dx - inset : dx - inset;
          return Listener(
            onPointerDown: enabled
                ? (PointerDownEvent e) {
                    _pressed = _indexAt(localX(e.localPosition.dx));
                    _press.springTo(
                      0.96,
                      softSpring(0.25),
                      reduceMotion: _reduce,
                    );
                    setState(() {});
                  }
                : null,
            onPointerUp: (_) {
              _press.springTo(
                1,
                softSpring(0.5, bounce: 0.6),
                reduceMotion: _reduce,
              );
              setState(() => _pressed = null);
            },
            onPointerCancel: (_) {
              _press.springTo(
                1,
                softSpring(0.5, bounce: 0.6),
                reduceMotion: _reduce,
              );
              setState(() => _pressed = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: enabled
                  ? (TapUpDetails d) =>
                        _select(_indexAt(localX(d.localPosition.dx)))
                  : null,
              onHorizontalDragStart: enabled ? (_) => _dragging = true : null,
              onHorizontalDragUpdate: enabled
                  ? (DragUpdateDetails d) {
                      final double fraction =
                          (localX(d.localPosition.dx) / _segmentWidth - 0.5)
                              .clamp(0.0, widget.segments.length - 1.0);
                      _center.springTo(
                        fraction,
                        softSpring(0.15),
                        reduceMotion: _reduce,
                      );
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      _dragging = false;
                      final int index = _center.value.round();
                      _glideTo(index);
                      _select(index);
                    }
                  : null,
              child: Container(
                width: width,
                height: height,
                decoration: ShapeDecoration(
                  color: theme.segmentTrack,
                  shape: const StadiumBorder(),
                ),
                child: Stack(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _center,
                        _stretch,
                        _squash,
                        _press,
                      ]),
                      builder: (BuildContext context, _) {
                        final double pressScale =
                            _pressed != null &&
                                _pressed == _center.value.round()
                            ? _press.value
                            : 1;
                        final double w =
                            _segmentWidth *
                            _stretch.value.clamp(0.8, 1.3) *
                            pressScale;
                        final double h =
                            (height - inset * 2) *
                            _squash.value.clamp(0.9, 1.05) *
                            pressScale;
                        final double cx =
                            inset + _segmentWidth * (_center.value + 0.5);
                        final double left = rtl
                            ? width - cx - w / 2
                            : cx - w / 2;
                        return Positioned(
                          left: left.clamp(0, width - w),
                          top: (height - h) / 2,
                          width: w,
                          height: h,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: theme.segmentIndicator,
                              shape: const StadiumBorder(),
                              shadows: <BoxShadow>[
                                BoxShadow(
                                  color: theme.isDark
                                      ? const Color(0x14000000)
                                      : const Color(0x0D000000),
                                  blurRadius: 2,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < widget.segments.length; i++)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: i == widget.selectedIndex,
                                inMutuallyExclusiveGroup: true,
                                onTap: enabled ? () => _select(i) : null,
                                child: AnimatedBuilder(
                                  animation: _press,
                                  builder:
                                      (BuildContext context, Widget? child) =>
                                          Transform.scale(
                                            scale: _pressed == i
                                                ? _press.value
                                                : 1,
                                            child: child,
                                          ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        widget.segments[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: style,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
