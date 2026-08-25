import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../utils/damped_drag_animation.dart';
import '../utils/drag_gesture_inspector.dart';
import '../utils/interactive_highlight.dart';
import '../utils/spring.dart';

/// Provides the press-driven scale to the tabs inside a [LiquidBottomTabs].
///
/// The Flutter counterpart of `LocalLiquidBottomTabScale`.
class LiquidBottomTabScale extends InheritedNotifier<Listenable> {
  const LiquidBottomTabScale({
    super.key,
    required super.notifier,
    required this.scale,
    required super.child,
  });

  final double Function() scale;

  static double Function() of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LiquidBottomTabScale>()
            ?.scale ??
        () => 1.0;
  }
}

/// One tab of a [LiquidBottomTabs].
class LiquidBottomTab extends StatelessWidget {
  const LiquidBottomTab({
    super.key,
    required this.onPressed,
    required this.children,
  });

  final VoidCallback onPressed;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final double Function() scale = LiquidBottomTabScale.of(context);
    final Listenable? notifier = context
        .dependOnInheritedWidgetOfExactType<LiquidBottomTabScale>()
        ?.notifier;
    return Expanded(
      child: ClipPath(
        clipper: const GlassShapeClipper(Capsule()),
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: ListenableBuilder(
            listenable: notifier ?? const AlwaysStoppedAnimation<double>(0),
            builder: (BuildContext context, Widget? _) {
              return Transform.scale(
                scale: scale(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 2,
                  children: children,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A bar of tabs behind a single pill of liquid glass that slides between them,
/// magnifying the accent-tinted copy of the tabs underneath.
class LiquidBottomTabs extends StatefulWidget {
  const LiquidBottomTabs({
    super.key,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.backdrop,
    required this.tabsCount,
    required this.children,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final Backdrop backdrop;
  final int tabsCount;
  final List<Widget> children;

  @override
  State<LiquidBottomTabs> createState() => _LiquidBottomTabsState();
}

class _LiquidBottomTabsState extends State<LiquidBottomTabs>
    with TickerProviderStateMixin {
  final LayerBackdrop _tabsBackdrop = LayerBackdrop();

  late final SpringValue _offsetAnimation = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.5,
  );
  late final DampedDragAnimation _animation;
  late final InteractiveHighlight _interactiveHighlight;
  late final Backdrop _pillBackdrop;
  late final Listenable _repaint;

  double _tabWidth = 0;
  double _maxWidth = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedTabIndex;
    _animation = DampedDragAnimation(
      vsync: this,
      initialValue: widget.selectedTabIndex.toDouble(),
      valueRange: (start: 0, end: (widget.tabsCount - 1).toDouble()),
      visibilityThreshold: 0.001,
      initialScale: 1,
      pressedScale: 78 / 56,
      onDragStopped: _onDragStopped,
      onDrag: _onDrag,
    );
    _interactiveHighlight = InteractiveHighlight(
      vsync: this,
      position: _highlightPosition,
    );
    _pillBackdrop = CombinedBackdrop.of(widget.backdrop, _tabsBackdrop);
    _repaint = Listenable.merge(<Listenable>[
      _animation,
      _interactiveHighlight,
      _offsetAnimation,
    ]);
  }

  @override
  void didUpdateWidget(LiquidBottomTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTabIndex != _currentIndex) {
      _setCurrentIndex(widget.selectedTabIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _offsetAnimation.dispose();
    _animation.dispose();
    _interactiveHighlight.dispose();
    _tabsBackdrop.dispose();
    super.dispose();
  }

  /// The 4dp of give the whole panel takes on when dragged past an end.
  double get _panelOffset {
    if (_maxWidth == 0) return 0;
    final double fraction = (_offsetAnimation.value / _maxWidth).clamp(
      -1.0,
      1.0,
    );
    return 4.0 * fraction.sign * Curves.easeOut.transform(fraction.abs());
  }

  Offset _highlightPosition(Size size, Offset offset) {
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    return Offset(
      isLtr
          ? (_animation.value + 0.5) * _tabWidth + _panelOffset
          : size.width - (_animation.value + 0.5) * _tabWidth + _panelOffset,
      size.height / 2,
    );
  }

  void _setCurrentIndex(int index, {bool notify = true}) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    _animation.animateToValue(index.toDouble());
    if (notify) widget.onTabSelected(index);
  }

  void _onDrag(Size size, Offset dragAmount) {
    if (_tabWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    _animation.updateValue(
      (_animation.targetValue + dragAmount.dx / _tabWidth * (isLtr ? 1 : -1))
          .clamp(0.0, (widget.tabsCount - 1).toDouble()),
    );
    _offsetAnimation.snapTo(_offsetAnimation.value + dragAmount.dx);
  }

  void _onDragStopped() {
    final int targetIndex = _animation.targetValue.round().clamp(
      0,
      widget.tabsCount - 1,
    );
    _currentIndex = targetIndex;
    _animation.animateToValue(targetIndex.toDouble());
    widget.onTabSelected(targetIndex);
    _offsetAnimation.animateTo(0, springOf(1.0, 300.0));
  }

  void _pillLayerBlock(GlassLayer layer) {
    layer.scaleX = _animation.scaleX;
    layer.scaleY = _animation.scaleY;
    final double velocity = _animation.velocity / 10.0;
    layer.scaleX /= 1.0 - (velocity * 0.75).clamp(-0.2, 0.2);
    layer.scaleY *= 1.0 - (velocity * 0.25).clamp(-0.2, 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color accentColor = isLight
        ? const Color(0xFF0088FF)
        : const Color(0xFF0091FF);
    final Color containerColor = isLight
        ? const Color(0xFFFAFAFA).withValues(alpha: 0.4)
        : const Color(0xFF121212).withValues(alpha: 0.4);
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    void drawContainer(Canvas canvas, Size size) {
      canvas.drawRect(Offset.zero & size, Paint()..color = containerColor);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth;
        _tabWidth = (_maxWidth - 8.0) / widget.tabsCount;

        return SizedBox(
          width: _maxWidth,
          height: 64,
          child: ListenableBuilder(
            listenable: _repaint,
            builder: (BuildContext context, Widget? _) {
              final double panelOffset = _panelOffset;
              final double pressProgress = _animation.pressProgress;

              return Stack(
                alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
                children: <Widget>[
                  // The panel itself.
                  Transform.translate(
                    offset: Offset(panelOffset, 0),
                    child: DrawBackdrop(
                      backdrop: widget.backdrop,
                      shape: () => const Capsule(),
                      effects: (BackdropEffectScope scope) => scope
                        ..vibrancy()
                        ..blur(8)
                        ..lens(24, 24),
                      layerBlock: (GlassLayer layer) {
                        final double scale = lerpDouble(
                          1.0,
                          1.0 + 16.0 / math.max(layer.size.width, 1.0),
                          _animation.pressProgress,
                        )!;
                        layer.scaleX = scale;
                        layer.scaleY = scale;
                      },
                      onDrawSurface: drawContainer,
                      repaint: _repaint,
                      child: _interactiveHighlight.wrapOverlay(
                        child: SizedBox(
                          height: 64,
                          width: _maxWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: widget.children,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // An accent-tinted copy of the tabs, invisible on screen but
                  // captured as the backdrop the selection pill magnifies.
                  ExcludeSemantics(
                    child: _Invisible(
                      child: BackdropLayer(
                        backdrop: _tabsBackdrop,
                        child: LiquidBottomTabScale(
                          notifier: _repaint,
                          scale: () =>
                              lerpDouble(1.0, 1.2, _animation.pressProgress)!,
                          child: Transform.translate(
                            offset: Offset(panelOffset, 0),
                            child: DrawBackdrop(
                              backdrop: widget.backdrop,
                              shape: () => const Capsule(),
                              effects: (BackdropEffectScope scope) {
                                final double progress =
                                    _animation.pressProgress;
                                scope
                                  ..vibrancy()
                                  ..blur(8)
                                  ..lens(24 * progress, 24 * progress);
                              },
                              highlight: () => Highlight.standard.copyWith(
                                alpha: _animation.pressProgress,
                              ),
                              onDrawSurface: drawContainer,
                              repaint: _repaint,
                              child: _interactiveHighlight.wrapOverlay(
                                child: SizedBox(
                                  height: 56,
                                  width: _maxWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        accentColor,
                                        BlendMode.srcIn,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: widget.children,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // The selection pill.
                  //
                  // Positioned rather than painted through a transform:
                  // Flutter checks every ancestor's bounds before descending
                  // into it, so a pill drawn outside its parent stops receiving
                  // touches as soon as it leaves the first tab. Compose does
                  // bounds-checks every ancestor before descending into it.
                  Positioned(
                    left: isLtr
                        ? 4 + _animation.value * _tabWidth + panelOffset
                        : null,
                    right: isLtr
                        ? null
                        : 4 + _animation.value * _tabWidth - panelOffset,
                    top: 4,
                    // Both the press highlight and the drag animation need
                    // every event, so one inspector feeds both rather than two
                    // nested ones competing in the gesture arena.
                    child: DragInspector(
                      onDragStart: (Offset position, Size size) {
                        _interactiveHighlight.handleDown(position);
                        _animation.handleDragStart(position);
                      },
                      onDrag: (Offset position, Offset delta, Size size) {
                        _interactiveHighlight.handleMove(position);
                        _animation.handleDrag(size, delta);
                      },
                      onDragEnd: () {
                        _interactiveHighlight.handleUp();
                        _animation.handleDragEnd();
                      },
                      onDragCancel: () {
                        _interactiveHighlight.handleUp();
                        _animation.handleDragEnd();
                      },
                      child: DrawBackdrop(
                        backdrop: _pillBackdrop,
                        shape: () => const Capsule(),
                        effects: (BackdropEffectScope scope) {
                          final double progress = _animation.pressProgress;
                          scope.lens(
                            10 * progress,
                            14 * progress,
                            chromaticAberration: true,
                          );
                        },
                        highlight: () => Highlight.standard.copyWith(
                          alpha: _animation.pressProgress,
                        ),
                        shadow: () =>
                            GlassShadow.standard.copyWith(alpha: pressProgress),
                        innerShadow: () => GlassInnerShadow(
                          radius: 8 * _animation.pressProgress,
                          alpha: _animation.pressProgress,
                        ),
                        layerBlock: _pillLayerBlock,
                        onDrawSurface: (Canvas canvas, Size size) {
                          final double progress = _animation.pressProgress;
                          final Rect rect = Offset.zero & size;
                          canvas.drawRect(
                            rect,
                            Paint()
                              ..color =
                                  (isLight
                                          ? const Color(0xFF000000)
                                          : const Color(0xFFFFFFFF))
                                      .withValues(alpha: 0.1 * (1 - progress)),
                          );
                          canvas.drawRect(
                            rect,
                            Paint()
                              ..color = const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.03 * progress),
                          );
                        },
                        repaint: _repaint,
                        child: SizedBox(height: 56, width: _tabWidth),
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

/// Paints its child but composites it away, so a [BackdropLayer] inside can
/// still capture it.
///
/// [Opacity] with `0` skips painting the child entirely, which would leave the
/// captured layer empty.
class _Invisible extends StatelessWidget {
  const _Invisible({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0x00000000), BlendMode.dstIn),
      child: child,
    );
  }
}
