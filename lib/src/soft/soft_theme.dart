import 'package:flutter/material.dart';

/// The colours, type and shape every soft component reads.
///
/// Neutral roles are black or white at fixed opacities, so they sit on any
/// surface; [accent] is the app's brand colour. Components never hard-code a
/// colour: they ask for a role here, so an app retints the whole family by
/// handing its own [SoftThemeData] to [SoftTheme].
@immutable
class SoftThemeData {
  const SoftThemeData({
    required this.brightness,
    required this.accent,
    required this.accentText,
    required this.accentTint,
    required this.onAccent,
    required this.background,
    required this.backgroundElevated,
    required this.card,
    required this.bar,
    required this.fillSolid,
    required this.fillThin,
    required this.labelPrimary,
    required this.labelPrimaryVariant,
    required this.labelSecondary,
    required this.labelSecondaryVariant,
    required this.labelTertiary,
    required this.labelQuaternary,
    required this.divider,
    required this.press,
    required this.pressBackground,
    required this.controls,
    required this.segmentTrack,
    required this.segmentIndicator,
    required this.error,
    required this.success,
    required this.warning,
    required this.badge,
    required this.scrim,
    required this.frostTint,
    required this.frostSigma,
    required this.shadow,
    this.fontFamily,
  });

  /// Light palette. [accent] is the brand colour every selected / primary
  /// element takes; [accentText] is the accent used for text and icons (it can
  /// be lighter in dark mode for legibility).
  factory SoftThemeData.light({
    Color accent = const Color(0xFF0080FF),
    Color? accentText,
    Color onAccent = const Color(0xFFFFFFFF),
    String? fontFamily,
  }) => SoftThemeData(
    brightness: Brightness.light,
    accent: accent,
    accentText: accentText ?? accent,
    accentTint: accent.withValues(alpha: 0.15),
    onAccent: onAccent,
    background: const Color(0xFFF0F1F2),
    backgroundElevated: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    bar: const Color(0xFFFAFAFA),
    fillSolid: const Color(0xFFEBEBEB),
    fillThin: const Color(0x0A000000),
    labelPrimary: const Color(0xE6000000),
    labelPrimaryVariant: const Color(0xB8000000),
    labelSecondary: const Color(0x8A000000),
    labelSecondaryVariant: const Color(0x66000000),
    labelTertiary: const Color(0x42000000),
    labelQuaternary: const Color(0x14000000),
    divider: const Color(0x1F000000),
    press: const Color(0x1F000000),
    pressBackground: const Color(0x14000000),
    controls: const Color(0x29000000),
    segmentTrack: const Color(0x0F000000),
    segmentIndicator: const Color(0xFFFFFFFF),
    error: const Color(0xFFDB382C),
    success: const Color(0xFF00BD13),
    warning: const Color(0xFFFF7700),
    badge: const Color(0xFFEB3B2F),
    scrim: const Color(0x33000000),
    // The no-blur fallback colour of the reference's floating surfaces,
    // thinned so the page reads through the blur.
    frostTint: const Color(0xA6F0F0F0),
    frostSigma: 20,
    shadow: const Color(0x1F000000),
    fontFamily: fontFamily,
  );

  /// Dark palette.
  factory SoftThemeData.dark({
    Color accent = const Color(0xFF1A8CFF),
    Color? accentText,
    Color onAccent = const Color(0xFFFFFFFF),
    String? fontFamily,
  }) => SoftThemeData(
    brightness: Brightness.dark,
    accent: accent,
    accentText:
        accentText ?? Color.lerp(accent, const Color(0xFFFFFFFF), 0.25)!,
    accentTint: accent.withValues(alpha: 0.25),
    onAccent: onAccent,
    background: const Color(0xFF000000),
    backgroundElevated: const Color(0xFF1E1E1E),
    card: const Color(0xFF1A1A1A),
    bar: const Color(0xFF1E1E1E),
    fillSolid: const Color(0xFF262626),
    fillThin: const Color(0x14FFFFFF),
    labelPrimary: const Color(0xE6FFFFFF),
    labelPrimaryVariant: const Color(0xB8FFFFFF),
    labelSecondary: const Color(0x8AFFFFFF),
    labelSecondaryVariant: const Color(0x66FFFFFF),
    labelTertiary: const Color(0x4DFFFFFF),
    labelQuaternary: const Color(0x26FFFFFF),
    divider: const Color(0x33FFFFFF),
    press: const Color(0x33FFFFFF),
    pressBackground: const Color(0x26FFFFFF),
    controls: const Color(0x40FFFFFF),
    segmentTrack: const Color(0x1FFFFFFF),
    segmentIndicator: const Color(0x33FFFFFF),
    error: const Color(0xFFFF6C61),
    success: const Color(0xFF24B232),
    warning: const Color(0xFFF08222),
    badge: const Color(0xFFEB493D),
    scrim: const Color(0x99000000),
    frostTint: const Color(0x8C333333),
    frostSigma: 20,
    shadow: const Color(0x66000000),
    fontFamily: fontFamily,
  );

  final Brightness brightness;
  final Color accent;
  final Color accentText;

  /// The accent at low opacity — a tinted fill (selected chip, secondary
  /// button).
  final Color accentTint;
  final Color onAccent;

  /// The page behind grouped cards.
  final Color background;

  /// Sheets, dialogs, popups — surfaces raised above the page.
  final Color backgroundElevated;

  /// A card or a group of list rows.
  final Color card;

  /// A solid bar (toolbar, docked bottom bar).
  final Color bar;

  /// A solid neutral fill (an inactive button).
  final Color fillSolid;

  /// A barely-there neutral fill (a search field).
  final Color fillThin;

  final Color labelPrimary;
  final Color labelPrimaryVariant;
  final Color labelSecondary;
  final Color labelSecondaryVariant;
  final Color labelTertiary;
  final Color labelQuaternary;

  /// Hairlines between rows.
  final Color divider;

  /// The mask laid over a pressed row or card.
  final Color press;

  /// A pressed / selected neutral background (a selected nav item).
  final Color pressBackground;

  /// Unfilled control parts: slider track, unchecked box outline.
  final Color controls;
  final Color segmentTrack;
  final Color segmentIndicator;
  final Color error;
  final Color success;
  final Color warning;
  final Color badge;

  /// Behind a modal surface.
  final Color scrim;

  /// Laid over the blur of a floating surface — part transparent, so the page
  /// reads through.
  final Color frostTint;
  final double frostSigma;
  final Color shadow;
  final String? fontFamily;

  bool get isDark => brightness == Brightness.dark;

  /// A text style in this theme's family. [weight] defaults to regular;
  /// medium is [FontWeight.w500].
  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? labelPrimary,
    height: height,
    fontFamily: fontFamily,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // The type scale (size, weight). Line height is left to the font.
  TextStyle get displaySmall => text(32, weight: FontWeight.w600);
  TextStyle get displayXSmall => text(24, weight: FontWeight.w600);
  TextStyle get headlineLarge => text(28, weight: FontWeight.w500);
  TextStyle get headlineMedium => text(20, weight: FontWeight.w500);
  TextStyle get headlineSmall => text(18, weight: FontWeight.w600);
  TextStyle get headlineXSmall => text(16, weight: FontWeight.w500);
  TextStyle get bodyXLarge => text(16);
  TextStyle get bodyLarge => text(15);
  TextStyle get bodyMedium => text(14);
  TextStyle get bodySmall => text(13);
  TextStyle get bodyXSmall => text(12);
  TextStyle get description => text(12, weight: FontWeight.w500);
  TextStyle get buttonLarge => text(16, weight: FontWeight.w500);
  TextStyle get buttonMedium => text(14, weight: FontWeight.w500);
  TextStyle get buttonSmall => text(12, weight: FontWeight.w500);
  TextStyle get caption => text(10);
  TextStyle get tag => text(10, weight: FontWeight.w500);

  SoftThemeData copyWith({
    Color? accent,
    Color? accentText,
    Color? accentTint,
    Color? onAccent,
    Color? background,
    Color? backgroundElevated,
    Color? card,
    Color? bar,
    Color? frostTint,
    double? frostSigma,
    String? fontFamily,
  }) => SoftThemeData(
    brightness: brightness,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentTint: accentTint ?? this.accentTint,
    onAccent: onAccent ?? this.onAccent,
    background: background ?? this.background,
    backgroundElevated: backgroundElevated ?? this.backgroundElevated,
    card: card ?? this.card,
    bar: bar ?? this.bar,
    fillSolid: fillSolid,
    fillThin: fillThin,
    labelPrimary: labelPrimary,
    labelPrimaryVariant: labelPrimaryVariant,
    labelSecondary: labelSecondary,
    labelSecondaryVariant: labelSecondaryVariant,
    labelTertiary: labelTertiary,
    labelQuaternary: labelQuaternary,
    divider: divider,
    press: press,
    pressBackground: pressBackground,
    controls: controls,
    segmentTrack: segmentTrack,
    segmentIndicator: segmentIndicator,
    error: error,
    success: success,
    warning: warning,
    badge: badge,
    scrim: scrim,
    frostTint: frostTint ?? this.frostTint,
    frostSigma: frostSigma ?? this.frostSigma,
    shadow: shadow,
    fontFamily: fontFamily ?? this.fontFamily,
  );
}

/// Corner radii (nominal; the continuous-corner shapes the components use
/// smooth these into a squircle).
abstract final class SoftRadius {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;
  static const double xxxxl = 32;
}

/// The standard easing curves.
abstract final class SoftCurves {
  static const Curve ease = Cubic(0.33, 0, 0.67, 1);
  static const Curve moveEase = Cubic(0.3, 0, 0.1, 1);
  static const Curve outEase = Cubic(0.3, 0, 1, 1);
  static const Curve inEase = Cubic(0, 0, 0.1, 1);
}

/// Supplies a [SoftThemeData] to the soft components below it.
class SoftTheme extends InheritedWidget {
  const SoftTheme({super.key, required this.data, required super.child});

  final SoftThemeData data;

  /// The nearest theme, or a default one in the Material theme's brightness
  /// when there is none.
  static SoftThemeData of(BuildContext context) {
    final SoftTheme? theme = context
        .dependOnInheritedWidgetOfExactType<SoftTheme>();
    if (theme != null) return theme.data;
    return Theme.of(context).brightness == Brightness.dark
        ? SoftThemeData.dark()
        : SoftThemeData.light();
  }

  @override
  bool updateShouldNotify(SoftTheme oldWidget) => oldWidget.data != data;
}
