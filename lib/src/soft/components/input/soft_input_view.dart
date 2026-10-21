import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';
import 'soft_input_shared.dart';
import 'soft_text_field.dart';

/// The input-card defaults.
abstract final class SoftInputViewDefaults {
  /// The card's corner radius.
  static const double cornerRadius = 12;

  /// The horizontal padding inside the card.
  static const double contentPadding = 16;

  /// Above the title.
  static const double titlePaddingTop = 12;

  /// Below the title.
  static const double titlePaddingBottom = 4;

  /// The title's minimum height.
  static const double titleMinHeight = 22;

  /// Above and below the field without a title.
  static const double fieldPaddingVertical = 15;

  /// Below the field under a title (above it is 0).
  static const double fieldPaddingBottomWithTitle = 12;

  /// Above and below the multi-line field.
  static const double multiFieldPadding = 13;

  /// Between the multi-line field and its counter.
  static const double multiCountSpacing = 4;

  /// Below the multi-line counter.
  static const double multiCountMarginBottom = 12;

  /// The multi-line counter's text size.
  static const double multiCountFontSize = 12;

  /// The error caption's text size.
  static const double errorFontSize = 10;

  /// Above the error caption.
  static const double errorPaddingTop = 4;

  /// The multi-line card's default line limit.
  static const int maxLines = 5;

  /// The error caption fading in.
  static const Duration errorAppearDuration = Duration(milliseconds: 217);

  /// The error caption fading out.
  static const Duration errorDisappearDuration = Duration(milliseconds: 283);

  /// The multi-line counter turning red at the limit.
  static const Duration countColorDuration = Duration(milliseconds: 250);

  /// The title: 16 medium.
  static TextStyle titleTextStyle(SoftTextStyles styles) =>
      styles.headline2.copyWith(fontWeight: FontWeight.w500);
}

/// The colours of a [SoftInputView].
@immutable
class SoftInputViewColors {
  const SoftInputViewColors({
    required this.cardColor,
    required this.titleColor,
    required this.disabledTitleColor,
    required this.countColor,
    required this.errorColor,
  });

  /// The defaults of [colors].
  factory SoftInputViewColors.from(SoftColors colors) => SoftInputViewColors(
    cardColor: colors.surfaceContainer,
    titleColor: colors.onSurface,
    disabledTitleColor: colors.disabledOnSurface,
    countColor: colors.onSurfaceVariantActions,
    errorColor: colors.error,
  );

  final Color cardColor;
  final Color titleColor;
  final Color disabledTitleColor;

  /// The multi-line counter.
  final Color countColor;

  /// The error caption and the full multi-line counter.
  final Color errorColor;

  SoftInputViewColors copyWith({
    Color? cardColor,
    Color? titleColor,
    Color? disabledTitleColor,
    Color? countColor,
    Color? errorColor,
  }) {
    return SoftInputViewColors(
      cardColor: cardColor ?? this.cardColor,
      titleColor: titleColor ?? this.titleColor,
      disabledTitleColor: disabledTitleColor ?? this.disabledTitleColor,
      countColor: countColor ?? this.countColor,
      errorColor: errorColor ?? this.errorColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftInputViewColors &&
      other.cardColor == cardColor &&
      other.titleColor == titleColor &&
      other.disabledTitleColor == disabledTitleColor &&
      other.countColor == countColor &&
      other.errorColor == errorColor;

  @override
  int get hashCode => Object.hash(
    cardColor,
    titleColor,
    disabledTitleColor,
    countColor,
    errorColor,
  );
}

/// The card input: a card (12 corners, the theme's `surfaceContainer`)
/// holding an optional 16 medium [title] and a bare [SoftTextField], with
/// the counter and the clear and password buttons at the end of the field.
///
/// A non-empty [errorMessage] shows a 10 caption below the card, fading in
/// over 217 ms and out over 283 ms, and shakes the field. With [singleLine]
/// false it is the multi-line card: the counter moves to the card's
/// bottom-end corner (12) and turns red at the limit. A [maxCount] above 0
/// truncates the input whether or not the counter shows.
class SoftInputView extends StatefulWidget {
  const SoftInputView({
    super.key,
    this.controller,
    this.focusNode,
    this.title = '',
    this.label = '',
    this.enabled = true,
    this.readOnly = false,
    this.showCount = false,
    this.maxCount = 0,
    this.showClearButton = false,
    this.showPasswordToggle = false,
    this.errorMessage = '',
    this.cornerRadius = SoftInputViewDefaults.cornerRadius,
    this.colors,
    this.textFieldColors,
    this.textStyle,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.singleLine = true,
    this.maxLines,
    this.leading,
    this.trailing,
    this.autofillHints,
    this.clearButtonSemanticLabel,
    this.showPasswordSemanticLabel,
    this.hidePasswordSemanticLabel,
  });

  /// The text; one is created when null.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Shown inside the card above the field; empty hides it.
  final String title;

  /// The field's placeholder.
  final String label;
  final bool enabled;
  final bool readOnly;

  /// Shows the "count/max" counter; needs [maxCount] above 0.
  final bool showCount;

  /// The most characters; 0 for no limit.
  final int maxCount;
  final bool showClearButton;
  final bool showPasswordToggle;

  /// Shown below the card; empty hides it.
  final String errorMessage;
  final double cornerRadius;

  /// The card's colours; the theme's defaults when null.
  final SoftInputViewColors? colors;

  /// The field's colours; the theme's defaults when null.
  final SoftTextFieldColors? textFieldColors;

  /// The input text; body 16 when null.
  final TextStyle? textStyle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  /// The single-line card, or the multi-line one.
  final bool singleLine;

  /// The line limit; 1, or 5 in the multi-line card, when null.
  final int? maxLines;
  final Widget? leading;
  final Widget? trailing;
  final Iterable<String>? autofillHints;
  final String? clearButtonSemanticLabel;
  final String? showPasswordSemanticLabel;
  final String? hidePasswordSemanticLabel;

  @override
  State<SoftInputView> createState() => _SoftInputViewState();
}

class _SoftInputViewState extends State<SoftInputView>
    with TickerProviderStateMixin {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  late final SoftSpring _error = SoftSpring(
    vsync: this,
    value: widget.errorMessage.isNotEmpty ? 1 : 0,
  );
  late String _shownError = widget.errorMessage;
  late bool _errorMounted = widget.errorMessage.isNotEmpty;
  late final SoftAnimatedColor _countColor = SoftAnimatedColor(
    vsync: this,
    value: const Color(0x00000000),
    duration: SoftInputViewDefaults.countColorDuration,
    curve: SoftInputCurves.standard,
  );
  bool _atLimit = false;
  bool _initialised = false;

  bool get _countVisible => widget.showCount && widget.maxCount > 0;

  @override
  void initState() {
    super.initState();
    // The late fields above read the first widget; read them now, before a
    // later widget can be the one they see.
    _error;
    _shownError;
    _errorMounted;
    _controller.addListener(_onText);
    _atLimit = _isAtLimit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCount(animate: _initialised);
    _initialised = true;
  }

  @override
  void didUpdateWidget(SoftInputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
    }
    final bool wasError = oldWidget.errorMessage.isNotEmpty;
    final bool isError = widget.errorMessage.isNotEmpty;
    if (isError) _shownError = widget.errorMessage;
    if (wasError != isError) _animateError(isError);
    _atLimit = _isAtLimit();
    _syncCount();
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _error.dispose();
    _countColor.dispose();
    super.dispose();
  }

  bool _isAtLimit() =>
      widget.maxCount > 0 &&
      _controller.text.characters.length >= widget.maxCount;

  void _onText() {
    final bool atLimit = _isAtLimit();
    if (atLimit == _atLimit) return;
    _atLimit = atLimit;
    _syncCount();
  }

  void _syncCount({bool animate = true}) {
    final SoftInputViewColors c = _colors;
    _countColor.animateTo(
      _atLimit ? c.errorColor : c.countColor,
      animate: animate && !softReduceMotion(context),
    );
  }

  void _animateError(bool show) {
    final bool reduce = softReduceMotion(context);
    if (show) {
      _errorMounted = true;
      if (reduce) {
        _error.snapTo(1);
      } else {
        _error.animateCurve(
          1,
          duration: SoftInputViewDefaults.errorAppearDuration,
          curve: SoftInputCurves.ease,
        );
      }
      return;
    }
    if (reduce) {
      _error.snapTo(0);
      _errorMounted = false;
      return;
    }
    _error
        .animateCurve(
          0,
          duration: SoftInputViewDefaults.errorDisappearDuration,
          curve: SoftInputCurves.ease,
        )
        .then((_) {
          if (mounted && widget.errorMessage.isEmpty && _errorMounted) {
            setState(() => _errorMounted = false);
          }
        });
  }

  SoftInputViewColors get _colors =>
      widget.colors ?? SoftInputViewColors.from(SoftTheme.colorsOf(context));

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftInputViewColors c = _colors;
    final bool hasTitle = widget.title.isNotEmpty;
    final bool single = widget.singleLine;
    final bool countVisible = _countVisible;
    final double top = !single
        ? SoftInputViewDefaults.multiFieldPadding
        : hasTitle
        ? 0
        : SoftInputViewDefaults.fieldPaddingVertical;
    final double bottom = !single
        ? (countVisible
              ? SoftInputViewDefaults.multiCountSpacing
              : SoftInputViewDefaults.multiFieldPadding)
        : hasTitle
        ? SoftInputViewDefaults.fieldPaddingBottomWithTitle
        : SoftInputViewDefaults.fieldPaddingVertical;
    final bool fieldCounts = countVisible && single;

    final Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        color: c.cardColor,
        shape: SoftSquircleBorder.all(
          widget.cornerRadius,
          smooth: theme.smoothCorners,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SoftInputViewDefaults.contentPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (hasTitle)
              Padding(
                padding: const EdgeInsets.only(
                  top: SoftInputViewDefaults.titlePaddingTop,
                  bottom: SoftInputViewDefaults.titlePaddingBottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoftInputViewDefaults.titleMinHeight,
                  ),
                  child: Text(
                    widget.title,
                    style:
                        SoftInputViewDefaults.titleTextStyle(
                          theme.textStyles,
                        ).copyWith(
                          color: widget.enabled
                              ? c.titleColor
                              : c.disabledTitleColor,
                        ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: top, bottom: bottom),
              child: SoftTextField(
                controller: _controller,
                focusNode: widget.focusNode,
                mode: SoftTextFieldMode.none,
                insideMargin: Size.zero,
                colors: widget.textFieldColors,
                label: widget.label,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                isError: widget.errorMessage.isNotEmpty,
                maxCount: fieldCounts ? widget.maxCount : null,
                showClearButton: widget.showClearButton,
                showPasswordToggle: widget.showPasswordToggle,
                textStyle:
                    widget.textStyle ??
                    SoftTextFieldDefaults.textStyle(
                      SoftTextFieldMode.none,
                      theme.textStyles,
                    ),
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: <TextInputFormatter>[
                  ...?widget.inputFormatters,
                  if (widget.maxCount > 0 && !fieldCounts)
                    LengthLimitingTextInputFormatter(
                      widget.maxCount,
                      maxLengthEnforcement:
                          MaxLengthEnforcement.truncateAfterCompositionEnds,
                    ),
                ],
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                onEditingComplete: widget.onEditingComplete,
                maxLines:
                    widget.maxLines ??
                    (single ? 1 : SoftInputViewDefaults.maxLines),
                minLines: single ? null : 1,
                leading: widget.leading,
                trailing: widget.trailing,
                autofillHints: widget.autofillHints,
                clearButtonSemanticLabel: widget.clearButtonSemanticLabel,
                showPasswordSemanticLabel: widget.showPasswordSemanticLabel,
                hidePasswordSemanticLabel: widget.hidePasswordSemanticLabel,
              ),
            ),
            if (countVisible && !single)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: SoftInputViewDefaults.multiCountMarginBottom,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _controller,
                      _countColor,
                    ]),
                    builder: (BuildContext context, Widget? _) {
                      final int length = _controller.text.characters.length;
                      return Text(
                        '${length.clamp(0, widget.maxCount)}/${widget.maxCount}',
                        style: theme.textStyles.main.copyWith(
                          fontSize: SoftInputViewDefaults.multiCountFontSize,
                          color: _countColor.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        card,
        if (_errorMounted)
          AnimatedBuilder(
            animation: _error,
            builder: (BuildContext context, Widget? child) =>
                Opacity(opacity: _error.value.clamp(0.0, 1.0), child: child),
            child: Padding(
              padding: const EdgeInsets.only(
                top: SoftInputViewDefaults.errorPaddingTop,
                left: SoftInputViewDefaults.contentPadding,
                right: SoftInputViewDefaults.contentPadding,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _shownError,
                  style: theme.textStyles.main.copyWith(
                    fontSize: SoftInputViewDefaults.errorFontSize,
                    color: c.errorColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
