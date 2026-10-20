import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// A group of list rows on one card: 16 from the screen edges, 20 corners,
/// with an optional header above it.
///
/// Rows inside get hairline dividers that start where the row's title starts
/// (after its icon) and end where its content ends; the first row gets 2 extra
/// above it and the last 2 extra below. A pressed row is masked, clipped to
/// the card's corners.
class SoftListGroup extends StatelessWidget {
  const SoftListGroup({super.key, this.header, required this.children});

  /// A 12 medium secondary heading above the card.
  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(
        _RowPosition(
          first: i == 0,
          last: i == children.length - 1,
          child: children[i],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16 + 8, 32, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 16),
              child: Text(
                header!,
                style: theme.text(
                  12,
                  weight: FontWeight.w500,
                  color: theme.labelSecondary,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: theme.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: rows,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowPosition extends InheritedWidget {
  const _RowPosition({
    required this.first,
    required this.last,
    required super.child,
  });

  final bool first;
  final bool last;

  static _RowPosition? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowPosition>();

  @override
  bool updateShouldNotify(_RowPosition old) =>
      old.first != first || old.last != last;
}

/// A list row: an optional leading [icon], a 16 medium [title] with an
/// optional 13 secondary [summary] under it, and on the end a 13 secondary
/// [value], a [trailing] widget (a switch) and/or a chevron.
///
/// At least 48 high (a two-line row about 60). Content sits 16 inside the card
/// (32 from the screen). Pressing lays a mask over the row on a (0.3, 0)
/// spring; a quick tap still shows it most of the way.
class SoftListTile extends StatefulWidget {
  const SoftListTile({
    super.key,
    required this.title,
    this.summary,
    this.icon,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? summary;
  final Widget? icon;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<SoftListTile> createState() => _SoftListTileState();
}

class _SoftListTileState extends State<SoftListTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mask = AnimationController.unbounded(
    vsync: this,
  );
  static final SpringDescription _spring = softSpring(0.3);

  @override
  void dispose() {
    _mask.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.onTap == null || !widget.enabled) return;
    _mask.springTo(1, _spring, reduceMotion: softReduceMotion(context));
  }

  void _up() {
    // A quick tap still shows the mask most of the way before it fades.
    final double from = _mask.value;
    if (from < 0.7 && !softReduceMotion(context)) {
      _mask.springTo(0.7, softSpring(0.12)).whenComplete(() {
        if (mounted) _mask.springTo(0, _spring);
      });
      return;
    }
    _mask.springTo(0, _spring, reduceMotion: softReduceMotion(context));
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final _RowPosition? position = _RowPosition.of(context);
    final bool first = position?.first ?? true;
    final bool last = position?.last ?? true;
    final bool enabled = widget.enabled;
    final Widget? icon = widget.icon;
    final Widget row = Padding(
      padding: EdgeInsets.only(top: first ? 2 : 0, bottom: last ? 2 : 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(size: 24, color: theme.labelPrimary),
                  child: icon,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.title,
                              style: theme.text(
                                16,
                                weight: FontWeight.w500,
                                color: enabled
                                    ? theme.labelPrimary
                                    : theme.labelTertiary,
                              ),
                            ),
                            if (widget.summary != null)
                              Text(
                                widget.summary!,
                                style: theme.text(
                                  13,
                                  color: enabled
                                      ? theme.labelSecondary
                                      : theme.labelTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.value != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 162),
                            child: Text(
                              widget.value!,
                              maxLines: 2,
                              textAlign: TextAlign.end,
                              style: theme.text(
                                13,
                                color: theme.labelSecondary,
                              ),
                            ),
                          ),
                        ),
                      if (widget.trailing != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: widget.trailing,
                        ),
                      if (widget.chevron)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
                          child: SoftChevron(
                            color: enabled
                                ? theme.labelTertiary
                                : theme.labelQuaternary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      enabled: enabled,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          onTapCancel: _up,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _mask,
                  builder: (BuildContext context, _) {
                    final double t = _mask.value.clamp(0.0, 1.0);
                    return ColoredBox(
                      color: theme.press.withValues(alpha: theme.press.a * t),
                    );
                  },
                ),
              ),
              row,
              if (!last)
                PositionedDirectional(
                  start: 16 + (icon == null ? 0 : 24 + 16),
                  end: 16,
                  bottom: 0,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DividerPainter(theme.divider),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final double h = (0.33 * dpr).roundToDouble().clamp(1.0, 4.0) / dpr;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - h, size.width, h),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.color != color;
}

/// The list chevron: a 12 × 24 stroked arrow, 1.4 wide.
class SoftChevron extends StatelessWidget {
  const SoftChevron({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: rtl,
      child: CustomPaint(
        size: const Size(12, 24),
        painter: _ChevronPainter(color),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(5, 6)
      ..lineTo(10.646, 11.646)
      ..cubicTo(10.842, 11.842, 10.842, 12.158, 10.646, 12.354)
      ..lineTo(5, 18);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
