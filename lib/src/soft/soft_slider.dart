import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// A slider with a thick pill track and a small white knob riding inside the
/// end of the fill.
///
/// At rest the track and fill are both 20 high and the knob a 12 dot. Touching
/// (on the way down, before any drag) swells the track to 28 and widens it to
/// the full width, so the fill sits inset by 4 inside it, and grows the knob
/// to 16 with a little overshoot. A tap on the track springs the value there;
/// a drag follows the finger with a hair of lag; dragging past either end
/// stretches the track outwards like a rubber band and lets it snap back.
///
/// With [divisions] the value moves in steps: a tick dot marks each one (white
/// inside the fill, faint outside, hidden under the knob), every step gives a
/// light haptic tick and reaching either end a stronger one.
class SoftSlider extends StatefulWidget {
  const SoftSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.semanticLabel,
    this.semanticFormatterCallback,
  }) : assert(min <= max);

  final double value;

  /// Null disables the slider.
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;
  final String Function(double value)? semanticFormatterCallback;

  static const double _trackHeight = 20;
  static const double _trackPressedHeight = 28;
  static const double _contentInset = 14;
  static const double _thumbRadius = 6;
  static const double _thumbPressedRadius = 8;
  static const double _tickRadius = 3;
  static const double minHeight = 36;

  @override
  State<SoftSlider> createState() => _SoftSliderState();
}

class _SoftSliderState extends State<SoftSlider> with TickerProviderStateMixin {
  /// The drawn position, 0..1 of the range; springs after the finger.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _fraction(widget.value),
  );

  /// Track swell, 0 at rest → 1 pressed.
  late final AnimationController _swell = AnimationController.unbounded(
    vsync: this,
  );

  /// Knob growth, 0 → 1.
  late final AnimationController _knob = AnimationController.unbounded(
    vsync: this,
  );

  /// Rubber-band stretch past an end, in logical pixels (negative = start).
  late final AnimationController _stretch = AnimationController(
    vsync: this,
    lowerBound: -100,
    upperBound: 100,
    value: 0,
  );

  static final SpringDescription _swellSpring = softSpring(0.5);
  static final SpringDescription _knobGrow = softSpring(0.5, bounce: 0.3);
  static final SpringDescription _knobShrink = softSpring(0.5);
  static final SpringDescription _tapSpring = softSpring(0.3);
  static final SpringDescription _followSpring = softSpring(0.15);

  bool _dragging = false;
  bool _pressed = false;
  double _width = 0;
  double? _lastReported;
  int? _lastStep;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;
  bool get _reduce => softReduceMotion(context);

  double _fraction(double value) => widget.max == widget.min
      ? 0
      : ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _valueAt(double fraction) {
    double v =
        widget.min + fraction.clamp(0.0, 1.0) * (widget.max - widget.min);
    final int? divisions = widget.divisions;
    if (divisions != null && divisions > 0) {
      final double step = (widget.max - widget.min) / divisions;
      v = widget.min + ((v - widget.min) / step).round() * step;
    }
    return v.clamp(widget.min, widget.max);
  }

  double get _length => math.max(0, _width - SoftSlider._contentInset * 2);

  double _fractionAtDx(double dx) =>
      _length == 0 ? 0 : (dx - SoftSlider._contentInset) / _length;

  @override
  void didUpdateWidget(SoftSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.value != oldWidget.value) {
      _position.springTo(
        _fraction(widget.value),
        _tapSpring,
        reduceMotion: _reduce,
      );
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _swell.dispose();
    _knob.dispose();
    _stretch.dispose();
    super.dispose();
  }

  void _press() {
    if (_pressed || !_enabled) return;
    _pressed = true;
    _swell.springTo(1, _swellSpring, reduceMotion: _reduce);
    _knob.springTo(1, _knobGrow, reduceMotion: _reduce);
  }

  void _unpress() {
    if (!_pressed) return;
    _pressed = false;
    _swell.springTo(0, _swellSpring, reduceMotion: _reduce);
    _knob.springTo(0, _knobShrink, reduceMotion: _reduce);
    if (_stretch.value != 0) {
      _stretch.animateTo(
        0,
        duration: _reduce ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.decelerate,
      );
    }
  }

  void _report(double value, {bool haptics = true}) {
    if (_lastReported == value) return;
    final int? divisions = widget.divisions;
    if (haptics && divisions != null && divisions > 0) {
      final int step = (_fraction(value) * divisions).round();
      if (_lastStep != null && step != _lastStep) {
        if (value == widget.min || value == widget.max) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }
      _lastStep = step;
    }
    _lastReported = value;
    widget.onChanged?.call(value);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_enabled) return;
    final double value = _valueAt(_fractionAtDx(details.localPosition.dx));
    widget.onChangeStart?.call(widget.value);
    _position.springTo(_fraction(value), _tapSpring, reduceMotion: _reduce);
    _report(value, haptics: false);
    widget.onChangeEnd?.call(value);
  }

  void _onDragStart(DragStartDetails details) {
    if (!_enabled) return;
    _dragging = true;
    _press();
    _lastReported = widget.value;
    _lastStep = widget.divisions == null
        ? null
        : (_fraction(widget.value) * widget.divisions!).round();
    widget.onChangeStart?.call(widget.value);
    _dragTo(details.localPosition.dx);
  }

  void _dragTo(double dx) {
    final double raw = _fractionAtDx(dx);
    final double value = _valueAt(raw);
    _position.springTo(_fraction(value), _followSpring, reduceMotion: _reduce);
    // Past an end: a rubber band, ever harder to pull.
    final double over = raw < 0
        ? raw * _length
        : raw > 1
        ? (raw - 1) * _length
        : 0;
    const double maxStretch = 14;
    _stretch.value = over == 0
        ? 0
        : over.sign * maxStretch * (1 - math.exp(-over.abs() / 40));
    _report(value);
  }

  void _onDragEnd() {
    if (!_dragging) return;
    _dragging = false;
    _unpress();
    widget.onChangeEnd?.call(_lastReported ?? widget.value);
  }

  void _nudge(int direction) {
    if (!_enabled) return;
    final int? divisions = widget.divisions;
    final double step =
        (widget.max - widget.min) /
        (divisions != null && divisions > 0 ? divisions : 10);
    final double value = (widget.value + step * direction).clamp(
      widget.min,
      widget.max,
    );
    widget.onChangeStart?.call(widget.value);
    _report(value, haptics: false);
    widget.onChangeEnd?.call(value);
  }

  String _describe(double value) =>
      widget.semanticFormatterCallback?.call(value) ??
      '${(_fraction(value) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = _enabled;
    final _SliderColors colors = _SliderColors(
      track: theme.isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
      fill: enabled ? theme.accent : theme.accent.withValues(alpha: 0.3),
      thumb: enabled
          ? const Color(0xFFFFFFFF)
          : (theme.isDark ? const Color(0x29FFFFFF) : const Color(0x8AFFFFFF)),
      thumbShadow: enabled
          ? (theme.isDark ? const Color(0x40000000) : const Color(0x1A000000))
          : const Color(0x00000000),
      tickActive: enabled
          ? const Color(0xFFFFFFFF)
          : (theme.isDark ? const Color(0x29FFFFFF) : const Color(0x8AFFFFFF)),
      tickInactive: theme.labelTertiary,
    );
    return Semantics(
      slider: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: _describe(widget.value),
      increasedValue: _describe(
        (widget.value + (widget.max - widget.min) / (widget.divisions ?? 10))
            .clamp(widget.min, widget.max),
      ),
      decreasedValue: _describe(
        (widget.value - (widget.max - widget.min) / (widget.divisions ?? 10))
            .clamp(widget.min, widget.max),
      ),
      onIncrease: enabled ? () => _nudge(1) : null,
      onDecrease: enabled ? () => _nudge(-1) : null,
      child: Listener(
        onPointerDown: enabled ? (_) => _press() : null,
        onPointerUp: (_) {
          if (!_dragging) _unpress();
        },
        onPointerCancel: (_) {
          if (!_dragging) _unpress();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: enabled ? _onTapUp : null,
          onHorizontalDragStart: enabled ? _onDragStart : null,
          onHorizontalDragUpdate: enabled
              ? (DragUpdateDetails d) => _dragTo(d.localPosition.dx)
              : null,
          onHorizontalDragEnd: enabled ? (_) => _onDragEnd() : null,
          onHorizontalDragCancel: enabled ? _onDragEnd : null,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              _width = constraints.hasBoundedWidth ? constraints.maxWidth : 200;
              return SizedBox(
                width: _width,
                height: SoftSlider.minHeight,
                child: CustomPaint(
                  painter: _SliderPainter(
                    repaint: Listenable.merge(<Listenable>[
                      _position,
                      _swell,
                      _knob,
                      _stretch,
                    ]),
                    position: () => _position.value,
                    swell: () => _swell.value,
                    knob: () => _knob.value,
                    stretch: () => _stretch.value,
                    colors: colors,
                    divisions: widget.divisions,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SliderColors {
  const _SliderColors({
    required this.track,
    required this.fill,
    required this.thumb,
    required this.thumbShadow,
    required this.tickActive,
    required this.tickInactive,
  });

  final Color track;
  final Color fill;
  final Color thumb;
  final Color thumbShadow;
  final Color tickActive;
  final Color tickInactive;

  @override
  bool operator ==(Object other) =>
      other is _SliderColors &&
      other.track == track &&
      other.fill == fill &&
      other.thumb == thumb &&
      other.thumbShadow == thumbShadow &&
      other.tickActive == tickActive &&
      other.tickInactive == tickInactive;

  @override
  int get hashCode =>
      Object.hash(track, fill, thumb, thumbShadow, tickActive, tickInactive);
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required Listenable repaint,
    required this.position,
    required this.swell,
    required this.knob,
    required this.stretch,
    required this.colors,
    required this.divisions,
    required this.rtl,
  }) : super(repaint: repaint);

  final double Function() position;
  final double Function() swell;
  final double Function() knob;
  final double Function() stretch;
  final _SliderColors colors;
  final int? divisions;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final double t = swell().clamp(0.0, 1.2);
    final double cy = size.height / 2;
    const double inset = SoftSlider._contentInset;
    final double length = math.max(0, size.width - inset * 2);
    final double p = position().clamp(0.0, 1.0);
    final double thumbX = inset + p * length;
    final double s = stretch();

    // Past an end the band stretches outwards and thins a little.
    final double thin = (s.abs() / 14) * 2;
    final double trackHeight =
        lerpDouble(
          SoftSlider._trackHeight,
          SoftSlider._trackPressedHeight,
          t,
        )! -
        thin;
    final double trackHalfExtra = trackHeight / 2;
    double trackLeft = inset - trackHalfExtra;
    double trackRight = inset + length + trackHalfExtra;
    if (s < 0) trackLeft += s;
    if (s > 0) trackRight += s;
    final RRect track = RRect.fromLTRBR(
      trackLeft,
      cy - trackHeight / 2,
      trackRight,
      cy + trackHeight / 2,
      Radius.circular(trackHeight / 2),
    );
    canvas.drawRRect(track, Paint()..color = colors.track);

    final double fillHeight = SoftSlider._trackHeight - thin;
    final double r = fillHeight / 2;
    double fillLeft = inset - r;
    if (s < 0) fillLeft += s;
    final double fillRight = math.max(
      fillLeft + fillHeight,
      thumbX + r + (s > 0 && p >= 1 ? s : 0),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(fillLeft, cy - r, fillRight, cy + r, Radius.circular(r)),
      Paint()..color = colors.fill,
    );

    final double knobRadius = lerpDouble(
      SoftSlider._thumbRadius,
      SoftSlider._thumbPressedRadius,
      knob(),
    )!;
    final double knobX = fillRight - r;

    final int? steps = divisions;
    if (steps != null && steps > 0) {
      for (int i = 0; i <= steps; i++) {
        final double x = inset + length * i / steps;
        if ((x - knobX).abs() <= knobRadius + 1) continue;
        canvas.drawCircle(
          Offset(x, cy),
          SoftSlider._tickRadius,
          Paint()..color = x <= knobX ? colors.tickActive : colors.tickInactive,
        );
      }
    }

    if (colors.thumbShadow.a > 0) {
      canvas.drawCircle(
        Offset(knobX, cy + 2),
        knobRadius,
        Paint()
          ..color = colors.thumbShadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawCircle(
      Offset(knobX, cy),
      knobRadius,
      Paint()..color = colors.thumb,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.divisions != divisions ||
      oldDelegate.rtl != rtl;
}
