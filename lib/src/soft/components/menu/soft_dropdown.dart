import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';
import 'soft_list_popup.dart';
import 'soft_popup_list.dart';
import 'soft_popup_position.dart';

/// The dropdown row metrics.
abstract final class SoftDropdownDefaults {
  /// A row's minimum height, its vertical padding included.
  static const double itemMinHeight = 40;

  /// A row's top and bottom padding.
  static const double itemVerticalPadding = 8;

  /// A row's start and end padding.
  static const double itemHorizontalPadding = 20;

  /// The title's font size: 15, regular.
  static const double titleFontSize = 15;

  /// The widest the icon and text may get.
  static const double maxItemTextWidth = 248;

  /// The leading icon cell's minimum size.
  static const double iconMinSize = 20;

  /// The gap between the icon and the title.
  static const double iconEndPadding = 12;

  /// The selection check's size.
  static const double checkIconSize = 24;

  /// The gap before the check (and before the hint, when there is one).
  static const double checkIconStartPadding = 8;

  /// The hint slot's maximum width.
  static const double hintMaxWidth = 40;

  /// The gap between the hint and the check.
  static const double hintEndPadding = 4;

  /// The title's line limit without a summary.
  static const int titleMaxLines = 3;

  /// The title's line limit over a summary.
  static const int titleWithSummaryMaxLines = 2;

  /// The summary's line limit.
  static const int summaryMaxLines = 2;

  /// A group header's minimum height, its padding included.
  static const double headerMinHeight = 32;

  /// A group header's font size: 12 medium.
  static const double headerFontSize = 12;

  /// A group header's line limit.
  static const int headerMaxLines = 2;

  /// The up-down arrow beside a dropdown row's value.
  static const Size arrowSize = Size(14, 24);

  /// The widest a dropdown row's value text gets.
  static const double valueMaxWidth = 162;
}

/// The colours of dropdown rows.
@immutable
class SoftDropdownColors {
  const SoftDropdownColors({
    required this.content,
    required this.summary,
    required this.selectedContent,
    required this.selectedSummary,
    required this.selectedIndicator,
    required this.disabledContent,
    required this.alertContent,
    required this.header,
  });

  /// The reference colours from [colors]: titles in the label colour, the
  /// selected one and its check in the primary, disabled titles tertiary,
  /// alert titles in the error colour, summaries and headers secondary.
  factory SoftDropdownColors.of(SoftColors colors) => SoftDropdownColors(
    content: colors.onSurfaceContainer,
    summary: colors.onSurfaceSecondary,
    selectedContent: colors.primary,
    selectedSummary: colors.onSurfaceSecondary,
    selectedIndicator: colors.primary,
    disabledContent: colors.disabledOnSecondaryVariant,
    alertContent: colors.error,
    header: colors.onSurfaceSecondary,
  );

  final Color content;
  final Color summary;
  final Color selectedContent;
  final Color selectedSummary;
  final Color selectedIndicator;
  final Color disabledContent;

  /// The title of an alert (destructive) row, selected or not.
  final Color alertContent;

  /// A group header's title.
  final Color header;

  @override
  bool operator ==(Object other) =>
      other is SoftDropdownColors &&
      other.content == content &&
      other.summary == summary &&
      other.selectedContent == selectedContent &&
      other.selectedSummary == selectedSummary &&
      other.selectedIndicator == selectedIndicator &&
      other.disabledContent == disabledContent &&
      other.alertContent == alertContent &&
      other.header == header;

  @override
  int get hashCode => Object.hash(
    content,
    summary,
    selectedContent,
    selectedSummary,
    selectedIndicator,
    disabledContent,
    alertContent,
    header,
  );
}

/// One option of a dropdown or popup menu.
@immutable
class SoftDropdownItem {
  const SoftDropdownItem({
    required this.text,
    this.enabled = true,
    this.selected = false,
    this.onTap,
    this.icon,
    this.summary,
    this.hint,
    this.alert = false,
  });

  final String text;
  final bool enabled;

  /// Shows the check and tints the title.
  final bool selected;

  /// Called when the row is chosen.
  final VoidCallback? onTap;

  /// A leading icon, in a cell at least 20 square, 12 before the title.
  final Widget? icon;

  /// A second line under the title.
  final String? summary;

  /// A trailing slot before the check, at most 40 wide — a badge, a dot, a
  /// count. Hidden while the row is disabled.
  final Widget? hint;

  /// A destructive option: its title is in the error colour.
  final bool alert;

  SoftDropdownItem copyWith({
    String? text,
    bool? enabled,
    bool? selected,
    VoidCallback? onTap,
    Widget? icon,
    String? summary,
    Widget? hint,
    bool? alert,
  }) {
    return SoftDropdownItem(
      text: text ?? this.text,
      enabled: enabled ?? this.enabled,
      selected: selected ?? this.selected,
      onTap: onTap ?? this.onTap,
      icon: icon ?? this.icon,
      summary: summary ?? this.summary,
      hint: hint ?? this.hint,
      alert: alert ?? this.alert,
    );
  }
}

/// A group of dropdown options. Groups are separated by a divider band; a
/// [title] puts a non-clickable header above the group.
@immutable
class SoftDropdownEntry {
  const SoftDropdownEntry({
    required this.items,
    this.enabled = true,
    this.title,
  });

  final List<SoftDropdownItem> items;

  /// False disables every item of the group.
  final bool enabled;
  final String? title;
}

/// One dropdown option inside a [SoftListPopupColumn]: an optional icon, the
/// title (15, up to three lines, two over a summary), an optional summary
/// (14, secondary), an optional hint and the check of the selected option.
///
/// Rows sharing a [groupKey] are one group: the column puts no divider band
/// between them.
class SoftDropdownRow extends StatelessWidget {
  const SoftDropdownRow({
    super.key,
    required this.item,
    this.selected,
    this.enabled,
    this.onTap,
    this.groupKey,
    this.colors,
  });

  final SoftDropdownItem item;

  /// Overrides [SoftDropdownItem.selected].
  final bool? selected;

  /// Overrides [SoftDropdownItem.enabled].
  final bool? enabled;

  /// Overrides [SoftDropdownItem.onTap].
  final VoidCallback? onTap;
  final Object? groupKey;
  final SoftDropdownColors? colors;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftDropdownColors c = colors ?? SoftDropdownColors.of(theme.colors);
    final bool isSelected = selected ?? item.selected;
    final bool isEnabled = enabled ?? item.enabled;
    final VoidCallback? tap = onTap ?? item.onTap;
    final Color titleColor = !isEnabled
        ? c.disabledContent
        : item.alert
        ? c.alertContent
        : isSelected
        ? c.selectedContent
        : c.content;
    final Color summaryColor = isSelected ? c.selectedSummary : c.summary;
    final Color? checkColor = !isSelected
        ? null
        : isEnabled
        ? c.selectedIndicator
        : c.disabledContent;
    final Widget? hint = isEnabled ? item.hint : null;
    final String? summary = item.summary;
    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.text,
          maxLines: summary == null
              ? SoftDropdownDefaults.titleMaxLines
              : SoftDropdownDefaults.titleWithSummaryMaxLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textStyles.body1.copyWith(
            fontSize: SoftDropdownDefaults.titleFontSize,
            fontWeight: FontWeight.w400,
            color: titleColor,
          ),
        ),
        if (summary != null)
          Text(
            summary,
            maxLines: SoftDropdownDefaults.summaryMaxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textStyles.body2.copyWith(color: summaryColor),
          ),
      ],
    );
    final Widget? icon = item.icon;
    return SoftListPopupItem(
      onTap: tap,
      enabled: isEnabled,
      groupKey: groupKey,
      child: MergeSemantics(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: isSelected,
          selected: isSelected,
          enabled: isEnabled,
          onTap: isEnabled ? tap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SoftDropdownDefaults.itemMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SoftDropdownDefaults.itemHorizontalPadding,
                vertical: SoftDropdownDefaults.itemVerticalPadding,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: SoftDropdownDefaults.maxItemTextWidth,
                        ),
                        child: icon == null
                            ? text
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: SoftDropdownDefaults.iconEndPadding,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth:
                                            SoftDropdownDefaults.iconMinSize,
                                        minHeight:
                                            SoftDropdownDefaults.iconMinSize,
                                      ),
                                      child: Center(
                                        widthFactor: 1,
                                        heightFactor: 1,
                                        child: icon,
                                      ),
                                    ),
                                  ),
                                  Flexible(child: text),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (hint != null) ...<Widget>[
                    const SizedBox(
                      width: SoftDropdownDefaults.checkIconStartPadding,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: SoftDropdownDefaults.hintMaxWidth,
                      ),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: hint,
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: hint != null
                          ? SoftDropdownDefaults.hintEndPadding
                          : SoftDropdownDefaults.checkIconStartPadding,
                    ),
                    child: SizedBox.square(
                      dimension: SoftDropdownDefaults.checkIconSize,
                      child: checkColor == null
                          ? null
                          : CustomPaint(painter: _CheckPainter(checkColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A non-clickable group title inside a popup list: 12 medium in the
/// secondary label colour, at least 32 high.
class SoftDropdownHeader extends StatelessWidget {
  const SoftDropdownHeader(this.text, {super.key, this.color});

  final String text;

  /// The title colour; the secondary label colour by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Semantics(
      header: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SoftDropdownDefaults.headerMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SoftDropdownDefaults.itemHorizontalPadding,
            vertical: SoftDropdownDefaults.itemVerticalPadding,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              maxLines: SoftDropdownDefaults.headerMaxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textStyles.footnote2.copyWith(
                fontSize: SoftDropdownDefaults.headerFontSize,
                fontWeight: FontWeight.w500,
                color: color ?? theme.colors.onSurfaceSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The up-down arrow a dropdown row shows beside its value: two 1.4 round
/// chevrons in a 14 × 24 box, mirrored right to left.
class SoftDropdownArrow extends StatelessWidget {
  const SoftDropdownArrow({super.key, this.color});

  /// The stroke colour; the theme's actions colour by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c =
        color ?? SoftTheme.of(context).colors.onSurfaceVariantActions;
    final bool rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return SizedBox.fromSize(
      size: SoftDropdownDefaults.arrowSize,
      child: CustomPaint(painter: _ArrowPainter(c, mirrored: rtl)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(5.62 * s, 12.25 * s)
        ..lineTo(10.88 * s, 17.5 * s)
        ..lineTo(22.38 * s, 6 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color, {required this.mirrored});

  final Color color;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 14;
    final double sy = size.height / 24;
    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.scale(sx, sy);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(4.199, 10)
          ..lineTo(8.328, 5.413)
          ..cubicTo(8.526, 5.192, 8.872, 5.192, 9.071, 5.413)
          ..lineTo(13.199, 10),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(13.199, 14)
          ..lineTo(9.071, 18.587)
          ..cubicTo(8.872, 18.808, 8.526, 18.808, 8.328, 18.587)
          ..lineTo(4.199, 14),
        paint,
      );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.mirrored != mirrored;
}

/// The children of a dropdown popup: per group an optional header, the
/// options (one group, so no bands between them) and a divider before the
/// next group. [onItemTap] receives the group and option indices.
List<Widget> softDropdownEntryChildren({
  required List<SoftDropdownEntry> entries,
  required void Function(int entryIndex, int itemIndex) onItemTap,
  SoftDropdownColors? colors,
}) {
  final List<Widget> children = <Widget>[];
  for (int e = 0; e < entries.length; e++) {
    final SoftDropdownEntry entry = entries[e];
    final String? title = entry.title;
    if (title != null) {
      children.add(
        SoftDropdownHeader(
          title,
          key: ValueKey<String>('header-$e'),
          color: colors?.header,
        ),
      );
    }
    for (int i = 0; i < entry.items.length; i++) {
      final SoftDropdownItem item = entry.items[i];
      children.add(
        SoftDropdownRow(
          key: ValueKey<String>('item-$e-$i'),
          item: item,
          enabled: entry.enabled && item.enabled,
          groupKey: e,
          colors: colors,
          onTap: () => onItemTap(e, i),
        ),
      );
    }
    if (e != entries.length - 1) {
      children.add(SoftPopupListDivider(key: ValueKey<String>('divider-$e')));
    }
  }
  return children;
}

/// Shows [entries] in a list popup anchored to the widget of [context] (see
/// [showSoftListPopup] for placement, motion and dismissal).
///
/// Choosing an option plays a confirm haptic, calls its
/// [SoftDropdownItem.onTap] and — when [collapseOnSelection], by default
/// with a single group — closes the popup. Pass [entriesListenable] to keep
/// an open popup in step with entries that change while it is shown (the
/// check moving in a grouped menu that stays open).
Future<void> showSoftPopupMenu({
  required BuildContext context,
  required List<SoftDropdownEntry> entries,
  ValueListenable<List<SoftDropdownEntry>>? entriesListenable,
  bool? collapseOnSelection,
  SoftDropdownColors? colors,
  Rect? anchorRect,
  Offset? touchPoint,
  SoftPopupPositioner positioner = SoftPopupPositioner.dropdown,
  SoftPopupAlign alignment = SoftPopupAlign.end,
  double? maxHeight,
  bool dimBackground = false,
  bool glass = true,
  VoidCallback? onDismissFinished,
}) {
  final bool collapse = collapseOnSelection ?? entries.length <= 1;
  List<SoftDropdownEntry> current() => entriesListenable?.value ?? entries;
  return showSoftListPopup<void>(
    context: context,
    anchorRect: anchorRect,
    touchPoint: touchPoint,
    positioner: positioner,
    alignment: alignment,
    maxHeight: maxHeight,
    dimBackground: dimBackground,
    glass: glass,
    onDismissFinished: onDismissFinished,
    builder: (BuildContext popupContext) {
      void onItemTap(int e, int i) {
        HapticFeedback.successNotification();
        final List<SoftDropdownEntry> list = current();
        if (e < list.length && i < list[e].items.length) {
          list[e].items[i].onTap?.call();
        }
        if (collapse) dismissSoftListPopup<void>(popupContext);
      }

      Widget column(List<SoftDropdownEntry> list) => SoftListPopupColumn(
        children: softDropdownEntryChildren(
          entries: list,
          colors: colors,
          onItemTap: onItemTap,
        ),
      );

      final ValueListenable<List<SoftDropdownEntry>>? listenable =
          entriesListenable;
      if (listenable == null) return column(entries);
      return ValueListenableBuilder<List<SoftDropdownEntry>>(
        valueListenable: listenable,
        builder: (BuildContext context, List<SoftDropdownEntry> value, _) =>
            column(value),
      );
    },
  );
}
