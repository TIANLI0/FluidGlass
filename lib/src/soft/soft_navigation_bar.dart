import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_badge.dart';
import 'soft_frosted.dart';
import 'soft_motion.dart';
import 'soft_theme.dart';

/// One destination of a [SoftNavigationBar].
@immutable
class SoftNavigationItem {
  const SoftNavigationItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge = 0,
    this.semanticLabel,
  });

  final IconData icon;

  /// Drawn when selected — a filled or heavier glyph. Falls back to [icon].
  final IconData? selectedIcon;
  final String label;

  /// Unread count shown on the icon; 0 shows none, negative shows a dot.
  final int badge;

  /// Read out instead of [label] (for example with the unread count in it).
  final String? semanticLabel;
}

/// A floating bottom navigation bar: a capsule sized to its items, centred,
/// over a translucent blur of the page.
///
/// Geometry: a 56-high capsule holding 48-high items with 4 all round, so the
/// selection mask and the panel are concentric. Each item is its content (the
/// wider of icon and label) plus 12 a side, at least 48 and at most 70 (the
/// cap grows with the text scale), with 8 between items.
///
/// Motion: the selection mask slides and resizes on a spring that swings over
/// and settles; labels and icons cross-fade between 90% and 72% opacity, the
/// selected icon switching to [SoftNavigationItem.selectedIcon]; a press
/// sinks the whole bar to 0.97 and lets it spring back, leans it a little
/// towards the finger, and lights a soft glow under it. Holding and sliding
/// moves the mask from item to item; lifting there selects it, lifting far
/// off the bar cancels.
class SoftNavigationBar extends StatefulWidget {
  const SoftNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.lowEnd = false,
  }) : assert(items.length > 0, 'A navigation bar needs items.');

  final List<SoftNavigationItem> items;
  final int selectedIndex;

  /// The item tapped — reported for the selected one too, so the caller can
  /// treat a second tap as "back to top".
  final ValueChanged<int> onSelected;

  /// Use the shorter, calmer selection spring.
  final bool lowEnd;

  static const double height = 56;
  static const double _inset = 4;
  static const double _itemGap = 8;
  static const double _itemPadding = 12;
  static const double _itemMinWidth = 48;
  static const double _itemMaxWidth = 70;
  static const double _iconSize = 24;
  static const double _iconLabelGap = 2;
  static const double _labelSize = 10;
  static const double _pressedScale = 0.97;
  static const double _followStrength = 0.3;
  static const double _followMax = 8;
  static const double _glowRadius = 40;
  static const double _glowCenterAlpha = 0.15;
  static const double _cancelSlop = 32;

  /// The bar's height at the current text scale.
  static double extent(BuildContext context) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: 'Ag设',
        style: SoftTheme.of(context).text(_labelSize, weight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double needed =
        _inset * 2 + 4 * 2 + _iconSize + _iconLabelGap + painter.height;
    painter.dispose();
    return math.max(needed, height);
  }

  @override
  State<SoftNavigationBar> createState() => _SoftNavigationBarState();
}

class _SoftNavigationBarState extends State<SoftNavigationBar>
    with TickerProviderStateMixin {
  late final AnimationController _maskLeft = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _maskWidth = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _follow = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: SoftMotion.fadeDuration,
  );
  Offset _glowAt = Offset.zero;

  int? _pending;
  int? _pointer;
  Offset _downAt = Offset.zero;
  List<double> _lefts = const <double>[];
  List<double> _widths = const <double>[];
  Size _panel = Size.zero;
  bool _placed = false;

  bool get _reduce => softReduceMotion(context);

  SpringDescription get _selectSpring =>
      widget.lowEnd ? SoftMotion.selectLowEnd : SoftMotion.select;

  @override
  void dispose() {
    _maskLeft.dispose();
    _maskWidth.dispose();
    _scale.dispose();
    _follow.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SoftNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex && _pending == null) {
      _moveMaskTo(widget.selectedIndex);
    }
  }

  void _moveMaskTo(int index) {
    if (index < 0 || index >= _lefts.length) return;
    _maskLeft.springTo(_lefts[index], _selectSpring, reduceMotion: _reduce);
    _maskWidth.springTo(_widths[index], _selectSpring, reduceMotion: _reduce);
  }

  void _syncLayout(List<double> lefts, List<double> widths, Size panel) {
    bool same(List<double> a, List<double> b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if ((a[i] - b[i]).abs() > 0.01) return false;
      }
      return true;
    }

    final bool changed =
        panel != _panel || !same(lefts, _lefts) || !same(widths, _widths);
    _lefts = lefts;
    _widths = widths;
    _panel = panel;
    if (!changed && _placed) return;
    final int index = _pending ?? widget.selectedIndex;
    if (index < 0 || index >= lefts.length) return;
    if (!_placed || !_maskLeft.isAnimating) {
      _maskLeft.value = lefts[index];
      _maskWidth.value = widths[index];
    }
    _placed = true;
  }

  int _indexAt(double x) {
    int best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < _lefts.length; i++) {
      final double distance = (x - (_lefts[i] + _widths[i] / 2)).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  bool _withinReach(Offset local) => (Offset.zero & _panel)
      .inflate(SoftNavigationBar._cancelSlop)
      .contains(local);

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downAt = event.localPosition;
    _pending = _indexAt(event.localPosition.dx);
    _moveMaskTo(_pending!);
    if (!_reduce) {
      _scale.springTo(SoftNavigationBar._pressedScale, SoftMotion.press);
      _glowAt = event.localPosition;
      _glow.forward();
    }
    setState(() {});
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final Offset local = event.localPosition;
    if (!_reduce) {
      final double raw =
          (local.dx - _downAt.dx) * SoftNavigationBar._followStrength;
      _follow.value =
          SoftNavigationBar._followMax *
          raw /
          (SoftNavigationBar._followMax + raw.abs());
      _glowAt = local;
    }
    final int next = _withinReach(local)
        ? _indexAt(local.dx)
        : widget.selectedIndex;
    setState(() => _pending = next);
    _moveMaskTo(next);
  }

  void _release({required bool commit, Offset? at}) {
    _pointer = null;
    final int? pending = _pending;
    _pending = null;
    _scale.springTo(1, SoftMotion.release, reduceMotion: _reduce);
    _follow.springTo(0, SoftMotion.release, reduceMotion: _reduce);
    _glow.reverse();
    setState(() {});
    if (commit && at != null && _withinReach(at) && pending != null) {
      widget.onSelected(pending);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pending == null) _moveMaskTo(widget.selectedIndex);
      });
      return;
    }
    _moveMaskTo(widget.selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final double maxItem = math.max(
      SoftNavigationBar._itemMaxWidth,
      SoftNavigationBar._itemMaxWidth * scale,
    );
    final TextStyle labelStyle = theme.text(
      SoftNavigationBar._labelSize,
      weight: FontWeight.w500,
    );

    final List<double> natural = <double>[
      for (final SoftNavigationItem item in widget.items)
        (math.max(
                  SoftNavigationBar._iconSize,
                  _labelWidth(context, item.label, labelStyle),
                ) +
                SoftNavigationBar._itemPadding * 2)
            .clamp(SoftNavigationBar._itemMinWidth, maxItem),
    ];
    final double gaps = SoftNavigationBar._itemGap * (natural.length - 1);
    final double naturalWidth =
        natural.fold<double>(0, (double a, double b) => a + b) +
        gaps +
        SoftNavigationBar._inset * 2;
    final double available = MediaQuery.sizeOf(context).width - 32;
    final double width = available > 0
        ? math.min(naturalWidth, available)
        : naturalWidth;
    final double room = width - SoftNavigationBar._inset * 2 - gaps;
    final double sum = natural.fold<double>(0, (double a, double b) => a + b);
    final double squeeze = sum > room && sum > 0 ? room / sum : 1.0;
    final List<double> widths = <double>[
      for (final double w in natural) w * squeeze,
    ];
    final List<double> lefts = <double>[];
    double x = SoftNavigationBar._inset;
    for (final double w in widths) {
      lefts.add(x);
      x += w + SoftNavigationBar._itemGap;
    }
    final double height = SoftNavigationBar.extent(context);
    _syncLayout(lefts, widths, Size(width, height));

    final double itemHeight = height - SoftNavigationBar._inset * 2;
    final int shown = _pending ?? widget.selectedIndex;
    final Duration fade = _reduce ? Duration.zero : SoftMotion.fadeDuration;

    final Widget panel = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (PointerUpEvent e) {
        if (e.pointer == _pointer) _release(commit: true, at: e.localPosition);
      },
      onPointerCancel: (PointerCancelEvent e) {
        if (e.pointer == _pointer) _release(commit: false);
      },
      child: SizedBox(
        width: width,
        height: height,
        child: SoftFrosted(
          shape: const StadiumBorder(),
          tint: theme.frostTint,
          sigma: theme.frostSigma,
          shadows: <BoxShadow>[
            BoxShadow(
              color: theme.shadow,
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
          border: BorderSide(color: theme.divider, width: 0.5),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  _maskLeft,
                  _maskWidth,
                ]),
                builder: (BuildContext context, _) => Positioned(
                  left: _maskLeft.value,
                  top: SoftNavigationBar._inset,
                  width: math.max(0, _maskWidth.value),
                  height: itemHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: theme.pressBackground,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (BuildContext context, _) => CustomPaint(
                      painter: _GlowPainter(
                        center: _glowAt,
                        opacity: Curves.easeOut.transform(_glow.value),
                      ),
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < widget.items.length; i++)
                Positioned(
                  left: lefts[i],
                  top: SoftNavigationBar._inset,
                  width: widths[i],
                  height: itemHeight,
                  child: _Item(
                    item: widget.items[i],
                    selected: i == shown,
                    realSelected: i == widget.selectedIndex,
                    labelStyle: labelStyle,
                    selectedColor: theme.labelPrimary,
                    unselectedColor: theme.labelPrimaryVariant,
                    fade: fade,
                    onActivate: () => widget.onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_scale, _follow]),
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(_follow.value, 0),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: panel,
    );
  }
}

double _labelWidth(BuildContext context, String label, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.selected,
    required this.realSelected,
    required this.labelStyle,
    required this.selectedColor,
    required this.unselectedColor,
    required this.fade,
    required this.onActivate,
  });

  final SoftNavigationItem item;
  final bool selected;
  final bool realSelected;
  final TextStyle labelStyle;
  final Color selectedColor;
  final Color unselectedColor;
  final Duration fade;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? selectedColor : unselectedColor;
    return Semantics(
      container: true,
      button: true,
      selected: realSelected,
      inMutuallyExclusiveGroup: true,
      label: item.semanticLabel ?? item.label,
      onTap: onActivate,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SoftBadge(
                count: item.badge,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: fade,
                  curve: Curves.easeOut,
                  builder: (BuildContext context, Color? value, _) => Icon(
                    selected ? (item.selectedIcon ?? item.icon) : item.icon,
                    size: SoftNavigationBar._iconSize,
                    color: value,
                  ),
                ),
              ),
              const SizedBox(height: SoftNavigationBar._iconLabelGap),
              AnimatedDefaultTextStyle(
                duration: fade,
                curve: Curves.easeOut,
                style: labelStyle.copyWith(color: color),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.center, required this.opacity});

  final Offset center;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ),
    );
    final double alpha = SoftNavigationBar._glowCenterAlpha * opacity;
    canvas.drawCircle(
      center,
      SoftNavigationBar._glowRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: alpha),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: center,
                radius: SoftNavigationBar._glowRadius,
              ),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.opacity != opacity;
}
