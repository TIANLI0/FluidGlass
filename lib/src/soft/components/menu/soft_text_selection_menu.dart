import 'package:flutter/widgets.dart';

import '../../../internal/control_focus.dart';
import '../../foundation/soft_glass.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_spot_light.dart';
import '../../foundation/soft_theme.dart';
import '../../foundation/soft_touch_motion.dart';
import 'soft_popup_list.dart';

@immutable
class SoftTextSelectionAction {
  const SoftTextSelectionAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool enabled;
}

/// Vertical menu for EditableText / SelectableRegion contextMenuBuilder.
/// It uses Flutter's selection-toolbar placement and leaves selection,
/// copy/paste permissions, labels and toolbar dismissal with the caller.
/// [anchors] use the framework's global selection coordinates.
class SoftTextSelectionMenu extends StatefulWidget {
  const SoftTextSelectionMenu({
    super.key,
    required this.anchors,
    required this.actions,
    this.glass = true,
    this.color,
    this.cornerRadius = 22,
  });
  final TextSelectionToolbarAnchors anchors;
  final List<SoftTextSelectionAction> actions;
  final bool glass;
  final Color? color;
  final double cornerRadius;
  @override
  State<SoftTextSelectionMenu> createState() => _SoftTextSelectionMenuState();
}

class _SoftTextSelectionMenuState extends State<SoftTextSelectionMenu>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _appear = SoftSpring(vsync: this);
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (softReduceMotion(context)) {
      _appear.snapTo(1);
    } else if (!_started) {
      _appear.animateTo(1, softSpring(damping: 0.9, response: 0.3));
    }
    _started = true;
  }

  @override
  void dispose() {
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();
    final SoftThemeData theme = SoftTheme.of(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Offset origin = Offset(safe.left + 16, safe.top + 8);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CustomSingleChildLayout(
          delegate: TextSelectionToolbarLayoutDelegate(
            anchorAbove:
                widget.anchors.primaryAnchor - origin - const Offset(0, 8),
            anchorBelow:
                (widget.anchors.secondaryAnchor ??
                    widget.anchors.primaryAnchor) -
                origin +
                const Offset(0, 8),
          ),
          child: AnimatedBuilder(
            animation: _appear,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: _appear.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.9 + 0.1 * _appear.value,
                child: child,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 280,
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: SoftTouchMotion(
                pressScale: false,
                followFinger: false,
                borderRadius: BorderRadius.circular(widget.cornerRadius),
                light: widget.glass
                    ? SoftSpotLightParams.translucentLarge1(theme.isDark)
                    : null,
                background: SoftGlass(
                  borderRadius: BorderRadius.circular(widget.cornerRadius),
                  color: widget.color ?? theme.colors.surface,
                  blur: widget.glass,
                  containerAlpha: widget.glass ? 0.88 : 1,
                ),
                child: SoftListPopupColumn(
                  children: <Widget>[
                    for (final SoftTextSelectionAction action in widget.actions)
                      SoftListPopupItem(
                        groupKey: 'actions',
                        enabled: action.enabled && action.onPressed != null,
                        onTap: action.onPressed,
                        child: ControlFocus(
                          enabled: action.enabled && action.onPressed != null,
                          onActivate: action.onPressed,
                          borderRadius: BorderRadius.circular(
                            widget.cornerRadius,
                          ),
                          child: Semantics(
                            button: true,
                            enabled: action.enabled && action.onPressed != null,
                            onTap: action.enabled ? action.onPressed : null,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    if (action.icon != null) ...<Widget>[
                                      IconTheme(
                                        data: IconThemeData(
                                          size: 20,
                                          color: action.enabled
                                              ? theme.colors.onSurface
                                              : theme.colors.disabledOnSurface,
                                        ),
                                        child: action.icon!,
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Flexible(
                                      child: Text(
                                        action.label,
                                        style: theme.textStyles.body2.copyWith(
                                          color:
                                              action.enabled &&
                                                  action.onPressed != null
                                              ? theme.colors.onSurface
                                              : theme.colors.disabledOnSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
