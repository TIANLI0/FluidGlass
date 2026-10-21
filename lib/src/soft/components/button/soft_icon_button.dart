import 'package:flutter/widgets.dart';

import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The icon button defaults.
abstract final class SoftIconButtonDefaults {
  static const double minWidth = 48;
  static const double minHeight = 48;

  /// The toolbar menu background radius: a circle at the default size.
  static const double cornerRadius = 24;
}

/// A compact button around an icon, for toolbars and image lists.
///
/// [child] sits centred in a 48 × 48 (at least) smooth-cornered box filled
/// with [backgroundColor]; pressing lays the theme's state layer over the
/// whole button. [holdDown] keeps the press shown — for a button whose popup
/// is open. A disabled button takes no touches and shows no press, as in the
/// reference; tint [child] yourself if it should look disabled.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.holdDown = false,
    this.backgroundColor,
    this.cornerRadius = SoftIconButtonDefaults.cornerRadius,
    this.minWidth = SoftIconButtonDefaults.minWidth,
    this.minHeight = SoftIconButtonDefaults.minHeight,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final bool holdDown;

  /// The fill; none by default.
  final Color? backgroundColor;
  final double cornerRadius;
  final double minWidth;
  final double minHeight;

  /// Announced instead of the child's semantics.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final BorderRadius radius = BorderRadius.circular(cornerRadius);
    Widget result = ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
    final Color? fill = backgroundColor;
    if (fill != null && fill.a > 0) {
      result = DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: SoftSquircleBorder(
            radius: radius,
            smooth: theme.smoothCorners,
          ),
        ),
        child: result,
      );
    }
    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        excludeSemantics: true,
        child: result,
      );
    }
    return SoftPressable(
      onTap: onPressed,
      enabled: enabled && onPressed != null,
      holdDown: holdDown,
      borderRadius: radius,
      child: result,
    );
  }
}
