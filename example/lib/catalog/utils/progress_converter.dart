import 'dart:math' as math;

/// Eases an over-scrolled progress value back towards its bounds.
double convertProgress(double progress) {
  return (1.0 - math.exp(-progress.abs())) * progress.sign;
}
