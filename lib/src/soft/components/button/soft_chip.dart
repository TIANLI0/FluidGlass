import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_button_press.dart';

/// The chip defaults.
abstract final class SoftChipDefaults {
  static const double minWidth = 52;
  static const double minHeight = 32;
  static const double maxWidth = 300;

  /// The label ellipsizes beyond this.
  static const double textMaxWidth = 200;

  /// Half the default height: a capsule.
  static const double cornerRadius = 16;

  static const double iconSize = 16;
  static const double iconSpacing = 4;
  static const EdgeInsetsGeometry padding = EdgeInsets.symmetric(
    horizontal: 12,
  );

  static const double dismissIconSize = 14;

  /// Between the label and the dismiss icon.
  static const double dismissIconStartPadding = 8;

  /// Between the dismiss icon and the chip's end edge; it replaces the end
  /// padding.
  static const double dismissIconEndPadding = 9;

  /// The dismiss touch target, centred on the icon.
  static const double dismissTargetSize = 28;
}

/// The colours of a [SoftChip] in each selection and enabled state.
@immutable
class SoftChipColors {
  const SoftChipColors({
    required this.containerColor,
    required this.selectedContainerColor,
    required this.disabledContainerColor,
    required this.selectedDisabledContainerColor,
    required this.contentColor,
    required this.selectedContentColor,
    required this.disabledContentColor,
    required this.selectedDisabledContentColor,
  });

  /// The theme's chip colours: a translucent grey capsule with a dark label,
  /// the accent capsule with a white label once selected.
  SoftChipColors.of(SoftColors colors)
    : this(
        containerColor: colors.secondaryVariant,
        selectedContainerColor: colors.primary,
        disabledContainerColor: colors.disabledSecondaryVariant,
        selectedDisabledContainerColor: colors.disabledPrimaryButton,
        contentColor: colors.onSurface,
        selectedContentColor: colors.onPrimary,
        disabledContentColor: colors.disabledOnSecondaryVariant,
        selectedDisabledContentColor: colors.disabledOnPrimaryButton,
      );

  final Color containerColor;
  final Color selectedContainerColor;
  final Color disabledContainerColor;
  final Color selectedDisabledContainerColor;
  final Color contentColor;
  final Color selectedContentColor;
  final Color disabledContentColor;
  final Color selectedDisabledContentColor;

  Color container({required bool enabled, required bool selected}) => enabled
      ? (selected ? selectedContainerColor : containerColor)
      : (selected ? selectedDisabledContainerColor : disabledContainerColor);

  Color content({required bool enabled, required bool selected}) => enabled
      ? (selected ? selectedContentColor : contentColor)
      : (selected ? selectedDisabledContentColor : disabledContentColor);

  @override
  bool operator ==(Object other) =>
      other is SoftChipColors &&
      other.containerColor == containerColor &&
      other.selectedContainerColor == selectedContainerColor &&
      other.disabledContainerColor == disabledContainerColor &&
      other.selectedDisabledContainerColor == selectedDisabledContainerColor &&
      other.contentColor == contentColor &&
      other.selectedContentColor == selectedContentColor &&
      other.disabledContentColor == disabledContentColor &&
      other.selectedDisabledContentColor == selectedDisabledContentColor;

  @override
  int get hashCode => Object.hash(
    containerColor,
    selectedContainerColor,
    disabledContainerColor,
    selectedDisabledContainerColor,
    contentColor,
    selectedContentColor,
    disabledContentColor,
    selectedDisabledContentColor,
  );
}

/// A checkable filter chip: a capsule with a single-line [label] and an
/// optional leading [icon].
///
/// Unselected it is a translucent grey capsule; selected, the accent capsule
/// with a white label. The colours cross-fade on the critically damped
/// state-layer spring, and pressing shrinks the chip and tints its fill like
/// a [SoftButton]-style surface.
///
/// With [onDismiss], a trailing close mark (or [dismissIcon]) appears as an
/// independent button: it never toggles the chip and is disabled with it.
/// Give it a [dismissSemanticLabel].
class SoftChip extends StatefulWidget {
  const SoftChip({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.label,
    this.enabled = true,
    this.icon,
    this.onDismiss,
    this.dismissIcon,
    this.dismissSemanticLabel,
    this.dismissTargetSize = SoftChipDefaults.dismissTargetSize,
    this.colors,
    this.cornerRadius = SoftChipDefaults.cornerRadius,
    this.minWidth = SoftChipDefaults.minWidth,
    this.minHeight = SoftChipDefaults.minHeight,
    this.maxWidth = SoftChipDefaults.maxWidth,
    this.padding = SoftChipDefaults.padding,
    this.textStyle,
  });

  final bool selected;
  final VoidCallback? onPressed;
  final String label;
  final bool enabled;

  /// Laid out in a 16 box and tinted with the label colour through
  /// [IconTheme].
  final Widget? icon;
  final VoidCallback? onDismiss;

  /// Replaces the built-in close mark.
  final Widget? dismissIcon;
  final String? dismissSemanticLabel;

  /// The dismiss touch target; it never grows the chip.
  final double dismissTargetSize;
  final SoftChipColors? colors;
  final double cornerRadius;
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  /// The label style; the theme's `body2` (14) by default.
  final TextStyle? textStyle;

  @override
  State<SoftChip> createState() => _SoftChipState();
}

class _SoftChipState extends State<SoftChip> with TickerProviderStateMixin {
  late final SoftButtonPress _press = SoftButtonPress(vsync: this);

  /// 0 → 1 from the colours of the previous state to the current ones.
  late final SoftSpring _colorT = SoftSpring(vsync: this, value: 1);
  Color? _fromContainer;
  Color? _fromContent;
  Color? _toContainer;
  Color? _toContent;
  bool _pressed = false;
  bool _dismissDown = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    _colorT.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveColors();
  }

  @override
  void didUpdateWidget(SoftChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
    _syncPress();
    _resolveColors();
  }

  void _resolveColors() {
    final SoftChipColors colors =
        widget.colors ?? SoftChipColors.of(SoftTheme.colorsOf(context));
    _retarget(
      colors.container(enabled: _enabled, selected: widget.selected),
      colors.content(enabled: _enabled, selected: widget.selected),
    );
  }

  void _syncPress() => _press.update(pressed: _pressed, enabled: _enabled);

  void _setPressed(bool value) {
    // A press that landed on the dismiss target is not a press of the chip.
    _pressed = value && !_dismissDown;
    _syncPress();
  }

  /// Starts a colour transition when the resolved colours change, from
  /// wherever the running one is.
  void _retarget(Color container, Color content) {
    if (_toContainer == null) {
      _toContainer = container;
      _toContent = content;
      return;
    }
    if (container == _toContainer && content == _toContent) return;
    final double t = _colorT.value.clamp(0.0, 1.0);
    _fromContainer = Color.lerp(
      _fromContainer ?? _toContainer,
      _toContainer,
      t,
    );
    _fromContent = Color.lerp(_fromContent ?? _toContent, _toContent, t);
    _toContainer = container;
    _toContent = content;
    if (softReduceMotion(context)) {
      _colorT.snapTo(1);
    } else {
      _colorT.snapTo(0);
      _colorT.animateTo(1, SoftMotion.stateLayer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = _enabled;
    final Color container = _toContainer!;
    final Color content = _toContent!;
    final BorderRadius radius = BorderRadius.circular(widget.cornerRadius);
    final TextStyle style = widget.textStyle ?? theme.textStyles.body2;
    final bool dismissible = widget.onDismiss != null;
    final EdgeInsets padding = widget.padding.resolve(
      Directionality.of(context),
    );

    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          SizedBox.square(
            dimension: SoftChipDefaults.iconSize,
            child: Center(child: widget.icon),
          ),
          const SizedBox(width: SoftChipDefaults.iconSpacing),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: SoftChipDefaults.textMaxWidth,
            ),
            child: Text(
              widget.label,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (dismissible) _dismiss(enabled),
      ],
    );

    Widget result = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
      ),
      child: Padding(
        // The dismiss slot takes the place of the end padding.
        padding: !dismissible
            ? padding
            : Directionality.of(context) == TextDirection.rtl
            ? padding.copyWith(left: 0)
            : padding.copyWith(right: 0),
        child: row,
      ),
    );
    final Color? fromContent = _fromContent;
    result = AnimatedBuilder(
      animation: _colorT,
      builder: (BuildContext context, Widget? child) {
        final Color color = fromContent == null
            ? content
            : Color.lerp(fromContent, content, _colorT.value.clamp(0.0, 1.0))!;
        return DefaultTextStyle.merge(
          style: style.copyWith(color: color),
          child: IconTheme.merge(
            data: IconThemeData(color: color, size: SoftChipDefaults.iconSize),
            child: child!,
          ),
        );
      },
      child: result,
    );
    result = CustomPaint(
      painter: SoftButtonFillPainter(
        color: container,
        fromColor: _fromContainer,
        colorProgress: _colorT,
        tint: _press.tint,
        pressColor: theme.colors.stateLayer.withValues(
          alpha: theme.colors.pressAlpha,
        ),
        radius: radius,
        smooth: theme.smoothCorners,
      ),
      child: result,
    );
    result = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: result,
    );
    return SoftAreaPressScale(
      progress: _press.scale,
      child: MergeSemantics(
        child: Semantics(
          checked: widget.selected,
          child: SoftPressable(
            onTap: enabled ? widget.onPressed : _noop,
            enabled: enabled,
            feedback: SoftPressFeedback.none,
            semanticsButton: false,
            onPressedChanged: _setPressed,
            child: result,
          ),
        ),
      ),
    );
  }

  static void _noop() {}

  Widget _dismiss(bool enabled) {
    const double icon = SoftChipDefaults.dismissIconSize;
    final double target = widget.dismissTargetSize;
    // The target is centred on the icon and eats into the 8 / 9 spacing
    // around it, so the chip keeps the reference's width.
    final double overhang = (target - icon) / 2;
    final Widget mark = SizedBox.square(
      dimension: icon,
      child: Center(child: widget.dismissIcon ?? const _CloseMark()),
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: math.max(0, SoftChipDefaults.dismissIconStartPadding - overhang),
        end: math.max(0, SoftChipDefaults.dismissIconEndPadding - overhang),
      ),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.dismissSemanticLabel,
        child: Listener(
          onPointerDown: (_) => _dismissDown = true,
          onPointerUp: (_) => _dismissDown = false,
          onPointerCancel: (_) => _dismissDown = false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onDismiss : null,
            child: SizedBox(
              width: math.max(target, icon),
              height: math.max(target, icon),
              child: Center(child: mark),
            ),
          ),
        ),
      ),
    );
  }
}

/// The built-in close mark in the icon colour.
class _CloseMark extends StatelessWidget {
  const _CloseMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(SoftChipDefaults.dismissIconSize),
      painter: _CloseMarkPainter(
        IconTheme.of(context).color ?? const Color(0xFF000000),
      ),
    );
  }
}

/// The close mark: two round-capped strokes, 2.2 wide on a 24 grid.
class _CloseMarkPainter extends CustomPainter {
  const _CloseMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.shortestSide / 24;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * unit;
    canvas
      ..drawLine(
        Offset(6 * unit, 6 * unit),
        Offset(18 * unit, 18 * unit),
        paint,
      )
      ..drawLine(
        Offset(18 * unit, 6 * unit),
        Offset(6 * unit, 18 * unit),
        paint,
      );
  }

  @override
  bool shouldRepaint(_CloseMarkPainter old) => old.color != color;
}
