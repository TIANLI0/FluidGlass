import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';

/// The curves the input family shares.
abstract final class SoftInputCurves {
  /// The standard ease, (0.33, 0, 0.67, 1): error colours, the shake.
  static const Cubic ease = Cubic(0.33, 0, 0.67, 1);

  /// The move ease, (0.3, 0, 0.1, 1): the floating label, the search bar.
  static const Cubic moveEase = Cubic(0.3, 0, 0.1, 1);

  /// The in ease, (0, 0, 0.1, 1): the focused underline.
  static const Cubic inEase = SoftMotion.inEase;

  /// A tween with no explicit easing, (0.4, 0, 0.2, 1).
  static const Cubic standard = Cubic(0.4, 0, 0.2, 1);
}

/// The default spring of an unspecified state animation: critically damped,
/// stiffness 1500.
final SpringDescription softInputDefaultSpring = softSpringStiffness(
  damping: 1,
  stiffness: 1500,
);

/// The spring of a default fade in or out: critically damped, stiffness 400.
final SpringDescription softInputFadeSpring = softSpringStiffness(
  damping: 1,
  stiffness: 400,
);

/// A colour that tweens from wherever it is to each new target over a fixed
/// duration and curve.
///
/// It is a [Listenable]; listen to repaint.
class SoftAnimatedColor extends ChangeNotifier
    implements ValueListenable<Color> {
  SoftAnimatedColor({
    required TickerProvider vsync,
    required Color value,
    required Duration duration,
    this.curve = Curves.linear,
  }) : _begin = value,
       _end = value,
       _controller = AnimationController(
         vsync: vsync,
         duration: duration,
         value: 1,
       ) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;
  final Curve curve;
  Color _begin;
  Color _end;

  /// The colour it is heading to.
  Color get target => _end;

  @override
  Color get value {
    final double t = _controller.value;
    if (t >= 1) return _end;
    return Color.lerp(_begin, _end, curve.transform(t))!;
  }

  /// Tweens to [target]; with [animate] false it jumps there.
  void animateTo(Color target, {bool animate = true}) {
    if (target == _end) return;
    if (!animate) {
      _controller.stop();
      _begin = target;
      _end = target;
      _controller.value = 1;
      notifyListeners();
      return;
    }
    _begin = value;
    _end = target;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// The text-editing core of the input family: an [EditableText] with the
/// platform's tap, double-tap and long-press selection gestures, which
/// [builder] wraps in its chrome. The gestures cover the whole chrome, so a
/// tap anywhere on the field focuses it.
class SoftEditable extends StatefulWidget {
  const SoftEditable({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.cursorColor,
    required this.builder,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.enableInteractiveSelection = true,
    this.selectionColor,
    this.selectionControls,
    this.contextMenuBuilder,
    this.autofillHints,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color cursorColor;

  /// Wraps the editable text in the field's chrome.
  final Widget Function(BuildContext context, Widget editable) builder;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  final TextAlign textAlign;
  final bool enableInteractiveSelection;
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final Iterable<String>? autofillHints;

  @override
  State<SoftEditable> createState() => _SoftEditableState();
}

class _SoftEditableState extends State<SoftEditable>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enableInteractiveSelection;

  @override
  Widget build(BuildContext context) {
    final bool dark = SoftTheme.of(context).isDark;
    final Widget editable = SizedBox(
      width: double.infinity,
      child: RepaintBoundary(
        child: EditableText(
          key: editableTextKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: widget.style,
          cursorColor: widget.cursorColor,
          backgroundCursorColor: const Color(0xFF8E8E93),
          selectionColor:
              widget.selectionColor ??
              widget.cursorColor.withValues(alpha: 0.4),
          readOnly: widget.readOnly || !widget.enabled,
          obscureText: widget.obscureText,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onEditingComplete: widget.onEditingComplete,
          autofocus: widget.autofocus,
          textAlign: widget.textAlign,
          keyboardAppearance: dark ? Brightness.dark : Brightness.light,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          selectionControls: widget.enableInteractiveSelection
              ? widget.selectionControls
              : null,
          contextMenuBuilder: widget.contextMenuBuilder,
          autofillHints: widget.autofillHints,
          rendererIgnoresPointer: true,
        ),
      ),
    );
    return TextFieldTapRegion(
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.text
              : SystemMouseCursors.basic,
          child: _gestures.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: widget.builder(context, editable),
          ),
        ),
      ),
    );
  }
}

/// A round 36 tap target holding a small glyph, with the tint press of the
/// reference's clickable.
class SoftInputIconButton extends StatelessWidget {
  const SoftInputIconButton({
    super.key,
    required this.onTap,
    required this.glyphSize,
    required this.painter,
    this.size = 36,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final double size;
  final double glyphSize;
  final CustomPainter painter;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: SoftPressable(
        onTap: onTap,
        semanticsButton: false,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: CustomPaint(size: Size.square(glyphSize), painter: painter),
          ),
        ),
      ),
    );
  }
}

/// The clear glyph: a filled circle with a cross 8.2 across, stroked 1.6.
///
/// With [crossColor] null the cross is knocked out of the circle, so the
/// surface under the field shows through it.
class SoftClearGlyphPainter extends CustomPainter {
  const SoftClearGlyphPainter({required this.color, this.crossColor});

  final Color color;
  final Color? crossColor;

  static const double _half = 4.1;
  static const double _stroke = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    final Paint fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final Color? cross = crossColor;
    if (cross != null) {
      canvas.drawCircle(c, r, fill);
      final Paint line = Paint()
        ..color = cross
        ..strokeWidth = _stroke;
      canvas.drawLine(
        c + const Offset(-_half, -_half),
        c + const Offset(_half, _half),
        line,
      );
      canvas.drawLine(
        c + const Offset(-_half, _half),
        c + const Offset(_half, -_half),
        line,
      );
      return;
    }
    final Path circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final Path bars = Path()
      ..addPath(_bar(c, math.pi / 4), Offset.zero)
      ..addPath(_bar(c, -math.pi / 4), Offset.zero);
    canvas.drawPath(Path.combine(PathOperation.difference, circle, bars), fill);
  }

  /// A butt-capped bar of the cross through [c] at [angle].
  static Path _bar(Offset c, double angle) {
    const double length = _half * math.sqrt2;
    final Offset along = Offset(math.cos(angle), math.sin(angle)) * length;
    final Offset across =
        Offset(-math.sin(angle), math.cos(angle)) * (_stroke / 2);
    return Path()
      ..moveTo((c - along + across).dx, (c - along + across).dy)
      ..lineTo((c + along + across).dx, (c + along + across).dy)
      ..lineTo((c + along - across).dx, (c + along - across).dy)
      ..lineTo((c - along - across).dx, (c - along - across).dy)
      ..close();
  }

  @override
  bool shouldRepaint(SoftClearGlyphPainter old) =>
      old.color != color || old.crossColor != crossColor;
}

/// The password eye, open or slashed, drawn on a 34 grid.
class SoftEyeGlyphPainter extends CustomPainter {
  const SoftEyeGlyphPainter({required this.color, required this.open});

  final Color color;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 34;
    final Offset centre = Offset(17 * s, 17 * s);
    final Path eye = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(6 * s, 17 * s)
      ..cubicTo(12 * s, 27.716 * s, 22 * s, 27.716 * s, 28 * s, 17 * s)
      ..cubicTo(22 * s, 6.286 * s, 12 * s, 6.286 * s, 6 * s, 17 * s)
      ..close()
      ..addOval(Rect.fromCircle(center: centre, radius: 5.02 * s))
      ..addOval(Rect.fromCircle(center: centre, radius: 3.016 * s));
    final Paint fill = Paint()..color = color;
    if (open) {
      canvas.drawPath(eye, fill);
      return;
    }
    final Offset start = Offset(6.7 * s, 6.73 * s);
    final Offset end = Offset(27.24 * s, 27.27 * s);
    const Offset normal = Offset(-0.7071, 0.7071);
    final double halfBand = 2.8 * s;
    final Path band = Path()
      ..moveTo(start.dx + normal.dx * halfBand, start.dy + normal.dy * halfBand)
      ..lineTo(end.dx + normal.dx * halfBand, end.dy + normal.dy * halfBand)
      ..lineTo(end.dx - normal.dx * halfBand, end.dy - normal.dy * halfBand)
      ..lineTo(start.dx - normal.dx * halfBand, start.dy - normal.dy * halfBand)
      ..close();
    canvas.drawPath(Path.combine(PathOperation.difference, eye, band), fill);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SoftEyeGlyphPainter old) =>
      old.color != color || old.open != open;
}

/// The magnifier glyph on a 20 grid.
class SoftSearchGlyphPainter extends CustomPainter {
  const SoftSearchGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 20;
    final Path p = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(12.572 * s, 13.379 * s)
      ..cubicTo(
        11.541 * s,
        14.183 * s,
        10.244 * s,
        14.662 * s,
        8.835 * s,
        14.662 * s,
      )
      ..cubicTo(
        5.477 * s,
        14.662 * s,
        2.754 * s,
        11.94 * s,
        2.754 * s,
        8.581 * s,
      )
      ..cubicTo(2.754 * s, 5.223 * s, 5.477 * s, 2.5 * s, 8.835 * s, 2.5 * s)
      ..cubicTo(
        12.194 * s,
        2.5 * s,
        14.916 * s,
        5.223 * s,
        14.916 * s,
        8.581 * s,
      )
      ..cubicTo(
        14.916 * s,
        9.99 * s,
        14.437 * s,
        11.287 * s,
        13.633 * s,
        12.318 * s,
      )
      ..lineTo(17.464 * s, 16.149 * s)
      ..cubicTo(
        17.563 * s,
        16.248 * s,
        17.612 * s,
        16.297 * s,
        17.645 * s,
        16.346 * s,
      )
      ..cubicTo(
        17.78 * s,
        16.548 * s,
        17.78 * s,
        16.811 * s,
        17.645 * s,
        17.013 * s,
      )
      ..cubicTo(
        17.612 * s,
        17.062 * s,
        17.563 * s,
        17.111 * s,
        17.464 * s,
        17.21 * s,
      )
      ..cubicTo(
        17.366 * s,
        17.308 * s,
        17.316 * s,
        17.358 * s,
        17.267 * s,
        17.39 * s,
      )
      ..cubicTo(
        17.065 * s,
        17.525 * s,
        16.802 * s,
        17.525 * s,
        16.601 * s,
        17.39 * s,
      )
      ..cubicTo(
        16.551 * s,
        17.358 * s,
        16.502 * s,
        17.308 * s,
        16.403 * s,
        17.21 * s,
      )
      ..lineTo(12.572 * s, 13.379 * s)
      ..close()
      ..moveTo(13.416 * s, 8.581 * s)
      ..cubicTo(
        13.416 * s,
        11.111 * s,
        11.365 * s,
        13.162 * s,
        8.835 * s,
        13.162 * s,
      )
      ..cubicTo(
        6.305 * s,
        13.162 * s,
        4.254 * s,
        11.111 * s,
        4.254 * s,
        8.581 * s,
      )
      ..cubicTo(4.254 * s, 6.051 * s, 6.305 * s, 4 * s, 8.835 * s, 4 * s)
      ..cubicTo(11.365 * s, 4 * s, 13.416 * s, 6.051 * s, 13.416 * s, 8.581 * s)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SoftSearchGlyphPainter old) => old.color != color;
}
