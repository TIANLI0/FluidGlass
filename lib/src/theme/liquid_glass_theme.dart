import 'package:flutter/material.dart';

import 'liquid_glass_colors.dart';

/// Supplies the [LiquidGlassColors] the components below it draw with.
///
/// Without one, each component falls back to the default palette for the
/// enclosing [Theme]'s brightness — which is what it drew before this widget
/// existed. Wrap it once, as high as the components go:
///
/// ```dart
/// LiquidGlassTheme(
///   colors: LiquidGlassColors.forBrightness(Theme.of(context).brightness)
///       .copyWith(accent: brandCoral),
///   child: child,
/// )
/// ```
///
/// Per-element overrides still win where a component has one — a
/// [LiquidPanel]'s `surfaceColor`, for instance — so a single odd-coloured
/// surface does not need a theme of its own.
class LiquidGlassTheme extends InheritedWidget {
  const LiquidGlassTheme({
    required this.colors,
    required super.child,
    super.key,
  });

  final LiquidGlassColors colors;

  /// The palette in scope at [context].
  ///
  /// Falls back to [LiquidGlassColors.forBrightness] for the enclosing
  /// [Theme]'s brightness, so this never returns null and a component never has
  /// to branch on whether the app themed it.
  static LiquidGlassColors of(BuildContext context) {
    final LiquidGlassTheme? theme =
        context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>();
    if (theme != null) {
      return theme.colors;
    }
    return LiquidGlassColors.forBrightness(Theme.of(context).brightness);
  }

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) =>
      oldWidget.colors != colors;
}
