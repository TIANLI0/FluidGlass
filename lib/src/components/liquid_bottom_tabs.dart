import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';

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
        // Slop-free, like Compose's `clickable`: nudging a tab label sideways
        // must not silently swallow the tap.
        child: DragInspector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: _RepaintScale(
            repaint: notifier ?? const AlwaysStoppedAnimation<double>(0),
            scale: scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 2,
              children: children,
            ),
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
    // Compose reports the selection through a `snapshotFlow` on the index,
    // which only emits when it actually changes; reporting on every release
    // would fire a spurious selection each time the pill is merely touched.
    if (_currentIndex != targetIndex) {
      _currentIndex = targetIndex;
      widget.onTabSelected(targetIndex);
    }
    // Unconditional, as in Compose: this is what re-presses the pill while it
    // settles back onto the tab.
    _animation.animateToValue(targetIndex.toDouble());
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
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    final Color accentColor = colors.accent;
    final Color containerColor = colors.container;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    void drawContainer(Canvas canvas, Size size) {
      canvas.drawRect(Offset.zero & size, Paint()..color = containerColor);
    }

    void drawAccentContainer(Canvas canvas, Size size) {
      const Capsule()
          .createOutline(size, isLtr ? TextDirection.ltr : TextDirection.rtl)
          .draw(canvas, Paint()..color = containerColor);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth;
        _tabWidth = (_maxWidth - 8.0) / widget.tabsCount;

        return SizedBox(
          width: _maxWidth,
          height: 64,
          child: Stack(
            alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
            // The pill paints outside the panel by design: it carries a
            // drop shadow and grows to 1.39x while pressed. A Stack clips
            // as soon as a positioned child overflows, and the pill's
            // `left` lands exactly on 0 at the first tab and exactly on the
            // panel width at the last, so rounding alone decided whether
            // the clip engaged and sheared the corners off at either end.
            clipBehavior: Clip.none,
            children: <Widget>[
              // The panel itself.
              DrawBackdrop(
                backdrop: widget.backdrop,
                shape: () => const Capsule(),
                effects: (BackdropEffectScope scope) => scope
                  ..vibrancy()
                  ..blur(8)
                  ..lens(24, 24),
                layerBlock: (GlassLayer layer) {
                  layer.translationX = _panelOffset;
                  final double scale = lerpDouble(
                    1.0,
                    1.0 + 16.0 / math.max(layer.size.width, 1.0),
                    _animation.pressProgress,
                  )!;
                  layer.scaleX = scale;
                  layer.scaleY = scale;
                },
                onDrawSurface: drawContainer,
                // The surface only paints src-over, so the isolating
                // save-layer would change nothing but cost a pass.
                isolateSurface: false,
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

              // An accent glass copy, invisible on screen but recorded as
              // the backdrop the selection pill magnifies. Recording the
              // glass commands avoids the synchronous `toImageSync` that
              // a live `BackdropLayer` would otherwise run on every spring
              // tick. The accent tabs are clipped directly into the pill.
              ExcludeSemantics(
                child: _Invisible(
                  child: DrawBackdrop(
                    backdrop: widget.backdrop,
                    shape: () => const Capsule(),
                    effects: (BackdropEffectScope scope) {
                      final double progress = _animation.pressProgress;
                      scope
                        ..vibrancy()
                        ..blur(8)
                        ..lens(24 * progress, 24 * progress);
                    },
                    highlight: () => Highlight.standard.copyWith(
                      alpha: _animation.pressProgress,
                    ),
                    layerBlock: (GlassLayer layer) {
                      layer.translationX = _panelOffset;
                    },
                    exportedBackdrop: _tabsBackdrop,
                    // The exported picture records this callback without the
                    // widget's clip, so draw the capsule explicitly. That
                    // keeps its edge curved when the pressed pill grows past
                    // the panel bounds.
                    onDrawSurface: drawAccentContainer,
                    isolateSurface: false,
                    repaint: _repaint,
                    child: SizedBox(height: 56, width: _maxWidth),
                  ),
                ),
              ),

              // The selection pill.
              //
              // The full-width render box moves both paint and hit testing.
              // A transformed tab-width box would look right but Flutter's
              // Stack would reject a pointer before reaching it once the pill
              // moved outside its original layout bounds.
              _SlidingPill(
                repaint: _repaint,
                position: () => _animation.value,
                panelOffset: () => _panelOffset,
                tabWidth: _tabWidth,
                fullWidth: _maxWidth,
                isLtr: isLtr,
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
                    shadow: () => GlassShadow.standard.copyWith(
                      alpha: _animation.pressProgress,
                    ),
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
                    isolateSurface: false,
                    repaint: _repaint,
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: const GlassShapeClipper(Capsule()),
                          child: _SlidingTabCopy(
                            repaint: _repaint,
                            position: () => _animation.value,
                            tabWidth: _tabWidth,
                            fullWidth: _maxWidth,
                            isLtr: isLtr,
                            child: LiquidBottomTabScale(
                              notifier: _repaint,
                              scale: () => lerpDouble(
                                1.0,
                                1.2,
                                _animation.pressProgress,
                              )!,
                              child: _interactiveHighlight.wrapOverlay(
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Scales at paint time so a tab press never rebuilds or lays out its label.
class _RepaintScale extends SingleChildRenderObjectWidget {
  const _RepaintScale({
    required this.repaint,
    required this.scale,
    super.child,
  });

  final Listenable repaint;
  final double Function() scale;

  @override
  _RenderRepaintScale createRenderObject(BuildContext context) =>
      _RenderRepaintScale(repaint: repaint, scale: scale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRepaintScale renderObject,
  ) {
    renderObject
      ..repaint = repaint
      ..scale = scale;
  }
}

class _RenderRepaintScale extends RenderProxyBox {
  _RenderRepaintScale({
    required Listenable repaint,
    required double Function() scale,
  }) : _repaint = repaint,
       _scale = scale;

  Listenable _repaint;
  set repaint(Listenable value) {
    if (_repaint == value) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double Function() _scale;
  set scale(double Function() value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsPaint();
  }

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  Matrix4 get _transform {
    final double value = _scale();
    if (value == 1.0) return Matrix4.identity();
    final Offset centre = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(value, value, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final Matrix4 transform = _transform;
    if (transform.isIdentity()) {
      _transformLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }
}

/// Moves the pill inside a full-width hit-test box without rebuilding it.
class _SlidingPill extends SingleChildRenderObjectWidget {
  const _SlidingPill({
    required this.repaint,
    required this.position,
    required this.panelOffset,
    required this.tabWidth,
    required this.fullWidth,
    required this.isLtr,
    super.child,
  });

  final Listenable repaint;
  final double Function() position;
  final double Function() panelOffset;
  final double tabWidth;
  final double fullWidth;
  final bool isLtr;

  @override
  _RenderSlidingPill createRenderObject(BuildContext context) =>
      _RenderSlidingPill(
        repaint: repaint,
        position: position,
        panelOffset: panelOffset,
        tabWidth: tabWidth,
        fullWidth: fullWidth,
        isLtr: isLtr,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlidingPill renderObject,
  ) {
    renderObject
      ..repaint = repaint
      ..position = position
      ..panelOffset = panelOffset
      ..tabWidth = tabWidth
      ..fullWidth = fullWidth
      ..isLtr = isLtr;
  }
}

class _RenderSlidingPill extends RenderProxyBox {
  _RenderSlidingPill({
    required Listenable repaint,
    required double Function() position,
    required double Function() panelOffset,
    required double tabWidth,
    required double fullWidth,
    required bool isLtr,
  }) : _repaint = repaint,
       _position = position,
       _panelOffset = panelOffset,
       _tabWidth = tabWidth,
       _fullWidth = fullWidth,
       _isLtr = isLtr;

  Listenable _repaint;
  set repaint(Listenable value) {
    if (_repaint == value) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double Function() _position;
  set position(double Function() value) {
    if (_position == value) return;
    _position = value;
    markNeedsPaint();
  }

  double Function() _panelOffset;
  set panelOffset(double Function() value) {
    if (_panelOffset == value) return;
    _panelOffset = value;
    markNeedsPaint();
  }

  double _tabWidth;
  set tabWidth(double value) {
    if (_tabWidth == value) return;
    _tabWidth = value;
    markNeedsLayout();
  }

  double _fullWidth;
  set fullWidth(double value) {
    if (_fullWidth == value) return;
    _fullWidth = value;
    markNeedsLayout();
  }

  bool _isLtr;
  set isLtr(bool value) {
    if (_isLtr == value) return;
    _isLtr = value;
    markNeedsPaint();
  }

  Offset get _childOffset {
    final double travel = _position() * _tabWidth;
    final double x = _isLtr
        ? 4.0 + travel + _panelOffset()
        : _fullWidth - 4.0 - _tabWidth - travel + _panelOffset();
    return Offset(x, 4);
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_fullWidth, 64));
    child?.layout(
      BoxConstraints.tight(Size(_tabWidth, 56)),
      parentUsesSize: false,
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset + _childOffset);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset childOffset = _childOffset;
    transform.translateByDouble(childOffset.dx, childOffset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          child.hitTest(result, position: position),
    );
  }
}

/// Paints the full accent row through the moving pill's fixed-size clip.
class _SlidingTabCopy extends SingleChildRenderObjectWidget {
  const _SlidingTabCopy({
    required this.repaint,
    required this.position,
    required this.tabWidth,
    required this.fullWidth,
    required this.isLtr,
    super.child,
  });

  final Listenable repaint;
  final double Function() position;
  final double tabWidth;
  final double fullWidth;
  final bool isLtr;

  @override
  _RenderSlidingTabCopy createRenderObject(BuildContext context) =>
      _RenderSlidingTabCopy(
        repaint: repaint,
        position: position,
        tabWidth: tabWidth,
        fullWidth: fullWidth,
        isLtr: isLtr,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlidingTabCopy renderObject,
  ) {
    renderObject
      ..repaint = repaint
      ..position = position
      ..tabWidth = tabWidth
      ..fullWidth = fullWidth
      ..isLtr = isLtr;
  }
}

class _RenderSlidingTabCopy extends RenderProxyBox {
  _RenderSlidingTabCopy({
    required Listenable repaint,
    required double Function() position,
    required double tabWidth,
    required double fullWidth,
    required bool isLtr,
  }) : _repaint = repaint,
       _position = position,
       _tabWidth = tabWidth,
       _fullWidth = fullWidth,
       _isLtr = isLtr;

  Listenable _repaint;
  set repaint(Listenable value) {
    if (_repaint == value) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double Function() _position;
  set position(double Function() value) {
    if (_position == value) return;
    _position = value;
    markNeedsPaint();
  }

  double _tabWidth;
  set tabWidth(double value) {
    if (_tabWidth == value) return;
    _tabWidth = value;
    markNeedsLayout();
  }

  double _fullWidth;
  set fullWidth(double value) {
    if (_fullWidth == value) return;
    _fullWidth = value;
    markNeedsLayout();
  }

  bool _isLtr;
  set isLtr(bool value) {
    if (_isLtr == value) return;
    _isLtr = value;
    markNeedsPaint();
  }

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  double get _translationX {
    final double value = _position();
    return _isLtr
        ? -4.0 - value * _tabWidth
        : -_fullWidth + 4.0 + _tabWidth + value * _tabWidth;
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(_tabWidth, 56));
    child?.layout(
      BoxConstraints.tight(Size(_fullWidth, 56)),
      parentUsesSize: false,
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(_translationX, 0, 0),
      super.paint,
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_translationX, 0, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }
}

/// Paints its child but composites it away while its exported picture remains
/// available to the selection pill.
///
/// [Opacity] with `0` skips painting the child entirely, which would leave the
/// exported backdrop empty.
///
/// A transparent `dstIn` colour filter costs an offscreen pass instead.
class _Invisible extends StatelessWidget {
  const _Invisible({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(clipper: const _ClipToNothing(), child: child);
  }
}

class _ClipToNothing extends CustomClipper<Rect> {
  const _ClipToNothing();

  @override
  Rect getClip(Size size) => Rect.zero;

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
