import 'package:flutter/material.dart';

import '../theme/liquid_glass_theme.dart';

/// Shared, typed option data for radio groups and selectors.
/// Values must be unique under their normal equality operator.
@immutable
class LiquidSelectOption<T extends Object> {
  const LiquidSelectOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
  });
  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool enabled;
}

/// A controlled checkbox, optionally accompanied by a whole-row label.
/// Null [onChanged] disables both pointer and keyboard input.
class LiquidCheckbox extends StatelessWidget {
  const LiquidCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.helperText,
    this.tristate = false,
    this.isError = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(tristate || value != null);
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final String? helperText;
  final bool tristate;
  final bool isError;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    final Widget control = label == null
        ? Checkbox(
            value: value,
            onChanged: onChanged,
            tristate: tristate,
            isError: isError,
            focusNode: focusNode,
            autofocus: autofocus,
            semanticLabel: semanticLabel,
            shape: shape,
            activeColor: colors.accent,
            materialTapTargetSize: MaterialTapTargetSize.padded,
          )
        : CheckboxListTile(
            value: value,
            onChanged: onChanged,
            tristate: tristate,
            isError: isError,
            focusNode: focusNode,
            autofocus: autofocus,
            title: Text(
              label!,
              style: TextStyle(
                color: colors.content.withValues(
                  alpha: onChanged == null ? 0.4 : 1,
                ),
              ),
            ),
            subtitle: helperText == null
                ? null
                : Text(
                    helperText!,
                    style: TextStyle(
                      color: colors.content.withValues(
                        alpha: onChanged == null ? 0.4 : 0.7,
                      ),
                    ),
                  ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            checkboxShape: shape,
            activeColor: colors.accent,
            materialTapTargetSize: MaterialTapTargetSize.padded,
          );
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.content),
        child: label != null && semanticLabel != null
            ? Semantics(label: semanticLabel, child: control)
            : control,
      ),
    );
  }
}

/// A controlled, typed radio group with native roving keyboard focus.
/// Disabled options remain visible and are skipped by keyboard selection.
class LiquidRadioGroup<T extends Object> extends StatelessWidget {
  const LiquidRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final List<LiquidSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    assert(
      options.map((o) => o.value).toSet().length == options.length,
      'Radio option values must be unique.',
    );
    final colors = LiquidGlassTheme.of(context);
    return Semantics(
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (next) => onChanged?.call(next),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final option in options)
                RadioListTile<T>(
                  value: option.value,
                  enabled: onChanged != null && option.enabled,
                  activeColor: colors.accent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: colors.content.withValues(
                        alpha: onChanged != null && option.enabled ? 1 : 0.4,
                      ),
                    ),
                  ),
                  subtitle: option.description == null
                      ? null
                      : Text(
                          option.description!,
                          style: TextStyle(
                            color: colors.content.withValues(
                              alpha: onChanged != null && option.enabled
                                  ? 0.7
                                  : 0.4,
                            ),
                          ),
                        ),
                  secondary: option.icon == null
                      ? null
                      : Icon(
                          option.icon,
                          color: colors.content.withValues(
                            alpha: onChanged != null && option.enabled
                                ? 0.65
                                : 0.4,
                          ),
                        ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single-choice chip. The caller owns selection across a group of chips.
class LiquidChoiceChip extends StatelessWidget {
  const LiquidChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.tooltip,
    this.focusNode,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      tooltip: tooltip,
      focusNode: focusNode,
      selectedColor: colors.accent.withValues(alpha: 0.16),
      backgroundColor: colors.content.withValues(alpha: 0.035),
      labelStyle: TextStyle(
        color: (selected ? colors.accent : colors.content).withValues(
          alpha: onSelected == null ? 0.4 : 1,
        ),
      ),
      chipAnimationStyle: _chipAnimationStyle(context),
      side: BorderSide(
        color: (selected ? colors.accent : colors.content).withValues(
          alpha: selected ? 0.35 : 0.12,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// An independently selected filter. Compose several in a [Wrap] for multi-select.
class LiquidFilterChip extends StatelessWidget {
  const LiquidFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.tooltip,
    this.focusNode,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      tooltip: tooltip,
      focusNode: focusNode,
      selectedColor: colors.accent.withValues(alpha: 0.16),
      backgroundColor: colors.content.withValues(alpha: 0.035),
      checkmarkColor: colors.accent,
      labelStyle: TextStyle(
        color: (selected ? colors.accent : colors.content).withValues(
          alpha: onSelected == null ? 0.4 : 1,
        ),
      ),
      chipAnimationStyle: _chipAnimationStyle(context),
      side: BorderSide(
        color: (selected ? colors.accent : colors.content).withValues(
          alpha: selected ? 0.35 : 0.12,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

ChipAnimationStyle? _chipAnimationStyle(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? ChipAnimationStyle(
        enableAnimation: AnimationStyle.noAnimation,
        selectAnimation: AnimationStyle.noAnimation,
        avatarDrawerAnimation: AnimationStyle.noAnimation,
        deleteDrawerAnimation: AnimationStyle.noAnimation,
      )
    : null;
