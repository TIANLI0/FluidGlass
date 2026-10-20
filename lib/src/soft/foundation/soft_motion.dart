import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A spring from a damping ratio and a response time in seconds: stiffness
/// `(2π / response)²`, unit mass.
///
/// A spring authored as (response, bounce) has `damping = 1 - bounce`.
SpringDescription softSpring({
  required double damping,
  required double response,
}) {
  final double omega = 2 * math.pi / response;
  return SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: omega * omega,
    ratio: damping,
  );
}

/// A spring from a damping ratio and a raw stiffness (unit mass).
SpringDescription softSpringStiffness({
  required double damping,
  required double stiffness,
}) {
  return SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: stiffness,
    ratio: damping,
  );
}

/// The curves and springs every soft component shares.
abstract final class SoftMotion {
  /// Entering or growing.
  static const Cubic inEase = Cubic(0, 0, 0.1, 1);

  /// Leaving or shrinking.
  static const Cubic outEase = Cubic(0.3, 0, 1, 1);

  /// An unshaped animation.
  static const Curve linear = Curves.linear;

  /// `sin(t · π/2)`.
  static const Curve sinOut = _SinOut();

  /// The pressed state layer: critically damped, stiffness 438.65.
  static final SpringDescription stateLayer = softSpringStiffness(
    damping: 1,
    stiffness: 438.65,
  );

  /// The spotlight glowing in: (0.15, 0).
  static final SpringDescription lightGlow = softSpring(
    damping: 1,
    response: 0.15,
  );

  /// The spotlight dying out: (0.4, 0).
  static final SpringDescription lightExtinguish = softSpring(
    damping: 1,
    response: 0.4,
  );

  /// The spotlight following the finger: (0.35, 0.15).
  static final SpringDescription lightMove = softSpring(
    damping: 0.85,
    response: 0.35,
  );

  /// How long to wait before showing a press, so a touch that turns into a
  /// scroll never flashes one.
  static const Duration tapIndicationDelay = Duration(milliseconds: 150);
}

/// The Android `AccelerateInterpolator`.
class SoftAccelerateCurve extends Curve {
  const SoftAccelerateCurve([this.factor = 1]);

  final double factor;

  @override
  double transformInternal(double t) =>
      factor == 1 ? t * t : math.pow(t, 2 * factor).toDouble();
}

/// The Android `DecelerateInterpolator`.
class SoftDecelerateCurve extends Curve {
  const SoftDecelerateCurve([this.factor = 1]);

  final double factor;

  @override
  double transformInternal(double t) => factor == 1
      ? 1 - (1 - t) * (1 - t)
      : 1 - math.pow(1 - t, 2 * factor).toDouble();
}

class _SinOut extends Curve {
  const _SinOut();

  @override
  double transformInternal(double t) => math.sin(t * math.pi / 2);
}

/// Whether the platform asked for reduced motion.
bool softReduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A value driven by springs that can be retargeted mid-flight, keeping its
/// velocity — a drag that moves the target every frame never restarts the
/// spring from rest.
///
/// It is a [Listenable]; listen to repaint.
class SoftSpring extends ChangeNotifier implements ValueListenable<double> {
  SoftSpring({required TickerProvider vsync, double value = 0})
    : _controller = AnimationController.unbounded(vsync: vsync, value: value) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;

  @override
  double get value => _controller.value;

  /// The current velocity, in units per second.
  double get velocity => _controller.velocity;

  bool get isAnimating => _controller.isAnimating;

  /// Jumps to [value] and stops.
  void snapTo(double value) {
    _controller.stop();
    _controller.value = value;
  }

  /// Springs to [target] with [spring], starting at [velocity] (the current
  /// velocity by default).
  ///
  /// [threshold] is the distance below which the spring is considered
  /// settled; the default suits values in 0–1.
  TickerFuture animateTo(
    double target,
    SpringDescription spring, {
    double? velocity,
    double threshold = 0.001,
  }) {
    final double v = velocity ?? this.velocity;
    if (value == target && v == 0) {
      _controller.stop();
      return TickerFuture.complete();
    }
    return _controller.animateWith(
      SpringSimulation(
        spring,
        value,
        target,
        v,
        tolerance: Tolerance(distance: threshold, velocity: threshold * 10),
        snapToEnd: true,
      ),
    );
  }

  /// Animates to [target] over [duration] with [curve].
  TickerFuture animateCurve(
    double target, {
    required Duration duration,
    Curve curve = Curves.linear,
  }) {
    return _controller.animateTo(target, duration: duration, curve: curve);
  }

  void stop() => _controller.stop();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// The overscroll rubber band of the reference: the farther the content is
/// pulled, the less it follows.
abstract final class SoftRubberBand {
  /// `sign(x) · (1 - 1 / (|x| · ratio / max + 1)) · max`.
  static double apply(double offset, double curveRatio, double maxDistance) {
    if (maxDistance <= 0) return 0;
    return offset.sign *
        (1 - 1 / ((offset.abs() * curveRatio / maxDistance) + 1)) *
        maxDistance;
  }

  /// The inverse of [apply]: the finger travel that produced [result].
  static double inverse(double result, double curveRatio, double maxDistance) {
    if (maxDistance <= 0) return result;
    final double absolute = result.abs();
    if (absolute >= maxDistance) return result.sign * maxDistance;
    final double remaining = maxDistance - absolute;
    if (curveRatio <= 0 || remaining <= 0) return result;
    return result.sign * (maxDistance * absolute) / (curveRatio * remaining);
  }

  /// The scroll overscroll damping `x - x² + x³/3` of a normalised input,
  /// times [range].
  static double dampingDistance(double normalizedInput, double range) {
    final double x = normalizedInput.clamp(0.0, 1.0);
    return (x - x * x + x * x * x / 3) * range;
  }
}

/// Evaluates the cubic Bézier easing (x1, y1, x2, y2) at [fraction] by
/// bisection, the way the reference does it.
double softCubicBezier(
  double fraction,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final double x = fraction.clamp(0.0, 1.0);
  double coordinate(double t, double first, double second) {
    final double inverse = 1 - t;
    return 3 * inverse * inverse * t * first +
        3 * inverse * t * t * second +
        t * t * t;
  }

  double low = 0;
  double high = 1;
  for (int i = 0; i < 18; i++) {
    final double middle = (low + high) * 0.5;
    if (coordinate(middle, x1, x2) < x) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return coordinate((low + high) * 0.5, y1, y2);
}
