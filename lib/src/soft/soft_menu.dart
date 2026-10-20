import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_frosted.dart';
import 'soft_motion.dart';
import 'soft_theme.dart';

/// One row of a [showSoftMenu].
@immutable
class SoftMenuItem<T> {
  const SoftMenuItem({
    required this.label,
    required this.value,
    this.icon,
    this.description,
    this.destructive = false,
    this.checked = false,
    this.enabled = true,
  });

  final String label;
  final T value;
  final IconData? icon;
  final String? description;

  /// Drawn in the error colour.
  final bool destructive;

  /// A check mark at the end (a select's current choice).
  final bool checked;
  final bool enabled;
}

/// Opens a popup menu next to [anchor] (the widget's box) and returns the
/// chosen item's value, or null when dismissed.
///
/// A translucent, blurred card, 24 corners, 168–256 wide, 8 from the anchor:
/// below it when there is room, above otherwise. Rows are at least 40 high,
/// 16 regular text with 20 either side. It flies out of the anchor's edge —
/// scale from 0 with a slight overshoot (0.4, 0.2), a drift along the way
/// (0.29, 0.13), a fade (0.27) — and folds back on stiffer springs. A finger
/// can press, slide from row to row (a highlight pill follows, inset 8) and
/// lift on the one it wants.
Future<T?> showSoftMenu<T>(
  BuildContext anchor, {
  required List<SoftMenuItem<T>> items,
}) {
  final RenderBox box = anchor.findRenderObject()! as RenderBox;
  final Rect rect = box.localToGlobal(Offset.zero) & box.size;
  final SoftThemeData theme = SoftTheme.of(anchor);
  return Navigator.of(anchor, rootNavigator: true).push<T>(
    _MenuRoute<T>(
      theme: theme,
      anchor: rect,
      items: items,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    ),
  );
}

class _MenuRoute<T> extends PopupRoute<T> {
  _MenuRoute({
    required this.theme,
    required this.anchor,
    required this.items,
    required this.barrierLabel,
  });

  final SoftThemeData theme;
  final Rect anchor;
  final List<SoftMenuItem<T>> items;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SoftTheme(
    data: theme,
    child: _Menu<T>(anchor: anchor, items: items),
  );
}

class _Menu<T> extends StatefulWidget {
  const _Menu({required this.anchor, required this.items});

  final Rect anchor;
  final List<SoftMenuItem<T>> items;

  @override
  State<_Menu<T>> createState() => _MenuState<T>();
}

class _MenuState<T> extends State<_Menu<T>> with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _alpha = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _path = AnimationController.unbounded(
    vsync: this,
  );

  /// The highlight pill's top, and its height.
  late final AnimationController _maskTop = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _maskHeight = AnimationController.unbounded(
    vsync: this,
  );
  int? _highlighted;
  final List<GlobalKey> _rowKeys = <GlobalKey>[];
  final GlobalKey _listKey = GlobalKey();
  bool _closing = false;

  bool get _reduce => softReduceMotion(context);

  @override
  void initState() {
    super.initState();
    _rowKeys.addAll(
      List<GlobalKey>.generate(widget.items.length, (_) => GlobalKey()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scale.springTo(1, softSpring(0.4, bounce: 0.2), reduceMotion: _reduce);
      _alpha.springTo(1, softSpring(0.27), reduceMotion: _reduce);
      _path.springTo(1, softSpring(0.29, bounce: 0.13), reduceMotion: _reduce);
    });
  }

  @override
  void dispose() {
    _scale.dispose();
    _alpha.dispose();
    _path.dispose();
    _maskTop.dispose();
    _maskHeight.dispose();
    super.dispose();
  }

  Future<void> _close([T? value]) async {
    if (_closing) return;
    _closing = true;
    _alpha.springTo(0, softSpring(0.23), reduceMotion: _reduce);
    _path.springTo(0, softSpring(0.26), reduceMotion: _reduce);
    await _scale.springTo(0, softSpring(0.21), reduceMotion: _reduce);
    if (mounted) Navigator.of(context).pop(value);
  }

  int? _rowAt(Offset global) {
    for (int i = 0; i < _rowKeys.length; i++) {
      final RenderBox? row =
          _rowKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final Rect rect = row.localToGlobal(Offset.zero) & row.size;
      if (rect.contains(global)) return i;
    }
    return null;
  }

  void _highlight(int? index) {
    if (index == _highlighted) return;
    _highlighted = index;
    if (index == null || !widget.items[index].enabled) {
      _highlighted = null;
      setState(() {});
      return;
    }
    final RenderBox? row =
        _rowKeys[index].currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? list =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || list == null) return;
    final double top = row.localToGlobal(Offset.zero, ancestor: list).dy;
    final bool first = _maskHeight.value == 0;
    if (first || _reduce) {
      _maskTop.value = top;
      _maskHeight.value = row.size.height;
    } else {
      _maskTop.springTo(top, softSpring(0.15));
      _maskHeight.springTo(row.size.height, softSpring(0.15));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final Size screen = media.size;
    final bool icons = widget.items.any((SoftMenuItem<T> i) => i.icon != null);
    final TextStyle labelStyle = theme.text(16, height: 1.3);

    double widest = 0;
    for (final SoftMenuItem<T> item in widget.items) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: item.label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final double width =
        (widest +
                40 +
                (icons ? 32 : 0) +
                (widget.items.any((SoftMenuItem<T> i) => i.checked) ? 28 : 0))
            .clamp(icons ? 196.0 : 168.0, 256.0);
    final Rect anchor = widget.anchor;
    final double below =
        screen.height - media.viewPadding.bottom - anchor.bottom - 8 - 16;
    final double above = anchor.top - media.viewPadding.top - 8 - 12;
    final bool down = below >= above || below > 240;
    final double left = (anchor.left).clamp(
      16.0,
      math.max(16.0, screen.width - 16 - width),
    );
    final Alignment pivot = Alignment(
      ((anchor.center.dx - left) / width * 2 - 1).clamp(-1.0, 1.0),
      down ? -1 : 1,
    );

    final Widget card = SizedBox(
      width: width,
      child: SoftFrosted(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        tint: theme.backgroundElevated.withValues(
          alpha: theme.isDark ? 0.76 : 0.82,
        ),
        sigma: 30,
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.4 : 0.14),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: down ? below : above),
            child: Listener(
              onPointerDown: (PointerDownEvent e) =>
                  _highlight(_rowAt(e.position)),
              onPointerMove: (PointerMoveEvent e) =>
                  _highlight(_rowAt(e.position)),
              onPointerUp: (PointerUpEvent e) {
                final int? index = _rowAt(e.position);
                _highlight(null);
                if (index != null && widget.items[index].enabled) {
                  _close(widget.items[index].value);
                }
              },
              onPointerCancel: (_) => _highlight(null),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  key: _listKey,
                  children: <Widget>[
                    if (_highlighted != null)
                      AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[
                          _maskTop,
                          _maskHeight,
                        ]),
                        builder: (BuildContext context, _) => Positioned(
                          left: 8,
                          right: 8,
                          top: _maskTop.value,
                          height: _maskHeight.value,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: theme.pressBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int i = 0; i < widget.items.length; i++)
                          _row(theme, widget.items[i], _rowKeys[i], labelStyle),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, T? result) {
        if (!didPop) _close();
      },
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: left,
            top: down ? anchor.bottom + 8 : null,
            bottom: down ? null : screen.height - anchor.top + 8,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_scale, _alpha, _path]),
              builder: (BuildContext context, Widget? child) => Opacity(
                opacity: _alpha.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - _path.value) * (down ? -12 : 12)),
                  child: Transform.scale(
                    scale: math.max(0, _scale.value),
                    alignment: pivot,
                    child: child,
                  ),
                ),
              ),
              child: card,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    SoftThemeData theme,
    SoftMenuItem<T> item,
    GlobalKey key,
    TextStyle labelStyle,
  ) {
    final Color color = !item.enabled
        ? theme.labelTertiary
        : item.destructive
        ? theme.error
        : theme.labelPrimary;
    return Semantics(
      key: key,
      button: true,
      enabled: item.enabled,
      selected: item.checked,
      onTap: item.enabled ? () => _close(item.value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: <Widget>[
              if (item.icon != null) ...<Widget>[
                Icon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.label,
                      maxLines: item.description == null ? 3 : 2,
                      style: labelStyle.copyWith(color: color),
                    ),
                    if (item.description != null)
                      Text(
                        item.description!,
                        maxLines: 2,
                        style: theme.text(12, color: theme.labelSecondary),
                      ),
                  ],
                ),
              ),
              if (item.checked) ...<Widget>[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 20, color: theme.accentText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact select: the current choice and a down chevron; tapping it opens
/// a [showSoftMenu] under it with the choice checked.
class SoftSelect<T> extends StatelessWidget {
  const SoftSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = '',
  });

  final T? value;

  /// Value → label, in order.
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    String label = placeholder;
    for (final (T v, String l) in options) {
      if (v == value) label = l;
    }
    final bool enabled = onChanged != null;
    return Builder(
      builder: (BuildContext anchor) => Semantics(
        button: true,
        enabled: enabled,
        value: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !enabled
              ? null
              : () async {
                  final T? chosen = await showSoftMenu<T>(
                    anchor,
                    items: <SoftMenuItem<T>>[
                      for (final (T v, String l) in options)
                        SoftMenuItem<T>(
                          label: l,
                          value: v,
                          checked: v == value,
                        ),
                    ],
                  );
                  if (chosen != null) onChanged?.call(chosen);
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text(
                    13,
                    color: enabled ? theme.labelSecondary : theme.labelTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.unfold_more_rounded,
                size: 16,
                color: enabled ? theme.labelTertiary : theme.labelQuaternary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
