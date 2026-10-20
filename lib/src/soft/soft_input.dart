import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// How a [SoftTextField] is framed.
enum SoftTextFieldStyle {
  /// A hairline under the text that turns into an accent line on focus.
  underline,

  /// A 10-radius outline, accent when focused.
  outlined,

  /// Sits in a card (20 corners), no line.
  card,
}

/// A text field: 15 regular text, a hint, an optional floating [label], a
/// clear button while focused and non-empty, and an error line.
///
/// Underline style: a 0.33 divider line; focusing grows a 1 accent line out
/// from the centre (250 ms). Outlined: a 10-radius outline, 0.33 → 1 accent.
/// Card: a card background, 20 corners, no line. A label floats above the
/// text at 10 secondary while focused or filled (200 ms). An [errorText]
/// turns the line red, shows the message in 10 red text under the field and
/// shakes the field once (5.33 sideways, 450 ms).
class SoftTextField extends StatefulWidget {
  const SoftTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.style = SoftTextFieldStyle.underline,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.clearable = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final SoftTextFieldStyle style;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int? maxLines;
  final bool clearable;

  @override
  State<SoftTextField> createState() => _SoftTextFieldState();
}

class _SoftTextFieldState extends State<SoftTextField>
    with TickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(SoftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null &&
        widget.errorText != oldWidget.errorText &&
        !softReduceMotion(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _ownFocus?.dispose();
    _line.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _line.forward();
    } else {
      _line.reverse();
    }
    setState(() {});
  }

  void _onText() => setState(() {});

  /// The shake: 0 → −1 → +0.5 → −0.5 → 0 times 5.33, over 83 / 133 / 117 /
  /// 117 ms.
  double _shakeOffset(double t) {
    const List<double> stops = <double>[0, 83 / 450, 216 / 450, 333 / 450, 1];
    const List<double> values = <double>[0, -1, 0.5, -0.5, 0];
    for (int i = 0; i < 4; i++) {
      if (t <= stops[i + 1]) {
        final double local = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return 5.33 *
            (values[i] +
                (values[i + 1] - values[i]) * SoftCurves.ease.transform(local));
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool focused = _focus.hasFocus;
    final bool filled = _controller.text.isNotEmpty;
    final bool error = widget.errorText != null;
    final bool floating = widget.label != null && (focused || filled);
    final TextStyle textStyle = theme.text(
      15,
      color: widget.enabled ? theme.labelPrimary : theme.labelTertiary,
    );
    final Widget field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      style: textStyle,
      cursorColor: theme.accent,
      cursorWidth: 2,
      decoration: InputDecoration.collapsed(
        hintText: widget.label != null && !floating
            ? widget.label
            : widget.hint,
        hintStyle: textStyle.copyWith(color: theme.labelTertiary),
      ),
    );
    final Widget? clear =
        widget.clearable && focused && filled && widget.enabled
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _controller.clear();
              widget.onChanged?.call('');
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: _ClearGlyph(
                size: 22,
                disc: theme.labelSecondary,
                cross: theme.isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFFFFFFF),
              ),
            ),
          )
        : null;
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null)
          AnimatedSize(
            duration: softReduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: SoftCurves.moveEase,
            child: floating
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.label!,
                      style: theme.text(
                        10,
                        color: error ? theme.error : theme.labelSecondary,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        Row(
          children: <Widget>[
            Expanded(child: field),
            ?clear,
          ],
        ),
      ],
    );

    final EdgeInsets padding = switch (widget.style) {
      SoftTextFieldStyle.underline => const EdgeInsets.symmetric(vertical: 15),
      SoftTextFieldStyle.outlined => const EdgeInsets.fromLTRB(16, 12, 10, 12),
      SoftTextFieldStyle.card => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
    };
    body = Padding(padding: padding, child: body);

    final Color idle = widget.enabled
        ? theme.divider
        : (theme.isDark ? const Color(0x19FFFFFF) : const Color(0x19000000));
    final Color active = error ? theme.error : theme.accent;
    body = switch (widget.style) {
      SoftTextFieldStyle.underline => AnimatedBuilder(
        animation: _line,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          foregroundPainter: _UnderlinePainter(
            idle: error ? theme.error : idle,
            active: active,
            t: SoftCurves.inEase.transform(_line.value),
          ),
          child: child,
        ),
        child: body,
      ),
      SoftTextFieldStyle.outlined => AnimatedBuilder(
        animation: _line,
        builder: (BuildContext context, Widget? child) => DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: Color.lerp(
                  error ? theme.error : idle,
                  active,
                  _line.value,
                )!,
                width: 0.33 + 0.67 * _line.value,
              ),
            ),
          ),
          child: child,
        ),
        child: body,
      ),
      SoftTextFieldStyle.card => DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: body,
      ),
    };

    return AnimatedBuilder(
      animation: _shake,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(_shake.isAnimating ? _shakeOffset(_shake.value) : 0, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          body,
          AnimatedSize(
            duration: softReduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 217),
            curve: SoftCurves.ease,
            child: error
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.style == SoftTextFieldStyle.card ? 16 : 0,
                      4,
                      0,
                      4,
                    ),
                    child: Text(
                      widget.errorText!,
                      style: theme.text(10, color: theme.error),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter({
    required this.idle,
    required this.active,
    required this.t,
  });

  final Color idle;
  final Color active;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 0.33, size.width, 0.33),
      Paint()..color = idle,
    );
    if (t <= 0) return;
    final double half = size.width / 2 * t;
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - half, size.height - 1, half * 2, 1),
      Paint()..color = active,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.idle != idle || old.active != active || old.t != t;
}

/// A filled disc with a knocked-out cross (the clear button).
class _ClearGlyph extends StatelessWidget {
  const _ClearGlyph({
    required this.size,
    required this.disc,
    required this.cross,
  });

  final double size;
  final Color disc;
  final Color cross;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _ClearPainter(disc: disc, cross: cross),
    ),
  );
}

class _ClearPainter extends CustomPainter {
  const _ClearPainter({required this.disc, required this.cross});

  final Color disc;
  final Color cross;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide * 9 / 22;
    canvas.drawCircle(c, r, Paint()..color = disc);
    final Paint line = Paint()
      ..color = cross
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final double d = r * 0.42;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), line);
    canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), line);
  }

  @override
  bool shouldRepaint(_ClearPainter old) =>
      old.disc != disc || old.cross != cross;
}

/// A search bar: a 40 pill with a search glyph, 15 text and a clear button;
/// focusing it slides in an accent "Cancel" text button beside it (a
/// (0.5, 0.25) spring) that clears and unfocuses.
class SoftSearchBar extends StatefulWidget {
  const SoftSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search',
    this.cancelLabel = 'Cancel',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final String cancelLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCancel;

  @override
  State<SoftSearchBar> createState() => _SoftSearchBarState();
}

class _SoftSearchBarState extends State<SoftSearchBar>
    with SingleTickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  late final AnimationController _edit = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _ownFocus?.dispose();
    _edit.dispose();
    super.dispose();
  }

  void _onFocus() {
    _edit.springTo(
      _focus.hasFocus ? 1 : 0,
      softSpring(0.5, bounce: 0.25),
      reduceMotion: softReduceMotion(context),
    );
  }

  void _onText() => setState(() {});

  void _cancel() {
    _controller.clear();
    widget.onChanged?.call('');
    _focus.unfocus();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final TextStyle text = theme.text(15);
    final TextStyle cancelStyle = theme.text(16, color: theme.accentText);
    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.cancelLabel, style: cancelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double cancelWidth = math.max(40, painter.width) + 12;
    painter.dispose();
    return SizedBox(
      height: 52,
      child: AnimatedBuilder(
        animation: _edit,
        builder: (BuildContext context, _) {
          final double t = _edit.value;
          final double shown = t.clamp(0.0, 1.0);
          return Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: _focus.requestFocus,
                  child: Container(
                    height: 40,
                    decoration: ShapeDecoration(
                      color: theme.isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0x14000000),
                      shape: const StadiumBorder(),
                    ),
                    padding: const EdgeInsetsDirectional.only(
                      start: 2.5,
                      end: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 36,
                          child: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.labelSecondary,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            onChanged: widget.onChanged,
                            onSubmitted: widget.onSubmitted,
                            textInputAction: TextInputAction.search,
                            style: text,
                            cursorColor: theme.accent,
                            cursorWidth: 2,
                            decoration: InputDecoration.collapsed(
                              hintText: widget.hint,
                              hintStyle: text.copyWith(
                                color: theme.labelSecondary,
                              ),
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _controller.clear();
                              widget.onChanged?.call('');
                            },
                            child: SizedBox.square(
                              dimension: 36,
                              child: Center(
                                child: _ClearGlyph(
                                  size: 20,
                                  disc: theme.labelTertiary,
                                  cross: const Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: cancelWidth * shown,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: cancelWidth,
                    maxWidth: cancelWidth,
                    child: Opacity(
                      opacity: shown,
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * shown,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _cancel,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 12,
                            ),
                            child: Text(
                              widget.cancelLabel,
                              maxLines: 1,
                              style: cancelStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
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
