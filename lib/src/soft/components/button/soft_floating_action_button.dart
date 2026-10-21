import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The floating action button defaults.
abstract final class SoftFloatingActionButtonDefaults {
  static const double minWidth = 56;
  static const double minHeight = 56;

  /// The level-three shadow.
  static const double elevation = 12;

  /// The scale the whole button springs down to while pressed.
  static const double pressedScale = 0.92;
}

/// A floating action button: a raised circle (by default) in the accent
/// colour.
///
/// While pressed the whole button, shadow included, springs down to 0.92 on
/// the critically damped state-layer spring and the theme's state layer
/// tints it. [contentColor] (the theme's `onSurface` by default, as in the
/// reference) reaches [child] through [IconTheme] and [DefaultTextStyle].
class SoftFloatingActionButton extends StatefulWidget {
  const SoftFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius,
    this.color,
    this.contentColor,
    this.elevation = SoftFloatingActionButtonDefaults.elevation,
    this.shadowColor = const Color(0xFF000000),
    this.minWidth = SoftFloatingActionButtonDefaults.minWidth,
    this.minHeight = SoftFloatingActionButtonDefaults.minHeight,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;

  /// The corners; null for a circle (a capsule when not square).
  final BorderRadius? borderRadius;

  /// The fill; the theme's `primary` by default.
  final Color? color;
  final Color? contentColor;
  final double elevation;
  final Color shadowColor;
  final double minWidth;
  final double minHeight;
  final String? semanticLabel;

  @override
  State<SoftFloatingActionButton> createState() =>
      _SoftFloatingActionButtonState();
}

class _SoftFloatingActionButtonState extends State<SoftFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _scale = SoftSpring(vsync: this);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    _scale.animateTo(pressed ? 1 : 0, SoftMotion.stateLayer);
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color content = widget.contentColor ?? theme.colors.onSurface;
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(9999);
    final ShapeBorder shape = SoftSquircleBorder(
      radius: radius,
      smooth: theme.smoothCorners,
    );
    Widget result = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
    );
    result = DefaultTextStyle.merge(
      style: theme.textStyles.main.copyWith(color: content),
      child: IconTheme.merge(
        data: IconThemeData(color: content),
        child: result,
      ),
    );
    if (widget.semanticLabel != null) {
      result = Semantics(
        label: widget.semanticLabel,
        excludeSemantics: true,
        child: result,
      );
    }
    result = PhysicalShape(
      clipper: ShapeBorderClipper(shape: shape),
      color: widget.color ?? theme.colors.primary,
      elevation: widget.elevation,
      shadowColor: widget.shadowColor,
      child: SoftPressable(
        onTap: widget.onPressed,
        enabled: widget.onPressed != null,
        borderRadius: radius,
        onPressedChanged: _setPressed,
        child: result,
      ),
    );
    return AnimatedBuilder(
      animation: _scale,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale:
            1 -
            (1 - SoftFloatingActionButtonDefaults.pressedScale) * _scale.value,
        child: child,
      ),
      child: result,
    );
  }
}
