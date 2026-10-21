import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The popup list metrics.
abstract final class SoftPopupListDefaults {
  /// The list's width floor.
  static const double minWidth = 168;

  /// The list's width ceiling.
  static const double maxWidth = 256;

  /// How many leading children decide the width.
  static const int maxItemsForWidth = 8;

  /// The padding above the first and below the last row, outside the
  /// scroller.
  static const double verticalPadding = 8;

  /// The band reserved between two rows of different groups; its hairline
  /// is centred in it.
  static const double dividerBandHeight = 12;

  /// The hairline's thickness (never thinner than a device pixel).
  static const double dividerThickness = 0.5;

  /// The hairline's inset from both sides.
  static const double dividerMargin = 20;

  /// The press mask's inset from both sides.
  static const double pressMaskMargin = 8;

  /// The press mask radius of a row exactly one line tall (a stadium).
  static const double pressMaskRadius = 20;

  /// The press mask radius of any taller row (smooth corners).
  static const double pressMaskRadiusTall = 28;

  /// The mask's colour in the light theme: the hover tint, not the press
  /// tint, so it reads as light as the original.
  static const Color pressLight = Color(0x14000000);

  /// The mask's colour in the dark theme.
  static const Color pressDark = Color(0x26FFFFFF);

  /// A quick tap's mask runs at least this far in before fading, so it
  /// still flashes.
  static const double pressMinVisibleProgress = 0.7;

  /// The mask fading in and out: critically damped, stiffness 438.65.
  static final SpringDescription pressSpring = softSpringStiffness(
    damping: 1,
    stiffness: 438.65,
  );

  /// The mask sliding to another row: critically damped, stiffness 1754.6.
  static final SpringDescription moveSpring = softSpringStiffness(
    damping: 1,
    stiffness: 1754.6,
  );
}

/// Registers a [SoftListPopupColumn] child as a selectable row: the column
/// tracks the finger across rows, slides one shared highlight between them
/// and calls [onTap] on the row the finger is released over.
///
/// It must be a direct child of the column (no widget that creates a render
/// object in between). Give the row its own semantics; the column's drag
/// tracking does not produce any.
class SoftListPopupItem extends ParentDataWidget<SoftListPopupParentData> {
  const SoftListPopupItem({
    super.key,
    required this.onTap,
    this.enabled = true,
    this.groupKey,
    required super.child,
  });

  final VoidCallback? onTap;
  final bool enabled;

  /// Adjacent rows with an equal non-null key form one group: the column
  /// reserves no divider band between them. Rows without a key are each
  /// their own group.
  final Object? groupKey;

  @override
  void applyParentData(RenderObject renderObject) {
    final SoftListPopupParentData data =
        renderObject.parentData! as SoftListPopupParentData;
    final bool relayout = !data.isRow || data.groupKey != groupKey;
    data
      ..isRow = true
      ..enabled = enabled
      ..groupKey = groupKey
      ..onTap = onTap;
    if (relayout) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SoftListPopupColumn;
}

/// The column every popup list is built from.
///
/// Its width is that of the widest of its first eight children, clamped to
/// 168–256; it pads 8 above and below, scrolls when taller than the popup
/// allows, and reserves a 12-high band with a centred hairline between two
/// adjacent [SoftListPopupItem] rows of different groups.
///
/// It owns the drag-to-select gesture: pressing a row lights it, dragging
/// slides that one highlight to the row under the finger (with a haptic per
/// crossing) and releasing selects the row the finger rests on. In a list
/// that scrolls, moving past the touch slop releases the highlight so the
/// scroll wins.
class SoftListPopupColumn extends StatefulWidget {
  const SoftListPopupColumn({super.key, required this.children});

  /// Rows ([SoftListPopupItem]), headers and dividers, top to bottom.
  final List<Widget> children;

  @override
  State<SoftListPopupColumn> createState() => _SoftListPopupColumnState();
}

class _SoftListPopupColumnState extends State<SoftListPopupColumn>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  late final _PopupHighlight _highlight = _PopupHighlight(this);

  int? _pointer;
  double _downY = 0;
  bool _pressed = false;
  SoftListPopupParentData? _active;

  @override
  void dispose() {
    _scroll.dispose();
    _highlight.dispose();
    super.dispose();
  }

  _RenderPopupList? get _list =>
      _listKey.currentContext?.findRenderObject() as _RenderPopupList?;

  bool get _dynamicSelection {
    if (!_scroll.hasClients) return true;
    final ScrollPosition p = _scroll.position;
    return !p.hasContentDimensions || p.maxScrollExtent <= p.minScrollExtent;
  }

  double get _touchSlop =>
      MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;

  void _enter(SoftListPopupParentData? row) {
    if (row != null && row.enabled) {
      _highlight.place(row.top, row.bottom);
    } else {
      _highlight.fade();
    }
  }

  void _cancel() {
    if (_active == null) return;
    _active = null;
    _highlight.fade();
  }

  void _moveTo(double y) {
    final SoftListPopupParentData? target = _list?.rowAt(y);
    if (target == null) {
      _cancel();
      return;
    }
    if (identical(target, _active)) return;
    _active = target;
    if (target.enabled) {
      _highlight.move(target.top, target.bottom);
    } else {
      _highlight.fade();
    }
  }

  void _track(Offset local) {
    final double width = _list?.size.width ?? 0;
    final bool inside = local.dx >= 0 && local.dx < width;
    if (!inside) {
      _cancel();
    } else if (_dynamicSelection) {
      final SoftListPopupParentData? target = _list?.rowAt(local.dy);
      final bool crossing =
          target != null && !identical(target, _active) && target.enabled;
      _moveTo(local.dy);
      if (crossing) HapticFeedback.heavyImpact();
    }
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      // A second finger cancels the selection.
      _cancel();
      _pressed = false;
      return;
    }
    _pointer = event.pointer;
    _downY = event.localPosition.dy;
    final SoftListPopupParentData? row = _list?.rowAt(_downY);
    _active = row;
    _enter(row);
    _pressed = row != null;
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || !_pressed) return;
    _track(event.localPosition);
    if (!_dynamicSelection &&
        (event.localPosition.dy - _downY).abs() > _touchSlop) {
      _cancel();
      _pressed = false;
    }
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!_pressed) {
      _cancel();
      return;
    }
    _pressed = false;
    _track(event.localPosition);
    final SoftListPopupParentData? target = _active;
    _cancel();
    if (target != null && target.enabled) target.onTap?.call();
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _pressed = false;
    _cancel();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: SoftPopupListDefaults.verticalPadding,
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: CustomPaint(
            painter: _HighlightPainter(
              highlight: _highlight,
              color: theme.isDark
                  ? SoftPopupListDefaults.pressDark
                  : SoftPopupListDefaults.pressLight,
              smooth: theme.smoothCorners,
            ),
            child: RepaintBoundary(
              child: FocusTraversalGroup(
                child: _PopupList(
                  key: _listKey,
                  dividerColor: theme.colors.dividerLine,
                  devicePixelRatio:
                      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
                  children: widget.children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The band between two popup groups: 12 high, with a 0.5 hairline in the
/// theme's divider colour centred in it and inset 20 from both sides.
///
/// Rows of different groups already get this band from the column; use it
/// where the divider is an explicit child, between dropdown groups.
class SoftPopupListDivider extends StatelessWidget {
  const SoftPopupListDivider({super.key, this.color});

  /// The hairline colour; the theme's `dividerLine` by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: SoftPopupListDefaults.dividerBandHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _HairlinePainter(
            color: color ?? SoftTheme.of(context).colors.dividerLine,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
          ),
        ),
      ),
    );
  }
}

class _HairlinePainter extends CustomPainter {
  const _HairlinePainter({required this.color, required this.devicePixelRatio});

  final Color color;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    _paintHairline(canvas, size.width, 0, color, devicePixelRatio);
  }

  @override
  bool shouldRepaint(_HairlinePainter old) =>
      old.color != color || old.devicePixelRatio != devicePixelRatio;
}

/// Paints the hairline centred in a divider band that starts at [top].
void _paintHairline(
  Canvas canvas,
  double width,
  double top,
  Color color,
  double devicePixelRatio,
) {
  final double thickness = math.max(
    SoftPopupListDefaults.dividerThickness,
    1 / devicePixelRatio,
  );
  final double w = width - SoftPopupListDefaults.dividerMargin * 2;
  if (w <= 0) return;
  canvas.drawRect(
    Rect.fromLTWH(
      SoftPopupListDefaults.dividerMargin,
      top + (SoftPopupListDefaults.dividerBandHeight - thickness) / 2,
      w,
      thickness,
    ),
    Paint()..color = color,
  );
}

/// The one highlight a popup list slides between its rows.
class _PopupHighlight extends ChangeNotifier {
  _PopupHighlight(TickerProvider vsync)
    : top = SoftSpring(vsync: vsync),
      bottom = SoftSpring(vsync: vsync),
      alpha = SoftSpring(vsync: vsync) {
    top.addListener(notifyListeners);
    bottom.addListener(notifyListeners);
    alpha
      ..addListener(notifyListeners)
      ..addListener(_checkThreshold);
  }

  final SoftSpring top;
  final SoftSpring bottom;
  final SoftSpring alpha;

  /// A fade waiting for a quick tap's mask to reach the minimum progress.
  bool _fadePending = false;

  static const double _threshold = 0.01;

  void _fadeIn() => alpha.animateTo(
    1,
    SoftPopupListDefaults.pressSpring,
    threshold: _threshold,
  );

  /// Puts the mask on a row and fades it in (a fresh press).
  void place(double rowTop, double rowBottom) {
    _fadePending = false;
    top.snapTo(rowTop);
    bottom.snapTo(rowBottom);
    _fadeIn();
  }

  /// Slides the mask to a row, keeping it visible on the way.
  void move(double rowTop, double rowBottom) {
    _fadePending = false;
    if (alpha.value <= 0) {
      top.snapTo(rowTop);
      bottom.snapTo(rowBottom);
    } else {
      top.animateTo(
        rowTop,
        SoftPopupListDefaults.moveSpring,
        threshold: _threshold,
      );
      bottom.animateTo(
        rowBottom,
        SoftPopupListDefaults.moveSpring,
        threshold: _threshold,
      );
    }
    _fadeIn();
  }

  /// Fades the mask out, first letting a quick tap's fade-in reach the
  /// minimum visible progress.
  void fade() {
    final double a = alpha.value;
    if (a > 0 && a < SoftPopupListDefaults.pressMinVisibleProgress) {
      _fadePending = true;
      _fadeIn();
    } else {
      _fadePending = false;
      alpha.animateTo(
        0,
        SoftPopupListDefaults.pressSpring,
        threshold: _threshold,
      );
    }
  }

  void _checkThreshold() {
    if (!_fadePending ||
        alpha.value < SoftPopupListDefaults.pressMinVisibleProgress) {
      return;
    }
    _fadePending = false;
    alpha.animateTo(
      0,
      SoftPopupListDefaults.pressSpring,
      threshold: _threshold,
    );
  }

  @override
  void dispose() {
    top.dispose();
    bottom.dispose();
    alpha.dispose();
    super.dispose();
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.highlight,
    required this.color,
    required this.smooth,
  }) : super(repaint: highlight);

  final _PopupHighlight highlight;
  final Color color;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    final double a = highlight.alpha.value.clamp(0.0, 1.0);
    if (a <= 0) return;
    final double top = highlight.top.value;
    final double height = highlight.bottom.value - top;
    if (height <= 0) return;
    const double inset = SoftPopupListDefaults.pressMaskMargin;
    final double width = size.width - inset * 2;
    if (width <= 0) return;
    // A one-line row is as tall as the radius is wide: a stadium with plain
    // arcs. Taller rows take the smooth silhouette.
    final bool singleLine =
        (height - SoftPopupListDefaults.pressMaskRadius * 2).abs() < 0.01;
    final double radius = singleLine
        ? SoftPopupListDefaults.pressMaskRadius
        : SoftPopupListDefaults.pressMaskRadiusTall;
    drawSoftSquircle(
      canvas,
      Rect.fromLTWH(inset, top, width, height),
      BorderRadius.circular(radius),
      Paint()..color = color.withValues(alpha: color.a * a),
      smooth: smooth && !singleLine,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.highlight != highlight || old.color != color || old.smooth != smooth;
}

/// What a [SoftListPopupColumn] knows about each child; written by
/// [SoftListPopupItem].
class SoftListPopupParentData extends ContainerBoxParentData<RenderBox> {
  bool isRow = false;
  bool enabled = true;
  Object? groupKey;
  VoidCallback? onTap;

  /// The row's bounds in the list, written by layout.
  double top = 0;
  double bottom = 0;
}

class _PopupList extends MultiChildRenderObjectWidget {
  const _PopupList({
    super.key,
    required this.dividerColor,
    required this.devicePixelRatio,
    required super.children,
  });

  final Color dividerColor;
  final double devicePixelRatio;

  @override
  _RenderPopupList createRenderObject(BuildContext context) => _RenderPopupList(
    dividerColor: dividerColor,
    devicePixelRatio: devicePixelRatio,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderPopupList renderObject) {
    renderObject
      ..dividerColor = dividerColor
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderPopupList extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, SoftListPopupParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, SoftListPopupParentData> {
  _RenderPopupList({
    required Color dividerColor,
    required double devicePixelRatio,
  }) : _dividerColor = dividerColor,
       _devicePixelRatio = devicePixelRatio;

  Color _dividerColor;
  set dividerColor(Color value) {
    if (value == _dividerColor) return;
    _dividerColor = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  final List<SoftListPopupParentData> _rows = <SoftListPopupParentData>[];
  final List<double> _hairlines = <double>[];

  /// The row whose bounds contain [y], in the list's coordinates.
  SoftListPopupParentData? rowAt(double y) {
    for (final SoftListPopupParentData row in _rows) {
      if (y >= row.top && y < row.bottom) return row;
    }
    return null;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! SoftListPopupParentData) {
      child.parentData = SoftListPopupParentData();
    }
  }

  double _widestLeading() {
    double widest = 0;
    int count = 0;
    RenderBox? child = firstChild;
    while (child != null && count < SoftPopupListDefaults.maxItemsForWidth) {
      widest = math.max(widest, child.getMaxIntrinsicWidth(double.infinity));
      count++;
      child = childAfter(child);
    }
    return widest;
  }

  double _intrinsicWidth() => _widestLeading().clamp(
    SoftPopupListDefaults.minWidth,
    SoftPopupListDefaults.maxWidth,
  );

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth();

  double _intrinsicHeight(double width, bool max) {
    double height = 0;
    bool previousWasRow = false;
    Object? previousGroup;
    RenderBox? child = firstChild;
    while (child != null) {
      final SoftListPopupParentData data =
          child.parentData! as SoftListPopupParentData;
      if (_needsBand(data, previousWasRow, previousGroup)) {
        height += SoftPopupListDefaults.dividerBandHeight;
      }
      height += max
          ? child.getMaxIntrinsicHeight(width)
          : child.getMinIntrinsicHeight(width);
      previousWasRow = data.isRow;
      previousGroup = data.groupKey;
      child = childAfter(child);
    }
    return height;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, false);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, true);

  static bool _needsBand(
    SoftListPopupParentData data,
    bool previousWasRow,
    Object? previousGroup,
  ) {
    if (!data.isRow || !previousWasRow) return false;
    final bool sameGroup =
        data.groupKey != null && data.groupKey == previousGroup;
    return !sameGroup;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double width = _resolveWidth(constraints);
    return constraints.constrain(Size(width, _intrinsicHeight(width, true)));
  }

  double _resolveWidth(BoxConstraints constraints) {
    final double upper = math.min(
      math.max(SoftPopupListDefaults.maxWidth, constraints.minWidth),
      constraints.maxWidth,
    );
    final double lower = math.min(
      math.max(SoftPopupListDefaults.minWidth, constraints.minWidth),
      upper,
    );
    return _widestLeading().clamp(lower, upper);
  }

  @override
  void performLayout() {
    final double width = _resolveWidth(constraints);
    final BoxConstraints childConstraints = BoxConstraints.tightFor(
      width: width,
    );
    _rows.clear();
    _hairlines.clear();
    double y = 0;
    bool previousWasRow = false;
    Object? previousGroup;
    RenderBox? child = firstChild;
    while (child != null) {
      final SoftListPopupParentData data =
          child.parentData! as SoftListPopupParentData;
      if (_needsBand(data, previousWasRow, previousGroup)) {
        _hairlines.add(y);
        y += SoftPopupListDefaults.dividerBandHeight;
      }
      child.layout(childConstraints, parentUsesSize: true);
      data.offset = Offset(0, y);
      if (data.isRow) {
        data
          ..top = y
          ..bottom = y + child.size.height;
        _rows.add(data);
      }
      y += child.size.height;
      previousWasRow = data.isRow;
      previousGroup = data.groupKey;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    if (_hairlines.isEmpty) return;
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final double y in _hairlines) {
      _paintHairline(canvas, size.width, y, _dividerColor, _devicePixelRatio);
    }
    canvas.restore();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
