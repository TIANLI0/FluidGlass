import 'dart:math' as math;
// Derived from coui17 basic/HorizontalPopupMenu.kt, Apache-2.0.
import 'package:flutter/widgets.dart';

import '../../../internal/control_focus.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';
import 'soft_list_popup.dart';
import 'soft_popup_list.dart';

@immutable
class SoftHorizontalMenuItem {
  const SoftHorizontalMenuItem({
    required this.icon,
    this.label,
    required this.onPressed,
    this.enabled = true,
    this.semanticLabel,
  });
  final Widget icon;
  final String? label, semanticLabel;
  final VoidCallback? onPressed;
  final bool enabled;
}

/// The horizontal popup grid: three columns when labelled, otherwise
/// three to five columns. Labels wrap, actions are independently disabled.
/// This is content only; [showSoftHorizontalPopupMenu] supplies the material,
/// anchor placement, light and transition from the existing popup pipeline.
class SoftHorizontalPopupMenu extends StatelessWidget {
  const SoftHorizontalPopupMenu({super.key, required this.items});
  final List<SoftHorizontalMenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bool labelled = items.any(
      (SoftHorizontalMenuItem item) => item.label?.isNotEmpty ?? false,
    );
    final int columns = labelled ? 3 : items.length.clamp(3, 5);
    final double gap = labelled ? 4 : 8;
    final double edge = labelled ? 8 : 12;
    final SoftThemeData theme = SoftTheme.of(context);
    final TextStyle labelStyle = theme.textStyles.main.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        int px(double value) => (value * dpr + 0.5).floor();
        double intrinsic = labelled ? 52 : 40;
        for (final SoftHorizontalMenuItem item in items) {
          if (item.label?.isNotEmpty ?? false) {
            final TextPainter painter = TextPainter(
              text: TextSpan(text: item.label, style: labelStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            intrinsic = math.max(intrinsic, painter.maxIntrinsicWidth + 12);
            painter.dispose();
          }
        }
        final double upper = math.min(
          math.max(SoftListPopupDefaults.maxWidth, constraints.minWidth),
          constraints.maxWidth,
        );
        final double lower = math.min(
          math.max(SoftListPopupDefaults.minWidth, constraints.minWidth),
          upper,
        );
        final int width = px(
          (columns * intrinsic + 2 * edge + (columns - 1) * gap).clamp(
            lower,
            upper,
          ),
        );
        final int columnWidth = width ~/ columns;
        return SizedBox(
          width: width / dpr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int row = 0; row < (items.length / columns).ceil(); row++)
                Builder(
                  builder: (context) {
                    final int count = math.min(
                      columns,
                      items.length - row * columns,
                    );
                    int rowEdge = px(edge);
                    int spacing = count <= 1 ? 0 : px(gap);
                    if (count > 1) {
                      final int affordable =
                          (width - 2 * rowEdge) ~/ (count - 1);
                      final int capped = math.min(spacing, affordable);
                      spacing = affordable >= px(4)
                          ? math.max(px(4), capped)
                          : math.max(0, capped);
                      rowEdge = math.min(
                        rowEdge,
                        math.max(0, (width - (count - 1) * spacing) ~/ 2),
                      );
                    }
                    final int perItem = count <= 1
                        ? rowEdge
                        : (((count - 1) * spacing + 2 * rowEdge) / count + 0.5)
                              .floor();
                    return Row(
                      textDirection: TextDirection.ltr,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int col = 0; col < count; col++)
                          Builder(
                            builder: (context) {
                              final SoftHorizontalMenuItem item =
                                  items[row * columns + col];
                              final bool hasText =
                                  item.label?.isNotEmpty ?? false;
                              final int start = count <= 1
                                  ? rowEdge
                                  : math.max(
                                      0,
                                      ((rowEdge * count -
                                                      col *
                                                          (2 * rowEdge -
                                                              spacing)) /
                                                  count +
                                              0.5)
                                          .floor(),
                                    );
                              final int end = count <= 1
                                  ? rowEdge
                                  : math.max(0, perItem - start);
                              final bool enabled =
                                  item.enabled && item.onPressed != null;
                              final double radius = hasText
                                  ? (theme.smoothCorners ? 23 : 16)
                                  : (theme.smoothCorners ? 17 : 12);
                              final Color foreground = enabled
                                  ? theme.colors.onSurface
                                  : theme.colors.disabledOnSurface;
                              return SizedBox(
                                width: columnWidth / dpr,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: start / dpr,
                                    right: end / dpr,
                                  ),
                                  child: Semantics(
                                    label: item.semanticLabel,
                                    child: ControlFocus(
                                      enabled: enabled,
                                      onActivate: item.onPressed,
                                      borderRadius: BorderRadius.circular(
                                        radius,
                                      ),
                                      child: _HorizontalMask(
                                        enabled: enabled,
                                        onTap: item.onPressed,
                                        borderRadius: BorderRadius.circular(
                                          radius,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 40,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: hasText ? 6 : 8,
                                              vertical: hasText ? 6 : 0,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                IconTheme(
                                                  data: IconThemeData(
                                                    size: hasText ? 20 : 24,
                                                    color: foreground,
                                                  ),
                                                  child: item.icon,
                                                ),
                                                if (hasText) ...<Widget>[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.label!,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: labelStyle.copyWith(
                                                      color: foreground,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Returns the selected index. Pop the menu before invoking the action, so
/// an action can safely open another route using its original context.
Future<int?> showSoftHorizontalPopupMenu({
  required BuildContext context,
  required List<SoftHorizontalMenuItem> items,
  Rect? anchorRect,
  Offset? touchPoint,
  bool glass = true,
  String? barrierLabel,
}) async {
  if (items.isEmpty) return null;
  final int? selected = await showSoftListPopup<int>(
    context: context,
    anchorRect: anchorRect,
    touchPoint: touchPoint,
    glass: glass,
    barrierLabel: barrierLabel,
    minWidth: SoftListPopupDefaults.minWidth,
    builder: (BuildContext menuContext) => SoftHorizontalPopupMenu(
      items: <SoftHorizontalMenuItem>[
        for (int i = 0; i < items.length; i++)
          SoftHorizontalMenuItem(
            icon: items[i].icon,
            label: items[i].label,
            semanticLabel: items[i].semanticLabel,
            enabled: items[i].enabled && items[i].onPressed != null,
            onPressed: () => Navigator.of(menuContext).pop(i),
          ),
      ],
    ),
  );
  if (selected != null) items[selected].onPressed?.call();
  return selected;
}

class _HorizontalMask extends StatefulWidget {
  const _HorizontalMask({
    required this.enabled,
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });
  final bool enabled;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Widget child;
  @override
  State<_HorizontalMask> createState() => _HorizontalMaskState();
}

class _HorizontalMaskState extends State<_HorizontalMask>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _progress = SoftSpring(vsync: this)..addListener(_tick);
  bool _finishEnter = false;
  void _tick() {
    if (_finishEnter && _progress.value >= 0.7) {
      _finishEnter = false;
      _progress.animateTo(0, SoftPopupListDefaults.pressSpring);
    }
  }

  void _press(bool down) {
    if (softReduceMotion(context)) {
      _progress.snapTo(down ? 1 : 0);
      return;
    }
    _finishEnter = !down && _progress.value > 0 && _progress.value < 0.7;
    _progress.animateTo(
      down || _finishEnter ? 1 : 0,
      SoftPopupListDefaults.pressSpring,
    );
  }

  @override
  void didUpdateWidget(_HorizontalMask old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) {
      _finishEnter = false;
      _progress.snapTo(0);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled ? (_) => _press(true) : null,
      onTapUp: widget.enabled ? (_) => _press(false) : null,
      onTapCancel: widget.enabled ? () => _press(false) : null,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) => DecoratedBox(
          decoration: ShapeDecoration(
            shape: SoftSquircleBorder(
              radius: widget.borderRadius,
              smooth: theme.smoothCorners,
            ),
            color:
                (theme.isDark
                        ? SoftPopupListDefaults.pressDark
                        : SoftPopupListDefaults.pressLight)
                    .withValues(
                      alpha:
                          (theme.isDark ? 0x26 / 255 : 0x14 / 255) *
                          _progress.value.clamp(0, 1),
                    ),
          ),
          child: child,
        ),
      ),
    );
  }
}
