import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_input_shared.dart';

/// The search-bar defaults.
abstract final class SoftSearchBarDefaults {
  /// 16 horizontal, 6 vertical around the field.
  static const Size insideMargin = Size(16, 6);

  /// The capsule's minimum height.
  static const double inputFieldMinHeight = 40;

  /// The query and placeholder size.
  static const double inputFieldFontSize = 15;

  /// The magnifier glyph.
  static const double leadingIconSize = 20;

  /// Before the magnifier.
  static const double leadingIconStartPadding = 12;

  /// After the magnifier.
  static const double leadingIconEndPadding = 8;

  /// Before the clear button.
  static const double trailingIconStartPadding = 4;

  /// After the clear button.
  static const double trailingIconEndPadding = 4;

  /// The clear button's round tap target.
  static const double trailingIconTouchTargetSize = 36;

  /// The clear button's circle.
  static const double trailingIconVisualSize = 18;

  /// The capsule fill without blur in the light theme: white at 39 %.
  static const Color noBlurSolidLight = Color(0x64FFFFFF);

  /// The capsule fill without blur in the dark theme.
  static const Color noBlurSolidDark = Color(0x28767676);

  /// The end action's width growing or shrinking.
  static const Duration actionResizeDuration = Duration(milliseconds: 450);

  /// The end action sliding in or out.
  static const Duration actionOffsetDuration = Duration(milliseconds: 400);

  /// The end action fading.
  static const Duration actionAlphaDuration = Duration(milliseconds: 350);

  /// How far the end action slides.
  static const double actionSlideDistance = 60;

  /// Before the end action.
  static const double actionStartPadding = 4;

  /// After the end action.
  static const double actionEndPadding = 16;

  /// The wait after collapsing before the query is cleared and the field
  /// lets go of focus.
  static const Duration collapseDelay = Duration(milliseconds: 100);
}

/// The colours of a [SoftSearchField].
@immutable
class SoftSearchBarColors {
  const SoftSearchBarColors({
    required this.backgroundColor,
    required this.labelColor,
    required this.iconColor,
    required this.clearIconColor,
  });

  /// The defaults of [theme].
  factory SoftSearchBarColors.from(SoftThemeData theme) => SoftSearchBarColors(
    backgroundColor: theme.isDark
        ? SoftSearchBarDefaults.noBlurSolidDark
        : SoftSearchBarDefaults.noBlurSolidLight,
    labelColor: theme.colors.onSurfaceSecondary,
    iconColor: theme.colors.onSurfaceSecondary,
    clearIconColor: theme.colors.onSurfaceContainerHigh,
  );

  /// The capsule.
  final Color backgroundColor;

  /// The placeholder.
  final Color labelColor;

  /// The default magnifier.
  final Color iconColor;

  /// The default clear button's circle.
  final Color clearIconColor;

  SoftSearchBarColors copyWith({
    Color? backgroundColor,
    Color? labelColor,
    Color? iconColor,
    Color? clearIconColor,
  }) {
    return SoftSearchBarColors(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      labelColor: labelColor ?? this.labelColor,
      iconColor: iconColor ?? this.iconColor,
      clearIconColor: clearIconColor ?? this.clearIconColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftSearchBarColors &&
      other.backgroundColor == backgroundColor &&
      other.labelColor == labelColor &&
      other.iconColor == iconColor &&
      other.clearIconColor == clearIconColor;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, labelColor, iconColor, clearIconColor);
}

/// A search bar: an [inputField] (usually a [SoftSearchField]) padded by
/// [insideMargin], an [outsideEndAction] (usually a
/// [SoftSearchBarCancelAction]) that slides in beside it while [expanded],
/// and [content] (suggestions, results) that unfolds below.
///
/// The action grows over 450 ms, slides in 60 over 400 ms and fades over
/// 350 ms, all on the move ease. The content fades and unfolds from its
/// bottom edge on a critically damped spring. While [expanded], the back
/// gesture collapses the bar instead of leaving the page.
class SoftSearchBar extends StatefulWidget {
  const SoftSearchBar({
    super.key,
    required this.inputField,
    required this.onExpandedChange,
    this.insideMargin = SoftSearchBarDefaults.insideMargin,
    this.expanded = false,
    this.outsideEndAction,
    this.content,
  });

  final Widget inputField;
  final ValueChanged<bool> onExpandedChange;

  /// The padding around [inputField]: width horizontal, height vertical.
  final Size insideMargin;
  final bool expanded;

  /// Shown at the end while [expanded].
  final Widget? outsideEndAction;

  /// Shown below while [expanded].
  final Widget? content;

  @override
  State<SoftSearchBar> createState() => _SoftSearchBarState();
}

class _SoftSearchBarState extends State<SoftSearchBar>
    with TickerProviderStateMixin {
  static final SpringDescription _contentSpring = softSpringStiffness(
    damping: 1,
    stiffness: 400,
  );

  late final SoftSpring _width = SoftSpring(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final SoftSpring _offset = SoftSpring(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final SoftSpring _alpha = SoftSpring(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final SoftSpring _content = SoftSpring(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final Listenable _action = Listenable.merge(<Listenable>[
    _width,
    _offset,
    _alpha,
  ]);
  late bool _actionMounted = widget.expanded;
  late bool _contentMounted = widget.expanded;

  @override
  void initState() {
    super.initState();
    // The late fields above read the first widget; read them now, before a
    // later widget can be the one they see.
    _action;
    _content;
    _actionMounted;
    _contentMounted;
  }

  @override
  void didUpdateWidget(SoftSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _animate(widget.expanded);
  }

  @override
  void dispose() {
    _width.dispose();
    _offset.dispose();
    _alpha.dispose();
    _content.dispose();
    super.dispose();
  }

  void _animate(bool expand) {
    final double target = expand ? 1 : 0;
    if (expand) {
      _actionMounted = true;
      _contentMounted = true;
    }
    if (softReduceMotion(context)) {
      _width.snapTo(target);
      _offset.snapTo(target);
      _alpha.snapTo(target);
      _content.snapTo(target);
      if (!expand) {
        _actionMounted = false;
        _contentMounted = false;
      }
      return;
    }
    const Curve ease = SoftInputCurves.moveEase;
    _width
        .animateCurve(
          target,
          duration: SoftSearchBarDefaults.actionResizeDuration,
          curve: ease,
        )
        .then((_) => _settled(action: true));
    _offset.animateCurve(
      target,
      duration: SoftSearchBarDefaults.actionOffsetDuration,
      curve: ease,
    );
    _alpha.animateCurve(
      target,
      duration: SoftSearchBarDefaults.actionAlphaDuration,
      curve: ease,
    );
    _content
        .animateTo(target, _contentSpring)
        .then((_) => _settled(action: false));
  }

  void _settled({required bool action}) {
    if (!mounted || widget.expanded) return;
    setState(() {
      if (action) {
        _actionMounted = false;
      } else {
        _contentMounted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget? endAction = widget.outsideEndAction;
    final Widget? content = widget.content;
    final Widget row = Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.insideMargin.width,
              vertical: widget.insideMargin.height,
            ),
            child: widget.inputField,
          ),
        ),
        if (endAction != null && _actionMounted)
          _EndAction(
            animation: _action,
            width: _width,
            offset: _offset,
            alpha: _alpha,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: SoftSearchBarDefaults.actionStartPadding,
                end: SoftSearchBarDefaults.actionEndPadding,
              ),
              child: endAction,
            ),
          ),
      ],
    );
    return PopScope<Object?>(
      canPop: !widget.expanded,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && widget.expanded) widget.onExpandedChange(false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row,
          if (content != null && _contentMounted)
            AnimatedBuilder(
              animation: _content,
              builder: (BuildContext context, Widget? child) {
                // One structure throughout, so the content keeps its state
                // when the animation settles.
                final double t = _content.value.clamp(0.0, 1.0);
                return ClipRect(
                  clipBehavior: t >= 1 ? Clip.none : Clip.hardEdge,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: t,
                    child: Opacity(opacity: t, child: child),
                  ),
                );
              },
              child: content,
            ),
        ],
      ),
    );
  }
}

class _EndAction extends StatelessWidget {
  const _EndAction({
    required this.animation,
    required this.width,
    required this.offset,
    required this.alpha,
    required this.child,
  });

  final Listenable animation;
  final SoftSpring width;
  final SoftSpring offset;
  final SoftSpring alpha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double sign = Directionality.of(context) == TextDirection.rtl
        ? -1
        : 1;
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double w = width.value.clamp(0.0, 1.0);
        final double a = alpha.value.clamp(0.0, 1.0);
        final double dx =
            sign *
            SoftSearchBarDefaults.actionSlideDistance *
            (1 - offset.value);
        return ClipRect(
          clipBehavior: w >= 1 ? Clip.none : Clip.hardEdge,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: w,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(opacity: a, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// The text button at the end of an expanded [SoftSearchBar]: [label] in
/// bold primary, with no press feedback.
class SoftSearchBarCancelAction extends StatelessWidget {
  const SoftSearchBarCancelAction({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.style,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  /// The text; main 17 bold in the primary colour when null.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return SoftPressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      feedback: SoftPressFeedback.none,
      child: Text(
        label,
        maxLines: 1,
        style:
            style ??
            theme.textStyles.main.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.primary,
            ),
      ),
    );
  }
}

/// The field of a [SoftSearchBar]: a 40 capsule with a magnifier, the query
/// (15) over a [label] placeholder, and a clear button that fades in while
/// there is a query.
///
/// Focusing it asks to expand. Once [expanded] turns false, it waits 100 ms,
/// fades out and clears any query, then lets go of focus.
class SoftSearchField extends StatefulWidget {
  const SoftSearchField({
    super.key,
    this.controller,
    this.focusNode,
    required this.expanded,
    required this.onExpandedChange,
    this.onChanged,
    this.onSearch,
    this.label = '',
    this.enabled = true,
    this.textStyle,
    this.colors,
    this.leading,
    this.trailing,
    this.searchSemanticLabel,
    this.clearButtonSemanticLabel,
  });

  /// The query; one is created when null.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool expanded;
  final ValueChanged<bool> onExpandedChange;
  final ValueChanged<String>? onChanged;

  /// Called with the query on the keyboard's search action.
  final ValueChanged<String>? onSearch;

  /// Shown while the query is empty and the bar is collapsed.
  final String label;
  final bool enabled;

  /// Merged over the query and placeholder style.
  final TextStyle? textStyle;

  /// The colours; the theme's defaults when null.
  final SoftSearchBarColors? colors;

  /// Replaces the magnifier; pass an empty box to drop it.
  final Widget? leading;

  /// Replaces the clear button.
  final Widget? trailing;

  /// Read out for the magnifier.
  final String? searchSemanticLabel;

  /// Read out for the clear button.
  final String? clearButtonSemanticLabel;

  @override
  State<SoftSearchField> createState() => _SoftSearchFieldState();
}

class _SoftSearchFieldState extends State<SoftSearchField>
    with TickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  late final SoftSpring _textAlpha = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _clear = SoftSpring(vsync: this);
  bool _hasText = false;
  bool _clearMounted = false;
  Timer? _collapse;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_onFocus);
    _focusNode.canRequestFocus = widget.enabled;
    _hasText = _controller.text.isNotEmpty;
    _clearMounted = _hasText;
    _clear.snapTo(_hasText ? 1 : 0);
    if (widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.expanded) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SoftSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onText);
      _hasText = _controller.text.isNotEmpty;
      _syncClear();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocus);
    }
    _focusNode.canRequestFocus = widget.enabled;
    if (oldWidget.expanded != widget.expanded) {
      _collapse?.cancel();
      _collapse = null;
      if (widget.expanded) {
        _textAlpha.snapTo(1);
        _focusNode.requestFocus();
      } else if (_focusNode.hasFocus) {
        _collapse = Timer(SoftSearchBarDefaults.collapseDelay, _onCollapsed);
      }
    }
  }

  @override
  void dispose() {
    _collapse?.cancel();
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _textAlpha.dispose();
    _clear.dispose();
    super.dispose();
  }

  Future<void> _onCollapsed() async {
    _collapse = null;
    if (!mounted || widget.expanded) return;
    if (_controller.text.isNotEmpty) {
      if (!softReduceMotion(context)) {
        await _textAlpha
            .animateTo(0, softInputDefaultSpring)
            .orCancel
            .catchError((_) {});
      }
      if (!mounted || widget.expanded) {
        _textAlpha.snapTo(1);
        return;
      }
      _controller.clear();
      widget.onChanged?.call('');
      _textAlpha.snapTo(1);
    }
    _focusNode.unfocus();
  }

  void _onText() {
    final bool hasText = _controller.text.isNotEmpty;
    if (hasText == _hasText) return;
    setState(() {
      _hasText = hasText;
      _syncClear();
    });
  }

  void _syncClear() {
    if (_hasText) {
      _clearMounted = true;
      _clear.animateTo(1, softInputFadeSpring);
    } else if (_clearMounted) {
      _clear.animateTo(0, softInputFadeSpring).then((_) {
        if (mounted && !_hasText && _clearMounted) {
          setState(() => _clearMounted = false);
        }
      });
    }
  }

  void _onFocus() {
    if (_focusNode.hasFocus) widget.onExpandedChange(true);
  }

  void _clearQuery() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftSearchBarColors c =
        widget.colors ?? SoftSearchBarColors.from(theme);
    final TextStyle base = theme.textStyles.main
        .copyWith(fontSize: SoftSearchBarDefaults.inputFieldFontSize)
        .merge(widget.textStyle);
    final TextStyle style = base.copyWith(color: theme.colors.onBackground);
    final bool showLabel = !(_hasText || widget.expanded);

    final Widget leading =
        widget.leading ??
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SoftSearchBarDefaults.leadingIconStartPadding,
            end: SoftSearchBarDefaults.leadingIconEndPadding,
          ),
          child: Semantics(
            label: widget.searchSemanticLabel,
            image: widget.searchSemanticLabel != null,
            child: CustomPaint(
              size: const Size.square(SoftSearchBarDefaults.leadingIconSize),
              painter: SoftSearchGlyphPainter(color: c.iconColor),
            ),
          ),
        );

    final Widget? trailing =
        widget.trailing ??
        (_clearMounted
            ? AnimatedBuilder(
                animation: _clear,
                builder: (BuildContext context, Widget? child) => Opacity(
                  opacity: _clear.value.clamp(0.0, 1.0),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: SoftSearchBarDefaults.trailingIconStartPadding,
                    end: SoftSearchBarDefaults.trailingIconEndPadding,
                  ),
                  child: SoftInputIconButton(
                    onTap: _clearQuery,
                    size: SoftSearchBarDefaults.trailingIconTouchTargetSize,
                    glyphSize: SoftSearchBarDefaults.trailingIconVisualSize,
                    painter: SoftClearGlyphPainter(
                      color: c.clearIconColor,
                      crossColor: const Color(0xFFFFFFFF),
                    ),
                    semanticLabel: widget.clearButtonSemanticLabel,
                  ),
                ),
              )
            : null);

    return SoftEditable(
      controller: _controller,
      focusNode: _focusNode,
      style: style,
      cursorColor: theme.colors.primary,
      enabled: widget.enabled,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: (String query) => widget.onSearch?.call(query),
      builder: (BuildContext context, Widget editable) {
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: c.backgroundColor,
            shape: const StadiumBorder(),
          ),
          child: Row(
            children: <Widget>[
              leading,
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoftSearchBarDefaults.inputFieldMinHeight,
                  ),
                  child: Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: <Widget>[
                      if (showLabel)
                        Text(
                          widget.label,
                          maxLines: 1,
                          style: base.copyWith(color: c.labelColor),
                        ),
                      AnimatedBuilder(
                        animation: _textAlpha,
                        builder: (BuildContext context, Widget? child) {
                          return Opacity(
                            opacity: _textAlpha.value.clamp(0.0, 1.0),
                            child: child,
                          );
                        },
                        child: editable,
                      ),
                    ],
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}
