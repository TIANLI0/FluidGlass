import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_dialog.dart';

/// The button-bar defaults. The row tier's metrics are the first group,
/// the stacked tier's the second.
abstract final class SoftDialogButtonBarDefaults {
  /// The minimum height of a row button.
  static const double rowButtonMinHeight = 44;

  /// A row button's padding; its bottom carries the panel's bottom inset.
  static const EdgeInsets rowButtonPadding = EdgeInsets.fromLTRB(
    12,
    12,
    12,
    22,
  );

  /// The divider between row buttons.
  static const double rowDividerThickness = 1;

  /// The row divider's gap to the top of the bar.
  static const double rowDividerInsetTop = 17;

  /// The row divider's gap to the bottom of the bar.
  static const double rowDividerInsetBottom = 21;

  /// The horizontal padding of a button in either tier; also what the
  /// row/stack decision takes off each cell.
  static const double buttonHorizontalPadding = 12;

  /// The minimum height of a stacked button.
  static const double stackedButtonMinHeight = 44;

  /// The minimum height of the bottom-most stacked button.
  static const double stackedButtonMinHeightBottom = 44;

  /// A stacked button's vertical padding.
  static const double stackedButtonPaddingVertical = 4;

  /// Extra top padding of the top-most stacked button when nothing sits
  /// above the bar.
  static const double stackedButtonPaddingTopExtra = 0;

  /// Extra bottom padding of the bottom-most stacked button.
  static const double stackedButtonPaddingBottomExtra = 0;

  /// The top margin of a stack of several buttons, or of a lone recommended
  /// one.
  static const double stackedBarMarginTop = 0;

  /// The divider between stacked buttons; also the divider width the
  /// row/stack decision takes off the bar.
  static const double stackedDividerThickness = 0.33;

  /// The stacked divider's inset on both sides.
  static const double stackedDividerInsetHorizontal = 24;

  /// Bar buttons are square cells; the panel's corners round the outer ones.
  static const double buttonCornerRadius = 0;

  /// The smallest scale a button shrinks to while pressed (surfaces up to
  /// 48 × 48).
  static const double pressedScaleMin = 0.92;

  /// The pressed scale of the largest surfaces (328 × 220 and up).
  static const double pressedScaleMax = 0.98;
}

/// The colours of a dialog bar button.
@immutable
class SoftDialogButtonColors {
  const SoftDialogButtonColors({
    required this.color,
    required this.disabledColor,
    required this.textColor,
    required this.disabledTextColor,
  });

  /// No fill, a `primary` label.
  SoftDialogButtonColors.borderless(SoftColors colors)
    : this(
        color: const Color(0x00000000),
        disabledColor: const Color(0x00000000),
        textColor: colors.primary,
        disabledTextColor: colors.disabledPrimary,
      );

  /// A `primary` fill with an `onPrimary` label: the recommended button.
  SoftDialogButtonColors.primary(SoftColors colors)
    : this(
        color: colors.primary,
        disabledColor: colors.disabledPrimaryButton,
        textColor: colors.onPrimary,
        disabledTextColor: colors.disabledOnPrimaryButton,
      );

  /// No fill, an `error` label: a destructive action.
  SoftDialogButtonColors.destructive(SoftColors colors)
    : this(
        color: const Color(0x00000000),
        disabledColor: const Color(0x00000000),
        textColor: colors.error,
        disabledTextColor: colors.error.withValues(alpha: 0.3),
      );

  final Color color;
  final Color disabledColor;
  final Color textColor;
  final Color disabledTextColor;

  @override
  bool operator ==(Object other) =>
      other is SoftDialogButtonColors &&
      other.color == color &&
      other.disabledColor == disabledColor &&
      other.textColor == textColor &&
      other.disabledTextColor == disabledTextColor;

  @override
  int get hashCode =>
      Object.hash(color, disabledColor, textColor, disabledTextColor);
}

/// One action of a [SoftDialogButtonBar], addressed by role: the bar
/// reorders its buttons when it stacks.
@immutable
class SoftDialogAction {
  const SoftDialogAction({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.recommended = false,
    this.destructive = false,
  });

  final String label;

  /// Disabled when null.
  final VoidCallback? onPressed;
  final bool enabled;

  /// Draws the action as a filled primary button. At most one action of a
  /// bar should set it.
  final bool recommended;

  /// Tints the label with the theme's `error` colour (ignored when
  /// [recommended]).
  final bool destructive;
}

/// A dialog button bar that lays its actions out in a row or a stack.
///
/// It stays a row only when there are exactly two actions and both labels
/// fit their half of the bar (the bar width, at most
/// [SoftDialogDefaults.maxWidth], less a 0.33 divider, split evenly, less
/// 12 on each side of each label); otherwise it stacks. The row puts
/// negative, neutral, positive from the start, with 1-wide dividers inset
/// 17 / 21; the stack puts neutral, positive, negative from the top, with
/// 0.33 dividers inset 24 on both sides.
///
/// Buttons are square, borderless cells with a `primary` label; pressing
/// one shrinks it (0.92–0.98 by area) and lays the state layer over it on a
/// critically damped spring. A [SoftDialogAction.recommended] action is
/// filled `primary` instead.
class SoftDialogButtonBar extends StatelessWidget {
  const SoftDialogButtonBar({
    super.key,
    this.negative,
    this.positive,
    this.neutral,
    this.dynamicLayout = true,
    this.showDivider = true,
    this.hasContentAbove = true,
    this.colors,
    this.recommendedColors,
    this.dividerColor,
    this.textStyle,
  });

  /// The cancel action.
  final SoftDialogAction? negative;

  /// The confirm action.
  final SoftDialogAction? positive;

  /// A third action.
  final SoftDialogAction? neutral;

  /// Whether the bar may stack itself; when false it is always a row.
  final bool dynamicLayout;

  /// Whether dividers separate the buttons.
  final bool showDivider;

  /// Whether a title, summary or content sits above the bar.
  final bool hasContentAbove;

  /// The non-recommended buttons; [SoftDialogButtonColors.borderless] by
  /// default.
  final SoftDialogButtonColors? colors;

  /// The recommended button; [SoftDialogButtonColors.primary] by default.
  final SoftDialogButtonColors? recommendedColors;

  /// `dividerLine` by default.
  final Color? dividerColor;

  /// The labels' style, also used to measure them; the theme's `button`
  /// style by default.
  final TextStyle? textStyle;

  List<SoftDialogAction> get _actions => <SoftDialogAction>[
    ?positive,
    ?negative,
    ?neutral,
  ];

  @override
  Widget build(BuildContext context) {
    final int count = _actions.length;
    if (count == 0) return const SizedBox.shrink();
    final SoftThemeData theme = SoftTheme.of(context);
    final TextStyle style = DefaultTextStyle.of(
      context,
    ).style.merge(textStyle ?? theme.textStyles.button);
    if (!dynamicLayout) return _row(theme, style);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.min(
          constraints.maxWidth,
          SoftDialogDefaults.maxWidth,
        );
        final bool fits = _labelsFit(context, width, count, style);
        return fits && count == 2 ? _row(theme, style) : _stack(theme, style);
      },
    );
  }

  /// Whether every label fits its cell of a row, measured in device pixels
  /// with whole-pixel rounding like the reference.
  bool _labelsFit(
    BuildContext context,
    double width,
    int count,
    TextStyle style,
  ) {
    if (!width.isFinite) return true;
    final double ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    int px(double logical) => (logical * ratio).round();
    final int dividers =
        (count - 1) * px(SoftDialogButtonBarDefaults.stackedDividerThickness);
    final int available =
        (px(width) - dividers) ~/ count -
        px(SoftDialogButtonBarDefaults.buttonHorizontalPadding) * 2;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    for (final SoftDialogAction action in _actions) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final int measured = (painter.width * ratio).ceil();
      painter.dispose();
      if (measured > available) return false;
    }
    return true;
  }

  SoftDialogButtonColors _colorsFor(
    SoftDialogAction action,
    SoftColors scheme,
  ) {
    if (action.recommended) {
      return recommendedColors ?? SoftDialogButtonColors.primary(scheme);
    }
    if (action.destructive) return SoftDialogButtonColors.destructive(scheme);
    return colors ?? SoftDialogButtonColors.borderless(scheme);
  }

  Widget _row(SoftThemeData theme, TextStyle style) {
    final List<SoftDialogAction> ordered = <SoftDialogAction>[
      ?negative,
      ?neutral,
      ?positive,
    ];
    final Color divider = dividerColor ?? theme.colors.dividerLine;
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < ordered.length; i++) {
      if (i > 0 && showDivider) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: SoftDialogButtonBarDefaults.rowDividerInsetTop,
              bottom: SoftDialogButtonBarDefaults.rowDividerInsetBottom,
            ),
            child: SizedBox(
              width: SoftDialogButtonBarDefaults.rowDividerThickness,
              child: ColoredBox(color: divider),
            ),
          ),
        );
      }
      final SoftDialogAction action = ordered[i];
      children.add(
        Expanded(
          child: _SoftDialogButton(
            action: action,
            colors: _colorsFor(action, theme.colors),
            style: style,
            minHeight: SoftDialogButtonBarDefaults.rowButtonMinHeight,
            padding: SoftDialogButtonBarDefaults.rowButtonPadding,
          ),
        ),
      );
    }
    // The cells are short, plain widgets: an intrinsic pass is cheap and
    // gives every cell (and its press fill) the height of the tallest.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _stack(SoftThemeData theme, TextStyle style) {
    final List<(_Slot, SoftDialogAction)> slots = <(_Slot, SoftDialogAction)>[
      if (neutral case final SoftDialogAction a) (_Slot.neutral, a),
      if (positive case final SoftDialogAction a) (_Slot.positive, a),
      if (negative case final SoftDialogAction a) (_Slot.negative, a),
    ];
    final Color divider = dividerColor ?? theme.colors.dividerLine;
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < slots.length; i++) {
      final (_Slot slot, SoftDialogAction action) = slots[i];
      if (i > 0 && showDivider) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal:
                  SoftDialogButtonBarDefaults.stackedDividerInsetHorizontal,
            ),
            child: SizedBox(
              height: SoftDialogButtonBarDefaults.stackedDividerThickness,
              child: ColoredBox(color: divider),
            ),
          ),
        );
      }
      final bool top = i == 0;
      final bool bottom = i == slots.length - 1;
      // A lone negative button keeps the row metrics.
      final bool loneNegative = slots.length == 1 && slot == _Slot.negative;
      children.add(
        _SoftDialogButton(
          action: action,
          colors: _colorsFor(action, theme.colors),
          style: style,
          minHeight: loneNegative
              ? SoftDialogButtonBarDefaults.rowButtonMinHeight
              : bottom
              ? SoftDialogButtonBarDefaults.stackedButtonMinHeightBottom
              : SoftDialogButtonBarDefaults.stackedButtonMinHeight,
          padding: loneNegative
              ? SoftDialogButtonBarDefaults.rowButtonPadding
              : EdgeInsets.fromLTRB(
                  SoftDialogButtonBarDefaults.buttonHorizontalPadding,
                  SoftDialogButtonBarDefaults.stackedButtonPaddingVertical +
                      (top && !hasContentAbove
                          ? SoftDialogButtonBarDefaults
                                .stackedButtonPaddingTopExtra
                          : 0),
                  SoftDialogButtonBarDefaults.buttonHorizontalPadding,
                  SoftDialogButtonBarDefaults.stackedButtonPaddingVertical +
                      (bottom
                          ? SoftDialogButtonBarDefaults
                                .stackedButtonPaddingBottomExtra
                          : 0),
                ),
        ),
      );
    }
    final bool marginTop =
        slots.length > 1 || (slots.length == 1 && slots.first.$2.recommended);
    return Padding(
      padding: EdgeInsets.only(
        top: marginTop ? SoftDialogButtonBarDefaults.stackedBarMarginTop : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

enum _Slot { neutral, positive, negative }

/// A square bar button: the press shrinks it by area and lays the state
/// layer over its fill.
class _SoftDialogButton extends StatefulWidget {
  const _SoftDialogButton({
    required this.action,
    required this.colors,
    required this.style,
    required this.minHeight,
    required this.padding,
  });

  final SoftDialogAction action;
  final SoftDialogButtonColors colors;
  final TextStyle style;
  final double minHeight;
  final EdgeInsets padding;

  @override
  State<_SoftDialogButton> createState() => _SoftDialogButtonState();
}

class _SoftDialogButtonState extends State<_SoftDialogButton>
    with TickerProviderStateMixin {
  late final SoftSpring _scale = SoftSpring(vsync: this);
  late final SoftSpring _tint = SoftSpring(vsync: this);
  bool _pressed = false;

  bool get _enabled => widget.action.enabled && widget.action.onPressed != null;

  @override
  void didUpdateWidget(_SoftDialogButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
      _scale.snapTo(0);
      _tint.snapTo(0);
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _tint.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value && _enabled;
    _scale.animateTo(_pressed ? 1 : 0, SoftMotion.stateLayer);
    _syncTint();
  }

  /// A quick tap still drives the tint to 70 % before it fades.
  Future<void> _syncTint() async {
    if (_pressed) {
      await _tint.animateTo(1, SoftMotion.stateLayer);
      return;
    }
    if (_tint.value <= 0) return;
    if (_tint.value < 0.7) {
      await _tint
          .animateTo(1, SoftMotion.stateLayer)
          .orCancel
          .catchError((_) {});
      if (!mounted || _pressed) return;
    }
    _tint.animateTo(0, SoftMotion.stateLayer);
  }

  @override
  Widget build(BuildContext context) {
    final SoftColors scheme = SoftTheme.of(context).colors;
    final bool enabled = _enabled;
    final SoftDialogButtonColors c = widget.colors;
    return SoftPressable(
      onTap: widget.action.onPressed,
      enabled: enabled,
      feedback: SoftPressFeedback.none,
      onPressedChanged: _setPressed,
      child: _PressScale(
        progress: _scale,
        child: CustomPaint(
          painter: _FillPainter(
            color: enabled ? c.color : c.disabledColor,
            tint: _tint,
            layer: scheme.stateLayer,
            layerAlpha: scheme.pressAlpha,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(
              padding: widget.padding,
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  widget.action.label,
                  textAlign: TextAlign.center,
                  style: widget.style.copyWith(
                    color: enabled ? c.textColor : c.disabledTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.color,
    required this.tint,
    required this.layer,
    required this.layerAlpha,
  }) : super(repaint: tint);

  final Color color;
  final SoftSpring tint;
  final Color layer;
  final double layerAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (color.a > 0) canvas.drawRect(rect, Paint()..color = color);
    final double t = tint.value.clamp(0.0, 1.0);
    if (t <= 0) return;
    canvas.drawRect(
      rect,
      Paint()..color = layer.withValues(alpha: layerAlpha * t),
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.color != color ||
      old.tint != tint ||
      old.layer != layer ||
      old.layerAlpha != layerAlpha;
}

/// Scales its child about its centre while pressed: down to 0.92 for
/// surfaces up to 48 × 48, 0.98 from 328 × 220, eased in between.
class _PressScale extends SingleChildRenderObjectWidget {
  const _PressScale({required this.progress, super.child});

  final ValueListenable<double> progress;

  @override
  _RenderPressScale createRenderObject(BuildContext context) =>
      _RenderPressScale(progress);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressScale renderObject,
  ) {
    renderObject.progress = progress;
  }
}

class _RenderPressScale extends RenderProxyBox {
  _RenderPressScale(this._progress);

  static const double _minArea = 48.0 * 48.0;
  static const double _maxArea = 328.0 * 220.0;

  ValueListenable<double> _progress;

  set progress(ValueListenable<double> value) {
    if (identical(value, _progress)) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  double get _scale {
    final double t = _progress.value;
    if (t == 0) return 1;
    final double area = size.width * size.height;
    const double low = SoftDialogButtonBarDefaults.pressedScaleMin;
    const double high = SoftDialogButtonBarDefaults.pressedScaleMax;
    final double end = area <= _minArea
        ? low
        : area >= _maxArea
        ? high
        : low +
              (high - low) *
                  SoftMotion.inEase.transform(
                    (area - _minArea) / (_maxArea - _minArea),
                  );
    return 1 - (1 - end) * t;
  }

  Matrix4 _transform(double s) => Matrix4.diagonal3Values(s, s, 1)
    ..setTranslationRaw(size.width / 2 * (1 - s), size.height / 2 * (1 - s), 0);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) return false;
    final double s = _scale;
    if (s == 1) return child.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: _transform(s),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final double s = _scale;
    if (s != 1) transform.multiply(_transform(s));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    final double s = _scale;
    if (s == 1) {
      context.paintChild(child, offset);
      return;
    }
    context.pushTransform(
      needsCompositing,
      offset,
      _transform(s),
      (PaintingContext context, Offset offset) =>
          context.paintChild(child, offset),
    );
  }
}
