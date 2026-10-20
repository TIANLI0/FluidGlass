import 'package:flutter/material.dart';

import '../backdrop.dart';
import '../backdrops/native_backdrop.dart';
import '../internal/control_focus.dart';
import '../shapes/rounded_rectangular_shape.dart';
import '../theme/liquid_glass_theme.dart';
import 'liquid_panel.dart';
import 'liquid_slider.dart';
import 'liquid_toggle.dart';

/// One semantic group, one pane of glass. Children are ordinary reusable rows.
class LiquidSettingsSection extends StatelessWidget {
  const LiquidSettingsSection({
    super.key,
    required this.children,
    this.title,
    this.description,
    this.footer,
    this.backdrop = nativeBackdrop,
    this.showDividers = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });
  final List<Widget> children;
  final String? title;
  final String? description;
  final Widget? footer;
  final Backdrop backdrop;
  final bool showDividers;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: TextStyle(
                  color: colors.content,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (description != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
            child: Text(
              description!,
              style: TextStyle(
                color: colors.content.withValues(alpha: 0.7),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ),
        LiquidPanel(
          backdrop: backdrop,
          shape: const RoundedRectangle(24),
          showShadow: false,
          blurRadius: 8,
          refractionHeight: 10,
          refractionAmount: 12,
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < children.length; i++) ...<Widget>[
                    if (showDividers && i > 0)
                      Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: colors.content.withValues(alpha: 0.08),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: footer,
          ),
      ],
    );
  }
}

/// A general display/navigation row. Null [onTap] makes it informational;
/// [enabled] false makes an otherwise actionable row unavailable.
class LiquidSettingsTile extends StatelessWidget {
  const LiquidSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.focusNode,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        leading: leading,
        trailing:
            trailing ??
            (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
        enabled: enabled,
        onTap: enabled ? onTap : null,
        focusNode: focusNode,
        textColor: colors.content,
        iconColor: colors.content.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// A setting whose entire row toggles one controlled value.
/// The knob uses LiquidToggle; its own focus/pointer path is excluded so a row
/// tap or keyboard activation can never fire two callbacks.
class LiquidSwitchTile extends StatelessWidget {
  const LiquidSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.backdrop = nativeBackdrop,
    this.focusNode,
    this.autofocus = false,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Backdrop backdrop;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    void activate() => onChanged?.call(!value);
    return Material(
      type: MaterialType.transparency,
      child: ControlFocus(
        enabled: onChanged != null,
        focusNode: focusNode,
        autofocus: autofocus,
        onActivate: activate,
        borderRadius: BorderRadius.circular(16),
        child: MergeSemantics(
          child: Semantics(
            enabled: onChanged != null,
            toggled: value,
            onTap: onChanged == null ? null : activate,
            child: InkWell(
              onTap: onChanged == null ? null : activate,
              canRequestFocus: false,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                title: Text(title),
                subtitle: subtitle == null ? null : Text(subtitle!),
                leading: leading,
                enabled: onChanged != null,
                textColor: colors.content,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                trailing: ExcludeFocus(
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: LiquidToggle(
                        selected: value,
                        onSelect: onChanged,
                        backdrop: backdrop,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labeled slider with an application formatter and change lifecycle hooks.
class LiquidSliderTile extends StatelessWidget {
  const LiquidSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.formatter,
    this.onChangeStart,
    this.onChangeEnd,
    this.backdrop = nativeBackdrop,
  }) : assert(min <= max),
       assert(divisions == null || divisions > 0);
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value)? formatter;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Backdrop backdrop;

  String _format(double v) =>
      formatter?.call(v) ??
      '${(max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: colors.content, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: Text(
                    _format(value),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: onChanged == null
                          ? colors.content.withValues(alpha: 0.4)
                          : colors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                subtitle!,
                style: TextStyle(
                  color: colors.content.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 8),
          LiquidSlider(
            value: value,
            onValueChanged: onChanged,
            backdrop: backdrop,
            valueRange: (start: min, end: max),
            divisions: divisions,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
            semanticLabel: title,
            semanticFormatterCallback: _format,
          ),
        ],
      ),
    );
  }
}
