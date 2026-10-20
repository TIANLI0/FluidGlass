import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../backdrop.dart';
import '../backdrops/native_backdrop.dart';
import '../internal/control_surface.dart';
import '../theme/liquid_glass_theme.dart';

/// A glass input that retains Flutter's text editing, IME and Form behavior.
///
/// Supply a [controller] for controlled text, or [initialValue] for a field
/// whose editing state is owned by Flutter. External controllers/focus nodes
/// remain owned by the caller. Validation, saving and reset use [Form].
class LiquidTextField extends StatelessWidget {
  const LiquidTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leading,
    this.trailing,
    this.backdrop = nativeBackdrop,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.style,
  }) : assert(controller == null || initialValue == null),
       assert(!obscureText || maxLines == 1),
       assert(minLines == null || minLines > 0),
       assert(maxLines == null || maxLines > 0),
       assert(minLines == null || maxLines == null || minLines <= maxLines);

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? leading;
  final Widget? trailing;
  final Backdrop backdrop;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode autovalidateMode;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => ControlSurface(
    backdrop: backdrop,
    child: TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      cursorColor: LiquidGlassTheme.of(context).accent,
      style: TextStyle(
        color: LiquidGlassTheme.of(
          context,
        ).content.withValues(alpha: enabled ? 1 : 0.4),
        fontSize: 15,
      ).merge(style),
      decoration: liquidInputDecoration(
        context,
        label: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: leading,
        suffixIcon: trailing,
      ),
    ),
  );
}

/// A search input with a stable clear-button slot and optional debouncing.
///
/// [onChanged] follows user edits and explicit clearing; programmatic controller
/// updates follow TextField's convention and do not fire it. Submission flushes
/// a pending debounce before [onSubmitted]. Pending work is cancelled on dispose.
class LiquidSearchField extends StatefulWidget {
  const LiquidSearchField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search',
    this.clearLabel = 'Clear search',
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.debounce = Duration.zero,
    this.backdrop = nativeBackdrop,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final String clearLabel;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final Duration debounce;
  final Backdrop backdrop;

  @override
  State<LiquidSearchField> createState() => _LiquidSearchFieldState();
}

class _LiquidSearchFieldState extends State<LiquidSearchField> {
  late TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  Timer? _timer;
  String? _pending;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (_pending != null && _pending != _controller.text) {
      _timer?.cancel();
      _pending = null;
    }
  }

  @override
  void didUpdateWidget(LiquidSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final value = _controller.value;
      _controller.removeListener(_controllerChanged);
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? TextEditingController.fromValue(value);
      _controller.addListener(_controllerChanged);
      _timer?.cancel();
      _pending = null;
    }
    if (!widget.enabled) {
      _timer?.cancel();
      _pending = null;
    }
    if (oldWidget.debounce != widget.debounce && _pending != null) {
      // Never call application code synchronously from didUpdateWidget: a
      // zero debounce could otherwise make its parent setState during build.
      _timer?.cancel();
      _timer = null;
      if (widget.debounce > Duration.zero) {
        _timer = Timer(widget.debounce, _flush);
      } else {
        // Right after this frame rather than on a zero timer: a zero timer
        // still waits for the clock to move, which on an idle screen (and
        // under a test's fake clock) it may not do until the next input.
        final String? pending = _pending;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          // Superseded meanwhile — retyped, cleared, re-armed or disposed.
          if (!mounted || _timer != null || !identical(_pending, pending)) {
            return;
          }
          _flush();
        });
      }
    }
  }

  void _changed(String value) {
    _timer?.cancel();
    _pending = null;
    if (!widget.enabled) return;
    if (widget.debounce <= Duration.zero) {
      widget.onChanged?.call(value);
    } else {
      _pending = value;
      _timer = Timer(widget.debounce, _flush);
    }
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && widget.enabled) widget.onChanged?.call(pending);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_controllerChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, child) => LiquidTextField(
          controller: _controller,
          backdrop: widget.backdrop,
          enabled: widget.enabled,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          hintText: widget.hintText,
          textInputAction: TextInputAction.search,
          leading: const Icon(Icons.search_rounded, size: 21),
          onChanged: _changed,
          onSubmitted: (text) {
            _flush();
            widget.onSubmitted?.call(text);
          },
          trailing: SizedBox(
            width: 48,
            child: ExcludeFocus(
              excluding: value.text.isEmpty,
              child: ExcludeSemantics(
                excluding: value.text.isEmpty,
                child: IgnorePointer(
                  ignoring: value.text.isEmpty,
                  child: AnimatedOpacity(
                    duration:
                        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    opacity: value.text.isEmpty ? 0 : 1,
                    child: IconButton(
                      tooltip: widget.clearLabel,
                      onPressed: !widget.enabled
                          ? null
                          : () {
                              _controller.clear();
                              _changed('');
                            },
                      icon: const Icon(Icons.cancel_outlined, size: 19),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
