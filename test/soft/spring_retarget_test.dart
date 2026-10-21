import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

void main() {
  usePhoneSurface();

  testWidgets('spring can restart after a curve, a snap and idle time', (
    tester,
  ) async {
    final SoftSpring spring = SoftSpring(vsync: tester);
    addTearDown(spring.dispose);
    spring.animateTo(1, SoftMotion.stateLayer);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    spring.animateTo(2, SoftMotion.stateLayer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(spring.value, inExclusiveRange(1, 2));
    spring.animateCurve(0, duration: const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    spring.snapTo(3);
    spring.animateTo(0, SoftMotion.stateLayer);
    await tester.pumpAndSettle();
    expect(spring.value, 0);
    expect(spring.isAnimating, isFalse);
  });

  testWidgets('spring advances when its target changes before every frame', (
    tester,
  ) async {
    final SoftSpring spring = SoftSpring(vsync: tester);
    addTearDown(spring.dispose);
    for (int frame = 1; frame <= 30; frame++) {
      spring.animateTo(frame.toDouble(), SoftTouchMotionSpec.dragSpring);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(spring.value, greaterThan(20));
    final List<double> release = <double>[];
    spring.animateTo(0, softSpring(damping: 0.35, response: 0.45));
    for (int frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      release.add(spring.value);
    }
    expect(release.any((double value) => value < -1), isTrue);
    await tester.pumpAndSettle();
    expect(spring.value, 0);
  });
}
