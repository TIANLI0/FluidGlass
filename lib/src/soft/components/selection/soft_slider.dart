import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show PointerExitEvent, PointerHoverEvent, kTouchSlop;
import 'package:flutter/widgets.dart';

import '../../../gestures/drag_gesture_inspector.dart';
import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';
import 'soft_selection_frame.dart';

/// Which haptics a slider plays while dragged.
enum SoftSliderHapticEffect {
  /// None.
  none,

  /// A threshold tick on reaching either end.
  edge,

  /// The end ticks, plus a tick on every step (or every key point when
  /// [SoftSlider.keyPoints] is set).
  step,
}

/// The slider geometry, timing and springs.
abstract final class SoftSliderDefaults {
  /// The rest thickness of the track, and the height the slider lays out at.
  static const double height = 20;

  /// The radius of the key-point dots.
  static const double keyPointRadius = 3;

  static const SoftSliderHapticEffect hapticEffect =
      SoftSliderHapticEffect.edge;

  /// The distance, as a fraction of the range, within which a value snaps
  /// onto a custom key point.
  static const double magnetThreshold = 0.02;

  /// The inactive track swells to 1.4× while dragged, past the layout bounds.
  static const double trackEnlargeScale = 1.4;

  /// The thumb radius over the track thickness (6 on 20).
  static const double thumbRadiusRatio = 0.3;

  /// The thumb grows from 6 to 8 while held.
  static const double thumbPressedScale = 8 / 6;

  /// The track swelling and shrinking back.
  static const Duration trackGrowDuration = Duration(milliseconds: 183);
  static const Cubic trackGrowCurve = Cubic(0.33, 0, 0.67, 1);

  /// The thumb growing: critically damped, stiffness 987.
  static final SpringDescription thumbSpring = softSpringStiffness(
    damping: 1,
    stiffness: 987,
  );

  /// The progress following the value while dragged: 0.9, 1755.
  static final SpringDescription dragSpring = softSpringStiffness(
    damping: 0.9,
    stiffness: 1755,
  );

  /// The progress settling on a value set otherwise: 0.96, 322.
  static final SpringDescription settleSpring = softSpringStiffness(
    damping: 0.96,
    stiffness: 322,
  );

  /// The thumb shadow: a 4 blur, 2 down, black at 10 %.
  static const double thumbShadowRadius = 4;
  static const double thumbShadowOffsetY = 2;
  static const Color thumbShadowColor = Color(0x1A000000);
}

/// The colours of a [SoftSlider] or [SoftRangeSlider].
@immutable
class SoftSliderColors {
  const SoftSliderColors({
    required this.foreground,
    required this.disabledForeground,
    required this.background,
    required this.disabledBackground,
    required this.thumb,
    required this.disabledThumb,
    required this.keyPoint,
    required this.keyPointForeground,
    required this.secondaryProgress,
    required this.disabledSecondaryProgress,
  });

  /// The reference roles: a `primary` progress on a `sliderBackground`
  /// track, an `onPrimary` thumb, `sliderKeyPoint` dots that turn
  /// `sliderKeyPointForeground` under the progress, and a `secondaryVariant`
  /// secondary progress.
  factory SoftSliderColors.of(SoftColors c) => SoftSliderColors(
    foreground: c.primary,
    disabledForeground: c.disabledPrimarySlider,
    background: c.sliderBackground,
    disabledBackground: c.disabledSecondary,
    thumb: c.onPrimary,
    disabledThumb: c.disabledOnPrimary,
    keyPoint: c.sliderKeyPoint,
    keyPointForeground: c.sliderKeyPointForeground,
    secondaryProgress: c.secondaryVariant,
    disabledSecondaryProgress: c.disabledSecondaryVariant,
  );

  final Color foreground;
  final Color disabledForeground;
  final Color background;
  final Color disabledBackground;
  final Color thumb;
  final Color disabledThumb;
  final Color keyPoint;
  final Color keyPointForeground;
  final Color secondaryProgress;
  final Color disabledSecondaryProgress;

  @override
  bool operator ==(Object other) =>
      other is SoftSliderColors &&
      other.foreground == foreground &&
      other.disabledForeground == disabledForeground &&
      other.background == background &&
      other.disabledBackground == disabledBackground &&
      other.thumb == thumb &&
      other.disabledThumb == disabledThumb &&
      other.keyPoint == keyPoint &&
      other.keyPointForeground == keyPointForeground &&
      other.secondaryProgress == secondaryProgress &&
      other.disabledSecondaryProgress == disabledSecondaryProgress;

  @override
  int get hashCode => Object.hash(
    foreground,
    disabledForeground,
    background,
    disabledBackground,
    thumb,
    disabledThumb,
    keyPoint,
    keyPointForeground,
    secondaryProgress,
    disabledSecondaryProgress,
  );
}

/// The two values of a [SoftRangeSlider].
@immutable
class SoftRangeValues {
  const SoftRangeValues(this.start, this.end);

  final double start;
  final double end;

  @override
  bool operator ==(Object other) =>
      other is SoftRangeValues && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SoftRangeValues($start, $end)';
}

/// A horizontal slider.
///
/// A capsule track [height] thick (20) with a primary progress and a white
/// thumb of radius 0.3 × [height] that carries a soft shadow. Dragging
/// anywhere on the track moves the value to the finger once the drag passes
/// the touch slop — a tap alone does nothing — and while dragged the track
/// swells to 1.4× (drawn past the layout bounds) and, if the drag began on
/// the thumb, the thumb grows to 8/6. The drawn progress follows [value] on a
/// spring, so the caller's value is what shows.
///
/// [steps] snaps to evenly spaced values between [min] and [max];
/// [keyPoints] adds magnetic points (within [magnetThreshold]) drawn as dots
/// when [showKeyPoints]. [secondaryProgress] draws a second, fainter
/// progress behind the first.
///
/// The slider takes horizontal drags in the gesture arena, so a vertical list
/// it sits in does not scroll under a sideways drag.
class SoftSlider extends StatefulWidget {
  const SoftSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.min = 0,
    this.max = 1,
    this.steps = 0,
    this.onChangeEnd,
    this.reverseDirection = false,
    this.height = SoftSliderDefaults.height,
    this.colors,
    this.hapticEffect = SoftSliderDefaults.hapticEffect,
    this.showKeyPoints = false,
    this.keyPoints,
    this.magnetThreshold = SoftSliderDefaults.magnetThreshold,
    this.secondaryProgress,
    this.semanticFormatter,
  }) : assert(steps >= 0),
       assert(min < max);

  /// Coerced into [min]..[max].
  final double value;

  /// Without it the slider does not respond to drags.
  final ValueChanged<double>? onChanged;
  final bool enabled;
  final double min;
  final double max;

  /// The number of allowed values strictly between [min] and [max].
  final int steps;

  /// Called when a drag ends.
  final VoidCallback? onChangeEnd;

  /// Increases from the end side instead (flipped again in right-to-left
  /// text).
  final bool reverseDirection;

  /// The rest track thickness.
  final double height;

  /// Defaults to [SoftSliderColors.of] the theme's colours.
  final SoftSliderColors? colors;
  final SoftSliderHapticEffect hapticEffect;

  /// Draws the [keyPoints], or every step when there are none.
  final bool showKeyPoints;

  /// Values within [min]..[max] that the value snaps onto.
  final List<double>? keyPoints;
  final double magnetThreshold;

  /// Coerced into [min]..[max]; null draws none.
  final double? secondaryProgress;

  /// The value accessibility services read; a percentage by default.
  final String Function(double value)? semanticFormatter;

  @override
  State<SoftSlider> createState() => _SoftSliderState();
}

class _SoftSliderState extends State<SoftSlider> with TickerProviderStateMixin {
  late final SoftSpring _progress = SoftSpring(
    vsync: this,
    value: _fraction(widget.value),
  );
  late final SoftSpring _thumb = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _grow = SoftSpring(vsync: this);
  final _SliderHaptics _haptics = _SliderHaptics(_Edge.both);
  late _KeyPoints _points = _KeyPoints.of(widget);
  late double _progressTarget = _fraction(widget.value);
  double _thumbTarget = 1;

  bool _reduceMotion = false;
  bool _rtl = false;
  double _slop = kTouchSlop;

  bool _pointerDown = false;
  bool _claimed = false;
  bool _dragging = false;
  bool _grabbed = false;
  bool _hovering = false;
  double _downX = 0;
  double _lastX = 0;
  Size _size = Size.zero;
  double? _lastReported;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  bool get _reverse =>
      _rtl ? !widget.reverseDirection : widget.reverseDirection;

  double _fraction(double value) {
    final double v = value.clamp(widget.min, widget.max);
    return (v - widget.min) / (widget.max - widget.min);
  }

  @override
  void didUpdateWidget(SoftSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _points = _KeyPoints.of(widget);
    if (!_interactive) _cancel();
    _syncProgress();
  }

  @override
  void dispose() {
    _progress.dispose();
    _thumb.dispose();
    _grow.dispose();
    super.dispose();
  }

  void _syncProgress() {
    final double target = _fraction(widget.value);
    if (target == _progressTarget) return;
    _progressTarget = target;
    if (_reduceMotion && !_dragging) {
      _progress.snapTo(target);
    } else {
      _progress.animateTo(
        target,
        _dragging
            ? SoftSliderDefaults.dragSpring
            : SoftSliderDefaults.settleSpring,
      );
    }
  }

  void _syncThumb() {
    final double target = (_dragging && _grabbed) || _hovering
        ? SoftSliderDefaults.thumbPressedScale
        : 1;
    if (target == _thumbTarget) return;
    _thumbTarget = target;
    if (_reduceMotion) {
      _thumb.snapTo(target);
    } else {
      _thumb.animateTo(target, SoftSliderDefaults.thumbSpring);
    }
  }

  void _syncGrow() {
    final double target = _dragging ? 1 : 0;
    if (_reduceMotion) {
      _grow.snapTo(target);
    } else {
      _grow.animateCurve(
        target,
        duration: SoftSliderDefaults.trackGrowDuration,
        curve: SoftSliderDefaults.trackGrowCurve,
      );
    }
  }

  double _valueAt(double x) {
    final double visual = _visualFraction(x, _size);
    return _points.resolve(
      _reverse ? 1 - visual : visual,
      widget.min,
      widget.max,
      widget.steps,
      widget.magnetThreshold,
    );
  }

  void _report(double value) {
    if (value == _lastReported) return;
    _lastReported = value;
    widget.onChanged?.call(value);
  }

  void _onDown(Offset position, Size size) {
    if (!_interactive) return;
    _pointerDown = true;
    _claimed = false;
    _downX = _lastX = position.dx;
    _size = size;
  }

  void _onMove(Offset position, Offset delta, Size size) {
    if (!_pointerDown) return;
    _lastX = position.dx;
    _size = size;
    if (_dragging) {
      _dragTo(position.dx);
    } else {
      _maybeStart();
    }
  }

  void _onClaim() {
    if (!_pointerDown) return;
    _claimed = true;
    _maybeStart();
  }

  /// The drag starts once the arena has given it to the slider and it has
  /// passed the touch slop sideways.
  void _maybeStart() {
    if (!_claimed || _dragging) return;
    if ((_lastX - _downX).abs() < _slop) return;
    final double x = _lastX;
    final double thumbX = _thumbX(_progress.value, _size, _reverse);
    _grabbed = (x - thumbX).abs() <= _capInset(_size.height);
    _dragging = true;
    _lastReported = null;
    _syncThumb();
    _syncGrow();
    final double value = _valueAt(x);
    _report(value);
    _haptics.reset(value);
  }

  void _dragTo(double x) {
    final double value = _valueAt(x);
    _report(value);
    _haptics.handle(
      value,
      min: widget.min,
      max: widget.max,
      effect: widget.hapticEffect,
      keyPoints: _points.all,
      hasCustomKeyPoints: widget.keyPoints != null,
    );
  }

  void _end() {
    _pointerDown = false;
    _claimed = false;
    if (!_dragging) return;
    _dragging = false;
    _grabbed = false;
    _syncThumb();
    _syncGrow();
    widget.onChangeEnd?.call();
  }

  void _cancel() {
    if (_hovering) {
      _hovering = false;
      _syncThumb();
    }
    _end();
  }

  void _onHover(PointerHoverEvent event) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final double thumbX = _thumbX(_progress.value, box.size, _reverse);
    final bool over =
        (event.localPosition.dx - thumbX).abs() <= _capInset(box.size.height);
    if (over == _hovering) return;
    _hovering = over;
    _syncThumb();
  }

  void _onExit(PointerExitEvent _) {
    if (!_hovering) return;
    _hovering = false;
    _syncThumb();
  }

  double get _accessibilityStep => widget.steps > 0
      ? (widget.max - widget.min) / (widget.steps + 1)
      : (widget.max - widget.min) / 20;

  void _adjust(int direction) {
    final double current = widget.value.clamp(widget.min, widget.max);
    final double target = (current + direction * _accessibilityStep).clamp(
      widget.min,
      widget.max,
    );
    if (target == current) return;
    widget.onChanged?.call(target);
    widget.onChangeEnd?.call();
  }

  String _format(double value) {
    final String Function(double)? formatter = widget.semanticFormatter;
    if (formatter != null) return formatter(value);
    return '${(_fraction(value) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = softReduceMotion(context);
    _rtl = Directionality.of(context) == TextDirection.rtl;
    _slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
    final SoftSliderColors colors =
        widget.colors ?? SoftSliderColors.of(SoftTheme.colorsOf(context));
    final bool enabled = widget.enabled;
    final bool interactive = _interactive;
    final double value = widget.value.clamp(widget.min, widget.max);
    final double? secondary = widget.secondaryProgress;
    return SoftMinTouchTarget(
      child: Semantics(
        container: true,
        slider: true,
        enabled: enabled,
        value: _format(value),
        increasedValue: _format(
          (value + _accessibilityStep).clamp(widget.min, widget.max),
        ),
        decreasedValue: _format(
          (value - _accessibilityStep).clamp(widget.min, widget.max),
        ),
        onIncrease: interactive ? () => _adjust(1) : null,
        onDecrease: interactive ? () => _adjust(-1) : null,
        child: MouseRegion(
          onHover: interactive ? _onHover : null,
          onExit: interactive ? _onExit : null,
          child: DragInspector(
            claimAxis: interactive ? Axis.horizontal : null,
            onDragStart: interactive ? _onDown : null,
            onDrag: interactive ? _onMove : null,
            onDragEnd: interactive ? _end : null,
            onDragCancel: interactive ? _end : null,
            onClaim: interactive ? _onClaim : null,
            child: _TrackBox(
              height: widget.height,
              painter: _SliderPainter(
                progress: _progress,
                thumbScale: _thumb,
                grow: _grow,
                background: enabled
                    ? colors.background
                    : colors.disabledBackground,
                foreground: enabled
                    ? colors.foreground
                    : colors.disabledForeground,
                thumb: enabled ? colors.thumb : colors.disabledThumb,
                keyPoint: colors.keyPoint,
                keyPointForeground: colors.keyPointForeground,
                secondary: enabled
                    ? colors.secondaryProgress
                    : colors.disabledSecondaryProgress,
                secondaryFraction: secondary == null
                    ? null
                    : _fraction(secondary),
                keyPoints: widget.showKeyPoints
                    ? _points.all
                    : const <double>[],
                reverse: _reverse,
                shadow: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider with two thumbs selecting a range.
///
/// It looks and moves like [SoftSlider]; the progress spans the two thumbs.
/// A drag takes the thumb it starts on, or the nearer one; when both sit on
/// the same value the last one dragged wins, and dragging past the other
/// thumb's value hands the drag over to it, so the thumbs never cross.
/// While dragged the thumbs follow the finger even before the caller echoes
/// the values back.
class SoftRangeSlider extends StatefulWidget {
  const SoftRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    this.min = 0,
    this.max = 1,
    this.steps = 0,
    this.onChangeEnd,
    this.height = SoftSliderDefaults.height,
    this.colors,
    this.hapticEffect = SoftSliderDefaults.hapticEffect,
    this.showKeyPoints = false,
    this.keyPoints,
    this.magnetThreshold = SoftSliderDefaults.magnetThreshold,
    this.secondaryProgress,
    this.semanticFormatter,
  }) : assert(steps >= 0),
       assert(min < max);

  /// Each coerced into [min]..[max].
  final SoftRangeValues values;

  /// Without it the slider does not respond to drags.
  final ValueChanged<SoftRangeValues>? onChanged;
  final bool enabled;
  final double min;
  final double max;
  final int steps;
  final VoidCallback? onChangeEnd;
  final double height;
  final SoftSliderColors? colors;
  final SoftSliderHapticEffect hapticEffect;
  final bool showKeyPoints;
  final List<double>? keyPoints;
  final double magnetThreshold;
  final double? secondaryProgress;

  /// Formats each value accessibility services read; the raw number by
  /// default.
  final String Function(double value)? semanticFormatter;

  @override
  State<SoftRangeSlider> createState() => _SoftRangeSliderState();
}

class _SoftRangeSliderState extends State<SoftRangeSlider>
    with TickerProviderStateMixin {
  late double _start = widget.values.start;
  late double _end = widget.values.end;
  late final SoftSpring _startProgress = SoftSpring(
    vsync: this,
    value: _fraction(_start),
  );
  late final SoftSpring _endProgress = SoftSpring(
    vsync: this,
    value: _fraction(_end),
  );
  late final SoftSpring _startThumb = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _endThumb = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _grow = SoftSpring(vsync: this);
  final _SliderHaptics _startHaptics = _SliderHaptics(_Edge.start);
  final _SliderHaptics _endHaptics = _SliderHaptics(_Edge.end);
  late _KeyPoints _points = _KeyPoints.of(widget);
  late double _startTarget = _fraction(_start);
  late double _endTarget = _fraction(_end);
  double _startThumbTarget = 1;
  double _endThumbTarget = 1;

  bool _reduceMotion = false;
  bool _rtl = false;
  double _slop = kTouchSlop;

  bool _pointerDown = false;
  bool _claimed = false;
  bool _draggingStart = false;
  bool _draggingEnd = false;
  bool _lastDraggedIsStart = true;
  bool _hoverStart = false;
  bool _hoverEnd = false;
  double _downX = 0;
  double _lastX = 0;
  Size _size = Size.zero;
  SoftRangeValues? _lastReported;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  bool get _dragging => _draggingStart || _draggingEnd;

  double _fraction(double value) {
    final double v = value.clamp(widget.min, widget.max);
    return (v - widget.min) / (widget.max - widget.min);
  }

  @override
  void didUpdateWidget(SoftRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _points = _KeyPoints.of(widget);
    if (!_interactive) _cancel();
    // While dragged the thumbs follow the finger, not the caller.
    if (!_dragging) {
      _start = widget.values.start;
      _end = widget.values.end;
    }
    _syncProgress();
  }

  @override
  void dispose() {
    _startProgress.dispose();
    _endProgress.dispose();
    _startThumb.dispose();
    _endThumb.dispose();
    _grow.dispose();
    super.dispose();
  }

  void _animate(SoftSpring spring, double target) {
    if (_reduceMotion && !_dragging) {
      spring.snapTo(target);
    } else {
      spring.animateTo(
        target,
        _dragging
            ? SoftSliderDefaults.dragSpring
            : SoftSliderDefaults.settleSpring,
      );
    }
  }

  void _syncProgress() {
    final double start = _fraction(_start);
    final double end = _fraction(_end);
    if (start != _startTarget) {
      _startTarget = start;
      _animate(_startProgress, start);
    }
    if (end != _endTarget) {
      _endTarget = end;
      _animate(_endProgress, end);
    }
  }

  void _syncThumbs() {
    final double pressed = SoftSliderDefaults.thumbPressedScale;
    final double start = _draggingStart || _hoverStart ? pressed : 1;
    final double end = _draggingEnd || _hoverEnd ? pressed : 1;
    if (start != _startThumbTarget) {
      _startThumbTarget = start;
      _reduceMotion
          ? _startThumb.snapTo(start)
          : _startThumb.animateTo(start, SoftSliderDefaults.thumbSpring);
    }
    if (end != _endThumbTarget) {
      _endThumbTarget = end;
      _reduceMotion
          ? _endThumb.snapTo(end)
          : _endThumb.animateTo(end, SoftSliderDefaults.thumbSpring);
    }
  }

  void _syncGrow() {
    final double target = _dragging ? 1 : 0;
    if (_reduceMotion) {
      _grow.snapTo(target);
    } else {
      _grow.animateCurve(
        target,
        duration: SoftSliderDefaults.trackGrowDuration,
        curve: SoftSliderDefaults.trackGrowCurve,
      );
    }
  }

  double _valueAt(double x) {
    final double visual = _visualFraction(x, _size);
    return _points.resolve(
      _rtl ? 1 - visual : visual,
      widget.min,
      widget.max,
      widget.steps,
      widget.magnetThreshold,
    );
  }

  void _report() {
    final SoftRangeValues values = SoftRangeValues(_start, _end);
    if (values == _lastReported) return;
    _lastReported = values;
    widget.onChanged?.call(values);
  }

  void _onDown(Offset position, Size size) {
    if (!_interactive) return;
    _pointerDown = true;
    _claimed = false;
    _downX = _lastX = position.dx;
    _size = size;
  }

  void _onMove(Offset position, Offset delta, Size size) {
    if (!_pointerDown) return;
    _lastX = position.dx;
    _size = size;
    if (_dragging) {
      _dragTo(position.dx, delta.dx);
    } else {
      _maybeStart();
    }
  }

  void _onClaim() {
    if (!_pointerDown) return;
    _claimed = true;
    _maybeStart();
  }

  void _maybeStart() {
    if (!_claimed || _dragging) return;
    if ((_lastX - _downX).abs() < _slop) return;
    final double x = _lastX;
    final double startX = _thumbX(_fraction(_start), _size, _rtl);
    final double endX = _thumbX(_fraction(_end), _size, _rtl);
    final double hit = _capInset(_size.height);
    final bool onStart = (x - startX).abs() <= hit;
    final bool onEnd = (x - endX).abs() <= hit;
    final bool takeStart = onStart && onEnd
        ? _lastDraggedIsStart
        : onStart || (!onEnd && (x - startX).abs() <= (x - endX).abs());
    if (takeStart) {
      _draggingStart = true;
      _startHaptics.reset(_start.clamp(widget.min, widget.max));
    } else {
      _draggingEnd = true;
      _endHaptics.reset(_end.clamp(widget.min, widget.max));
    }
    _lastReported = null;
    _syncThumbs();
    _syncGrow();
  }

  void _handleStart(double value) => _startHaptics.handle(
    value,
    min: widget.min,
    max: widget.max,
    effect: widget.hapticEffect,
    keyPoints: _points.all,
    hasCustomKeyPoints: widget.keyPoints != null,
  );

  void _handleEnd(double value) => _endHaptics.handle(
    value,
    min: widget.min,
    max: widget.max,
    effect: widget.hapticEffect,
    keyPoints: _points.all,
    hasCustomKeyPoints: widget.keyPoints != null,
  );

  void _dragTo(double x, double dx) {
    // Towards the end side of the track, in reading order.
    final double forward = _rtl ? -dx : dx;
    if (_draggingStart) {
      _lastDraggedIsStart = true;
      final double newStart = math.min(_valueAt(x), _end);
      if (newStart >= _end && forward > 0 && _start == _end) {
        // Pushed past the other thumb: the drag moves on with it.
        _draggingStart = false;
        _draggingEnd = true;
        _endHaptics
          ..reset(_end)
          ..atKeyPoint = _startHaptics.atKeyPoint;
        _end = math.max(_valueAt(x), _start);
        _report();
        _handleEnd(_end);
      } else {
        _start = newStart;
        _report();
        _handleStart(newStart);
      }
    } else if (_draggingEnd) {
      _lastDraggedIsStart = false;
      final double newEnd = math.max(_valueAt(x), _start);
      if (newEnd <= _start && forward < 0 && _start == _end) {
        _draggingEnd = false;
        _draggingStart = true;
        _startHaptics
          ..reset(_start)
          ..atKeyPoint = _endHaptics.atKeyPoint;
        _start = math.min(_valueAt(x), _end);
        _report();
        _handleStart(_start);
      } else {
        _end = newEnd;
        _report();
        _handleEnd(newEnd);
      }
    }
    _syncThumbs();
    _syncProgress();
  }

  void _endDrag() {
    _pointerDown = false;
    _claimed = false;
    if (!_dragging) return;
    _draggingStart = false;
    _draggingEnd = false;
    _syncThumbs();
    _syncGrow();
    widget.onChangeEnd?.call();
    // Pick up whatever the caller settled on.
    _start = widget.values.start;
    _end = widget.values.end;
    _syncProgress();
  }

  void _cancel() {
    _hoverStart = false;
    _hoverEnd = false;
    _syncThumbs();
    _endDrag();
  }

  void _onHover(PointerHoverEvent event) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final double hit = _capInset(box.size.height);
    final double x = event.localPosition.dx;
    _hoverStart =
        (x - _thumbX(_startProgress.value, box.size, _rtl)).abs() <= hit;
    _hoverEnd = (x - _thumbX(_endProgress.value, box.size, _rtl)).abs() <= hit;
    _syncThumbs();
  }

  void _onExit(PointerExitEvent _) {
    _hoverStart = false;
    _hoverEnd = false;
    _syncThumbs();
  }

  String _format(double value) {
    final String Function(double)? formatter = widget.semanticFormatter;
    return formatter != null ? formatter(value) : '$value';
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = softReduceMotion(context);
    _rtl = Directionality.of(context) == TextDirection.rtl;
    _slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
    final SoftSliderColors colors =
        widget.colors ?? SoftSliderColors.of(SoftTheme.colorsOf(context));
    final bool enabled = widget.enabled;
    final bool interactive = _interactive;
    final double? secondary = widget.secondaryProgress;
    final double start = _start.clamp(widget.min, widget.max);
    final double end = _end.clamp(widget.min, widget.max);
    return SoftMinTouchTarget(
      child: Semantics(
        container: true,
        enabled: enabled,
        value: '${_format(start)}-${_format(end)}',
        child: MouseRegion(
          onHover: interactive ? _onHover : null,
          onExit: interactive ? _onExit : null,
          child: DragInspector(
            claimAxis: interactive ? Axis.horizontal : null,
            onDragStart: interactive ? _onDown : null,
            onDrag: interactive ? _onMove : null,
            onDragEnd: interactive ? _endDrag : null,
            onDragCancel: interactive ? _endDrag : null,
            onClaim: interactive ? _onClaim : null,
            child: _TrackBox(
              height: widget.height,
              painter: _RangeSliderPainter(
                start: _startProgress,
                end: _endProgress,
                startScale: _startThumb,
                endScale: _endThumb,
                grow: _grow,
                background: enabled
                    ? colors.background
                    : colors.disabledBackground,
                foreground: enabled
                    ? colors.foreground
                    : colors.disabledForeground,
                thumb: enabled ? colors.thumb : colors.disabledThumb,
                keyPoint: colors.keyPoint,
                keyPointForeground: colors.keyPointForeground,
                secondary: enabled
                    ? colors.secondaryProgress
                    : colors.disabledSecondaryProgress,
                secondaryFraction: secondary == null
                    ? null
                    : _fraction(secondary),
                keyPoints: widget.showKeyPoints
                    ? _points.all
                    : const <double>[],
                rtl: _rtl,
                shadow: enabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays the track out [height] tall and as wide as allowed (144 when
/// unbounded).
class _TrackBox extends StatelessWidget {
  const _TrackBox({required this.height, required this.painter});

  final double height;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LimitedBox(
        maxWidth: 144,
        child: CustomPaint(
          size: Size(double.infinity, height),
          painter: painter,
        ),
      ),
    );
  }
}

/// The cap centre's inset from each end: half the swollen track thickness.
double _capInset(double height) =>
    height * SoftSliderDefaults.trackEnlargeScale / 2;

double _visualFraction(double x, Size size) {
  final double cap = _capInset(size.height);
  final double available = math.max(0, size.width - 2 * cap);
  if (available == 0) return 0;
  return ((x - cap) / available).clamp(0.0, 1.0);
}

double _thumbX(double fraction, Size size, bool reverse) {
  final double cap = _capInset(size.height);
  final double available = math.max(0, size.width - 2 * cap);
  return cap + (reverse ? 1 - fraction : fraction) * available;
}

/// The key points of a slider, as fractions of its range: the custom
/// [SoftSlider.keyPoints], else every step. Snapping and haptics use them;
/// they are drawn only with [SoftSlider.showKeyPoints].
class _KeyPoints {
  const _KeyPoints(this.all);

  factory _KeyPoints.of(Widget slider) {
    final (
      double min,
      double max,
      int steps,
      List<double>? keyPoints,
    ) = switch (slider) {
      SoftSlider s => (s.min, s.max, s.steps, s.keyPoints),
      SoftRangeSlider s => (s.min, s.max, s.steps, s.keyPoints),
      _ => (0.0, 1.0, 0, null),
    };
    if (keyPoints != null) {
      return _KeyPoints(<double>[
        for (final double p in keyPoints)
          ((p - min) / (max - min)).clamp(0.0, 1.0),
      ]);
    }
    if (steps == 0) return const _KeyPoints(<double>[]);
    return _KeyPoints(<double>[
      for (int i = 0; i < steps + 2; i++) i / (steps + 1),
    ]);
  }

  final List<double> all;

  /// The value at [fraction]: on a step, onto a key point within [magnet],
  /// or anywhere.
  double resolve(
    double fraction,
    double min,
    double max,
    int steps,
    double magnet,
  ) {
    final double f = fraction.clamp(0.0, 1.0);
    if (steps > 0) {
      final int count = steps + 1;
      final int index = (f * count).round().clamp(0, count);
      return min + (max - min) * index / count;
    }
    if (all.isNotEmpty) {
      double closest = all.first;
      double best = (closest - f).abs();
      for (int i = 1; i < all.length; i++) {
        final double distance = (all[i] - f).abs();
        if (distance < best) {
          best = distance;
          closest = all[i];
        }
      }
      if (best < magnet) return ui.lerpDouble(min, max, closest)!;
    }
    return ui.lerpDouble(min, max, f)!;
  }
}

enum _Edge { both, start, end }

/// The reference's slider haptics: a threshold tick on reaching an end, and
/// with [SoftSliderHapticEffect.step] a tick per new step or key point.
class _SliderHaptics {
  _SliderHaptics(this.edge);

  final _Edge edge;
  bool _edgeTriggered = false;
  double _lastStep = 0;
  bool atKeyPoint = false;

  void reset(double value) {
    _edgeTriggered = false;
    _lastStep = value;
    atKeyPoint = false;
  }

  void handle(
    double value, {
    required double min,
    required double max,
    required SoftSliderHapticEffect effect,
    required List<double> keyPoints,
    required bool hasCustomKeyPoints,
  }) {
    if (effect == SoftSliderHapticEffect.none) return;
    final bool atEdge = switch (edge) {
      _Edge.both => value == min || value == max,
      _Edge.start => value == min,
      _Edge.end => value == max,
    };
    if (atEdge && !_edgeTriggered) {
      playSoftSelectionHaptic(SoftSelectionHaptic.threshold);
      _edgeTriggered = true;
    } else if (!atEdge) {
      _edgeTriggered = false;
    }
    if (effect != SoftSliderHapticEffect.step) return;
    if (hasCustomKeyPoints && keyPoints.isNotEmpty) {
      final double fraction = (value - min) / (max - min);
      double nearest = double.infinity;
      for (final double p in keyPoints) {
        nearest = math.min(nearest, (p - fraction).abs());
      }
      final bool now = nearest < 0.005;
      if (now && !atKeyPoint && !atEdge) {
        playSoftSelectionHaptic(SoftSelectionHaptic.tick);
      }
      atKeyPoint = now;
    } else if (value != _lastStep && !atEdge) {
      playSoftSelectionHaptic(SoftSelectionHaptic.tick);
      _lastStep = value;
    }
  }
}

/// Draws a thumb with its drop shadow; disabled thumbs have none.
void _drawThumb(
  Canvas canvas,
  Offset centre,
  double radius,
  Color color, {
  required bool shadow,
}) {
  if (shadow && radius > 0) {
    final double shadowRadius = radius + SoftSliderDefaults.thumbShadowRadius;
    final Offset shadowCentre =
        centre + const Offset(0, SoftSliderDefaults.thumbShadowOffsetY);
    const Color c = SoftSliderDefaults.thumbShadowColor;
    canvas.drawCircle(
      shadowCentre,
      shadowRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          shadowCentre,
          shadowRadius,
          <Color>[c, c, c.withValues(alpha: 0)],
          <double>[0, radius / shadowRadius, 1],
        ),
    );
  }
  canvas.drawCircle(centre, radius, Paint()..color = color);
}

void _drawTrack(Canvas canvas, Size size, double grow, Color background) {
  final double h = size.height;
  final double swollen = ui.lerpDouble(
    h,
    h * SoftSliderDefaults.trackEnlargeScale,
    grow,
  )!;
  final double cap = _capInset(h);
  final double available = math.max(0, size.width - 2 * cap);
  final double cy = h / 2;
  canvas.drawRRect(
    RRect.fromLTRBR(
      cap - swollen / 2,
      cy - swollen / 2,
      cap + available + swollen / 2,
      cy + swollen / 2,
      Radius.circular(swollen / 2),
    ),
    Paint()..color = background,
  );
}

void _drawBar(Canvas canvas, double left, double right, Size size, Color c) {
  final double half = size.height / 2;
  if (right <= left) return;
  canvas.drawRRect(
    RRect.fromLTRBR(left, 0, right, size.height, Radius.circular(half)),
    Paint()..color = c,
  );
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.progress,
    required this.thumbScale,
    required this.grow,
    required this.background,
    required this.foreground,
    required this.thumb,
    required this.keyPoint,
    required this.keyPointForeground,
    required this.secondary,
    required this.secondaryFraction,
    required this.keyPoints,
    required this.reverse,
    required this.shadow,
  }) : super(
         repaint: Listenable.merge(<Listenable>[progress, thumbScale, grow]),
       );

  final ValueListenable<double> progress;
  final ValueListenable<double> thumbScale;
  final ValueListenable<double> grow;
  final Color background;
  final Color foreground;
  final Color thumb;
  final Color keyPoint;
  final Color keyPointForeground;
  final Color secondary;
  final double? secondaryFraction;
  final List<double> keyPoints;
  final bool reverse;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    final double half = h / 2;
    final double cap = _capInset(h);
    final double thumbX = _thumbX(progress.value, size, reverse);
    _drawTrack(canvas, size, grow.value, background);
    final double? s = secondaryFraction;
    if (s != null) {
      final double sx = _thumbX(s, size, reverse);
      _drawBar(
        canvas,
        reverse ? sx - half : cap - half,
        reverse ? w - cap + half : sx + half,
        size,
        secondary,
      );
    }
    _drawBar(
      canvas,
      reverse ? thumbX - half : cap - half,
      reverse ? w - cap + half : thumbX + half,
      size,
      foreground,
    );
    for (final double p in keyPoints) {
      final double x = _thumbX(p, size, reverse);
      final bool selected = reverse ? x >= thumbX : x <= thumbX;
      canvas.drawCircle(
        Offset(x, half),
        SoftSliderDefaults.keyPointRadius,
        Paint()..color = selected ? keyPointForeground : keyPoint,
      );
    }
    _drawThumb(
      canvas,
      Offset(thumbX, half),
      h * SoftSliderDefaults.thumbRadiusRatio * thumbScale.value,
      thumb,
      shadow: shadow,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.progress != progress ||
      old.thumbScale != thumbScale ||
      old.grow != grow ||
      old.background != background ||
      old.foreground != foreground ||
      old.thumb != thumb ||
      old.keyPoint != keyPoint ||
      old.keyPointForeground != keyPointForeground ||
      old.secondary != secondary ||
      old.secondaryFraction != secondaryFraction ||
      !listEquals(old.keyPoints, keyPoints) ||
      old.reverse != reverse ||
      old.shadow != shadow;
}

class _RangeSliderPainter extends CustomPainter {
  _RangeSliderPainter({
    required this.start,
    required this.end,
    required this.startScale,
    required this.endScale,
    required this.grow,
    required this.background,
    required this.foreground,
    required this.thumb,
    required this.keyPoint,
    required this.keyPointForeground,
    required this.secondary,
    required this.secondaryFraction,
    required this.keyPoints,
    required this.rtl,
    required this.shadow,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           start,
           end,
           startScale,
           endScale,
           grow,
         ]),
       );

  final ValueListenable<double> start;
  final ValueListenable<double> end;
  final ValueListenable<double> startScale;
  final ValueListenable<double> endScale;
  final ValueListenable<double> grow;
  final Color background;
  final Color foreground;
  final Color thumb;
  final Color keyPoint;
  final Color keyPointForeground;
  final Color secondary;
  final double? secondaryFraction;
  final List<double> keyPoints;
  final bool rtl;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    final double half = h / 2;
    final double cap = _capInset(h);
    final double startX = _thumbX(start.value, size, rtl);
    final double endX = _thumbX(end.value, size, rtl);
    final double left = math.min(startX, endX);
    final double right = math.max(startX, endX);
    _drawTrack(canvas, size, grow.value, background);
    final double? s = secondaryFraction;
    if (s != null) {
      final double sx = _thumbX(s, size, rtl);
      _drawBar(
        canvas,
        rtl ? sx - half : cap - half,
        rtl ? w - cap + half : sx + half,
        size,
        secondary,
      );
    }
    _drawBar(canvas, left - half, right + half, size, foreground);
    for (final double p in keyPoints) {
      final double x = _thumbX(p, size, rtl);
      final bool selected = x >= left && x <= right;
      canvas.drawCircle(
        Offset(x, half),
        SoftSliderDefaults.keyPointRadius,
        Paint()..color = selected ? keyPointForeground : keyPoint,
      );
    }
    final double radius = h * SoftSliderDefaults.thumbRadiusRatio;
    _drawThumb(
      canvas,
      Offset(startX, half),
      radius * startScale.value,
      thumb,
      shadow: shadow,
    );
    _drawThumb(
      canvas,
      Offset(endX, half),
      radius * endScale.value,
      thumb,
      shadow: shadow,
    );
  }

  @override
  bool shouldRepaint(_RangeSliderPainter old) =>
      old.start != start ||
      old.end != end ||
      old.startScale != startScale ||
      old.endScale != endScale ||
      old.grow != grow ||
      old.background != background ||
      old.foreground != foreground ||
      old.thumb != thumb ||
      old.keyPoint != keyPoint ||
      old.keyPointForeground != keyPointForeground ||
      old.secondary != secondary ||
      old.secondaryFraction != secondaryFraction ||
      !listEquals(old.keyPoints, keyPoints) ||
      old.rtl != rtl ||
      old.shadow != shadow;
}
