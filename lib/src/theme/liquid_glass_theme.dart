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
    final LiquidGlassTheme? theme = context
        .dependOnInheritedWidgetOfExactType<LiquidGlassTheme>();
    final LiquidGlassColors colors =
        theme?.colors ??
        LiquidGlassColors.forBrightness(Theme.of(context).brightness);
    return _forAccessibility(context, colors);
  }

  /// Raises the surface tint to opaque when the reader has asked for contrast.
  ///
  /// Increase Contrast is a request to stop deciding legibility by whatever
  /// happens to be behind a surface. The tint is where that is decided —
  /// [LiquidGlassColors.container] ships at alpha 0.4 — so making it opaque is
  /// the whole response, and it reaches every component at once because they
  /// all read their colours from here.
  ///
  /// Applied to an app-supplied palette too: an app that set its own brand
  /// colours has not thereby opted out of the reader's accessibility settings.
  ///
  /// The other half of the response is the refraction, a *moving* distortion
  /// under whatever is being read through it. That is dropped separately, by
  /// clamping the tier in `DrawBackdrop` — which is also the cheap path.
  ///
  /// **Only [MediaQueryData.highContrast] is available to check.** Flutter
  /// surfaces `accessibleNavigation`, `invertColors`, `highContrast`,
  /// `disableAnimations` and `boldText`, and nothing for *Reduce
  /// Transparency* — the setting that most directly asks a glass library to
  /// stand down. Reaching it needs a platform channel. `highContrast` is iOS
  /// 13+ and Android API 34+ only, so on everything else this returns the
  /// palette untouched and the app has to offer its own switch, which
  /// [GlassQualityScope] is for.
  static LiquidGlassColors _forAccessibility(
    BuildContext context,
    LiquidGlassColors colors,
  ) {
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    if (media == null || !media.highContrast) return colors;
    if (colors.container.a >= 1.0) return colors;
    return colors.copyWith(container: colors.container.withValues(alpha: 1.0));
  }

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) =>
      oldWidget.colors != colors;
}
