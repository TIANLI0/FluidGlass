import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bar({required int selected, SpringDescription? spring}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 300,
        child: LiquidBottomTabs(
          selectedTabIndex: selected,
          onTabSelected: (int _) {},
          backdrop: emptyBackdrop,
          tabsCount: 3,
          selectionSpring: spring,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              LiquidBottomTab(
                onPressed: () {},
                children: <Widget>[Text('tab $i')],
              ),
          ],
        ),
      ),
    ),
  ),
);

/// Where the selection pill is drawn: the last of the bar's glass elements,
/// placed through the render tree's paint transforms.
double _pillX(WidgetTester tester) => tester
    .getTopLeft(
      find
          .descendant(
            of: find.byType(LiquidBottomTabs),
            matching: find.byType(DrawBackdrop),
          )
          .last,
    )
    .dx;

/// Every pill position until everything settles.
Future<List<double>> _travel(WidgetTester tester) async {
  final List<double> xs = <double>[];
  for (int i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    xs.add(_pillX(tester));
  }
  await tester.pumpAndSettle();
  return xs;
}

void main() {
  test('springOfResponse matches the response/bounce parameterisation', () {
    final SpringDescription s = springOfResponse(0.55, bounce: 0.35);
    expect(s.mass, 1);
    expect(s.stiffness, closeTo(math.pow(2 * math.pi / 0.55, 2), 1e-9));
    final double ratio = s.damping / (2 * math.sqrt(s.stiffness));
    expect(ratio, closeTo(0.65, 1e-9));

    final SpringDescription critical = springOfResponse(0.3);
    expect(
      critical.damping / (2 * math.sqrt(critical.stiffness)),
      closeTo(1, 1e-9),
    );
  });

  testWidgets(
    'with a bouncy selection spring the pill overshoots and settles',
    (tester) async {
      final SpringDescription spring = springOfResponse(0.55, bounce: 0.35);
      await tester.pumpWidget(_bar(selected: 0, spring: spring));
      await tester.pumpWidget(_bar(selected: 2, spring: spring));
      final List<double> xs = await _travel(tester);
      final double settled = _pillX(tester);

      expect(xs.reduce(math.max), greaterThan(settled + 1));
      expect(xs.last, closeTo(settled, 0.5));
    },
  );

  testWidgets('without one the pill arrives without overshoot, as before', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 0));
    await tester.pumpWidget(_bar(selected: 2));
    final List<double> xs = await _travel(tester);
    final double settled = _pillX(tester);

    expect(xs.reduce(math.max), lessThanOrEqualTo(settled + 0.5));
  });

  testWidgets('a dragged pill still sticks to the finger', (tester) async {
    await tester.pumpWidget(
      _bar(selected: 0, spring: springOfResponse(0.55, bounce: 0.35)),
    );
    final double start = _pillX(tester);
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('tab 0').first),
    );
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // 60 of finger travel; the drag spring is near-instant, so the pill has
    // followed nearly all of it within a couple of frames.
    await tester.pump(const Duration(milliseconds: 48));
    expect(_pillX(tester) - start, greaterThan(50));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
