import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Builds the Flutter equivalent of Compose's
/// `spring(dampingRatio, stiffness, visibilityThreshold)`.
///
/// Compose springs have unit mass, and express damping as a ratio, so
/// `damping = 2 * ratio * sqrt(stiffness)`.
SpringDescription springOf(double dampingRatio, double stiffness) {
  return SpringDescription(
    mass: 1.0,
    stiffness: stiffness,
    damping: 2.0 * dampingRatio * math.sqrt(stiffness),
  );
}

/// The velocity tolerance, as a multiple of the displacement one.
///
/// Modern Compose does not gate on velocity at all: `FloatSpringSpec` asks
/// `estimateAnimationDurationMillis` for the last time the displacement is
/// `visibilityThreshold`, runs exactly that long, and then snaps to the target.
/// (The `1000 / 16` multiplier is inherited from the retired
/// `androidx.dynamicanimation.SpringForce` that `SpringSimulation` was forked
/// from.) Flutter's [SpringSimulation.isDone] requires both bounds, and the
/// velocity one only becomes the binding constraint above a stiffness of about
/// 3900 — far above every spec used here — so the two agree to within a frame.
const double kVelocityThresholdMultiplier = 1000.0 / 16.0;

/// A spring-driven scalar that can be retargeted mid-flight without losing
/// velocity — the Flutter counterpart of Compose's `Animatable<Float>`.
class SpringValue extends ChangeNotifier {
  SpringValue({
    required TickerProvider vsync,
    required double value,
    this.visibilityThreshold = 0.01,
  })  : _value = value,
        _target = value {
    _ticker = vsync.createTicker(_onTick);
  }

  final double visibilityThreshold;

  late final Ticker _ticker;

  double _value;
  double _velocity = 0.0;
  double _target;

  Simulation? _simulation;

  /// When the running simulation started, on the ticker's own clock. Null means
  /// "the next tick", which is how a freshly started ticker begins at t = 0.
  Duration? _startTime;

  /// The most recent tick, so retargeting mid-flight can measure from it
  /// rather than restarting the clock — otherwise a spring retargeted every
  /// frame (which is what dragging does) would never advance past t = 0.
  Duration _lastElapsed = Duration.zero;

  final List<VoidCallback> _onDone = <VoidCallback>[];

  double get value => _value;
  double get velocity => _velocity;
  double get targetValue => _target;
  bool get isAnimating => _ticker.isActive;

  /// Jumps to [value], cancelling any animation.
  void snapTo(double value) {
    _stop();
    _target = value;
    if (_value != value) {
      _value = value;
      _velocity = 0.0;
      notifyListeners();
    } else {
      _velocity = 0.0;
    }
  }

  /// Springs to [target], starting from the current value and velocity.
  void animateTo(double target, SpringDescription spring, {double? withVelocity}) {
    _target = target;
    if (withVelocity != null) _velocity = withVelocity;
    if (_value == target && _velocity == 0.0) {
      _stop();
      return;
    }
    _simulation = SpringSimulation(
      spring,
      _value,
      target,
      _velocity,
      tolerance: Tolerance(
        distance: visibilityThreshold,
        velocity: visibilityThreshold * kVelocityThresholdMultiplier,
      ),
    );
    _restart();
  }

  /// Animates to [target] over [duration] with [curve].
  ///
  /// The default matches Compose's `tween()`, whose easing is FastOutSlowIn.
  void tweenTo(double target, Duration duration, {Curve curve = Curves.fastOutSlowIn}) {
    _target = target;
    _simulation = _TweenSimulation(_value, target, duration, curve);
    _restart();
  }

  void _restart() {
    if (_ticker.isActive) {
      _startTime = _lastElapsed;
    } else {
      _startTime = null;
      _ticker.start();
    }
  }

  /// Calls [callback] once the animation settles (or immediately if idle).
  void whenSettled(VoidCallback callback) {
    if (!isAnimating) {
      callback();
      return;
    }
    _onDone.add(callback);
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;
    _startTime ??= elapsed;
    final Simulation? simulation = _simulation;
    if (simulation == null) {
      _stop();
      return;
    }
    final double t = (elapsed - _startTime!).inMicroseconds /
        Duration.microsecondsPerSecond;
    _value = simulation.x(t);
    _velocity = simulation.dx(t);
    if (simulation.isDone(t)) {
      _value = _target;
      _velocity = 0.0;
      _stop();
      notifyListeners();
      final List<VoidCallback> done = List<VoidCallback>.of(_onDone);
      _onDone.clear();
      for (final VoidCallback callback in done) {
        callback();
      }
      return;
    }
    notifyListeners();
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    _simulation = null;
    _startTime = null;
    _lastElapsed = Duration.zero;
  }

  void stop() => _stop();

  @override
  void dispose() {
    _ticker.dispose();
    _onDone.clear();
    super.dispose();
  }
}

class _TweenSimulation extends Simulation {
  _TweenSimulation(this.begin, this.end, Duration duration, this.curve)
      : seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double begin;
  final double end;
  final double seconds;
  final Curve curve;

  @override
  double x(double time) {
    if (seconds <= 0) return end;
    final double t = (time / seconds).clamp(0.0, 1.0);
    return begin + (end - begin) * curve.transform(t);
  }

  @override
  double dx(double time) {
    const double dt = 1 / 1000;
    return (x(time + dt) - x(time)) / dt;
  }

  @override
  bool isDone(double time) => time >= seconds;
}

/// A spring-driven [Offset], animating each axis independently, as Compose's
/// `Animatable<Offset, AnimationVector2D>` does.
class SpringOffset extends ChangeNotifier {
  SpringOffset({
    required TickerProvider vsync,
    required Offset value,
    double visibilityThreshold = 0.5,
  })  : x = SpringValue(vsync: vsync, value: value.dx, visibilityThreshold: visibilityThreshold),
        y = SpringValue(vsync: vsync, value: value.dy, visibilityThreshold: visibilityThreshold) {
    x.addListener(notifyListeners);
    y.addListener(notifyListeners);
  }

  final SpringValue x;
  final SpringValue y;

  Offset get value => Offset(x.value, y.value);
  Offset get targetValue => Offset(x.targetValue, y.targetValue);

  void snapTo(Offset value) {
    x.snapTo(value.dx);
    y.snapTo(value.dy);
  }

  void animateTo(Offset target, SpringDescription spring) {
    x.animateTo(target.dx, spring);
    y.animateTo(target.dy, spring);
  }

  @override
  void dispose() {
    x.dispose();
    y.dispose();
    super.dispose();
  }
}

/// A tween-driven [Color], for the adaptive-luminance demo.
class TweenColor extends ChangeNotifier {
  TweenColor({required TickerProvider vsync, required Color value})
      : _begin = value,
        _end = value,
        _driver = SpringValue(vsync: vsync, value: 1.0, visibilityThreshold: 0.001) {
    _driver.addListener(notifyListeners);
  }

  final SpringValue _driver;
  Color _begin;
  Color _end;

  Color get value => Color.lerp(_begin, _end, _driver.value.clamp(0.0, 1.0))!;

  void animateTo(Color target, Duration duration) {
    if (target == _end) return;
    _begin = value;
    _end = target;
    _driver.snapTo(0.0);
    _driver.tweenTo(1.0, duration, curve: Curves.fastOutSlowIn);
  }

  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }
}
