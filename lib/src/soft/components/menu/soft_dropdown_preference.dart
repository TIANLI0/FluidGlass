import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';
import '../basic/soft_card.dart';
import '../basic/soft_list.dart';
import 'soft_dropdown.dart';

/// A list row that opens a dropdown popup of [entries]: the title and
/// summary, the selected options' text (14, secondary, at most 162 wide)
/// and the up-down arrow on the end side.
///
/// Tapping the row plays a context-click haptic and opens the popup at the
/// finger; the row stays pressed until the popup has finished closing.
/// Rows with no options are disabled.
class SoftDropdownPreference extends StatefulWidget {
  const SoftDropdownPreference({
    super.key,
    required this.title,
    required this.entries,
    this.summary,
    this.start,
    this.enabled = true,
    this.showValue = true,
    this.openAtTouchPoint = true,
    this.collapseOnSelection,
    this.maxHeight,
    this.position = SoftCardListPosition.none,
    this.colors,
    this.onExpandedChange,
  });

  /// A single group of plain options, one of them selected.
  SoftDropdownPreference.items({
    super.key,
    required this.title,
    required List<String> items,
    required int selectedIndex,
    ValueChanged<int>? onSelectedIndexChange,
    this.summary,
    this.start,
    this.enabled = true,
    this.showValue = true,
    this.maxHeight,
    this.position = SoftCardListPosition.none,
    this.colors,
    this.onExpandedChange,
  }) : openAtTouchPoint = true,
       collapseOnSelection = true,
       entries = <SoftDropdownEntry>[
         SoftDropdownEntry(
           items: <SoftDropdownItem>[
             for (int i = 0; i < items.length; i++)
               SoftDropdownItem(
                 text: items[i],
                 selected: i == selectedIndex,
                 onTap: onSelectedIndexChange == null
                     ? null
                     : () => onSelectedIndexChange(i),
               ),
           ],
         ),
       ];

  final String title;
  final List<SoftDropdownEntry> entries;
  final String? summary;
  final Widget? start;
  final bool enabled;

  /// Whether to show the selected options' text before the arrow.
  final bool showValue;

  /// Whether the popup opens at the finger rather than under the row's end.
  final bool openAtTouchPoint;

  /// Whether choosing an option closes the popup; by default only a
  /// single-group popup closes.
  final bool? collapseOnSelection;

  /// Caps the popup's height; it scrolls beyond.
  final double? maxHeight;
  final SoftCardListPosition position;
  final SoftDropdownColors? colors;

  /// Called when the popup opens and when it is dismissed.
  final ValueChanged<bool>? onExpandedChange;

  @override
  State<SoftDropdownPreference> createState() => _SoftDropdownPreferenceState();
}

class _SoftDropdownPreferenceState extends State<SoftDropdownPreference> {
  final GlobalKey _anchorKey = GlobalKey();
  late final ValueNotifier<List<SoftDropdownEntry>> _entries =
      ValueNotifier<List<SoftDropdownEntry>>(_nonEmpty(widget.entries));
  bool _expanded = false;
  bool _holdDown = false;
  bool _open = false;
  Offset? _touchPoint;

  static List<SoftDropdownEntry> _nonEmpty(List<SoftDropdownEntry> entries) =>
      entries
          .where((SoftDropdownEntry e) => e.items.isNotEmpty)
          .toList(growable: false);

  @override
  void didUpdateWidget(SoftDropdownPreference oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      final List<SoftDropdownEntry> next = _nonEmpty(widget.entries);
      if (!_open) {
        _entries.value = next;
      } else {
        // The open popup lives in another route; update it after this
        // frame's build.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _entries.value = _nonEmpty(widget.entries);
        });
      }
    }
  }

  @override
  void dispose() {
    _entries.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    widget.onExpandedChange?.call(value);
  }

  bool get _active => widget.enabled && _entries.value.isNotEmpty;

  Future<void> _openPopup() async {
    if (!_active || _expanded) return;
    final Offset? point = widget.openAtTouchPoint ? _touchPoint : null;
    _touchPoint = null;
    final RenderBox? anchor =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final Rect? anchorRect = anchor == null || !anchor.hasSize
        ? null
        : anchor.localToGlobal(Offset.zero) & anchor.size;
    _setExpanded(true);
    setState(() => _holdDown = true);
    _open = true;
    HapticFeedback.heavyImpact();
    await showSoftPopupMenu(
      context: context,
      entries: _entries.value,
      entriesListenable: _entries,
      collapseOnSelection:
          widget.collapseOnSelection ?? widget.entries.length <= 1,
      colors: widget.colors,
      anchorRect: anchorRect,
      touchPoint: point,
      maxHeight: widget.maxHeight,
      onDismissFinished: () {
        _open = false;
        if (mounted) setState(() => _holdDown = false);
      },
    );
    if (mounted) _setExpanded(false);
  }

  @override
  Widget build(BuildContext context) {
    final SoftColors c = SoftTheme.of(context).colors;
    final SoftThemeData theme = SoftTheme.of(context);
    final bool active = _active;
    final List<SoftDropdownEntry> entries = _entries.value;
    String? value;
    if (widget.showValue && entries.isNotEmpty) {
      final String joined = <String>[
        for (final SoftDropdownEntry e in entries)
          for (final SoftDropdownItem i in e.items)
            if (i.selected && i.text.trim().isNotEmpty) i.text,
      ].join('\n');
      if (joined.isNotEmpty) value = joined;
    }
    final Widget end = Row(
      key: _anchorKey,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (value != null)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SoftDropdownDefaults.valueMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textStyles.body2.copyWith(
                    color: active
                        ? c.onSurfaceSecondary
                        : c.disabledOnSecondaryVariant,
                  ),
                ),
              ),
            ),
          ),
        SoftDropdownArrow(
          color: active
              ? c.onSurfaceVariantActions
              : c.disabledOnSecondaryVariant,
        ),
      ],
    );
    return Semantics(
      expanded: _expanded,
      child: Listener(
        onPointerDown: (PointerDownEvent event) => _touchPoint = event.position,
        child: SoftBasicComponent(
          title: widget.title,
          summary: widget.summary,
          start: widget.start,
          end: <Widget>[end],
          position: widget.position,
          enabled: active,
          holdDown: _holdDown,
          onTap: active ? _openPopup : null,
        ),
      ),
    );
  }
}

/// A list row that opens a popup menu of [entries] under its end side: the
/// same row as [SoftDropdownPreference] without the value text, for action
/// menus.
class SoftDropdownMenu extends StatelessWidget {
  const SoftDropdownMenu({
    super.key,
    required this.title,
    required this.entries,
    this.summary,
    this.start,
    this.enabled = true,
    this.collapseOnSelection,
    this.maxHeight,
    this.position = SoftCardListPosition.none,
    this.colors,
    this.onExpandedChange,
  });

  final String title;
  final List<SoftDropdownEntry> entries;
  final String? summary;
  final Widget? start;
  final bool enabled;
  final bool? collapseOnSelection;
  final double? maxHeight;
  final SoftCardListPosition position;
  final SoftDropdownColors? colors;
  final ValueChanged<bool>? onExpandedChange;

  @override
  Widget build(BuildContext context) {
    return SoftDropdownPreference(
      title: title,
      entries: entries,
      summary: summary,
      start: start,
      enabled: enabled,
      showValue: false,
      openAtTouchPoint: false,
      collapseOnSelection: collapseOnSelection,
      maxHeight: maxHeight,
      position: position,
      colors: colors,
      onExpandedChange: onExpandedChange,
    );
  }
}
