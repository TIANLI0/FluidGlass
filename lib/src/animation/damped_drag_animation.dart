import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../gestures/drag_gesture_inspector.dart';
import 'spring.dart';

/// Drives the "liquid" feel of the interactive components: a spring-tracked
/// value, a press progress, and squash-and-stretch scales that lag behind it.
class DampedDragAnimation extends ChangeNotifier {
  DampedDragAnimation({
    required TickerProvider vsync,
    required this.initialValue,
    required ({double start, double end}) valueRange,
    required this.visibilityThreshold,
    required this.initialScale,
    required this.pressedScale,
    this.onDragStarted,
    this.onDragStopped,
    this.onDrag,
  }) : assert(valueRange.start.isFinite && valueRange.end.isFinite),
       _valueRange = valueRange,
       _valueAnimation = SpringValue(
         vsync: vsync,
         value: initialValue,
         visibilityThreshold: visibilityThreshold,
       ),
       // Compose's `Animatable(0f, 5f)` threshold is dead: it only supplies
       // the default spec for `animateTo`, and this animation always passes
       // one explicitly. The live threshold is the spec's, which Kotlin sets
       // to `visibilityThreshold * 10f`. At 5.0 the spring settled on its
       // first tick, so the value tracked the raw tracker output and the
       // squash-and-stretch lost its lag and its ring-down.
       _velocityAnimation = SpringValue(
         vsync: vsync,
         value: 0.0,
         visibilityThreshold: visibilityThreshold * 10.0,
       ),
       _pressProgressAnimation = SpringValue(
         vsync: vsync,
         value: 0.0,
         visibilityThreshold: 0.001,
       ),
       _scaleXAnimation = SpringValue(
         vsync: vsync,
         value: initialScale,
         visibilityThreshold: 0.001,
       ),
       _scaleYAnimation = SpringValue(
         vsync: vsync,
         value: initialScale,
         visibilityThreshold: 0.001,
       ) {
    _valueAnimation.addListener(_onValueTick);
    _velocityAnimation.addListener(notifyListeners);
    _pressProgressAnimation.addListener(notifyListeners);
    _scaleXAnimation.addListener(notifyListeners);
    _scaleYAnimation.addListener(notifyListeners);
  }

  final double initialValue;
  final double visibilityThreshold;
  final double initialScale;

  /// The scale a press grows the element to.
  ///
  /// Settable, so a component whose size decides it can follow a new size;
  /// the next press uses the new value.
  double pressedScale;

  /// The values [value] may take.
  ///
  /// Settable, so a component whose count or range changes — tabs added after
  /// sign-in, a media duration that arrives late — keeps clamping and
  /// normalising against the range it has now rather than the one it was
  /// built with. A value left outside the new range is moved to its nearest
  /// end at once.
  ({double start, double end}) get valueRange => _valueRange;
  ({double start, double end}) _valueRange;
  set valueRange(({double start, double end}) range) {
    assert(range.start.isFinite && range.end.isFinite);
    if (range == _valueRange) return;
    _valueRange = range;
    final double coerced = _coerce(targetValue);
    if (coerced != targetValue || _coerce(value) != value) {
      _valueAnimation.snapTo(coerced);
    }
    notifyListeners();
  }

  final void Function(Offset position)? onDragStarted;
  final VoidCallback? onDragStopped;
  final void Function(Size size, Offset dragAmount)? onDrag;

  late final SpringDescription _valueSpec = springOf(1.0, 1000.0);

  /// The spring [animateToValue] travels on — a selection made by a tap, or a
  /// drag let go between two stops settling onto one. Null travels on the same
  /// spring as a drag does, which is how every component has always moved.
  ///
  /// Separate from the drag's own because the two jobs want opposite springs:
  /// following a finger has to be near-instant or the element lags behind it,
  /// while a selection travelling on its own can afford to take its time and
  /// overshoot. Settable, so a component can change it after construction.
  SpringDescription? settleSpring;
  late final SpringDescription _velocitySpec = springOf(0.5, 300.0);
  late final SpringDescription _pressProgressSpec = springOf(1.0, 1000.0);
  late final SpringDescription _scaleXSpec = springOf(0.6, 250.0);
  late final SpringDescription _scaleYSpec = springOf(0.7, 250.0);

  final SpringValue _valueAnimation;
  final SpringValue _velocityAnimation;
  final SpringValue _pressProgressAnimation;
  final SpringValue _scaleXAnimation;
  final SpringValue _scaleYAnimation;

  // Compose resets the tracker on press; Flutter's has no reset, so it is
  // replaced instead.
  VelocityTracker _velocityTracker = VelocityTracker.withKind(
    PointerDeviceKind.unknown,
  );

  /// Velocity is tracked only for the animation `updateValue` starts, so
  /// `animateToValue` must not feed the tracker.
  bool _trackVelocity = false;

  int _releaseGeneration = 0;
  int _mutation = 0;

  /// The release waiting for the value to come close to its target, or null.
  int? _pendingRelease;
  bool _disposed = false;

  double get value => _valueAnimation.value;

  /// Where [value] sits in [valueRange], 0 at its start and 1 at its end.
  ///
  /// Zero for an empty range, which a slider over `min == max` is: 0/0 would
  /// otherwise read as NaN, and a NaN progress clamps to the far end — a full
  /// track for a value that has nowhere to go.
  double get progress {
    final double span = valueRange.end - valueRange.start;
    return span == 0 ? 0.0 : (value - valueRange.start) / span;
  }

  double get targetValue => _valueAnimation.targetValue;
  double get pressProgress => _pressProgressAnimation.value;
  double get scaleX => _scaleXAnimation.value;
  double get scaleY => _scaleYAnimation.value;
  double get velocity => _velocityAnimation.value;

  double _coerce(double value) => value.clamp(
    math.min(valueRange.start, valueRange.end),
    math.max(valueRange.start, valueRange.end),
  );

  void press() {
    _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.unknown);
    _pressProgressAnimation.animateTo(1.0, _pressProgressSpec);
    _scaleXAnimation.animateTo(pressedScale, _scaleXSpec);
    _scaleYAnimation.animateTo(pressedScale, _scaleYSpec);
  }

  void release() {
    final int generation = ++_releaseGeneration;
    _pendingRelease = null;
    // One frame later, as Compose's coroutine resumes: a target set in the same
    // event as the release is then already in place when it is checked.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _releaseGeneration) return;
      _pendingRelease = generation;
      _checkPendingRelease();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Finishes a pending release once the value has come close to its target.
  ///
  /// Asked on the value's own ticks, never on frames of its own. It used to
  /// re-arm itself with a post-frame callback and `scheduleFrame` until the
  /// value arrived, which under `TickerMode(enabled: false)` never happened: a
  /// muted ticker is still active, so the value neither moved nor counted as
  /// done, and a toggle changed on a covered route kept the app drawing every
  /// frame until the route came back. Compose's `snapshotFlow` suspends on the
  /// value instead, and so does this — a muted value sends no ticks and asks
  /// for no frames.
  void _checkPendingRelease() {
    final int? generation = _pendingRelease;
    if (generation == null) return;
    final double threshold = (valueRange.end - valueRange.start).abs() * 0.025;
    final bool settled =
        value == targetValue ||
        !_valueAnimation.isAnimating ||
        (value - targetValue).abs() < threshold;
    if (!settled) return;
    _pendingRelease = null;
    _finishRelease(generation);
  }

  void _finishRelease(int generation) {
    if (_disposed || generation != _releaseGeneration) return;
    _pressProgressAnimation.animateTo(0.0, _pressProgressSpec);
    _scaleXAnimation.animateTo(initialScale, _scaleXSpec);
    _scaleYAnimation.animateTo(initialScale, _scaleYSpec);
  }

  /// Springs the value towards [value], tracking its velocity on the way.
  void updateValue(double value) {
    _trackVelocity = true;
    _valueAnimation.animateTo(_coerce(value), _valueSpec);
  }

  /// Jumps to [value] with no press, no spring and no velocity — for a
  /// platform asking for reduced motion.
  void snapToValue(double value) {
    ++_mutation;
    _trackVelocity = false;
    _valueAnimation.snapTo(_coerce(value));
    _velocityAnimation.snapTo(0.0);
    notifyListeners();
  }

  /// Presses, springs to [value], and releases once it settles.
  void animateToValue(double value) {
    final int mutation = ++_mutation;
    press();
    _trackVelocity = false;
    _valueAnimation.animateTo(_coerce(value), settleSpring ?? _valueSpec);
    if (velocity != 0.0) {
      _velocityAnimation.animateTo(0.0, _velocitySpec);
    }
    if (mutation == _mutation) {
      release();
    }
  }

  void _onValueTick() {
    if (_trackVelocity) _updateVelocity();
    notifyListeners();
    _checkPendingRelease();
  }

  void _updateVelocity() {
    _velocityTracker.addPosition(
      SchedulerBinding.instance.currentFrameTimeStamp,
      Offset(value, 0),
    );
    final double span = valueRange.end - valueRange.start;
    final double targetVelocity = span == 0
        ? 0.0
        : _velocityTracker.getVelocity().pixelsPerSecond.dx / span;
    _velocityAnimation.animateTo(targetVelocity, _velocitySpec);
  }

  /// The pointer went down.
  void handleDragStart(Offset position) {
    onDragStarted?.call(position);
    press();
  }

  /// The pointer moved.
  void handleDrag(Size size, Offset dragAmount) {
    onDrag?.call(size, dragAmount);
  }

  /// The pointer went up, or the gesture was taken over. Both end the drag
  /// the same way.
  void handleDragEnd() {
    onDragStopped?.call();
    release();
  }

  /// Releases visual feedback without committing a cancelled interaction.
  void cancelDrag() {
    ++_releaseGeneration;
    _pendingRelease = null;
    _trackVelocity = false;
    _pressProgressAnimation.snapTo(0);
    _scaleXAnimation.snapTo(initialScale);
    _scaleYAnimation.snapTo(initialScale);
    _velocityAnimation.snapTo(0);
  }

  /// Wraps [child] with the pointer handling that drives this animation.
  ///
  /// [claimAxis] and [onClaim] are [DragInspector]'s: give the axis the value
  /// runs along, so a drag along it is not lost to a list scrolling the other
  /// way — and, past the slop the other way, lets that list have it.
  Widget wrapGestures({
    required Widget child,
    VoidCallback? onCancel,
    Axis? claimAxis,
    VoidCallback? onClaim,
  }) {
    return DragInspector(
      onDragStart: (Offset position, Size size) => handleDragStart(position),
      onDrag: (Offset position, Offset delta, Size size) =>
          handleDrag(size, delta),
      onDragEnd: handleDragEnd,
      onDragCancel: onCancel ?? handleDragEnd,
      claimAxis: claimAxis,
      onClaim: onClaim,
      child: child,
    );
  }

  @override
  void dispose() {
    // A release registered on the last pointer-up may still be waiting for a
    // frame; it must not start a disposed spring.
    _disposed = true;
    _pendingRelease = null;
    _releaseGeneration++;
    _valueAnimation.dispose();
    _velocityAnimation.dispose();
    _pressProgressAnimation.dispose();
    _scaleXAnimation.dispose();
    _scaleYAnimation.dispose();
    super.dispose();
  }
}
