import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';
import '../badge/soft_badge.dart';

/// The chip tab defaults.
abstract final class SoftChipTabDefaults {
  /// A tab's height, and its width range.
  static const double height = 32;
  static const double minWidth = 52;
  static const double maxWidth = 300;

  /// The widest a label gets before it ellipsizes.
  static const double textMaxWidth = 200;

  /// The capsule radius of the 32 pill.
  static const double cornerRadius = 16;

  /// The leading icon and the gap after it.
  static const double iconSize = 16;
  static const double iconEndPadding = 4;

  /// The padding before the first and after the last content.
  static const double startPadding = 12;
  static const double endPadding = 12;

  /// The end padding while the red dot shows.
  static const double endPaddingWithRedDot = 8;

  /// Before the count.
  static const double countStartMargin = 2;

  /// The red dot: its size, its gap after the content, and its distance
  /// from the top of the tab.
  static const double redDotDiameter = 6;
  static const double redDotOffsetHorizontal = 2;
  static const double redDotOffsetVertical = 6;

  /// Between two tabs of a group.
  static const double groupSpacing = 8;

  /// The faded edge of a group that can scroll that way.
  static const double fadeWidth = 12;

  /// The selected outline.
  static const double checkedStrokeWidth = 0.6;

  /// The smallest layer alpha change worth animating.
  static const double minVisibleChange = 1 / 256;

  /// The selected / unselected layers: (0.2, 0).
  static final SpringDescription layerSpring = softSpring(
    damping: 1,
    response: 0.2,
  );

  /// Scrolling a selected tab into view: (0.4, 0.2).
  static final SpringDescription scrollSpring = softSpring(
    damping: 0.8,
    response: 0.4,
  );

  /// The unselected overlay, light and dark.
  static const Color containerLight = Color(0x0A000000);
  static const Color containerDark = Color(0x1AFFFFFF);

  /// The selected overlay over the selected surface.
  static const Color checkedOverlay = Color(0x40FFFFFF);

  /// The selected outline, light and dark.
  static const Color checkedStrokeLight = Color(0x0A000000);
  static const Color checkedStrokeDark = Color(0x0AFFFFFF);
}

/// One tab of a [SoftChipTabGroup].
@immutable
class SoftChipTabData {
  const SoftChipTabData({
    required this.label,
    this.icon,
    this.enabled = true,
    this.showRedDot = false,
    this.count,
  });

  final String label;

  /// A leading glyph, laid out in a 16 box and tinted like the label through
  /// [IconTheme].
  final Widget? icon;
  final bool enabled;
  final bool showRedDot;

  /// A number shown after the label.
  final int? count;
}

/// A pill tab: a 32 capsule holding an optional icon, a label, an optional
/// count and an optional red dot.
///
/// Unselected, the pill is a faint overlay (`black 4 %`, `white 10 %` dark)
/// over whatever is behind it; selected, it fills with the theme's
/// `surfaceContainerHighest`, a white 25 % sheen and a 0.6 outline. The two
/// layers crossfade on a critically damped spring. A disabled tab keeps its
/// fill and greys its label.
class SoftChipTab extends StatefulWidget {
  const SoftChipTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.showRedDot = false,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool enabled;
  final bool showRedDot;
  final int? count;

  @override
  State<SoftChipTab> createState() => _SoftChipTabState();
}

class _SoftChipTabState extends State<SoftChipTab>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _checked = SoftSpring(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    // The late fields above read the first widget; read them now, before a
    // later widget can be the one they see.
    _checked;
  }

  @override
  void didUpdateWidget(SoftChipTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final double target = widget.selected ? 1 : 0;
    if (softReduceMotion(context)) {
      _checked.snapTo(target);
    } else {
      _checked.animateTo(
        target,
        SoftChipTabDefaults.layerSpring,
        threshold: SoftChipTabDefaults.minVisibleChange,
      );
    }
  }

  @override
  void dispose() {
    _checked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    final Color content = widget.enabled
        ? theme.colors.onSurface
        : theme.colors.onSurfaceVariantActions;
    final int? count = widget.count;
    final Widget? icon = widget.icon;
    final Widget row = Padding(
      padding: EdgeInsetsDirectional.only(
        start: SoftChipTabDefaults.startPadding,
        end: widget.showRedDot
            ? SoftChipTabDefaults.endPaddingWithRedDot
            : SoftChipTabDefaults.endPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            IconTheme(
              data: IconThemeData(
                color: content,
                size: SoftChipTabDefaults.iconSize,
              ),
              child: SizedBox.square(
                dimension: SoftChipTabDefaults.iconSize,
                child: Center(child: icon),
              ),
            ),
            const SizedBox(width: SoftChipTabDefaults.iconEndPadding),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SoftChipTabDefaults.textMaxWidth,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textStyles.body2.copyWith(color: content),
              ),
            ),
          ),
          if (count != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: SoftChipTabDefaults.countStartMargin,
              ),
              child: Text(
                '$count',
                maxLines: 1,
                style: theme.textStyles.footnote1.copyWith(
                  color: theme.colors.onSurfaceSecondary,
                ),
              ),
            ),
          if (widget.showRedDot)
            SizedBox(
              height: SoftChipTabDefaults.height,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: SoftChipTabDefaults.redDotOffsetHorizontal,
                  top: SoftChipTabDefaults.redDotOffsetVertical,
                ),
                child: const Align(
                  alignment: AlignmentDirectional.topStart,
                  widthFactor: 1,
                  child: SoftBadge(
                    stroke: true,
                    dotDiameter: SoftChipTabDefaults.redDotDiameter,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: SoftChipTabDefaults.minWidth,
            maxWidth: SoftChipTabDefaults.maxWidth,
            minHeight: SoftChipTabDefaults.height,
          ),
          child: CustomPaint(
            painter: _ChipPainter(
              checked: _checked,
              surface: theme.colors.surfaceContainerHighest,
              container: dark
                  ? SoftChipTabDefaults.containerDark
                  : SoftChipTabDefaults.containerLight,
              stroke: dark
                  ? SoftChipTabDefaults.checkedStrokeDark
                  : SoftChipTabDefaults.checkedStrokeLight,
              smooth: theme.smoothCorners,
            ),
            child: SizedBox(
              height: SoftChipTabDefaults.height,
              child: Center(widthFactor: 1, child: row),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter({
    required this.checked,
    required this.surface,
    required this.container,
    required this.stroke,
    required this.smooth,
  }) : super(repaint: checked);

  final SoftSpring checked;
  final Color surface;
  final Color container;
  final Color stroke;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    final double a = checked.value.clamp(0.0, 1.0);
    final Rect rect = Offset.zero & size;
    final Path pill = softSquirclePath(
      rect,
      const BorderRadius.all(Radius.circular(SoftChipTabDefaults.cornerRadius)),
      smooth: smooth,
    );
    if (a > 0) {
      canvas.drawPath(
        pill,
        Paint()..color = surface.withValues(alpha: surface.a * a),
      );
    }
    if (a < 1) {
      canvas.drawPath(
        pill,
        Paint()..color = container.withValues(alpha: container.a * (1 - a)),
      );
    }
    if (a > 0) {
      const Color overlay = SoftChipTabDefaults.checkedOverlay;
      canvas.drawPath(
        pill,
        Paint()..color = overlay.withValues(alpha: overlay.a * a),
      );
      const double w = SoftChipTabDefaults.checkedStrokeWidth;
      final Rect inner = rect.deflate(w / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          inner,
          Radius.circular(math.max(0, size.shortestSide / 2 - w / 2)),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = stroke.withValues(alpha: stroke.a * a),
      );
    }
  }

  @override
  bool shouldRepaint(_ChipPainter old) =>
      old.surface != surface ||
      old.container != container ||
      old.stroke != stroke ||
      old.smooth != smooth ||
      !identical(old.checked, checked);
}

/// A single-line, sideways-scrolling row of [SoftChipTab]s, 8 apart, one of
/// them selected.
///
/// An edge the row can still scroll towards fades out over 12. Selecting a
/// tab that the visible area (inset by the faded edges) cuts through scrolls
/// it into view on a (0.4, 0.2) spring; the first selection never scrolls.
class SoftChipTabGroup extends StatefulWidget {
  const SoftChipTabGroup({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelectedChange,
  });

  final List<SoftChipTabData> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelectedChange;

  @override
  State<SoftChipTabGroup> createState() => _SoftChipTabGroupState();
}

class _SoftChipTabGroupState extends State<SoftChipTabGroup>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<(bool, bool)> _edges = ValueNotifier<(bool, bool)>((
    false,
    false,
  ));
  final GlobalKey _viewport = GlobalKey();
  List<GlobalKey> _keys = const <GlobalKey>[];
  late final SoftSpring _spring = SoftSpring(vsync: this)
    ..addListener(_onSpring);

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(SoftChipTabGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollIntoView(widget.selectedIndex);
      });
    }
  }

  void _syncKeys() {
    if (_keys.length == widget.tabs.length) return;
    _keys = List<GlobalKey>.generate(widget.tabs.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _spring.dispose();
    _scroll.dispose();
    _edges.dispose();
    super.dispose();
  }

  void _onSpring() {
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    p.jumpTo(_spring.value.clamp(p.minScrollExtent, p.maxScrollExtent));
  }

  bool _onMetrics(ScrollMetrics metrics) {
    final bool before = metrics.extentBefore > 0;
    final bool after = metrics.extentAfter > 0;
    final bool leftToRight = metrics.axisDirection == AxisDirection.right;
    final (bool, bool) edges = leftToRight ? (before, after) : (after, before);
    if (edges != _edges.value) _edges.value = edges;
    return false;
  }

  void _scrollIntoView(int index) {
    if (!_scroll.hasClients || index < 0 || index >= _keys.length) return;
    final ScrollPosition p = _scroll.position;
    if (p.maxScrollExtent <= 0) return;
    final RenderObject? viewport = _viewport.currentContext?.findRenderObject();
    final RenderObject? tab = _keys[index].currentContext?.findRenderObject();
    if (viewport is! RenderBox || tab is! RenderBox) return;
    final Offset origin = tab.localToGlobal(Offset.zero, ancestor: viewport);
    final double left = origin.dx;
    final double right = left + tab.size.width;
    final (bool fadeLeft, bool fadeRight) = _edges.value;
    const double fade = SoftChipTabDefaults.fadeWidth;
    final double visibleLeft = fadeLeft ? fade : 0;
    final double visibleRight = viewport.size.width - (fadeRight ? fade : 0);
    final double delta;
    if (visibleLeft > left && visibleLeft < right) {
      delta = left - visibleLeft;
    } else if (visibleRight > left && visibleRight < right) {
      delta = right - visibleRight;
    } else {
      return;
    }
    final double sign = p.axisDirection == AxisDirection.right ? 1 : -1;
    final double target = (p.pixels + sign * delta).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (softReduceMotion(context)) {
      p.jumpTo(target);
      return;
    }
    _spring
      ..snapTo(p.pixels)
      ..animateTo(target, SoftChipTabDefaults.scrollSpring, threshold: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: SoftChipTabDefaults.groupSpacing,
      children: <Widget>[
        for (int i = 0; i < widget.tabs.length; i++)
          SoftChipTab(
            key: _keys[i],
            label: widget.tabs[i].label,
            icon: widget.tabs[i].icon,
            enabled: widget.tabs[i].enabled,
            showRedDot: widget.tabs[i].showRedDot,
            count: widget.tabs[i].count,
            selected: i == widget.selectedIndex,
            onTap: () => widget.onSelectedChange(i),
          ),
      ],
    );
    final Widget scroller = NotificationListener<ScrollMetricsNotification>(
      onNotification: (ScrollMetricsNotification n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _spring.stop();
          }
          return _onMetrics(n.metrics);
        },
        child: SingleChildScrollView(
          key: _viewport,
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: row,
        ),
      ),
    );
    return ValueListenableBuilder<(bool, bool)>(
      valueListenable: _edges,
      builder: (BuildContext context, (bool, bool) edges, Widget? child) =>
          _EdgeFade(left: edges.$1, right: edges.$2, child: child),
      child: scroller,
    );
  }
}

/// Fades the edges of its child out over [SoftChipTabDefaults.fadeWidth] —
/// a mask layer only while an edge is faded.
class _EdgeFade extends SingleChildRenderObjectWidget {
  const _EdgeFade({required this.left, required this.right, super.child});

  final bool left;
  final bool right;

  @override
  _RenderEdgeFade createRenderObject(BuildContext context) =>
      _RenderEdgeFade(left: left, right: right);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeFade renderObject) {
    renderObject
      ..left = left
      ..right = right;
  }
}

class _RenderEdgeFade extends RenderProxyBox {
  _RenderEdgeFade({required bool left, required bool right})
    : _left = left,
      _right = right;

  bool _left;
  set left(bool v) {
    if (v == _left) return;
    _left = v;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  bool _right;
  set right(bool v) {
    if (v == _right) return;
    _right = v;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  bool get _fading => _left || _right;

  @override
  bool get alwaysNeedsCompositing => child != null && _fading;

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? box = child;
    if (box == null) return;
    if (!_fading || size.isEmpty) {
      layer = null;
      context.paintChild(box, offset);
      return;
    }
    final double fade = math.min(SoftChipTabDefaults.fadeWidth, size.width / 2);
    final double l = fade / size.width;
    const Color opaque = Color(0xFFFFFFFF);
    const Color clear = Color(0x00FFFFFF);
    final ShaderMaskLayer mask =
        (layer as ShaderMaskLayer?) ?? ShaderMaskLayer();
    mask
      ..shader = LinearGradient(
        colors: <Color>[
          _left ? clear : opaque,
          opaque,
          opaque,
          _right ? clear : opaque,
        ],
        stops: <double>[0, l, 1 - l, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    layer = mask;
    context.pushLayer(mask, super.paint, offset);
  }
}
