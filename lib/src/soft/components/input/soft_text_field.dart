import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';
import 'soft_input_shared.dart';

/// How a [SoftTextField] decorates its background.
enum SoftTextFieldMode {
  /// A stroke-only rounded rectangle (10 corners, no fill): a 0.33 hairline,
  /// 1 in the primary colour while focused. The text is bold.
  rectangle,

  /// No fill; a 0.33 underline, plus a 1 primary line that grows from the
  /// start edge while focused — the dialog and panel form.
  line,

  /// No decoration at all: bare text, the form used inside input cards.
  none,
}

/// The text-field defaults.
abstract final class SoftTextFieldDefaults {
  /// The rectangle's corner radius.
  static const double cornerRadius = 10;

  /// 16 horizontal, 12 vertical: the rectangle's padding.
  static const Size rectangleInsideMargin = Size(16, 12);

  /// 0 horizontal, 15 vertical: the line form's padding.
  static const Size lineInsideMargin = Size(0, 15);

  /// 0 horizontal, 9 vertical: the bare form's padding.
  static const Size noneInsideMargin = Size(0, 9);

  /// The padding of [mode]: width is horizontal, height vertical.
  static Size insideMargin(SoftTextFieldMode mode) => switch (mode) {
    SoftTextFieldMode.rectangle => rectangleInsideMargin,
    SoftTextFieldMode.line => lineInsideMargin,
    SoftTextFieldMode.none => noneInsideMargin,
  };

  /// The counter's text size.
  static const double counterFontSize = 10;

  /// The gap before the counter.
  static const double counterPadding = 8;

  /// The focused (and error) stroke.
  static const double borderWidth = 1;

  /// The resting stroke.
  static const double unfocusedBorderWidth = 0.33;

  /// The floating label's text size.
  static const double floatingLabelFontSize = 10;

  /// How far the error shake swings.
  static const double shakeAmplitude = 5.33;

  /// The round tap target of the clear and password buttons.
  static const double trailingButtonSize = 36;

  /// The clear button's circle.
  static const double clearButtonVisualSize = 18;

  /// The password eye.
  static const double passwordIconSize = 28;

  /// The error colour blend.
  static const Duration errorColorDuration = Duration(milliseconds: 217);

  /// The focused underline growing in or fading out.
  static const Duration lineDuration = Duration(milliseconds: 250);

  /// The label floating up or settling back.
  static const Duration labelDuration = Duration(milliseconds: 200);

  /// The counter turning red at the limit.
  static const Duration counterColorDuration = Duration(milliseconds: 250);

  /// The whole error shake.
  static const Duration shakeDuration = Duration(milliseconds: 450);

  /// The input text of [mode]: body 16, bold in the rectangle.
  static TextStyle textStyle(SoftTextFieldMode mode, SoftTextStyles styles) =>
      mode == SoftTextFieldMode.rectangle
      ? styles.body1.copyWith(fontWeight: FontWeight.w700)
      : styles.body1;
}

/// The colours of a [SoftTextField].
@immutable
class SoftTextFieldColors {
  const SoftTextFieldColors({
    required this.backgroundColor,
    required this.labelColor,
    required this.borderColor,
    required this.unfocusedBorderColor,
    required this.errorColor,
    required this.counterColor,
    required this.iconColor,
    required this.disabledTextColor,
  });

  /// The defaults of [colors].
  factory SoftTextFieldColors.from(SoftColors colors) => SoftTextFieldColors(
    backgroundColor: const Color(0x00000000),
    labelColor: colors.onSurfaceSecondary,
    borderColor: colors.primary,
    unfocusedBorderColor: colors.dividerLine,
    errorColor: colors.error,
    counterColor: colors.onSurfaceContainerHigh,
    iconColor: colors.onSurfaceSecondary,
    disabledTextColor: colors.disabledOnSurface,
  );

  /// The rectangle's fill; transparent by default (stroke only).
  final Color backgroundColor;

  /// The label or placeholder.
  final Color labelColor;

  /// The focused stroke or underline, and the cursor.
  final Color borderColor;

  /// The resting stroke or underline.
  final Color unfocusedBorderColor;

  /// The stroke, underline, label and full counter in the error state.
  final Color errorColor;

  /// The counter.
  final Color counterColor;

  /// The clear and password buttons.
  final Color iconColor;

  /// The text and label while disabled.
  final Color disabledTextColor;

  SoftTextFieldColors copyWith({
    Color? backgroundColor,
    Color? labelColor,
    Color? borderColor,
    Color? unfocusedBorderColor,
    Color? errorColor,
    Color? counterColor,
    Color? iconColor,
    Color? disabledTextColor,
  }) {
    return SoftTextFieldColors(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      labelColor: labelColor ?? this.labelColor,
      borderColor: borderColor ?? this.borderColor,
      unfocusedBorderColor: unfocusedBorderColor ?? this.unfocusedBorderColor,
      errorColor: errorColor ?? this.errorColor,
      counterColor: counterColor ?? this.counterColor,
      iconColor: iconColor ?? this.iconColor,
      disabledTextColor: disabledTextColor ?? this.disabledTextColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftTextFieldColors &&
      other.backgroundColor == backgroundColor &&
      other.labelColor == labelColor &&
      other.borderColor == borderColor &&
      other.unfocusedBorderColor == unfocusedBorderColor &&
      other.errorColor == errorColor &&
      other.counterColor == counterColor &&
      other.iconColor == iconColor &&
      other.disabledTextColor == disabledTextColor;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    labelColor,
    borderColor,
    unfocusedBorderColor,
    errorColor,
    counterColor,
    iconColor,
    disabledTextColor,
  );
}

enum _LabelState { hidden, placeholder, normal, floating }

/// A text field: an [EditableText] in one of three [mode]s.
///
/// The [label] is a plain placeholder that disappears once there is text;
/// with [useLabelAsPlaceholder] false it floats instead, shrinking to 10 and
/// rising half the vertical padding as soon as the field is focused or
/// filled (200 ms, move ease). [isError] blends the stroke, underline and
/// label to the error colour over 217 ms and shakes the text. [maxCount]
/// truncates the input and shows a "count/max" counter that turns red at
/// the limit. [showClearButton] adds a clear button while the field is
/// focused and not empty; [showPasswordToggle] masks the text behind an eye
/// toggle.
class SoftTextField extends StatefulWidget {
  const SoftTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.mode = SoftTextFieldMode.line,
    this.insideMargin,
    this.colors,
    this.cornerRadius = SoftTextFieldDefaults.cornerRadius,
    this.label = '',
    this.useLabelAsPlaceholder = true,
    this.justShowFocusLine = false,
    this.enabled = true,
    this.readOnly = false,
    this.isError = false,
    this.maxCount,
    this.showClearButton = false,
    this.showPasswordToggle = false,
    this.textStyle,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.maxLines = 1,
    this.minLines,
    this.leading,
    this.trailing,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.contextMenuBuilder,
    this.autofillHints,
    this.clearButtonSemanticLabel,
    this.showPasswordSemanticLabel,
    this.hidePasswordSemanticLabel,
  });

  /// The text; one is created when null.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final SoftTextFieldMode mode;

  /// The padding inside the field (width horizontal, height vertical); the
  /// [mode]'s default when null.
  final Size? insideMargin;

  /// The colours; the theme's defaults when null.
  final SoftTextFieldColors? colors;

  /// The rectangle's corner radius.
  final double cornerRadius;

  /// The label (hint). Empty hides it.
  final String label;

  /// Whether the label is a placeholder that disappears once there is text,
  /// rather than a label that floats above it.
  final bool useLabelAsPlaceholder;

  /// In the line form: hide the resting underline and show only the focused
  /// one — the form of an input preference on a card.
  final bool justShowFocusLine;
  final bool enabled;
  final bool readOnly;

  /// Tints the stroke, underline and label with the error colour and plays
  /// the shake each time it turns on.
  final bool isError;

  /// The most characters; shows a "count/max" counter and truncates input.
  final int? maxCount;

  /// Shows a clear button while the field is focused and not empty.
  final bool showClearButton;

  /// Shows an eye toggle that masks or reveals the text.
  final bool showPasswordToggle;

  /// The input text; [SoftTextFieldDefaults.textStyle] when null.
  final TextStyle? textStyle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  /// The most lines before the text scrolls; null for no limit.
  final int? maxLines;
  final int? minLines;

  /// Laid out before the text.
  final Widget? leading;

  /// Laid out after the counter and the built-in buttons.
  final Widget? trailing;
  final bool autofocus;
  final TextAlign textAlign;
  final bool enableInteractiveSelection;

  /// The selection handles and toolbar; none when null.
  final TextSelectionControls? selectionControls;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final Iterable<String>? autofillHints;

  /// Read out for the clear button.
  final String? clearButtonSemanticLabel;

  /// Read out for the eye while the text is hidden.
  final String? showPasswordSemanticLabel;

  /// Read out for the eye while the text is shown.
  final String? hidePasswordSemanticLabel;

  @override
  State<SoftTextField> createState() => _SoftTextFieldState();
}

class _SoftTextFieldState extends State<SoftTextField>
    with TickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  bool _hasText = false;
  bool _focused = false;
  bool _atLimit = false;
  bool _passwordVisible = false;
  bool _lineActive = false;
  bool _clearMounted = false;
  bool _initialised = false;

  late final SoftSpring _borderWidth = SoftSpring(
    vsync: this,
    value: SoftTextFieldDefaults.unfocusedBorderWidth,
  );
  late final SoftSpring _baseWidth = SoftSpring(
    vsync: this,
    value: SoftTextFieldDefaults.unfocusedBorderWidth,
  );
  late final SoftSpring _lineFraction = SoftSpring(vsync: this);
  late final SoftSpring _lineAlpha = SoftSpring(vsync: this);
  late final SoftSpring _label = SoftSpring(vsync: this);
  late final SoftSpring _clear = SoftSpring(vsync: this);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: SoftTextFieldDefaults.shakeDuration,
  );
  late final SoftAnimatedColor _borderColor = _color();
  late final SoftAnimatedColor _baseColor = _color();
  late final SoftAnimatedColor _focusColor = _color();
  late final SoftAnimatedColor _labelColor = _color();
  late final SoftAnimatedColor _counterColor = SoftAnimatedColor(
    vsync: this,
    value: const Color(0x00000000),
    duration: SoftTextFieldDefaults.counterColorDuration,
    curve: SoftInputCurves.standard,
  );

  SoftAnimatedColor _color() => SoftAnimatedColor(
    vsync: this,
    value: const Color(0x00000000),
    duration: SoftTextFieldDefaults.errorColorDuration,
    curve: SoftInputCurves.ease,
  );

  late final Listenable _chrome = Listenable.merge(<Listenable>[
    _borderWidth,
    _borderColor,
    _baseWidth,
    _baseColor,
    _focusColor,
    _lineFraction,
    _lineAlpha,
  ]);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_onFocus);
    _focusNode.canRequestFocus = widget.enabled;
    _hasText = _controller.text.isNotEmpty;
    _focused = _focusNode.hasFocus;
    _atLimit = _isAtLimit();
    if (widget.isError) _shake.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(animate: _initialised);
    _initialised = true;
  }

  @override
  void didUpdateWidget(SoftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
      _hasText = _controller.text.isNotEmpty;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocus);
      _focused = _focusNode.hasFocus;
    }
    _focusNode.canRequestFocus = widget.enabled;
    if (!widget.enabled && _focusNode.hasFocus) _focusNode.unfocus();
    if (oldWidget.isError != widget.isError) {
      if (widget.isError && !_reduceMotion) {
        _shake.forward(from: 0);
      } else {
        _shake.value = 0;
      }
    }
    _atLimit = _isAtLimit();
    _sync();
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _borderWidth.dispose();
    _baseWidth.dispose();
    _lineFraction.dispose();
    _lineAlpha.dispose();
    _label.dispose();
    _clear.dispose();
    _shake.dispose();
    _borderColor.dispose();
    _baseColor.dispose();
    _focusColor.dispose();
    _labelColor.dispose();
    _counterColor.dispose();
    super.dispose();
  }

  bool get _reduceMotion => softReduceMotion(context);

  bool _isAtLimit() {
    final int? max = widget.maxCount;
    return max != null && _controller.text.characters.length >= max;
  }

  void _onText() {
    final bool hasText = _controller.text.isNotEmpty;
    final bool atLimit = _isAtLimit();
    if (hasText == _hasText && atLimit == _atLimit) return;
    _hasText = hasText;
    _atLimit = atLimit;
    _sync();
    setState(() {});
  }

  void _onFocus() {
    final bool focused = _focusNode.hasFocus;
    if (focused == _focused) return;
    _focused = focused;
    _sync();
    setState(() {});
  }

  _LabelState get _labelState {
    if (widget.label.isEmpty) return _LabelState.hidden;
    if (widget.useLabelAsPlaceholder) {
      return _hasText ? _LabelState.placeholder : _LabelState.normal;
    }
    return _hasText || (_focused && widget.enabled)
        ? _LabelState.floating
        : _LabelState.normal;
  }

  bool get _clearVisible =>
      widget.showClearButton && widget.enabled && _focused && _hasText;

  /// Moves every animation towards the current state.
  void _sync({bool animate = true}) {
    final bool run = animate && !_reduceMotion;
    final SoftTextFieldColors c = _colors;
    final bool enabled = widget.enabled;
    final bool error = widget.isError;

    // The rectangle: errors keep the focused width; disabled falls back to
    // the resting stroke.
    final double width = enabled && (_focused || error)
        ? SoftTextFieldDefaults.borderWidth
        : SoftTextFieldDefaults.unfocusedBorderWidth;
    if (run) {
      _borderWidth.animateTo(width, softInputDefaultSpring, threshold: 0.01);
    } else {
      _borderWidth.snapTo(width);
    }
    _borderColor.animateTo(
      !enabled
          ? c.unfocusedBorderColor
          : error
          ? c.errorColor
          : _focused
          ? c.borderColor
          : c.unfocusedBorderColor,
      animate: run,
    );

    // The line: the resting underline thickens in the error colour.
    final bool lineError = error && enabled;
    _baseColor.animateTo(
      lineError ? c.errorColor : c.unfocusedBorderColor,
      animate: run,
    );
    final double baseWidth = lineError
        ? SoftTextFieldDefaults.borderWidth
        : SoftTextFieldDefaults.unfocusedBorderWidth;
    if (run && _baseWidth.value != baseWidth) {
      _baseWidth.animateCurve(
        baseWidth,
        duration: SoftTextFieldDefaults.errorColorDuration,
        curve: SoftInputCurves.ease,
      );
    } else if (!run) {
      _baseWidth.snapTo(baseWidth);
    }
    _focusColor.animateTo(error ? c.errorColor : c.borderColor, animate: run);
    final bool lineActive = _focused && enabled;
    if (widget.mode == SoftTextFieldMode.line &&
        (lineActive != _lineActive || !enabled)) {
      if (lineActive) {
        // Snaps opaque, then grows from the start edge.
        _lineAlpha.snapTo(1);
        _lineFraction.snapTo(0);
        if (run) {
          _lineFraction.animateCurve(
            1,
            duration: SoftTextFieldDefaults.lineDuration,
            curve: SoftInputCurves.inEase,
          );
        } else {
          _lineFraction.snapTo(1);
        }
      } else if (!enabled) {
        _lineAlpha.snapTo(0);
        _lineFraction.snapTo(0);
      } else if (_lineAlpha.value > 0) {
        // Fades out in place.
        if (run) {
          _lineAlpha.animateCurve(
            0,
            duration: SoftTextFieldDefaults.lineDuration,
            curve: SoftInputCurves.inEase,
          );
        } else {
          _lineAlpha.snapTo(0);
        }
      }
    }
    _lineActive = lineActive;

    _labelColor.animateTo(
      !enabled
          ? c.disabledTextColor
          : error
          ? c.errorColor
          : c.labelColor,
      animate: run,
    );
    final double label = _labelState == _LabelState.floating ? 1 : 0;
    if (run && _label.value != label) {
      _label.animateCurve(
        label,
        duration: SoftTextFieldDefaults.labelDuration,
        curve: SoftInputCurves.moveEase,
      );
    } else if (!run) {
      _label.snapTo(label);
    }

    _counterColor.animateTo(
      _atLimit ? c.errorColor : c.counterColor,
      animate: run,
    );

    final bool clear = _clearVisible;
    if (clear) _clearMounted = true;
    if (!run) {
      _clear.snapTo(clear ? 1 : 0);
      if (!clear) _clearMounted = false;
    } else if (clear) {
      _clear.animateTo(1, softInputFadeSpring);
    } else if (_clearMounted) {
      _clear.animateTo(0, softInputFadeSpring).then((_) {
        if (mounted && !_clearVisible && _clearMounted) {
          setState(() => _clearMounted = false);
        }
      });
    }
  }

  SoftTextFieldColors get _colors =>
      widget.colors ?? SoftTextFieldColors.from(SoftTheme.colorsOf(context));

  Size get _margin =>
      widget.insideMargin ?? SoftTextFieldDefaults.insideMargin(widget.mode);

  void _clearText() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftTextFieldColors c = _colors;
    final Size margin = _margin;
    final TextStyle base =
        widget.textStyle ??
        SoftTextFieldDefaults.textStyle(widget.mode, theme.textStyles);
    final TextStyle style = base.copyWith(
      color: widget.enabled
          ? base.color ?? theme.colors.onBackground
          : c.disabledTextColor,
    );
    final _LabelState labelState = _labelState;
    final bool hasBuiltin =
        widget.maxCount != null ||
        widget.showClearButton ||
        widget.showPasswordToggle;
    final bool hasLeading = widget.leading != null;
    final bool hasTrailing = widget.trailing != null || hasBuiltin;
    final EdgeInsetsDirectional padding = EdgeInsetsDirectional.only(
      start: hasLeading ? 0 : margin.width,
      end: hasTrailing ? 0 : margin.width,
      top: margin.height,
      bottom: margin.height,
    );
    final bool obscured = widget.showPasswordToggle && !_passwordVisible;

    return SoftEditable(
      controller: _controller,
      focusNode: _focusNode,
      style: style,
      cursorColor: c.borderColor,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: obscured,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: <TextInputFormatter>[
        ...?widget.inputFormatters,
        if (widget.maxCount != null)
          LengthLimitingTextInputFormatter(
            widget.maxCount,
            maxLengthEnforcement:
                MaxLengthEnforcement.truncateAfterCompositionEnds,
          ),
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      selectionControls: widget.selectionControls,
      contextMenuBuilder: widget.contextMenuBuilder,
      autofillHints: widget.autofillHints,
      builder: (BuildContext context, Widget editable) {
        final Widget shaken = AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) {
            final double dx =
                _shakeAt(_shake.value) * SoftTextFieldDefaults.shakeAmplitude;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: editable,
        );
        final Widget content = Stack(
          alignment: AlignmentDirectional.topStart,
          children: <Widget>[
            if (labelState == _LabelState.normal ||
                labelState == _LabelState.floating)
              _FloatingLabel(
                text: widget.label,
                progress: _label,
                color: _labelColor,
                style: theme.textStyles.main.copyWith(
                  fontSize: style.fontSize ?? 16,
                  fontWeight:
                      labelState == _LabelState.floating &&
                          widget.mode == SoftTextFieldMode.rectangle
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
                rise: margin.height / 2,
              ),
            Transform.translate(
              offset: Offset(
                0,
                labelState == _LabelState.floating ? margin.height / 2 : 0,
              ),
              child: shaken,
            ),
          ],
        );
        return CustomPaint(
          painter: _ChromePainter(
            repaint: _chrome,
            mode: widget.mode,
            fill: c.backgroundColor,
            radius: widget.cornerRadius,
            smooth: theme.smoothCorners,
            borderWidth: _borderWidth,
            borderColor: _borderColor,
            baseWidth: _baseWidth,
            baseColor: _baseColor,
            focusColor: _focusColor,
            lineFraction: _lineFraction,
            lineAlpha: _lineAlpha,
            drawBase: !widget.justShowFocusLine,
            error: widget.isError && widget.enabled,
            textDirection: Directionality.of(context),
          ),
          child: Row(
            children: <Widget>[
              ?widget.leading,
              Expanded(
                child: Padding(padding: padding, child: content),
              ),
              if (hasBuiltin) _builtinTrailing(c, margin),
              ?widget.trailing,
            ],
          ),
        );
      },
    );
  }

  Widget _builtinTrailing(SoftTextFieldColors c, Size margin) {
    final bool hasButtons = widget.showClearButton || widget.showPasswordToggle;
    final int? max = widget.maxCount;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: hasButtons ? 0 : margin.width),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (max != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: SoftTextFieldDefaults.counterPadding,
              ),
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  _controller,
                  _counterColor,
                ]),
                builder: (BuildContext context, Widget? _) => Text(
                  '${_controller.text.characters.length}/$max',
                  style: SoftTheme.textStylesOf(context).main.copyWith(
                    fontSize: SoftTextFieldDefaults.counterFontSize,
                    color: _counterColor.value,
                  ),
                ),
              ),
            ),
          if (widget.showClearButton && _clearMounted)
            AnimatedBuilder(
              animation: _clear,
              builder: (BuildContext context, Widget? child) =>
                  Opacity(opacity: _clear.value.clamp(0.0, 1.0), child: child),
              child: SoftInputIconButton(
                onTap: _clearText,
                size: SoftTextFieldDefaults.trailingButtonSize,
                glyphSize: SoftTextFieldDefaults.clearButtonVisualSize,
                painter: SoftClearGlyphPainter(color: c.iconColor),
                semanticLabel: widget.clearButtonSemanticLabel,
              ),
            ),
          if (widget.showPasswordToggle)
            SoftInputIconButton(
              onTap: () => setState(() => _passwordVisible = !_passwordVisible),
              size: SoftTextFieldDefaults.trailingButtonSize,
              glyphSize: SoftTextFieldDefaults.passwordIconSize,
              painter: SoftEyeGlyphPainter(
                color: c.iconColor,
                open: _passwordVisible,
              ),
              semanticLabel: _passwordVisible
                  ? widget.hidePasswordSemanticLabel
                  : widget.showPasswordSemanticLabel,
            ),
        ],
      ),
    );
  }
}

/// The shake at [t] of its 450 ms: offsets 0, -1, 0.5, -0.5, 0 (times the
/// amplitude) at 0, 83, 216, 333 and 450 ms, eased between keyframes.
double _shakeAt(double t) {
  if (t <= 0 || t >= 1) return 0;
  const List<double> times = <double>[0, 83, 216, 333, 450];
  const List<double> values = <double>[0, -1, 0.5, -0.5, 0];
  final double ms = t * 450;
  for (int i = 0; i < times.length - 1; i++) {
    if (ms <= times[i + 1]) {
      final double local = (ms - times[i]) / (times[i + 1] - times[i]);
      final double eased = SoftInputCurves.ease.transform(local);
      return values[i] + (values[i + 1] - values[i]) * eased;
    }
  }
  return 0;
}

/// The label, laid out once at full size and scaled towards 10 as it
/// floats, so the animation never relays out text.
class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({
    required this.text,
    required this.progress,
    required this.color,
    required this.style,
    required this.rise,
  });

  final String text;
  final SoftSpring progress;
  final SoftAnimatedColor color;
  final TextStyle style;
  final double rise;

  @override
  Widget build(BuildContext context) {
    final double full = style.fontSize ?? 16;
    final double small = SoftTextFieldDefaults.floatingLabelFontSize / full;
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? child) {
        final double t = progress.value;
        final double scale = 1 + (small - 1) * t;
        return Transform.translate(
          offset: Offset(0, -rise * t),
          child: Transform.scale(
            scale: scale,
            alignment: AlignmentDirectional.topStart.resolve(
              Directionality.of(context),
            ),
            child: child,
          ),
        );
      },
      child: ListenableBuilder(
        listenable: color,
        builder: (BuildContext context, Widget? _) =>
            Text(text, style: style.copyWith(color: color.value)),
      ),
    );
  }
}

class _ChromePainter extends CustomPainter {
  _ChromePainter({
    required Listenable repaint,
    required this.mode,
    required this.fill,
    required this.radius,
    required this.smooth,
    required this.borderWidth,
    required this.borderColor,
    required this.baseWidth,
    required this.baseColor,
    required this.focusColor,
    required this.lineFraction,
    required this.lineAlpha,
    required this.drawBase,
    required this.error,
    required this.textDirection,
  }) : super(repaint: repaint);

  final SoftTextFieldMode mode;
  final Color fill;
  final double radius;
  final bool smooth;
  final SoftSpring borderWidth;
  final SoftAnimatedColor borderColor;
  final SoftSpring baseWidth;
  final SoftAnimatedColor baseColor;
  final SoftAnimatedColor focusColor;
  final SoftSpring lineFraction;
  final SoftSpring lineAlpha;
  final bool drawBase;
  final bool error;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case SoftTextFieldMode.none:
        return;
      case SoftTextFieldMode.rectangle:
        final Rect rect = Offset.zero & size;
        if (fill.a > 0) {
          drawSoftSquircle(
            canvas,
            rect,
            BorderRadius.circular(radius),
            Paint()..color = fill,
            smooth: smooth,
          );
        }
        final double w = borderWidth.value;
        if (w <= 0) return;
        final double inset = w / 2;
        canvas.drawPath(
          softSquirclePath(
            rect.deflate(inset),
            BorderRadius.circular((radius - inset).clamp(0.0, radius)),
            smooth: smooth,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = borderColor.value,
        );
      case SoftTextFieldMode.line:
        if (drawBase || error) {
          final double w = baseWidth.value;
          canvas.drawRect(
            Rect.fromLTWH(0, size.height - w, size.width, w),
            Paint()..color = baseColor.value,
          );
        }
        final double alpha = lineAlpha.value.clamp(0.0, 1.0);
        if (alpha <= 0) return;
        const double w = SoftTextFieldDefaults.borderWidth;
        final Color color = focusColor.value;
        final double length = size.width * lineFraction.value.clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(
            textDirection == TextDirection.rtl ? size.width - length : 0,
            size.height - w,
            length,
            w,
          ),
          Paint()..color = color.withValues(alpha: color.a * alpha),
        );
    }
  }

  @override
  bool shouldRepaint(_ChromePainter old) =>
      old.mode != mode ||
      old.fill != fill ||
      old.radius != radius ||
      old.smooth != smooth ||
      old.drawBase != drawBase ||
      old.error != error ||
      old.textDirection != textDirection;
}
