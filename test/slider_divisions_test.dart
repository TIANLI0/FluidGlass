import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a 0–16 slider — a device volume, the case a short integer range and a
/// finger-width track makes hard to hit exactly.
Future<void> _pump(
  WidgetTester tester, {
  required List<double> reported,
  required List<double> ended,
  int? divisions,
  double value = 8,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: LiquidSlider(
              value: value,
              valueRange: (start: 0, end: 16),
              visibilityThreshold: 0.01,
              divisions: divisions,
              backdrop: emptyBackdrop,
              onValueChanged: reported.add,
              onChangeEnd: ended.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a continuous track reports whatever the finger lands on', (
    WidgetTester tester,
  ) async {
    final List<double> reported = <double>[];
    final List<double> ended = <double>[];
    await _pump(tester, reported: reported, ended: ended);

    await tester.tapAt(tester.getCenter(find.byType(LiquidSlider)));
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
    // Nothing rounds it, so a tap in the middle of a 0–16 range lands near 8
    // but is not required to be an integer.
    expect(reported.last, closeTo(8, 1.5));
  });

  testWidgets('divisions snap the reported value to a step', (
    WidgetTester tester,
  ) async {
    final List<double> reported = <double>[];
    final List<double> ended = <double>[];
    await _pump(tester, reported: reported, ended: ended, divisions: 16);

    final Rect box = tester.getRect(find.byType(LiquidSlider));
    // A third of the way along a 0–16 range: 5.33 continuous, 5 stepped.
    await tester.tapAt(Offset(box.left + box.width / 3, box.center.dy));
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
    for (final double v in reported) {
      expect(v, closeTo(v.roundToDouble(), 1e-9), reason: '$v is off-step');
    }
  });

  testWidgets('onChangeEnd fires once for a tap, carrying the settled value', (
    WidgetTester tester,
  ) async {
    final List<double> reported = <double>[];
    final List<double> ended = <double>[];
    await _pump(tester, reported: reported, ended: ended, divisions: 16);

    // Clear of the thumb, which rests at the midpoint for value 8 of 0–16:
    // a tap that lands on the bead is a drag that went nowhere, not a track tap.
    final Rect box = tester.getRect(find.byType(LiquidSlider));
    await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
    await tester.pumpAndSettle();

    expect(ended, hasLength(1));
    expect(ended.single, reported.last);
  });

  testWidgets('onChangeEnd fires when the finger lifts after a drag', (
    WidgetTester tester,
  ) async {
    final List<double> reported = <double>[];
    final List<double> ended = <double>[];
    await _pump(tester, reported: reported, ended: ended, divisions: 16);

    final Rect box = tester.getRect(find.byType(LiquidSlider));
    final TestGesture gesture = await tester.startGesture(box.center);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // Still dragging: the value has been reported, but the interaction has not
    // ended — this is the distinction a debouncing caller needs.
    expect(ended, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(ended, hasLength(1));
  });
}
