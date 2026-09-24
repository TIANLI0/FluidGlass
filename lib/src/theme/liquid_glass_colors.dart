import 'package:flutter/material.dart';

/// The colours the liquid-glass components draw with.
///
/// The glass itself is colourless — it refracts whatever is behind it. What
/// needs a colour is everything drawn *on* it: the tint that keeps a panel
/// legible over busy content, the accent a selection is marked in, the text of
/// a row. Those used to be iOS's values inlined in each component, which made
/// the components unusable in an app with its own palette — an accent is not a
/// detail an app can leave to a library.
///
/// [light] and [dark] are exactly what the components drew before this type
/// existed, so an app that supplies nothing keeps the same appearance.
///
/// One palette, not a light/dark pair: an app already branches on brightness
/// for its own colours, and the components resolve the default pair off
/// [ThemeData.brightness] when no palette is supplied. Override a field or two
/// off the matching default rather than spelling out all six:
///
/// ```dart
/// LiquidGlassTheme(
///   colors: (isDark ? LiquidGlassColors.dark : LiquidGlassColors.light)
///       .copyWith(accent: brandCoral),
///   child: child,
/// )
/// ```
@immutable
class LiquidGlassColors {
  const LiquidGlassColors({
    required this.accent,
    required this.toggleAccent,
    required this.container,
    required this.content,
    required this.track,
    required this.destructive,
    this.glow = const Color(0xFFFFFFFF),
    this.success = const Color(0xFF34C759),
  });

  /// What the components drew on a light [Theme] before this type existed.
  ///
  /// `final` rather than `const` on purpose: the alphas are written as
  /// [Color.withValues] so they stay bit-identical to the values the components
  /// used to inline. Spelling them as packed hex instead would shift the stored
  /// float alpha in the third decimal — invisible, but no longer *the same
  /// colour*, which is the one promise this default makes.
  static final LiquidGlassColors light = LiquidGlassColors(
    accent: const Color(0xFF0088FF),
    toggleAccent: const Color(0xFF34C759),
    container: const Color(0xFFFAFAFA).withValues(alpha: 0.4),
    content: const Color(0xFF000000),
    track: const Color(0xFF787878).withValues(alpha: 0.2),
    destructive: const Color(0xFFE5484D),
  );

  /// What the components drew on a dark [Theme] before this type existed.
  static final LiquidGlassColors dark = LiquidGlassColors(
    accent: const Color(0xFF0091FF),
    toggleAccent: const Color(0xFF30D158),
    container: const Color(0xFF121212).withValues(alpha: 0.4),
    content: const Color(0xFFFFFFFF),
    track: const Color(0xFF787880).withValues(alpha: 0.36),
    destructive: const Color(0xFFFF6369),
    success: const Color(0xFF30D158),
  );

  /// The default palette for [brightness].
  static LiquidGlassColors forBrightness(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// What a selection is marked in.
  ///
  /// The pill of a [LiquidBottomTabs] magnifies the tabs beneath it in this
  /// colour; a [LiquidSlider] fills its track with it.
  final Color accent;

  /// The "on" colour of a [LiquidToggle].
  ///
  /// Separate from [accent] because a switch reads as on/off rather than as
  /// selected — iOS keeps it green whatever the app's accent is. Pass [accent]
  /// here to collapse the two.
  final Color toggleAccent;

  /// The tint drawn over the refracted backdrop.
  ///
  /// This is what stops a glass surface from disappearing over busy content, so
  /// it carries its own alpha — a fully opaque value turns the element into a
  /// plain panel and wastes the refraction behind it.
  final Color container;

  /// Text and icons drawn on the glass.
  ///
  /// Components that need a fainter derivative (separators, the wash under a
  /// press) step this one down themselves, so pass it fully opaque.
  final Color content;

  /// The unfilled part of a [LiquidSlider]'s and a [LiquidToggle]'s track.
  ///
  /// Carries its own alpha: it sits on the glass, not behind it.
  final Color track;

  /// A row that removes something — see [LiquidMenuItem.isDestructive].
  ///
  /// Also the colour a [RimLight] pulses in when something failed.
  final Color destructive;

  /// The colour of light itself: the glow under a finger, the light a press
  /// spills onto neighbouring glass, the comet a [RimLight] runs while
  /// something loads.
  ///
  /// White by default, which is what every glow was before this field
  /// existed. Tint it and every light in the subtree takes the tint — an app
  /// that gives each of its characters a colour can light the glass in the
  /// colour of whoever is on screen. Keep it light: it is added to what is
  /// under it, so a dark colour adds almost nothing.
  final Color glow;

  /// The colour a [RimLight] sweeps in when something succeeded.
  final Color success;

  LiquidGlassColors copyWith({
    Color? accent,
    Color? toggleAccent,
    Color? container,
    Color? content,
    Color? track,
    Color? destructive,
    Color? glow,
    Color? success,
  }) {
    return LiquidGlassColors(
      accent: accent ?? this.accent,
      toggleAccent: toggleAccent ?? this.toggleAccent,
      container: container ?? this.container,
      content: content ?? this.content,
      track: track ?? this.track,
      destructive: destructive ?? this.destructive,
      glow: glow ?? this.glow,
      success: success ?? this.success,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassColors &&
      other.accent == accent &&
      other.toggleAccent == toggleAccent &&
      other.container == container &&
      other.content == content &&
      other.track == track &&
      other.destructive == destructive &&
      other.glow == glow &&
      other.success == success;

  @override
  int get hashCode => Object.hash(
    accent,
    toggleAccent,
    container,
    content,
    track,
    destructive,
    glow,
    success,
  );

  @override
  String toString() =>
      'LiquidGlassColors(accent: $accent, '
      'toggleAccent: $toggleAccent, container: $container, '
      'content: $content, track: $track, destructive: $destructive, '
      'glow: $glow, success: $success)';
}
