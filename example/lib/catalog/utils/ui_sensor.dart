import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The device's gravity direction, used to light the control-centre glass.
///
/// Desktop has no accelerometer, so the angle stays at 45 degrees there.
class UISensor extends ChangeNotifier {
  double get gravityAngle => _gravityAngle;
  double _gravityAngle = 45.0;

  Offset get gravity => _gravity;
  Offset _gravity = Offset.zero;

  void start() {}

  void stop() {}

  /// Feeds a raw accelerometer sample, low-pass filtered.
  void update(double x, double y) {
    const double alpha = 0.5;
    final double norm = math.sqrt(x * x + y * y + 9.81 * 9.81);
    _gravityAngle = _gravityAngle * (1.0 - alpha) +
        math.atan2(y, x) * (180.0 / math.pi) * alpha;
    _gravity = _gravity * (1.0 - alpha) + Offset(x / norm, y / norm) * alpha;
    notifyListeners();
  }
}
