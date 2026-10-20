import 'package:flutter/material.dart';

import '../backdrop.dart';
import '../backdrops/native_backdrop.dart';
import '../internal/control_focus.dart';
import '../internal/control_surface.dart';
import '../theme/liquid_glass_theme.dart';
import 'liquid_command_palette.dart';
import 'liquid_selection.dart';

/// A controlled generic selector with a searchable, accessible chooser.
///
/// Only [onChanged] requests a new value; the caller returns it through [value].
/// Dismissal leaves the value unchanged. Null callbacks or no enabled options
/// disable the control. For Form-owned state use [LiquidSelectFormField].
class LiquidSelect<T extends Object> extends StatefulWidget {
  const LiquidSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.helperText,
    this.errorText,
    this.hintText = 'Choose an option',
    this.backdrop = nativeBackdrop,
    this.focusNode,
    this.autofocus = false,
    this.labels = const LiquidCommandPaletteLabels(
      title: 'Choose an option',
      searchHint: 'Search options…',
    ),
  });
  final List<LiquidSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? helperText;
  final String? errorText;
  final String hintText;
  final Backdrop backdrop;
  final FocusNode? focusNode;
  final bool autofocus;
  final LiquidCommandPaletteLabels labels;

  @override
  State<LiquidSelect<T>> createState() => _LiquidSelectState<T>();
}

class _LiquidSelectState<T extends Object> extends State<LiquidSelect<T>> {
  bool _opening = false;
  final GlobalKey _anchor = GlobalKey();
  bool get _enabled =>
      widget.onChanged != null && widget.options.any((o) => o.enabled);

  Future<void> _open() async {
    if (!_enabled || _opening) return;
    final List<LiquidSelectOption<T>> snapshot = List.of(widget.options);
    final RenderBox? box =
        _anchor.currentContext?.findRenderObject() as RenderBox?;
    final int selected = snapshot.indexWhere((o) => o.value == widget.value);
    setState(() => _opening = true);
    try {
      final command = await showLiquidCommandPalette(
        context: context,
        labels: widget.labels,
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        originRadius: 16,
        initialSelectedId: selected < 0 ? null : '$selected',
        commands: <LiquidCommand>[
          for (int i = 0; i < snapshot.length; i++)
            LiquidCommand(
              id: '$i',
              label: snapshot[i].label,
              description: snapshot[i].description,
              icon: snapshot[i].icon,
              enabled: snapshot[i].enabled,
            ),
        ],
      );
      if (!mounted || command == null || !_enabled) return;
      final option = snapshot[int.parse(command.id)];
      // Availability can change while the chooser is open. Never commit an
      // option that has since been removed or disabled by the application.
      if (widget.options.any((o) => o.value == option.value && o.enabled) &&
          option.value != widget.value) {
        widget.onChanged?.call(option.value);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.options.map((o) => o.value).toSet().length ==
          widget.options.length,
      'Select option values must be unique.',
    );
    final current = widget.options
        .where((o) => o.value == widget.value)
        .firstOrNull;
    final colors = LiquidGlassTheme.of(context);
    return ControlSurface(
      backdrop: widget.backdrop,
      child: Material(
        type: MaterialType.transparency,
        child: ControlFocus(
          enabled: _enabled,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onActivate: _open,
          borderRadius: BorderRadius.circular(16),
          child: Semantics(
            container: true,
            button: true,
            enabled: _enabled,
            expanded: _opening,
            label: widget.label,
            value: current?.label ?? widget.hintText,
            hint: widget.errorText ?? widget.helperText,
            onTap: _enabled ? _open : null,
            excludeSemantics: true,
            child: InkWell(
              key: _anchor,
              onTap: _enabled ? _open : null,
              canRequestFocus: false,
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                isEmpty: current == null,
                isFocused: _opening,
                decoration:
                    liquidInputDecoration(
                      context,
                      label: widget.label,
                      helperText: widget.helperText,
                      errorText: widget.errorText,
                    ).copyWith(
                      enabled: _enabled,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                child: Row(
                  children: <Widget>[
                    if (current?.icon != null) ...<Widget>[
                      Icon(current!.icon, size: 20, color: colors.accent),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        current?.label ?? widget.hintText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.content.withValues(
                            alpha: !_enabled
                                ? 0.4
                                : current == null
                                ? 0.6
                                : 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 20,
                      color: colors.content.withValues(alpha: 0.55),
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

/// A selector whose value belongs to Flutter's Form state, like TextFormField.
/// [initialValue] participates in reset; [onSaved] receives the current value.
class LiquidSelectFormField<T extends Object> extends FormField<T> {
  LiquidSelectFormField({
    super.key,
    required List<LiquidSelectOption<T>> options,
    super.initialValue,
    ValueChanged<T?>? onChanged,
    super.onSaved,
    super.validator,
    super.onReset,
    super.enabled = true,
    super.autovalidateMode = AutovalidateMode.disabled,
    String? label,
    String? helperText,
    String hintText = 'Choose an option',
    Backdrop backdrop = nativeBackdrop,
    FocusNode? focusNode,
    bool autofocus = false,
    LiquidCommandPaletteLabels labels = const LiquidCommandPaletteLabels(
      title: 'Choose an option',
      searchHint: 'Search options…',
    ),
  }) : super(
         builder: (field) => LiquidSelect<T>(
           options: options,
           value: field.value,
           onChanged: !field.widget.enabled
               ? null
               : (value) {
                   field.didChange(value);
                   onChanged?.call(value);
                 },
           label: label,
           helperText: helperText,
           errorText: field.errorText,
           hintText: hintText,
           backdrop: backdrop,
           focusNode: focusNode,
           autofocus: autofocus,
           labels: labels,
         ),
       );
}
