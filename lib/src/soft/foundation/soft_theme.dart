import 'package:flutter/widgets.dart';

import 'soft_colors.dart';

/// The type scale of the soft components.
///
/// Sizes and line heights follow the reference text appearances; the line
/// height is a multiple of the font size, like `em`.
@immutable
class SoftTextStyles {
  const SoftTextStyles({
    this.main = const TextStyle(fontSize: 17, height: 1.158),
    this.paragraph = const TextStyle(fontSize: 17, height: 1.158),
    this.body1 = const TextStyle(fontSize: 16, height: 1.158),
    this.body2 = const TextStyle(fontSize: 14, height: 1.2245),
    this.button = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.263,
    ),
    this.footnote1 = const TextStyle(fontSize: 13, height: 1.2245),
    this.footnote2 = const TextStyle(fontSize: 11, height: 1.143),
    this.headline1 = const TextStyle(fontSize: 16, height: 1.158),
    this.headline2 = const TextStyle(fontSize: 16, height: 1.158),
    this.subtitle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.2245,
    ),
    this.title1 = const TextStyle(fontSize: 32, height: 1.2322),
    this.title2 = const TextStyle(fontSize: 24, height: 1.2),
    this.title3 = const TextStyle(fontSize: 20, height: 1.1831),
    this.title4 = const TextStyle(fontSize: 18, height: 1.2381),
  });

  /// 17, line height 1.158.
  final TextStyle main;

  /// 17, line height 1.158.
  final TextStyle paragraph;

  /// 16, line height 1.158.
  final TextStyle body1;

  /// 14, line height 1.2245.
  final TextStyle body2;

  /// 16 medium, line height 1.263.
  final TextStyle button;

  /// 13, line height 1.2245.
  final TextStyle footnote1;

  /// 11, line height 1.143.
  final TextStyle footnote2;

  /// 16, line height 1.158: list titles.
  final TextStyle headline1;

  /// 16, line height 1.158.
  final TextStyle headline2;

  /// 14 bold, line height 1.2245.
  final TextStyle subtitle;

  /// 32, line height 1.2322.
  final TextStyle title1;

  /// 24, line height 1.2.
  final TextStyle title2;

  /// 20, line height 1.1831.
  final TextStyle title3;

  /// 18, line height 1.2381.
  final TextStyle title4;
}

/// The colours and type the soft components read.
@immutable
class SoftThemeData {
  const SoftThemeData({
    required this.colors,
    this.textStyles = const SoftTextStyles(),
    this.smoothCorners = true,
  });

  /// The light theme.
  const SoftThemeData.light({
    this.colors = const SoftColors.light(),
    this.textStyles = const SoftTextStyles(),
    this.smoothCorners = true,
  });

  /// The dark theme.
  const SoftThemeData.dark({
    this.colors = const SoftColors.dark(),
    this.textStyles = const SoftTextStyles(),
    this.smoothCorners = true,
  });

  final SoftColors colors;
  final SoftTextStyles textStyles;

  /// Whether surfaces draw smooth (superellipse) corners or plain circular
  /// ones.
  final bool smoothCorners;

  bool get isDark => colors.isDark;

  SoftThemeData copyWith({
    SoftColors? colors,
    SoftTextStyles? textStyles,
    bool? smoothCorners,
  }) {
    return SoftThemeData(
      colors: colors ?? this.colors,
      textStyles: textStyles ?? this.textStyles,
      smoothCorners: smoothCorners ?? this.smoothCorners,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftThemeData &&
      other.colors == colors &&
      other.textStyles == textStyles &&
      other.smoothCorners == smoothCorners;

  @override
  int get hashCode => Object.hash(colors, textStyles, smoothCorners);
}

/// Provides [SoftThemeData] to the soft components below it.
///
/// Without one, components follow the platform brightness with the default
/// palettes.
class SoftTheme extends InheritedWidget {
  const SoftTheme({super.key, required this.data, required super.child});

  final SoftThemeData data;

  static SoftThemeData of(BuildContext context) {
    final SoftTheme? theme = context
        .dependOnInheritedWidgetOfExactType<SoftTheme>();
    if (theme != null) return theme.data;
    final Brightness brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return brightness == Brightness.dark
        ? const SoftThemeData.dark()
        : const SoftThemeData.light();
  }

  /// The colours of the nearest theme.
  static SoftColors colorsOf(BuildContext context) => of(context).colors;

  /// The type scale of the nearest theme.
  static SoftTextStyles textStylesOf(BuildContext context) =>
      of(context).textStyles;

  @override
  bool updateShouldNotify(SoftTheme oldWidget) => oldWidget.data != data;
}
