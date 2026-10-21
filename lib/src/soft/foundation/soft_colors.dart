import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colour scheme of the soft components.
///
/// The roles and both palettes follow the reference scheme one to one; the
/// comments name the components that read each role.
@immutable
class SoftColors {
  const SoftColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryVariant,
    required this.onPrimaryVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.disabledPrimary,
    required this.disabledOnPrimary,
    required this.disabledPrimaryButton,
    required this.disabledOnPrimaryButton,
    required this.disabledPrimarySlider,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryVariant,
    required this.onSecondaryVariant,
    required this.disabledSecondary,
    required this.disabledOnSecondary,
    required this.disabledSecondaryVariant,
    required this.disabledOnSecondaryVariant,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryContainerVariant,
    required this.onSecondaryContainerVariant,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryContainerVariant,
    required this.background,
    required this.onBackground,
    required this.onBackgroundVariant,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceSecondary,
    required this.onSurfaceVariantSummary,
    required this.onSurfaceVariantActions,
    required this.disabledOnSurface,
    required this.surfaceContainer,
    required this.onSurfaceContainer,
    required this.onSurfaceContainerVariant,
    required this.surfaceContainerHigh,
    required this.onSurfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurfaceContainerHighest,
    required this.outline,
    required this.dividerLine,
    required this.windowDimming,
    required this.sliderKeyPoint,
    required this.sliderKeyPointForeground,
    required this.sliderBackground,
    required this.bar,
    required this.labelPrimaryVariant,
  });

  /// The light palette.
  const SoftColors.light({
    this.primary = const Color(0xFF0080FF),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.primaryVariant = const Color(0xFF0080FF),
    this.onPrimaryVariant = const Color(0xFFAECDFF),
    this.error = const Color(0xFFDB382C),
    this.onError = const Color(0xFFFFFFFF),
    this.errorContainer = const Color(0x26EB3B2F),
    this.onErrorContainer = const Color(0xFFDB382C),
    this.disabledPrimary = const Color(0x4D0080FF),
    this.disabledOnPrimary = const Color(0xFFFFFFFF),
    this.disabledPrimaryButton = const Color(0x4D0080FF),
    this.disabledOnPrimaryButton = const Color(0x8AFFFFFF),
    this.disabledPrimarySlider = const Color(0xFFEBEBEB),
    this.primaryContainer = const Color(0xFF0080FF),
    this.onPrimaryContainer = const Color(0xFFFFFFFF),
    this.secondary = const Color(0xFFE5E5E5),
    this.onSecondary = const Color(0xFFFFFFFF),
    this.secondaryVariant = const Color(0x14000000),
    this.onSecondaryVariant = const Color(0xE6000000),
    this.disabledSecondary = const Color(0xFFF2F2F2),
    this.disabledOnSecondary = const Color(0x42000000),
    this.disabledSecondaryVariant = const Color(0x14000000),
    this.disabledOnSecondaryVariant = const Color(0x42000000),
    this.secondaryContainer = const Color(0x14000000),
    this.onSecondaryContainer = const Color(0x66000000),
    this.secondaryContainerVariant = const Color(0x14000000),
    this.onSecondaryContainerVariant = const Color(0x66000000),
    this.tertiaryContainer = const Color(0x260080FF),
    this.onTertiaryContainer = const Color(0xFF0080FF),
    this.tertiaryContainerVariant = const Color(0x260080FF),
    this.background = const Color(0xFFFFFFFF),
    this.onBackground = const Color(0xE6000000),
    this.onBackgroundVariant = const Color(0x8A000000),
    this.surface = const Color(0xFFF0F1F2),
    this.onSurface = const Color(0xE6000000),
    this.surfaceVariant = const Color(0xFFFFFFFF),
    this.onSurfaceSecondary = const Color(0x8A000000),
    this.onSurfaceVariantSummary = const Color(0x66000000),
    this.onSurfaceVariantActions = const Color(0x42000000),
    this.disabledOnSurface = const Color(0x42000000),
    this.surfaceContainer = const Color(0xFFFFFFFF),
    this.onSurfaceContainer = const Color(0xE6000000),
    this.onSurfaceContainerVariant = const Color(0x66000000),
    this.surfaceContainerHigh = const Color(0xFFE6E6E6),
    this.onSurfaceContainerHigh = const Color(0x42000000),
    this.surfaceContainerHighest = const Color(0xFFFFFFFF),
    this.onSurfaceContainerHighest = const Color(0xE6000000),
    this.outline = const Color(0x26000000),
    this.dividerLine = const Color(0x1F000000),
    this.windowDimming = const Color(0x33000000),
    this.sliderKeyPoint = const Color(0xFFF2F2F2),
    this.sliderKeyPointForeground = const Color(0xFF6EB5FF),
    this.sliderBackground = const Color(0x0D000000),
    this.bar = const Color(0xFFFAFAFA),
    this.labelPrimaryVariant = const Color(0xB8000000),
  }) : brightness = Brightness.light;

  /// The dark palette.
  const SoftColors.dark({
    this.primary = const Color(0xFF1A8CFF),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.primaryVariant = const Color(0xFF1A8CFF),
    this.onPrimaryVariant = const Color(0xFF99C7F1),
    this.error = const Color(0xFFFF6C61),
    this.onError = const Color(0xFFFFFFFF),
    this.errorContainer = const Color(0x40EB493D),
    this.onErrorContainer = const Color(0xFFFF6C61),
    this.disabledPrimary = const Color(0x4D1A8CFF),
    this.disabledOnPrimary = const Color(0xFF404040),
    this.disabledPrimaryButton = const Color(0x4D1A8CFF),
    this.disabledOnPrimaryButton = const Color(0x29FFFFFF),
    this.disabledPrimarySlider = const Color(0xFF262626),
    this.primaryContainer = const Color(0xFF5C9DFF),
    this.onPrimaryContainer = const Color(0xFFFFFFFF),
    this.secondary = const Color(0xFF757575),
    this.onSecondary = const Color(0xFFFFFFFF),
    this.secondaryVariant = const Color(0x26FFFFFF),
    this.onSecondaryVariant = const Color(0xE6FFFFFF),
    this.disabledSecondary = const Color(0x4D757575),
    this.disabledOnSecondary = const Color(0x4DFFFFFF),
    this.disabledSecondaryVariant = const Color(0x1AFFFFFF),
    this.disabledOnSecondaryVariant = const Color(0x4DFFFFFF),
    this.secondaryContainer = const Color(0x26FFFFFF),
    this.onSecondaryContainer = const Color(0x66FFFFFF),
    this.secondaryContainerVariant = const Color(0x26FFFFFF),
    this.onSecondaryContainerVariant = const Color(0x66FFFFFF),
    this.tertiaryContainer = const Color(0x401A8CFF),
    this.onTertiaryContainer = const Color(0xFF1A8CFF),
    this.tertiaryContainerVariant = const Color(0x401A8CFF),
    this.background = const Color(0xFF1E1E1E),
    this.onBackground = const Color(0xE6FFFFFF),
    this.onBackgroundVariant = const Color(0x8AFFFFFF),
    this.surface = const Color(0xFF000000),
    this.onSurface = const Color(0xE6FFFFFF),
    this.surfaceVariant = const Color(0x1AFFFFFF),
    this.onSurfaceSecondary = const Color(0x8AFFFFFF),
    this.onSurfaceVariantSummary = const Color(0x66FFFFFF),
    this.onSurfaceVariantActions = const Color(0x4DFFFFFF),
    this.disabledOnSurface = const Color(0x4DFFFFFF),
    this.surfaceContainer = const Color(0x1AFFFFFF),
    this.onSurfaceContainer = const Color(0xE6FFFFFF),
    this.onSurfaceContainerVariant = const Color(0x66FFFFFF),
    this.surfaceContainerHigh = const Color(0x33FFFFFF),
    this.onSurfaceContainerHigh = const Color(0x4DFFFFFF),
    this.surfaceContainerHighest = const Color(0xFF1E1E1E),
    this.onSurfaceContainerHighest = const Color(0xE6FFFFFF),
    this.outline = const Color(0x26FFFFFF),
    this.dividerLine = const Color(0x33FFFFFF),
    this.windowDimming = const Color(0x99000000),
    this.sliderKeyPoint = const Color(0xFF595959),
    this.sliderKeyPointForeground = const Color(0xFF5DAAFF),
    this.sliderBackground = const Color(0x1AFFFFFF),
    this.bar = const Color(0xFF1E1E1E),
    this.labelPrimaryVariant = const Color(0xB8FFFFFF),
  }) : brightness = Brightness.dark;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// Switch, Button, Slider.
  final Color primary;
  final Color onPrimary;

  /// Card.
  final Color primaryVariant;
  final Color onPrimaryVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  /// The disabled primary of the switch.
  final Color disabledPrimary;
  final Color disabledOnPrimary;

  /// The disabled primary of the button.
  final Color disabledPrimaryButton;
  final Color disabledOnPrimaryButton;

  /// The disabled primary of the slider.
  final Color disabledPrimarySlider;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryVariant;
  final Color onSecondaryVariant;
  final Color disabledSecondary;
  final Color disabledOnSecondary;
  final Color disabledSecondaryVariant;
  final Color disabledOnSecondaryVariant;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryContainerVariant;
  final Color onSecondaryContainerVariant;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryContainerVariant;
  final Color background;
  final Color onBackground;
  final Color onBackgroundVariant;

  /// The page colour (the grey under the cards in the light scheme).
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color onSurfaceSecondary;
  final Color onSurfaceVariantSummary;
  final Color onSurfaceVariantActions;
  final Color disabledOnSurface;

  /// The card colour.
  final Color surfaceContainer;
  final Color onSurfaceContainer;
  final Color onSurfaceContainerVariant;
  final Color surfaceContainerHigh;
  final Color onSurfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurfaceContainerHighest;
  final Color outline;
  final Color dividerLine;

  /// Dialog, Dropdown, Spinner, BottomSheet.
  final Color windowDimming;
  final Color sliderKeyPoint;
  final Color sliderKeyPointForeground;
  final Color sliderBackground;

  /// The bottom navigation bar.
  final Color bar;

  /// Unselected items in the floating bottom navigation bar.
  final Color labelPrimaryVariant;

  /// The state-layer colour laid over a pressed or hovered surface: black on
  /// the light scheme, white on the dark one.
  Color get stateLayer =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// The state layer's alpha while pressed.
  double get pressAlpha => isDark ? 0x33 / 255 : 0x1F / 255;

  /// The state layer's alpha while hovered.
  double get hoverAlpha => isDark ? 0x26 / 255 : 0x14 / 255;

  /// Overrides any palette role while preserving the remaining colours.
  SoftColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryVariant,
    Color? onPrimaryVariant,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? disabledPrimary,
    Color? disabledOnPrimary,
    Color? disabledPrimaryButton,
    Color? disabledOnPrimaryButton,
    Color? disabledPrimarySlider,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryVariant,
    Color? onSecondaryVariant,
    Color? disabledSecondary,
    Color? disabledOnSecondary,
    Color? disabledSecondaryVariant,
    Color? disabledOnSecondaryVariant,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? secondaryContainerVariant,
    Color? onSecondaryContainerVariant,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? tertiaryContainerVariant,
    Color? background,
    Color? onBackground,
    Color? onBackgroundVariant,
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceSecondary,
    Color? onSurfaceVariantSummary,
    Color? onSurfaceVariantActions,
    Color? disabledOnSurface,
    Color? surfaceContainer,
    Color? onSurfaceContainer,
    Color? onSurfaceContainerVariant,
    Color? surfaceContainerHigh,
    Color? onSurfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? onSurfaceContainerHighest,
    Color? outline,
    Color? dividerLine,
    Color? windowDimming,
    Color? sliderKeyPoint,
    Color? sliderKeyPointForeground,
    Color? sliderBackground,
    Color? bar,
    Color? labelPrimaryVariant,
  }) {
    return SoftColors(
      brightness: brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryVariant: primaryVariant ?? this.primaryVariant,
      onPrimaryVariant: onPrimaryVariant ?? this.onPrimaryVariant,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      disabledPrimary: disabledPrimary ?? this.disabledPrimary,
      disabledOnPrimary: disabledOnPrimary ?? this.disabledOnPrimary,
      disabledPrimaryButton:
          disabledPrimaryButton ?? this.disabledPrimaryButton,
      disabledOnPrimaryButton:
          disabledOnPrimaryButton ?? this.disabledOnPrimaryButton,
      disabledPrimarySlider:
          disabledPrimarySlider ?? this.disabledPrimarySlider,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryVariant: secondaryVariant ?? this.secondaryVariant,
      onSecondaryVariant: onSecondaryVariant ?? this.onSecondaryVariant,
      disabledSecondary: disabledSecondary ?? this.disabledSecondary,
      disabledOnSecondary: disabledOnSecondary ?? this.disabledOnSecondary,
      disabledSecondaryVariant:
          disabledSecondaryVariant ?? this.disabledSecondaryVariant,
      disabledOnSecondaryVariant:
          disabledOnSecondaryVariant ?? this.disabledOnSecondaryVariant,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      secondaryContainerVariant:
          secondaryContainerVariant ?? this.secondaryContainerVariant,
      onSecondaryContainerVariant:
          onSecondaryContainerVariant ?? this.onSecondaryContainerVariant,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      tertiaryContainerVariant:
          tertiaryContainerVariant ?? this.tertiaryContainerVariant,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      onBackgroundVariant: onBackgroundVariant ?? this.onBackgroundVariant,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceSecondary: onSurfaceSecondary ?? this.onSurfaceSecondary,
      onSurfaceVariantSummary:
          onSurfaceVariantSummary ?? this.onSurfaceVariantSummary,
      onSurfaceVariantActions:
          onSurfaceVariantActions ?? this.onSurfaceVariantActions,
      disabledOnSurface: disabledOnSurface ?? this.disabledOnSurface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      onSurfaceContainer: onSurfaceContainer ?? this.onSurfaceContainer,
      onSurfaceContainerVariant:
          onSurfaceContainerVariant ?? this.onSurfaceContainerVariant,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      onSurfaceContainerHigh:
          onSurfaceContainerHigh ?? this.onSurfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      onSurfaceContainerHighest:
          onSurfaceContainerHighest ?? this.onSurfaceContainerHighest,
      outline: outline ?? this.outline,
      dividerLine: dividerLine ?? this.dividerLine,
      windowDimming: windowDimming ?? this.windowDimming,
      sliderKeyPoint: sliderKeyPoint ?? this.sliderKeyPoint,
      sliderKeyPointForeground:
          sliderKeyPointForeground ?? this.sliderKeyPointForeground,
      sliderBackground: sliderBackground ?? this.sliderBackground,
      bar: bar ?? this.bar,
      labelPrimaryVariant: labelPrimaryVariant ?? this.labelPrimaryVariant,
    );
  }
}
