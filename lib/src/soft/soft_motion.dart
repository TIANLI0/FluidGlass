import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A spring described by how long the move takes ([response], the period of
/// the undamped oscillation in seconds) and how much it overshoots ([bounce],
/// 0 = none, towards 1 = a lot; negative = overdamped).
///
/// Unit mass: `stiffness = (2π / response)²`, damping ratio `1 - bounce`
/// (or `1 / (1 + bounce)` below zero).
SpringDescription softSpring(double response, {double bounce = 0}) {
  assert(response > 0, 'response is a period in seconds and must be positive');
  assert(bounce > -1 && bounce < 1, 'bounce must lie between -1 and 1');
  final double stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  final double ratio = bounce >= 0 ? 1 - bounce : 1 / (1 + bounce);
  return SpringDescription(
    mass: 1,
    stiffness: stiffness,
    damping: 2 * ratio * math.sqrt(stiffness),
  );
}

/// The motion vocabulary every soft component draws from, so that the same
/// kind of movement feels the same everywhere.
abstract final class SoftMotion {
  /// A selection travelling to its new place: an indicator sliding between
  /// tabs or segments, a thumb settling on a step.
  static final SpringDescription select = softSpring(0.55, bounce: 0.35);

  /// The same on a device that was judged low-end: shorter, less swing.
  static final SpringDescription selectLowEnd = softSpring(0.5, bounce: 0.3);

  /// A press going down: quick, a touch of give.
  static final SpringDescription press = softSpring(0.13, bounce: 0.18);

  /// A press letting go: springs back past rest and settles.
  static final SpringDescription release = softSpring(0.35, bounce: 0.62);

  /// Fades and colour changes: no overshoot.
  static final SpringDescription fade = softSpring(0.2);

  /// A surface appearing or leaving (sheets, dialogs, menus).
  static final SpringDescription surface = softSpring(0.4, bounce: 0.15);

  /// Ease used where a duration is wanted instead of a spring.
  static const Curve ease = Cubic(0.3, 0, 0.1, 1);

  /// Ease for things leaving.
  static const Curve easeOut = Cubic(0.33, 0, 0.67, 1);

  static const Duration fadeDuration = Duration(milliseconds: 200);
}

/// Drives an unbounded controller along a spring, carrying its velocity, or
/// jumps there when motion is reduced.
extension SoftSpringController on AnimationController {
  TickerFuture springTo(
    double target,
    SpringDescription spring, {
    bool reduceMotion = false,
  }) {
    if (reduceMotion) {
      stop();
      value = target;
      return TickerFuture.complete();
    }
    return animateWith(
      SpringSimulation(
        spring,
        value,
        target,
        velocity,
        tolerance: const Tolerance(distance: 0.001, velocity: 0.001),
      ),
    );
  }
}

/// Whether the platform asked for reduced motion.
bool softReduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
