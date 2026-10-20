import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// The back arrow: 24, a 1.4 stroke with round ends.
class SoftBackIcon extends StatelessWidget {
  const SoftBackIcon({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? SoftTheme.of(context).labelPrimary;
    return Transform.flip(
      flipX: Directionality.of(context) == TextDirection.rtl,
      child: CustomPaint(size: const Size.square(24), painter: _BackPainter(c)),
    );
  }
}

class _BackPainter extends CustomPainter {
  const _BackPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(10.1, 4.4)
        ..lineTo(2.5, 12)
        ..lineTo(10.1, 19.6)
        ..moveTo(2.5, 12)
        ..lineTo(21.5, 12.001),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackPainter old) => old.color != color;
}

/// A 48 × 40 touch target holding a 24 icon, for bar actions.
class SoftBarAction extends StatelessWidget {
  const SoftBarAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 40,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                size: 24,
                color: onPressed == null
                    ? theme.labelTertiary
                    : theme.labelPrimary,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 52 top bar: an optional back button, an 18 medium title, actions.
///
/// 16 from the edges, 4 on a side that has a button (so the back arrow sits
/// at 16). [dividerOpacity] fades in the hairline under it as content scrolls
/// beneath.
class SoftAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SoftAppBar({
    super.key,
    this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.dividerOpacity = 0,
    this.background,
  });

  final String? title;

  /// Shows the back arrow when set.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double dividerOpacity;

  /// Defaults to the page background.
  final Color? background;

  static const double height = 52;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Material(
      color: background ?? theme.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(width: onBack == null ? 16 : 4),
                  if (onBack != null)
                    SoftBarAction(
                      icon: const SoftBackIcon(),
                      onPressed: onBack,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                    ),
                  if (onBack != null) const SizedBox(width: 4),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.text(18, weight: FontWeight.w600),
                          ),
                  ),
                  if (actions.isNotEmpty) const SizedBox(width: 4),
                  ...actions,
                  SizedBox(width: actions.isEmpty ? 16 : 4),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: dividerOpacity.clamp(0.0, 1.0),
                  child: Container(height: 0.33, color: theme.divider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling page under a large title: 110 high with a 32 semibold title at
/// rest, collapsing as the content scrolls into a 52 bar whose 18 title the
/// large one shrinks into. Let go half way and it settles open or closed. A
/// hairline fades in (and widens from the middle) as it collapses.
class SoftLargeTitleScaffold extends StatefulWidget {
  const SoftLargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.onBack,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> slivers;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  State<SoftLargeTitleScaffold> createState() => _SoftLargeTitleScaffoldState();
}

class _SoftLargeTitleScaffoldState extends State<SoftLargeTitleScaffold> {
  final ScrollController _scroll = ScrollController();

  static const double _expanded = 110;
  static const double _collapsed = 52;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _settle(ScrollEndNotification n) {
    const double range = _expanded - _collapsed;
    final double offset = _scroll.offset;
    if (offset > 0 && offset < range) {
      final double target = offset < range / 2 ? 0 : range;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          target,
          duration: softReduceMotion(context)
              ? const Duration(milliseconds: 1)
              : const Duration(milliseconds: 250),
          curve: SoftCurves.moveEase,
        );
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double top = MediaQuery.viewPaddingOf(context).top;
    return ColoredBox(
      color: theme.background,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _settle,
        child: CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _LargeTitleDelegate(
                title: widget.title,
                theme: theme,
                top: top,
                onBack: widget.onBack,
                actions: widget.actions,
              ),
            ),
            ...widget.slivers,
          ],
        ),
      ),
    );
  }
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _LargeTitleDelegate({
    required this.title,
    required this.theme,
    required this.top,
    required this.onBack,
    required this.actions,
  });

  final String title;
  final SoftThemeData theme;
  final double top;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  double get maxExtent => top + _SoftLargeTitleScaffoldState._expanded;

  @override
  double get minExtent => top + _SoftLargeTitleScaffoldState._collapsed;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const double range =
        _SoftLargeTitleScaffoldState._expanded -
        _SoftLargeTitleScaffoldState._collapsed;
    final double t = (shrinkOffset / range).clamp(0.0, 1.0);
    final double size = lerpDouble(32, 18, t)!;
    const FontWeight weight = FontWeight.w600;
    final double barTitleStart = onBack == null ? 16 : 4 + 48 + 4;
    final double start = lerpDouble(16, barTitleStart, t)!;
    // Expanded: the title's top at 54; collapsed: centred in the 52 bar.
    final double titleTop = lerpDouble(54, (52 - size * 1.3) / 2, t)!;
    final double dividerMargin = lerpDouble(24, 0, t)!;
    return SizedBox.expand(
      child: ColoredBox(
        color: theme.background,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: Stack(
            children: <Widget>[
              SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    if (onBack != null) ...<Widget>[
                      const SizedBox(width: 4),
                      SoftBarAction(
                        icon: const SoftBackIcon(),
                        onPressed: onBack,
                      ),
                    ],
                    const Spacer(),
                    ...actions,
                    SizedBox(width: actions.isEmpty ? 16 : 4),
                  ],
                ),
              ),
              PositionedDirectional(
                start: start,
                end: 16 + actions.length * 48,
                top: titleTop,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text(size, weight: weight, height: 1.3),
                ),
              ),
              Positioned(
                left: dividerMargin,
                right: dividerMargin,
                bottom: 0,
                child: Opacity(
                  opacity: t,
                  child: Container(height: 0.33, color: theme.divider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.title != title ||
      old.theme != theme ||
      old.top != top ||
      old.onBack != onBack ||
      old.actions != actions;
}

/// A row of text tabs, 40 high: the selected one 16 medium primary, the rest
/// 16 regular secondary, a 2 primary bar under the selected text. The bar
/// moves to a new tab in min(300, 150 + 50 × tabs crossed) ms on an ease, the
/// two labels cross-fading on the same clock. Scrolls when the tabs overflow
/// (20 between tabs, 16 from the edges). A light haptic tick on change.
class SoftTabBar extends StatefulWidget {
  const SoftTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<SoftTabBar> createState() => _SoftTabBarState();
}

class _SoftTabBarState extends State<SoftTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  final List<GlobalKey> _keys = <GlobalKey>[];
  final GlobalKey _rowKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  Rect _from = Rect.zero;
  Rect _to = Rect.zero;
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.selectedIndex;
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Rect r = _rectOf(widget.selectedIndex);
      setState(() => _from = _to = r);
    });
  }

  void _syncKeys() {
    while (_keys.length < widget.tabs.length) {
      _keys.add(GlobalKey());
    }
  }

  Rect _rectOf(int index) {
    final RenderBox? box =
        _keys[index].currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? row =
        _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || row == null) return Rect.zero;
    return box.localToGlobal(Offset.zero, ancestor: row) & box.size;
  }

  @override
  void didUpdateWidget(SoftTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _previous = oldWidget.selectedIndex;
      final double t = Curves.linear.transform(_move.value);
      _from = Rect.lerp(_from, _to, SoftCurves.ease.transform(t))!;
      _to = _rectOf(widget.selectedIndex);
      final int crossed = (widget.selectedIndex - oldWidget.selectedIndex)
          .abs();
      _move.duration = softReduceMotion(context)
          ? Duration.zero
          : Duration(milliseconds: math.min(300, 150 + 50 * crossed));
      _move.forward(from: 0);
      if (_scroll.hasClients) {
        final double target =
            (_to.center.dx - _scroll.position.viewportDimension / 2).clamp(
              0.0,
              _scroll.position.maxScrollExtent,
            );
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: SoftCurves.ease,
        );
      }
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: _move,
          builder: (BuildContext context, _) {
            final double e = SoftCurves.ease.transform(_move.value);
            final Rect bar = Rect.lerp(_from, _to, e)!;
            return Stack(
              key: _rowKey,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (int i = 0; i < widget.tabs.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 20),
                      _tab(theme, i, e),
                    ],
                  ],
                ),
                Positioned(
                  left: bar.left,
                  width: bar.width,
                  bottom: 0,
                  height: 2,
                  child: ColoredBox(color: theme.labelPrimary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tab(SoftThemeData theme, int i, double e) {
    final bool selected = i == widget.selectedIndex;
    // The two labels involved cross-fade with the bar.
    final double on = selected
        ? (_move.isAnimating ? e : 1)
        : (i == _previous && _move.isAnimating ? 1 - e : 0);
    final Color color = Color.lerp(
      theme.labelSecondary,
      theme.labelPrimary,
      on,
    )!;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i != widget.selectedIndex) HapticFeedback.selectionClick();
          widget.onSelected(i);
        },
        child: SizedBox(
          height: 40,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 128),
              child: Text(
                widget.tabs[i],
                key: _keys[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.text(
                  16,
                  weight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
