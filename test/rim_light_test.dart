import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _glassPaints = 0;

/// Stands in for the glass: counts how often it is painted.
class _CountingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => _glassPaints++;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Host extends StatefulWidget {
  const _Host({required this.onController, this.reduceMotion = false});

  final ValueChanged<RimLightController> onController;
  final bool reduceMotion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final RimLightController controller = RimLightController(vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduceMotion),
      child: Center(
        child: RimLight(
          controller: controller,
          shape: const Capsule(),
          child: CustomPaint(
            painter: _CountingPainter(),
            child: const SizedBox(width: 200, height: 56),
          ),
        ),
      ),
    );
  }
}

Future<RimLightController> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  late RimLightController c;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: _Host(onController: (RimLightController v) => c = v,
          reduceMotion: reduceMotion),
    ),
  );
  return c;
}

Future<void> _frames(WidgetTester tester, double seconds) async {
  final int n = (seconds * 60).ceil();
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('an idle rim schedules nothing', (WidgetTester tester) async {
    final RimLightController c = await _pump(tester);
    expect(c.isTicking, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a focused rim settles and stops costing frames', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.focus(from: const Offset(40, 28));
    expect(c.isTicking, isTrue);
    await _frames(tester, 0.6);
    expect(c.state, RimLightState.focused);
    expect(c.presence, 1.0);
    expect(c.isTicking, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    c.clear();
    await _frames(tester, 0.5);
    expect(c.state, RimLightState.idle);
    expect(c.presence, 0.0);
    expect(c.isTicking, isFalse);
  });

  testWidgets('loading orbits until told otherwise', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.load();
    await _frames(tester, 3);
    expect(c.isTicking, isTrue);
    expect(c.loadingPhase, greaterThan(2));
  });

  testWidgets('success out of loading hands off from the comet and ends', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.load();
    await _frames(tester, 0.5);
    final double phase = c.loadingPhase % 1.0;
    c.succeed();
    expect(c.state, RimLightState.success);
    expect(c.handoff, closeTo(phase, 1e-9));
    await _frames(tester, RimLightController.successDuration + 0.1);
    expect(c.state, RimLightState.idle);
    expect(c.isTicking, isFalse);
  });

  testWidgets('a sweep out of loading hands off too, in the light colour', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.load();
    await _frames(tester, 0.4);
    final double phase = c.loadingPhase % 1.0;
    c.sweep();
    expect(c.state, RimLightState.sweep);
    expect(c.handoff, closeTo(phase, 1e-9));
    await _frames(tester, RimLightController.successDuration + 0.1);
    expect(c.state, RimLightState.idle);
    expect(c.isTicking, isFalse);
  });

  testWidgets('a sweep with an origin leaves from it, not from a comet', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.load();
    await _frames(tester, 0.2);
    c.sweep(from: const Offset(100, 56));
    expect(c.handoff, isNull);
    expect(c.origin, const Offset(100, 56));
  });

  testWidgets('a failure shakes, then comes to rest', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.fail();
    await _frames(tester, 0.05);
    expect(c.shake, isNot(0));
    await _frames(tester, RimLightController.failureDuration + 0.1);
    expect(c.shake, 0);
    expect(c.state, RimLightState.idle);
    expect(c.isTicking, isFalse);
  });

  testWidgets('progress repaints on value changes only, not on a ticker', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    c.setProgress(0.3);
    await _frames(tester, 0.5);
    expect(c.isTicking, isFalse);
    int notifications = 0;
    c.addListener(() => notifications++);
    c.setProgress(0.3);
    expect(notifications, 0, reason: 'the same value is not a change');
    c.setProgress(0.6);
    expect(notifications, 1);
    expect(c.progress, 0.6);
  });

  testWidgets('with motion reduced nothing orbits or shakes', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester, reduceMotion: true);
    c.load();
    await _frames(tester, 0.5);
    expect(c.isTicking, isFalse, reason: 'a steady glow needs no ticker');
    c.fail();
    await _frames(tester, 0.05);
    expect(c.shake, 0);
  });

  testWidgets('the light never repaints the glass under it', (
    WidgetTester tester,
  ) async {
    final RimLightController c = await _pump(tester);
    final int before = _glassPaints;
    c.load();
    await _frames(tester, 1);
    c.succeed();
    await _frames(tester, 0.5);
    // Sixty-odd frames of moving light, and the glass painted not once more:
    // the light's repaints stop at its own boundary.
    expect(_glassPaints, before);
  });
}
