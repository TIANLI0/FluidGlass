import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../fluid_glass.dart';
import '../internal/glass_painters.dart';

/// Marks the accent-tinted copy of the tabs inside a [LiquidBottomTabs], and
/// provides the press-driven scale to the tabs there.
///
/// The Flutter counterpart of `LocalLiquidBottomTabScale`. Since 0.1.12 the
/// copy is scaled where it is drawn — inside the selection pill, at paint time
/// — rather than in the widget tree, so [scale] reads 1.0 and [notifier] never
/// fires. The widget is kept so a tab can still tell which of its two
/// renderings it is in: `LiquidBottomTabScale.of(context)` returns a getter in
/// both, and `context.getElementForInheritedWidgetOfExactType` finds the widget
/// only in the copy.
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
///
/// Three pieces of glass would be the literal reading of the design: the panel,
/// an accent-tinted copy of the panel for the pill to look through, and the
/// pill. Drawn that way the copy had to be captured with an
/// `OffsetLayer.toImageSync` on every frame the pill moved — a pipeline flush
/// per frame, and by a wide margin the most expensive thing on screen while a
/// tab was being switched. So the copy is not a glass element of its own. The
/// pill's backdrop ([_AccentGlassBackdrop]) draws the copy's glass itself, only
/// over the pill's own footprint, and the accent tab row it shows is an
/// ordinary captured subtree whose content does not change while the pill
/// moves, so it is captured once and read every frame.
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

/// The height of the accent tab row, and of the pill: the panel minus its 4dp
/// inset on each side.
const double _rowHeight = 56.0;
const double _panelHeight = 64.0;
const double _inset = 4.0;

class _LiquidBottomTabsState extends State<LiquidBottomTabs>
    with TickerProviderStateMixin {
  /// The accent-tinted tab row, captured as it is painted. Nothing inside it
  /// animates, so the capture is taken when the row first paints and again
  /// only when its content changes — a theme or a label — never per frame.
  final LayerBackdrop _tabsBackdrop = LayerBackdrop();

  late final SpringValue _offsetAnimation = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.5,
  );
  late final DampedDragAnimation _animation;
  late final InteractiveHighlight _interactiveHighlight;
  late _AccentGlassBackdrop _pillBackdrop;
  late final Listenable _repaint;

  double _tabWidth = 0;
  double _maxWidth = 0;
  int _currentIndex = 0;

  // Read in `build`, used by the pill's backdrop during paint.
  Color _containerColor = const Color(0x00000000);
  bool _isLtr = true;

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
    _pillBackdrop = _AccentGlassBackdrop(
      page: widget.backdrop,
      tabs: _tabsBackdrop,
      owner: this,
    );
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
    if (widget.backdrop != oldWidget.backdrop) {
      _pillBackdrop.dispose();
      _pillBackdrop = _AccentGlassBackdrop(
        page: widget.backdrop,
        tabs: _tabsBackdrop,
        owner: this,
      );
    }
  }

  @override
  void dispose() {
    _offsetAnimation.dispose();
    _animation.dispose();
    _interactiveHighlight.dispose();
    _tabsBackdrop.dispose();
    _pillBackdrop.dispose();
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

  /// Where the pill's top-left corner sits within the bar.
  Offset get _pillOffset {
    final double along = _inset + _animation.value * _tabWidth;
    return Offset(
      (_isLtr ? along : _maxWidth - along - _tabWidth) + _panelOffset,
      _inset,
    );
  }

  Offset _highlightPosition(Size size, Offset offset) {
    return Offset(
      _isLtr
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
    _animation.updateValue(
      (_animation.targetValue + dragAmount.dx / _tabWidth * (_isLtr ? 1 : -1))
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

  void _panelLayerBlock(GlassLayer layer) {
    layer.translationX = _panelOffset;
    final double scale = ui.lerpDouble(
      1.0,
      1.0 + 16.0 / math.max(layer.size.width, 1.0),
      _animation.pressProgress,
    )!;
    layer.scaleX = scale;
    layer.scaleY = scale;
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
    _containerColor = colors.container;
    _isLtr = Directionality.of(context) == TextDirection.ltr;
    final Color containerColor = _containerColor;

    void drawContainer(Canvas canvas, Size size) {
      canvas.drawRect(Offset.zero & size, Paint()..color = containerColor);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _maxWidth = constraints.maxWidth;
        _tabWidth = (_maxWidth - _inset * 2) / widget.tabsCount;

        // Nothing here is rebuilt while the pill moves. Every animated value
        // — the panel's give, the pill's position, the press — is read during
        // paint by the render objects below, which listen to `_repaint`.
        return SizedBox(
          width: _maxWidth,
          height: _panelHeight,
          child: Stack(
            alignment: _isLtr ? Alignment.centerLeft : Alignment.centerRight,
            // The pill paints outside the panel by design: it carries a
            // drop shadow and grows to 1.39x while pressed. A Stack clips
            // as soon as a positioned child overflows, and the pill's
            // `left` lands exactly on 0 at the first tab and exactly on the
            // panel width at the last, so rounding alone decided whether
            // the clip engaged and sheared the corners off at either end.
            clipBehavior: Clip.none,
            children: <Widget>[
              // The panel itself. Its give under an over-drag is part of the
              // layer transform, so it costs a repaint and not a layout.
              DrawBackdrop(
                backdrop: widget.backdrop,
                shape: () => const Capsule(),
                effects: (BackdropEffectScope scope) => scope
                  ..vibrancy()
                  ..blur(8)
                  ..lens(24, 24),
                layerBlock: _panelLayerBlock,
                onDrawSurface: drawContainer,
                // The surface only paints src-over, so the isolating
                // save-layer would change nothing but cost a pass.
                isolateSurface: false,
                repaint: _repaint,
                child: _interactiveHighlight.wrapOverlay(
                  child: SizedBox(
                    height: _panelHeight,
                    width: _maxWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: widget.children,
                      ),
                    ),
                  ),
                ),
              ),

              // The accent-tinted copy of the tabs: invisible on screen,
              // captured for the pill to draw through its glass. Only the
              // tabs are here — the glass around them is the pill's business
              // (see [_AccentGlassBackdrop]) — and nothing in this subtree
              // moves, so the capture is taken once and held until a tab's
              // content actually changes. It sits where the panel's content
              // sits, give included, and the pill maps into it through the
              // render tree — so the copy a pill shows is always the tab
              // under it.
              ExcludeSemantics(
                child: _Invisible(
                  child: _PaintShifted(
                    repaint: _repaint,
                    offset: () => Offset(_panelOffset, _inset),
                    childSize: () => Size(_maxWidth, _rowHeight),
                    child: BackdropLayer(
                      backdrop: _tabsBackdrop,
                      child: LiquidBottomTabScale(
                        notifier: const AlwaysStoppedAnimation<double>(0),
                        scale: _unitScale,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _inset,
                          ),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              accentColor,
                              BlendMode.srcIn,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: widget.children,
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
              // Moved at paint time by a render object laid out to the whole
              // bar, which also shifts hit testing: Flutter bounds-checks every
              // ancestor before descending into it, so a pill drawn outside its
              // own layout box would stop receiving touches as soon as it left
              // the first tab.
              _PaintShifted(
                repaint: _repaint,
                offset: () => _pillOffset,
                childSize: () => Size(_tabWidth, _rowHeight),
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static double _unitScale() => 1.0;
}

/// The pill's backdrop: the page, and over it the accent-tinted glass copy of
/// the bar — blurred and refracted page, container tint, accent tabs, rim —
/// drawn by hand over just the pill's footprint.
///
/// This is what a second `DrawBackdrop` captured through a `BackdropLayer` used
/// to provide, at the price of an `OffsetLayer.toImageSync` on every frame the
/// pill moved. Drawing it here instead costs the same blur and lens passes
/// over a third of the pixels and no capture at all. The geometry is the whole
/// bar's: the effect chain is resolved for the bar-sized element and then run
/// in a save-layer the size of the pill's window onto it
/// ([BackdropEffectScope.resolve]'s `layerRect`), so the lens still bends
/// along the bar's edge exactly where it did.
class _AccentGlassBackdrop extends Backdrop {
  _AccentGlassBackdrop({
    required this.page,
    required this.tabs,
    required this.owner,
  });

  /// What the bar refracts.
  final Backdrop page;

  /// The captured accent tab row, in whose coordinates the copy is drawn.
  final LayerBackdrop tabs;

  final _LiquidBottomTabsState owner;

  /// The blur the copy applies to the page, in logical pixels.
  static const double blurRadius = 8.0;

  final BackdropEffectScope _scope = BackdropEffectScope();
  final FragmentShaderCache _rimShaders = FragmentShaderCache();
  final BakedDecoration _shadowBake = BakedDecoration();

  @override
  bool get isCoordinatesDependent => true;

  /// Repaints when either the page or the tab row changes.
  late final Listenable _repaintNotifier = Listenable.merge(<Listenable>[
    ?page.repaintNotifier,
    tabs,
  ]);

  @override
  Listenable? get repaintNotifier => _repaintNotifier;

  @override
  void drawBackdrop(BackdropDrawContext context) {
    final RenderBox? consumer = context.consumer;
    if (consumer == null || !consumer.attached) return;

    // The page under the pill. Where the pill is bigger than the bar — the
    // 11 logical pixels it grows past the row while pressed — this is what
    // shows through, refracted by the pill's own lens.
    page.drawBackdrop(context);

    final LayerBackdropSource? row = tabs.source;
    if (row == null || !row.hasContent) return;
    final Matrix4? toRow = tabs.consumerToSourceTransform(consumer);
    if (toRow == null) return;
    final Matrix4 toPill = Matrix4.copy(toRow);
    if (toPill.invert() == 0.0) return;

    // The pill's whole padded layer, in the row's coordinates: exactly what
    // the compositor will let a save-layer inside it cover, so that is what
    // the copy's save-layers are given. Asking for more would be cut back to
    // this, and a lens handed a texture smaller than it was told would bend
    // the wrong place.
    final Rect pillLayer = (Offset.zero & context.size).inflate(
      context.sampleMargin,
    );
    final Rect window = MatrixUtils.transformRect(toRow, pillLayer);

    final Size rowSize = row.sourceSize;
    final TextDirection direction = context.textDirection;
    final double dpr = context.devicePixelRatio;
    final GlassQuality quality = context.quality;
    const RoundedRectangularShape shape = Capsule();
    final GlassOutline outline = shape.createOutline(rowSize, direction);
    final double progress = owner._animation.pressProgress;

    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.transform(toPill.storage);

    // 1. The copy's drop shadow, outside its shape. Baked once — its inputs
    // hold still — and blitted; only the strip of it the pill uncovers while
    // pressed is ever seen.
    paintGlassShadow(
      canvas,
      Offset.zero,
      rowSize,
      outline,
      GlassShadow.standard,
      dpr,
      cache: _shadowBake,
      cacheKey: (rowSize, shape, direction, dpr),
    );

    canvas.save();
    outline.clip(canvas);

    // 2. The page through the copy's effects, over the window only.
    _scope.beginUpdate(
      size: rowSize,
      textDirection: direction,
      shape: shape,
      devicePixelRatio: dpr,
      quality: quality,
    );
    _scope
      ..vibrancy()
      ..blur(blurRadius)
      ..lens(24 * progress, 24 * progress);
    final List<ui.ImageFilter> filters = _scope.resolve(layerRect: window);
    for (int i = filters.length - 1; i >= 0; i--) {
      canvas.saveLayer(window, Paint()..imageFilter = filters[i]);
    }
    canvas.save();
    canvas.transform(toRow.storage);
    page.drawBackdrop(context);
    canvas.restore();
    for (int i = 0; i < filters.length; i++) {
      canvas.restore();
    }

    // 3. The container tint, the press glow, and the accent tabs — each tab
    // scaled about its own centre by the press, as `LiquidBottomTabScale` used
    // to scale it in the tree.
    canvas.drawRect(window, Paint()..color = owner._containerColor);
    owner._interactiveHighlight.paintOverlay(canvas, rowSize, quality: quality);

    final double scale = ui.lerpDouble(1.0, 1.2, progress)!;
    final double tabWidth = owner._tabWidth;
    final int count = owner.widget.tabsCount;
    for (int slot = 0; slot < count; slot++) {
      final Rect tab = Rect.fromLTWH(
        _inset + slot * tabWidth,
        0,
        tabWidth,
        rowSize.height,
      );
      if (!tab.overlaps(window)) continue;
      canvas.save();
      canvas.translate(tab.left, tab.top);
      shape.createOutline(tab.size, direction).clip(canvas);
      canvas.translate(-tab.left, -tab.top);
      if (scale != 1.0) {
        final Offset centre = tab.center;
        canvas.translate(centre.dx, centre.dy);
        canvas.scale(scale);
        canvas.translate(-centre.dx, -centre.dy);
      }
      row.drawSource(canvas, dpr);
      canvas.restore();
    }
    canvas.restore();

    // 4. The copy's rim, fading in with the press.
    paintGlassHighlight(
      canvas,
      Offset.zero,
      rowSize,
      outline,
      Highlight.standard.copyWith(alpha: progress),
      shape.corners(rowSize, direction),
      _rimShaders,
      dpr,
      shadeRim: quality.hasShadedRim,
    );

    canvas.restore();
  }

  void dispose() {
    _scope.dispose();
    _rimShaders.clear();
    _shadowBake.dispose();
  }
}

/// Lays its child out at [childSize] inside a box the size of the whole bar,
/// and paints and hit-tests it at [offset] — read fresh on every paint, so the
/// pill (and the captured row it looks into) moves without a layout.
class _PaintShifted extends SingleChildRenderObjectWidget {
  const _PaintShifted({
    required this.repaint,
    required this.offset,
    required this.childSize,
    required Widget super.child,
  });

  final Listenable repaint;
  final Offset Function() offset;
  final Size Function() childSize;

  @override
  _RenderPaintShifted createRenderObject(BuildContext context) =>
      _RenderPaintShifted(
        repaint: repaint,
        offset: offset,
        childSize: childSize,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaintShifted renderObject,
  ) {
    renderObject
      ..repaint = repaint
      ..offset = offset
      ..childSize = childSize;
  }
}

class _RenderPaintShifted extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderPaintShifted({
    required Listenable repaint,
    required Offset Function() offset,
    required Size Function() childSize,
  }) : _repaint = repaint,
       _offset = offset,
       _childSize = childSize;

  Listenable _repaint;
  set repaint(Listenable value) {
    if (_repaint == value) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Offset Function() _offset;
  set offset(Offset Function() value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsPaint();
  }

  Size Function() _childSize;
  set childSize(Size Function() value) {
    if (_childSize == value) return;
    _childSize = value;
    markNeedsLayout();
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
  void performLayout() {
    size = constraints.biggest;
    child?.layout(BoxConstraints.tight(_childSize()));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) context.paintChild(child, offset + _offset());
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset offset = _offset();
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _offset(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

/// Paints its child but composites it away, so a [BackdropLayer] inside can
/// still capture it.
///
/// [Opacity] with `0` skips painting the child entirely, which would leave the
/// captured layer empty.
///
/// Clipping to nothing rather than filtering to nothing: the [BackdropLayer]
/// inside is a repaint boundary, so its own layer is still recorded in full
/// and the clip only removes it from the screen. A transparent `dstIn` colour
/// filter costs an offscreen pass instead.
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
