import 'package:flutter/material.dart';

import '../backdrop.dart';
import '../components/liquid_panel.dart';
import '../shapes/rounded_rectangular_shape.dart';
import '../theme/liquid_glass_theme.dart';

/// A quiet surface for information-bearing controls. Focus/error strokes belong
/// to the input decorator; the glass never paints a second competing outline.
class ControlSurface extends StatelessWidget {
  const ControlSurface({
    super.key,
    required this.backdrop,
    required this.child,
  });
  final Backdrop backdrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return LiquidPanel(
      backdrop: backdrop,
      shape: const RoundedRectangle(16),
      surfaceColor: Color.alphaBlend(
        colors.container,
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
      ),
      showHighlight: false,
      showShadow: false,
      blurRadius: 6,
      refractionHeight: 6,
      refractionAmount: 8,
      child: child,
    );
  }
}

InputDecoration liquidInputDecoration(
  BuildContext context, {
  String? label,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final colors = LiquidGlassTheme.of(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    labelStyle: TextStyle(color: colors.content.withValues(alpha: 0.7)),
    hintStyle: TextStyle(color: colors.content.withValues(alpha: 0.6)),
    helperStyle: TextStyle(color: colors.content.withValues(alpha: 0.7)),
    errorStyle: TextStyle(color: colors.destructive),
    helperMaxLines: 3,
    errorMaxLines: 3,
    border: border(colors.content.withValues(alpha: 0.14)),
    enabledBorder: border(colors.content.withValues(alpha: 0.14)),
    disabledBorder: border(colors.content.withValues(alpha: 0.07)),
    focusedBorder: border(colors.accent, 2),
    errorBorder: border(colors.destructive),
    focusedErrorBorder: border(colors.destructive, 2),
  );
}
