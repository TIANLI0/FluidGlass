import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks down the shape of the springs the catalog animates with.
///
/// Compose expresses a spring as a damping ratio and a stiffness with unit
/// mass, so `damping = 2 * ratio * sqrt(stiffness)`. If that conversion, the
/// termination threshold or the time base ever drifts, every component's feel
/// drifts with it — and nothing else in the suite would notice.
void main() {
  /// Runs [spec] from 0 to 1 and reports how it behaved.
  Future<({double peak, int settledMs, double at128ms})> trace(
    WidgetTester tester,
    String label,
    SpringDescription spec, {
    double visibilityThreshold = 0.001,
  }) async {
    late SpringValue spring;
    await tester.pumpWidget(
      MaterialApp(
        home: _Vsync(
          key: ValueKey<String>(label),
          builder: (TickerProvider vsync) {
            spring = SpringValue(
              vsync: vsync,
              value: 0,
              visibilityThreshold: visibilityThreshold,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    spring.animateTo(1.0, spec);

    double peak = 0;
    double at128ms = 0;
    int settledMs = -1;
    for (int ms = 16; ms <= 2000; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      if (spring.value > peak) peak = spring.value;
      if (ms == 128) at128ms = spring.value;
      if (settledMs < 0 && !spring.isAnimating) settledMs = ms;
    }
    spring.dispose();
    return (
      peak: peak,
      settledMs: settledMs < 0 ? 2000 : settledMs,
      at128ms: at128ms,
    );
  }

  testWidgets('springOf(1.0, k) is critically damped — no overshoot',
      (WidgetTester tester) async {
    // DampedDragAnimation's value and pressProgress specs.
    final result = await trace(tester, 'value', springOf(1.0, 1000.0));
    expect(result.peak, lessThanOrEqualTo(1.0 + 1e-6),
        reason: 'a damping ratio of 1 must not overshoot');
    expect(result.settledMs, inInclusiveRange(240, 400));
    expect(result.at128ms, closeTo(0.868, 0.02));
  });

  testWidgets('the squash springs overshoot by the amount Compose asks for',
      (WidgetTester tester) async {
    // scaleX: spring(0.6, 250). Underdamped, so it must visibly overshoot.
    final scaleX = await trace(tester, 'scaleX', springOf(0.6, 250.0));
    expect(scaleX.peak, closeTo(1.094, 0.02));
    expect(scaleX.settledMs, inInclusiveRange(560, 800));

    // scaleY: spring(0.7, 250). Less bouncy than scaleX, which is what makes
    // the squash read as a squash rather than a uniform pulse.
    final scaleY = await trace(tester, 'scaleY', springOf(0.7, 250.0));
    expect(scaleY.peak, closeTo(1.046, 0.02));
    expect(scaleY.peak, lessThan(scaleX.peak));
  });

  testWidgets('the press highlight is the bounciest spring in the catalog',
      (WidgetTester tester) async {
    // InteractiveHighlight press/position, and the tab bar's offset return.
    final result = await trace(tester, 'highlight', springOf(0.5, 300.0));
    expect(result.peak, closeTo(1.163, 0.02));
  });

  testWidgets('the menu open spring never overshoots',
      (WidgetTester tester) async {
    // Regression: the open used to be underdamped (ratio 0.75), which was
    // measured on-device blooming to 102.8% and then easing back to 100% over
    // ~175ms. On an opaque panel the eye calls the bloom finished at 100%, so
    // that back-settle read as a *second* opening animation rather than as
    // bounce. Critically damped is the fix, and this pins it.
    final result = await trace(tester, 'menu-open', springOf(1.0, 550.0));
    expect(result.peak, lessThanOrEqualTo(1.0 + 1e-6),
        reason: 'any overshoot re-reads as a second animation');
    expect(result.settledMs, inInclusiveRange(300, 500),
        reason: 'still quick enough to feel immediate');
  });

  testWidgets('the velocity spring smooths rather than tracks',
      (WidgetTester tester) async {
    // Regression: this spring used to be built with visibilityThreshold 5.0 —
    // copied from Compose's `Animatable(0f, 5f)`, which is only the default
    // spec for calls that do not pass one. The live threshold is the spec's,
    // `visibilityThreshold * 10f`. At 5.0 the simulation was already "done" on
    // its first tick, so the value snapped to the raw velocity tracker and the
    // squash-and-stretch lost its lag, its overshoot and its ring-down.
    final DampedDragAnimation animation = DampedDragAnimation(
      vsync: const TestVSync(),
      initialValue: 0,
      valueRange: (start: 0, end: 2),
      visibilityThreshold: 0.001,
      initialScale: 1,
      pressedScale: 1.4,
    );
    addTearDown(animation.dispose);

    final result = await trace(tester, 'velocity', springOf(0.5, 300.0),
        visibilityThreshold: 0.001 * 10.0);
    expect(result.settledMs, greaterThan(300),
        reason: 'a smoothing spring must take time to settle, not snap');
    expect(result.peak, greaterThan(1.05),
        reason: 'it must overshoot, so the stretch rings out after the finger '
            'stops');
  });
}

class _Vsync extends StatefulWidget {
  const _Vsync({super.key, required this.builder});
  final Widget Function(TickerProvider vsync) builder;
  @override
  State<_Vsync> createState() => _VsyncState();
}

class _VsyncState extends State<_Vsync> with TickerProviderStateMixin {
  Widget? _child;
  @override
  Widget build(BuildContext context) => _child ??= widget.builder(this);
}
