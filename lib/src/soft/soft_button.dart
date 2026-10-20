import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_pressable.dart';
import 'soft_theme.dart';

/// How a [SoftButton] is filled.
enum SoftButtonVariant {
  /// Accent fill, white text — the one main action.
  primary,

  /// A solid neutral fill, primary text.
  secondary,

  /// The accent at low opacity, accent text.
  tonal,

  /// No fill, a 1 hairline outline, secondary text.
  outline,

  /// A translucent white fill for buttons over imagery.
  translucent,
}

/// A pill button.
///
/// Large: at least 132 × 44, 16 medium text, 12 / 8 padding. Small: at least
/// 52 × 28, 14 medium text, 12 / 4 padding. [expand] fills the width (the
/// main action at the foot of a page). Presses sink the button by its size and
/// lean it towards the finger; [loading] swaps the label for three breathing
/// dots and ignores taps.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = SoftButtonVariant.primary,
    this.small = false,
    this.expand = false,
    this.loading = false,
    this.icon,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final SoftButtonVariant variant;
  final bool small;
  final bool expand;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = onPressed != null && !loading;
    final bool dark = theme.isDark;
    final (
      Color fill,
      Color text,
      Color disabledFill,
      Color disabledText,
    ) = switch (variant) {
      SoftButtonVariant.primary => (
        theme.accent,
        theme.onAccent,
        theme.accent.withValues(alpha: 0.3),
        dark ? const Color(0x28FFFFFF) : const Color(0x8AFFFFFF),
      ),
      SoftButtonVariant.secondary => (
        dark ? const Color(0xFF353535) : const Color(0xFFEBEBEB),
        theme.labelPrimary,
        dark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
        dark ? const Color(0x28FFFFFF) : const Color(0x42000000),
      ),
      SoftButtonVariant.tonal => (
        theme.accentTint,
        theme.accentText,
        dark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
        dark ? const Color(0x28FFFFFF) : const Color(0x42000000),
      ),
      SoftButtonVariant.outline => (
        const Color(0x00000000),
        theme.labelSecondary,
        const Color(0x00000000),
        dark ? const Color(0x28FFFFFF) : const Color(0x42000000),
      ),
      SoftButtonVariant.translucent => (
        const Color(0x33FFFFFF),
        const Color(0xFFFFFFFF),
        const Color(0x33FFFFFF),
        const Color(0x4DFFFFFF),
      ),
    };
    final Color textColor = enabled || loading ? text : disabledText;
    final TextStyle style = theme.text(
      small ? 14 : 16,
      weight: FontWeight.w500,
      color: textColor,
    );
    final ShapeBorder shape = variant == SoftButtonVariant.outline
        ? StadiumBorder(
            side: BorderSide(
              color: enabled
                  ? theme.divider
                  : (dark ? const Color(0x1AFFFFFF) : const Color(0x14000000)),
            ),
          )
        : const StadiumBorder();
    final Widget content = loading
        ? SoftLoadingDots(color: textColor)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: small ? 16 : 20, color: textColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ],
          );
    Widget button = Container(
      constraints: BoxConstraints(
        minWidth: expand ? double.infinity : (small ? 52 : 132),
        minHeight: small ? 28 : 44,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: small ? 4 : 8),
      // Only a full-width button centres its label in the space it is given;
      // otherwise the button hugs its label (an aligned Container would
      // stretch to fill a Wrap or a Row).
      alignment: expand ? Alignment.center : null,
      decoration: ShapeDecoration(
        color: enabled || loading ? fill : disabledFill,
        shape: shape,
      ),
      child: content,
    );
    if (expand) button = SizedBox(width: double.infinity, child: button);
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? label : null,
      child: SoftPressable(
        enabled: enabled,
        onTap: onPressed,
        shape: const StadiumBorder(),
        follow: true,
        child: button,
      ),
    );
  }
}

/// Three dots breathing in turn (a 1.33 s cycle), standing in for a button's
/// label while it works.
class SoftLoadingDots extends StatefulWidget {
  const SoftLoadingDots({super.key, required this.color});

  final Color color;

  @override
  State<SoftLoadingDots> createState() => _SoftLoadingDotsState();
}

class _SoftLoadingDotsState extends State<SoftLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1332),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (softReduceMotion(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  /// One dot's opacity at [ms] into the cycle, starting [offset] ms late:
  /// 0.2 → 0.5 over 133 ms, → 1 over 67, → 0.5 over 67, → 0.2 over 133.
  static double _alpha(double ms, double offset) {
    final double t = (ms - offset) % 1332;
    if (t < 133) return 0.2 + 0.3 * t / 133;
    if (t < 200) return 0.5 + 0.5 * (t - 133) / 67;
    if (t < 467) return 1;
    if (t < 534) return 1 - 0.5 * (t - 467) / 67;
    if (t < 667) return 0.5 - 0.3 * (t - 534) / 133;
    return 0.2;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 16,
      child: AnimatedBuilder(
        animation: _cycle,
        builder: (BuildContext context, _) {
          final double ms = _cycle.value * 1332;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(
                      alpha: widget.color.a * _alpha(ms, i * 333.0),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A floating action button: a 56 accent circle with an accent-tinted shadow.
/// [expanded] turns the icon 45° (a plus becoming a cross).
class SoftFab extends StatelessWidget {
  const SoftFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.expanded = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = onPressed != null;
    final bool reduce = softReduceMotion(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SoftPressable(
        enabled: enabled,
        onTap: onPressed,
        shape: const CircleBorder(),
        follow: true,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? theme.accent : const Color(0xFFE6E6E6),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.34),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            child: Icon(icon, color: theme.onAccent, size: 24),
          ),
        ),
      ),
    );
  }
}

/// A row of buttons laid out the way a page footer wants them: one button
/// centred at most 296 wide, two sharing the row 16 apart.
class SoftButtonBar extends StatelessWidget {
  const SoftButtonBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.length == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 296),
          child: SizedBox(width: double.infinity, child: children.first),
        ),
      );
    }
    return Row(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
