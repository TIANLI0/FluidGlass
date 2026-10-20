import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_card.dart';

/// The list-row defaults.
abstract final class SoftBasicComponentDefaults {
  /// The minimum height before any group-position padding.
  static const double minHeight = 48;

  /// 16 horizontal, 10 vertical.
  static const EdgeInsets insideMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );

  /// The gap between the title and the summary.
  static const double marginBetweenLine = 2;
}

/// The basic list row every preference is built from: an optional [start]
/// widget, a [title] (16 medium) over a [summary] (14), [end] widgets on the
/// end side, and an optional [bottom] widget below.
///
/// The end side gets at most 60 % of what is left after [start], and the
/// title column takes the rest; all three are centred vertically. Tappable
/// rows lay the theme's state layer over themselves while pressed.
class SoftBasicComponent extends StatelessWidget {
  const SoftBasicComponent({
    super.key,
    this.title,
    this.summary,
    this.titleColor,
    this.summaryColor,
    this.start,
    this.end,
    this.bottom,
    this.content,
    this.insideMargin = SoftBasicComponentDefaults.insideMargin,
    this.position = SoftCardListPosition.none,
    this.onTap,
    this.onLongPress,
    this.holdDown = false,
    this.enabled = true,
  });

  final String? title;
  final String? summary;

  /// Overrides the title colour (enabled state).
  final Color? titleColor;

  /// Overrides the summary colour (enabled state).
  final Color? summaryColor;
  final Widget? start;

  /// The end-side widgets, laid out in a row and centred vertically.
  final List<Widget>? end;
  final Widget? bottom;

  /// Replaces the title/summary column.
  final Widget? content;
  final EdgeInsets insideMargin;
  final SoftCardListPosition position;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Keeps the row pressed (its popup is open).
  final bool holdDown;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors c = theme.colors;
    Widget? centre = content;
    if (centre == null) {
      final String? t = title;
      final String? s = summary;
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (t != null)
            Text(
              t,
              style: theme.textStyles.headline1.copyWith(
                fontWeight: FontWeight.w500,
                color: enabled
                    ? (titleColor ?? c.onBackground)
                    : c.disabledOnSecondaryVariant,
              ),
            ),
          if (s != null)
            Padding(
              padding: EdgeInsets.only(
                top: t != null
                    ? SoftBasicComponentDefaults.marginBetweenLine
                    : 0,
              ),
              child: Text(
                s,
                style: theme.textStyles.body2.copyWith(
                  color: enabled
                      ? (summaryColor ?? c.onSurfaceVariantSummary)
                      : c.disabledOnSecondaryVariant,
                ),
              ),
            ),
        ],
      );
    }
    final List<Widget>? endWidgets = end;
    Widget row;
    if (start == null && endWidgets == null) {
      row = Align(alignment: AlignmentDirectional.centerStart, child: centre);
    } else {
      row = _BasicRow(
        start: start,
        centre: centre,
        end: endWidgets == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final Widget w in endWidgets) Flexible(child: w),
                ],
              ),
      );
    }
    Widget body = Padding(
      padding:
          insideMargin.add(
                EdgeInsets.only(
                  top: position.extraTop,
                  bottom: position.extraBottom,
                ),
              )
              as EdgeInsets,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row,
          if (bottom != null) ...<Widget>[const SizedBox(height: 8), bottom!],
        ],
      ),
    );
    body = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            SoftBasicComponentDefaults.minHeight +
            position.extraTop +
            position.extraBottom,
        minWidth: double.infinity,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: body,
      ),
    );
    if (onTap == null && onLongPress == null && !holdDown) return body;
    return SoftPressable(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      holdDown: holdDown,
      enabled: enabled,
      child: body,
    );
  }
}

class _BasicRow extends MultiChildRenderObjectWidget {
  _BasicRow({
    required Widget? start,
    required Widget centre,
    required Widget? end,
  }) : _hasStart = start != null,
       _hasEnd = end != null,
       super(children: <Widget>[?start, centre, ?end]);

  final bool _hasStart;
  final bool _hasEnd;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBasicRow(
    hasStart: _hasStart,
    hasEnd: _hasEnd,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderBasicRow renderObject) {
    renderObject
      ..hasStart = _hasStart
      ..hasEnd = _hasEnd
      ..textDirection = Directionality.of(context);
  }
}

class _BasicRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBasicRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BasicRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BasicRowParentData> {
  _RenderBasicRow({
    required bool hasStart,
    required bool hasEnd,
    required TextDirection textDirection,
  }) : _hasStart = hasStart,
       _hasEnd = hasEnd,
       _textDirection = textDirection;

  static const double _spacer = 8;

  bool _hasStart;
  set hasStart(bool v) {
    if (v == _hasStart) return;
    _hasStart = v;
    markNeedsLayout();
  }

  bool _hasEnd;
  set hasEnd(bool v) {
    if (v == _hasEnd) return;
    _hasEnd = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BasicRowParentData) {
      child.parentData = _BasicRowParentData();
    }
  }

  RenderBox? get _start => _hasStart ? firstChild : null;
  RenderBox get _centre => _hasStart ? childAfter(firstChild!)! : firstChild!;
  RenderBox? get _end => _hasEnd ? lastChild : null;

  @override
  double computeMinIntrinsicHeight(double width) => _maxHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _maxHeight(width);

  double _maxHeight(double width) {
    double h = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      h = math.max(h, child.getMaxIntrinsicHeight(width));
      child = childAfter(child);
    }
    return h;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double w = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      w += child.getMaxIntrinsicWidth(height);
      child = childAfter(child);
    }
    return w + (childCount - 1) * _spacer;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  void performLayout() {
    final double maxWidth = constraints.maxWidth;
    final BoxConstraints loose = BoxConstraints(maxWidth: maxWidth);
    final RenderBox? start = _start;
    final RenderBox centre = _centre;
    final RenderBox? end = _end;
    double startWidth = 0;
    if (start != null) {
      start.layout(loose, parentUsesSize: true);
      startWidth = start.size.width;
    }
    final double startSpacer = startWidth > 0 ? _spacer : 0;
    final double afterStart = math.max(0, maxWidth - startWidth - startSpacer);
    double endWidth = 0;
    if (end != null) {
      // The end side takes what it needs, up to 60 % of what is left.
      final double cap = math.max(0, afterStart - _spacer) * 6 / 10;
      end.layout(BoxConstraints(maxWidth: cap), parentUsesSize: true);
      endWidth = end.size.width;
    }
    final double endSpacer = endWidth > 0 ? _spacer : 0;
    final double forCentre = math.max(0, afterStart - endWidth - endSpacer);
    centre.layout(BoxConstraints(maxWidth: forCentre), parentUsesSize: true);
    final double rowHeight = math.max(
      math.max(start?.size.height ?? 0, centre.size.height),
      end?.size.height ?? 0,
    );
    size = constraints.constrain(Size(maxWidth, rowHeight));
    final bool rtl = _textDirection == TextDirection.rtl;
    double x(double left, double w) => rtl ? size.width - left - w : left;
    if (start != null) {
      (start.parentData! as _BasicRowParentData).offset = Offset(
        x(0, start.size.width),
        (rowHeight - start.size.height) / 2,
      );
    }
    (centre.parentData! as _BasicRowParentData).offset = Offset(
      x(startWidth + startSpacer, centre.size.width),
      (rowHeight - centre.size.height) / 2,
    );
    if (end != null) {
      (end.parentData! as _BasicRowParentData).offset = Offset(
        x(maxWidth - end.size.width, end.size.width),
        (rowHeight - end.size.height) / 2,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A category title above a card: 12 medium, 32 from the screen edges, 8
/// above and below.
class SoftSmallTitle extends StatelessWidget {
  const SoftSmallTitle(
    this.text, {
    super.key,
    this.color,
    this.insideMargin = const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
  });

  final String text;
  final Color? color;
  final EdgeInsets insideMargin;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Padding(
      padding: insideMargin,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            text,
            style: theme.textStyles.subtitle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? theme.colors.onBackgroundVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The divider defaults.
abstract final class SoftDividerDefaults {
  /// 0.33 thick.
  static const double thickness = 0.33;

  /// The inset of a divider between rows inside a card.
  static const double cardInset = 32;
}

/// A horizontal hairline, 0.33 thick, in the theme's `dividerLine`.
///
/// Between rows inside a [SoftCard], inset it 16 on both sides (or align its
/// start with the title of a row that has a leading icon).
class SoftDivider extends StatelessWidget {
  const SoftDivider({
    super.key,
    this.thickness = SoftDividerDefaults.thickness,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double thickness;
  final Color? color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? SoftTheme.of(context).colors.dividerLine;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: SizedBox(
        height: thickness,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(c)),
      ),
    );
  }
}

/// A vertical hairline.
class SoftVerticalDivider extends StatelessWidget {
  const SoftVerticalDivider({
    super.key,
    this.thickness = SoftDividerDefaults.thickness,
    this.color,
  });

  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? SoftTheme.of(context).colors.dividerLine;
    return SizedBox(
      width: thickness,
      height: double.infinity,
      child: CustomPaint(painter: _LinePainter(c)),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color;
}
