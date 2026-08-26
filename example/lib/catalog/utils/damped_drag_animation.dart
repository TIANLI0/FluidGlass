import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'drag_gesture_inspector.dart';
import 'spring.dart';

/// Drives the "liquid" feel of the interactive components: a spring-tracked
/// value, a press progress, and squash-and-stretch scales that lag behind it.
class DampedDragAnimation extends ChangeNotifier {
  DampedDragAnimation({
    required TickerProvider vsync,
    required this.initialValue,
    required this.valueRange,
    required this.visibilityThreshold,
    required this.initialScale,
    required this.pressedScale,
    this.onDragStarted,
    this.onDragStopped,
    this.onDrag,
  })  : _valueAnimation =
            SpringValue(vsync: vsync, value: initialValue, visibilityThreshold: visibilityThreshold),
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
        _pressProgressAnimation =
            SpringValue(vsync: vsync, value: 0.0, visibilityThreshold: 0.001),
        _scaleXAnimation =
            SpringValue(vsync: vsync, value: initialScale, visibilityThreshold: 0.001),
        _scaleYAnimation =
            SpringValue(vsync: vsync, value: initialScale, visibilityThreshold: 0.001) {
    _valueAnimation.addListener(_onValueTick);
    _velocityAnimation.addListener(notifyListeners);
    _pressProgressAnimation.addListener(notifyListeners);
    _scaleXAnimation.addListener(notifyListeners);
    _scaleYAnimation.addListener(notifyListeners);
  }

  final double initialValue;
  final ({double start, double end}) valueRange;
  final double visibilityThreshold;
  final double initialScale;
  final double pressedScale;

  final void Function(Offset position)? onDragStarted;
  final VoidCallback? onDragStopped;
  final void Function(Size size, Offset dragAmount)? onDrag;

  late final SpringDescription _valueSpec = springOf(1.0, 1000.0);
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
  VelocityTracker _velocityTracker =
      VelocityTracker.withKind(PointerDeviceKind.unknown);

  /// Velocity is tracked only for the animation `updateValue` starts, so
  /// `animateToValue` must not feed the tracker.
  bool _trackVelocity = false;

  int _releaseGeneration = 0;
  int _mutation = 0;

  double get value => _valueAnimation.value;
  double get progress =>
      (value - valueRange.start) / (valueRange.end - valueRange.start);
  double get targetValue => _valueAnimation.targetValue;
  double get pressProgress => _pressProgressAnimation.value;
  double get scaleX => _scaleXAnimation.value;
  double get scaleY => _scaleYAnimation.value;
  double get velocity => _velocityAnimation.value;

  double _coerce(double value) =>
      value.clamp(math.min(valueRange.start, valueRange.end),
          math.max(valueRange.start, valueRange.end));

  void press() {
    _velocityTracker = VelocityTracker.withKind(PointerDeviceKind.unknown);
    _pressProgressAnimation.animateTo(1.0, _pressProgressSpec);
    _scaleXAnimation.animateTo(pressedScale, _scaleXSpec);
    _scaleYAnimation.animateTo(pressedScale, _scaleYSpec);
  }

  void release() {
    final int generation = ++_releaseGeneration;
    _afterFrame(() {
      if (generation != _releaseGeneration) return;
      _awaitValueSettled(generation);
    });
  }

  void _awaitValueSettled(int generation) {
    if (value == targetValue || !_valueAnimation.isAnimating) {
      _finishRelease(generation);
      return;
    }
    final double threshold = (valueRange.end - valueRange.start).abs() * 0.025;
    if ((value - targetValue).abs() < threshold) {
      _finishRelease(generation);
      return;
    }
    _afterFrame(() {
      if (generation != _releaseGeneration) return;
      _awaitValueSettled(generation);
    });
  }

  void _finishRelease(int generation) {
    if (generation != _releaseGeneration) return;
    _pressProgressAnimation.animateTo(0.0, _pressProgressSpec);
    _scaleXAnimation.animateTo(initialScale, _scaleXSpec);
    _scaleYAnimation.animateTo(initialScale, _scaleYSpec);
  }

  void _afterFrame(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) => callback());
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Springs the value towards [value], tracking its velocity on the way.
  void updateValue(double value) {
    _trackVelocity = true;
    _valueAnimation.animateTo(_coerce(value), _valueSpec);
  }

  /// Presses, springs to [value], and releases once it settles.
  void animateToValue(double value) {
    final int mutation = ++_mutation;
    press();
    _trackVelocity = false;
    _valueAnimation.animateTo(_coerce(value), _valueSpec);
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
  }

  void _updateVelocity() {
    _velocityTracker.addPosition(
      SchedulerBinding.instance.currentFrameTimeStamp,
      Offset(value, 0),
    );
    final double targetVelocity = _velocityTracker.getVelocity().pixelsPerSecond.dx /
        (valueRange.end - valueRange.start);
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

  /// Wraps [child] with the pointer handling that drives this animation.
  Widget wrapGestures({required Widget child}) {
    return DragInspector(
      onDragStart: (Offset position, Size size) => handleDragStart(position),
      onDrag: (Offset position, Offset delta, Size size) =>
          handleDrag(size, delta),
      onDragEnd: handleDragEnd,
      onDragCancel: handleDragEnd,
      child: child,
    );
  }

  @override
  void dispose() {
    _valueAnimation.dispose();
    _velocityAnimation.dispose();
    _pressProgressAnimation.dispose();
    _scaleXAnimation.dispose();
    _scaleYAnimation.dispose();
    super.dispose();
  }
}
