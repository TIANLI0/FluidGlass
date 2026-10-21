import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_button_press.dart';

/// The size tiers of a [SoftButton].
enum SoftButtonSize {
  /// 58 × 44, 22 corners, 12 horizontal padding.
  regular,

  /// 52 × 28, 14 corners, 12 / 4 padding.
  small,

  /// 44 × 20, 10 corners, 8 / 2 padding.
  tiny;

  double get minWidth => switch (this) {
    regular => SoftButtonDefaults.minWidth,
    small => SoftButtonDefaults.minWidthSmall,
    tiny => SoftButtonDefaults.minWidthTiny,
  };

  double get minHeight => switch (this) {
    regular => SoftButtonDefaults.minHeight,
    small => SoftButtonDefaults.minHeightSmall,
    tiny => SoftButtonDefaults.minHeightTiny,
  };

  double get cornerRadius => switch (this) {
    regular => SoftButtonDefaults.cornerRadius,
    small => SoftButtonDefaults.cornerRadiusSmall,
    tiny => SoftButtonDefaults.cornerRadiusTiny,
  };

  EdgeInsetsGeometry get padding => switch (this) {
    regular => SoftButtonDefaults.padding,
    small => SoftButtonDefaults.paddingSmall,
    tiny => SoftButtonDefaults.paddingTiny,
  };
}

/// The button defaults.
abstract final class SoftButtonDefaults {
  static const double minWidth = 58;
  static const double minHeight = 44;

  /// Half the height: a capsule.
  static const double cornerRadius = 22;
  static const EdgeInsetsGeometry padding = EdgeInsets.symmetric(
    horizontal: 12,
  );

  static const double minWidthSmall = 52;
  static const double minHeightSmall = 28;
  static const double cornerRadiusSmall = 14;
  static const EdgeInsetsGeometry paddingSmall = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 4,
  );

  /// The tiny tier is the small one stepped down by 8.
  static const double minWidthTiny = 44;
  static const double minHeightTiny = 20;
  static const double cornerRadiusTiny = 10;
  static const EdgeInsetsGeometry paddingTiny = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );
}

/// The colour variants of a [SoftButton].
enum SoftButtonVariant {
  /// The translucent grey fill (`secondaryVariant`) with a dark label.
  normal,

  /// The accent fill with a white label.
  primary,

  /// No fill, an accent label.
  borderless,
}

/// The fill and content colours of a button, enabled and disabled.
@immutable
class SoftButtonColors {
  const SoftButtonColors({
    required this.color,
    required this.disabledColor,
    required this.contentColor,
    required this.disabledContentColor,
  });

  /// The grey button: `secondaryVariant` / `onSecondaryVariant`.
  SoftButtonColors.normal(SoftColors colors)
    : this(
        color: colors.secondaryVariant,
        disabledColor: colors.disabledSecondaryVariant,
        contentColor: colors.onSecondaryVariant,
        disabledContentColor: colors.disabledOnSecondaryVariant,
      );

  /// The accent button: `primary` / `onPrimary`.
  SoftButtonColors.primary(SoftColors colors)
    : this(
        color: colors.primary,
        disabledColor: colors.disabledPrimaryButton,
        contentColor: colors.onPrimary,
        disabledContentColor: colors.disabledOnPrimaryButton,
      );

  /// The borderless button: no fill, a `primary` label.
  SoftButtonColors.borderless(SoftColors colors)
    : this(
        color: const Color(0x00000000),
        disabledColor: const Color(0x00000000),
        contentColor: colors.primary,
        disabledContentColor: colors.disabledPrimary,
      );

  /// The colours of [variant] in [colors].
  factory SoftButtonColors.of(SoftButtonVariant variant, SoftColors colors) =>
      switch (variant) {
        SoftButtonVariant.normal => SoftButtonColors.normal(colors),
        SoftButtonVariant.primary => SoftButtonColors.primary(colors),
        SoftButtonVariant.borderless => SoftButtonColors.borderless(colors),
      };

  final Color color;
  final Color disabledColor;
  final Color contentColor;
  final Color disabledContentColor;

  SoftButtonColors copyWith({
    Color? color,
    Color? disabledColor,
    Color? contentColor,
    Color? disabledContentColor,
  }) {
    return SoftButtonColors(
      color: color ?? this.color,
      disabledColor: disabledColor ?? this.disabledColor,
      contentColor: contentColor ?? this.contentColor,
      disabledContentColor: disabledContentColor ?? this.disabledContentColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftButtonColors &&
      other.color == color &&
      other.disabledColor == disabledColor &&
      other.contentColor == contentColor &&
      other.disabledContentColor == disabledContentColor;

  @override
  int get hashCode =>
      Object.hash(color, disabledColor, contentColor, disabledContentColor);
}

/// A button: a capsule (by default) holding [child] centred in a row.
///
/// Pressing shrinks it towards 0.92 (0.98 for large surfaces, eased by area)
/// and composites the theme's state layer over the fill — not over the
/// label — on a critically damped spring; a quick tap still drives the tint
/// to 70 % before it fades. The press shows after the scroll-safe delay.
///
/// The content colour reaches [child] through [DefaultTextStyle] (the `main`
/// style) and [IconTheme]. Disabled when [enabled] is false or [onPressed]
/// is null.
class SoftButton extends StatefulWidget {
  const SoftButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.pressScaleEnabled = true,
    this.variant = SoftButtonVariant.normal,
    this.colors,
    this.size = SoftButtonSize.regular,
    this.cornerRadius,
    this.minWidth,
    this.minHeight,
    this.padding,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  /// Whether the button shrinks while pressed; the tint plays either way.
  final bool pressScaleEnabled;

  /// The colour variant; ignored when [colors] is given.
  final SoftButtonVariant variant;
  final SoftButtonColors? colors;

  /// The tier the null metrics below fall back to.
  final SoftButtonSize size;
  final double? cornerRadius;
  final double? minWidth;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  /// Replaces the child's semantics label.
  final String? semanticLabel;

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> with TickerProviderStateMixin {
  late final SoftButtonPress _press = SoftButtonPress(vsync: this);
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  @override
  void didUpdateWidget(SoftButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
    _sync();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _sync() => _press.update(
    pressed: _pressed,
    enabled: _enabled,
    scaleEnabled: widget.pressScaleEnabled,
  );

  void _setPressed(bool value) {
    _pressed = value;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = _enabled;
    final SoftButtonColors colors =
        widget.colors ?? SoftButtonColors.of(widget.variant, theme.colors);
    final Color fill = enabled ? colors.color : colors.disabledColor;
    final Color content = enabled
        ? colors.contentColor
        : colors.disabledContentColor;
    final BorderRadius radius = BorderRadius.circular(
      widget.cornerRadius ?? widget.size.cornerRadius,
    );
    final Color press = theme.colors.stateLayer.withValues(
      alpha: theme.colors.pressAlpha,
    );

    Widget result = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth ?? widget.size.minWidth,
        minHeight: widget.minHeight ?? widget.size.minHeight,
      ),
      child: Padding(
        padding: widget.padding ?? widget.size.padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[Flexible(child: widget.child)],
        ),
      ),
    );
    result = DefaultTextStyle.merge(
      style: theme.textStyles.main.copyWith(color: content),
      child: IconTheme.merge(
        data: IconThemeData(color: content),
        child: result,
      ),
    );
    result = CustomPaint(
      painter: SoftButtonFillPainter(
        color: fill,
        tint: _press.tint,
        pressColor: press,
        radius: radius,
        smooth: theme.smoothCorners,
      ),
      child: result,
    );
    if (widget.semanticLabel != null) {
      result = Semantics(
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: result,
      );
    }
    return SoftAreaPressScale(
      progress: _press.scale,
      child: SoftPressable(
        // A disabled button still announces itself as a button.
        onTap: enabled ? widget.onPressed : _noop,
        enabled: enabled,
        feedback: SoftPressFeedback.none,
        onPressedChanged: _setPressed,
        child: result,
      ),
    );
  }

  static void _noop() {}
}

/// A [SoftButton] with a single [text] label in the `button` style (16
/// medium).
class SoftTextButton extends StatelessWidget {
  const SoftTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
    this.pressScaleEnabled = true,
    this.variant = SoftButtonVariant.normal,
    this.colors,
    this.size = SoftButtonSize.regular,
    this.cornerRadius,
    this.minWidth,
    this.minHeight,
    this.padding,
    this.textStyle,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool pressScaleEnabled;
  final SoftButtonVariant variant;
  final SoftButtonColors? colors;
  final SoftButtonSize size;
  final double? cornerRadius;
  final double? minWidth;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  /// The label style; the theme's `button` style by default. Leave its
  /// colour unset to take the button's content colour.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = textStyle ?? SoftTheme.textStylesOf(context).button;
    return SoftButton(
      onPressed: onPressed,
      enabled: enabled,
      pressScaleEnabled: pressScaleEnabled,
      variant: variant,
      colors: colors,
      size: size,
      cornerRadius: cornerRadius,
      minWidth: minWidth,
      minHeight: minHeight,
      padding: padding,
      child: Text(text, style: style),
    );
  }
}
