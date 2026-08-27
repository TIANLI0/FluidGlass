import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// One row of a [LiquidSheet].
@immutable
class LiquidSheetItem {
  const LiquidSheetItem({
    required this.label,
    this.detail,
    this.isSelected = false,
    this.isDestructive = false,
    this.onSelected,
  });

  final String label;

  /// A second line under [label] — what the choice currently resolves to, for
  /// instance. A row that says "Follow system" and nothing else does not tell
  /// the reader what the system actually picked.
  final String? detail;

  /// Draws a check at the trailing edge, and weights the label.
  ///
  /// Trailing rather than leading, unlike [LiquidMenuItem]: a sheet row is wide
  /// and its label is the thing being read, so a mark at the start pushes every
  /// label out of alignment with the ones above it.
  final bool isSelected;

  /// Tints the row red, for a row that removes something.
  final bool isDestructive;

  final VoidCallback? onSelected;
}

/// A half-screen sheet of liquid glass, rounded at the top two corners.
///
/// On a phone this is the form a single choice out of several belongs in: rows
/// tall enough to read, a title saying what is being chosen, and the page still
/// visible — refracted — behind it. A pop-up menu is the wrong instrument for
/// the job: a menu panel is narrow, its rows are short, and every one of them
/// competes for contrast with whatever the panel happens to be over.
///
/// This is the face and the rows only. Two things are the caller's:
///
/// - **The `Backdrop`**, as everywhere in this package — a glass widget cannot
///   invent what it refracts. For a sheet that means a frozen capture taken
///   before the sheet was inserted, since a live one would include the sheet.
/// - **Getting it on screen.** [showLiquidSheet] wires the modal bottom sheet
///   for you (transparent background so this panel is the only surface, root
///   navigator, dismissal on selection); use this widget directly for a sheet
///   that is not a route.
class LiquidSheet extends StatelessWidget {
  const LiquidSheet({
    super.key,
    required this.backdrop,
    this.title,
    this.items = const <LiquidSheetItem>[],
    this.child,
    this.onSelected,
    this.surfaceColor,
    this.showDragHandle = true,
    this.cornerRadius = 28,
    this.rowHeight = 56,
  });

  /// What the glass refracts.
  final Backdrop backdrop;

  final String? title;

  /// The rows. Ignored when [child] is given.
  final List<LiquidSheetItem> items;

  /// Free-form content instead of [items].
  final Widget? child;

  /// Called after a row's own [LiquidSheetItem.onSelected].
  ///
  /// [showLiquidSheet] uses it to dismiss; on its own the sheet only reports.
  final ValueChanged<LiquidSheetItem>? onSelected;

  /// The tint over the refracted backdrop. Defaults to the theme's `container`.
  ///
  /// A sheet full of text wants a heavier tint than a bar does: its contrast
  /// against the content behind it is otherwise decided by whatever the sheet
  /// happens to be over. Pass an opaque colour to drop the glass entirely —
  /// which is what an app should do when it could not capture a backdrop.
  final Color? surfaceColor;

  /// Whether to draw the grab handle.
  ///
  /// Draw it here rather than through `BottomSheetThemeData.showDragHandle`:
  /// that one paints in the framework's own `Material`, which [showLiquidSheet]
  /// makes transparent, so the handle would float outside the glass.
  final bool showDragHandle;

  /// The radius of the top two corners. The bottom two are square — a sheet
  /// sitting on the screen's edge shows a gap under a rounded one.
  final double cornerRadius;

  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    return LiquidPanel(
      backdrop: backdrop,
      surfaceColor: surfaceColor ?? colors.container,
      shape: UnevenRoundedRectangle.only(
        topStart: cornerRadius,
        topEnd: cornerRadius,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showDragHandle) _Handle(color: colors.content),
            if (title case final String heading)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  showDragHandle ? 4 : 20,
                  20,
                  8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    heading,
                    style: TextStyle(
                      color: colors.content,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child:
                    child ??
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final LiquidSheetItem item in items)
                          _SheetRow(
                            item: item,
                            height: rowHeight,
                            contentColor: item.isDestructive
                                ? colors.destructive
                                : colors.content,
                            accentColor: colors.accent,
                            washColor: colors.content.withValues(alpha: 0.08),
                            onSelected: (LiquidSheetItem chosen) {
                              chosen.onSelected?.call();
                              onSelected?.call(chosen);
                            },
                          ),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const SizedBox(width: 36, height: 4),
      ),
    );
  }
}

class _SheetRow extends StatefulWidget {
  const _SheetRow({
    required this.item,
    required this.height,
    required this.contentColor,
    required this.accentColor,
    required this.washColor,
    required this.onSelected,
  });

  final LiquidSheetItem item;
  final double height;
  final Color contentColor;
  final Color accentColor;
  final Color washColor;
  final ValueChanged<LiquidSheetItem> onSelected;

  @override
  State<_SheetRow> createState() => _SheetRowState();
}

class _SheetRowState extends State<_SheetRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final LiquidSheetItem item = widget.item;
    // Slop-free, as in `LiquidMenu`: a finger that wanders while choosing must
    // not have its selection swallowed. The wash is an inset rounded rectangle
    // rather than a full-bleed bar, so the first and last rows do not shear it
    // against the panel's rounded corners.
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: item.isSelected,
      label: item.detail == null ? item.label : '${item.label}, ${item.detail}',
      child: ExcludeSemantics(
        child: DragInspector(
          behavior: HitTestBehavior.opaque,
          onDragStart: (Offset position, Size size) =>
              setState(() => _pressed = true),
          onDragEnd: () => setState(() => _pressed = false),
          onDragCancel: () => setState(() => _pressed = false),
          onTap: () => widget.onSelected(item),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _pressed
                      ? widget.washColor
                      : widget.washColor.withValues(alpha: 0.0),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.label,
                            style: TextStyle(
                              color: widget.contentColor,
                              fontSize: 16,
                              fontWeight: item.isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (item.detail case final String detail)
                            Text(
                              detail,
                              style: TextStyle(
                                color: widget.contentColor.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.isSelected)
                      Icon(Icons.check, size: 20, color: widget.accentColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [LiquidSheet] as a modal bottom sheet.
///
/// Five overrides the caller would otherwise have to remember, and one that is
/// easy to get wrong: the framework's own surface has to be made transparent so
/// the glass panel is the only one, and its drag handle turned off with it,
/// since that handle paints in the surface that just became transparent.
///
/// [barrierColor] is worth passing explicitly: an app that refracts a frozen
/// capture must paint the same dim into that capture, or the sheet reads as a
/// lit window floating over a dimmed page.
Future<T?> showLiquidSheet<T>({
  required BuildContext context,
  required Backdrop backdrop,
  String? title,
  List<LiquidSheetItem> items = const <LiquidSheetItem>[],
  Widget? child,
  Color? barrierColor,
  Color? surfaceColor,
  bool showDragHandle = true,
  bool isDismissible = true,
  double cornerRadius = 28,
  double rowHeight = 56,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    barrierColor: barrierColor,
    // The panel is the surface; the framework's must not draw a second one
    // behind it, nor its handle in front of it.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    // Without this the framework caps the sheet at 9/16 of the screen and the
    // rows inside a taller sheet are simply cut off.
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => LiquidSheet(
      backdrop: backdrop,
      title: title,
      items: items,
      surfaceColor: surfaceColor,
      showDragHandle: showDragHandle,
      cornerRadius: cornerRadius,
      rowHeight: rowHeight,
      onSelected: (LiquidSheetItem _) => Navigator.of(sheetContext).pop(),
      child: child,
    ),
  );
}
