import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/catalog/components/liquid_bottom_tabs.dart';
import 'package:fluid_glass_example/catalog/components/liquid_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Behaviours the Flutter port has to share with Compose, each of which Flutter
// would get wrong by default.
void main() {
  testWidgets('a press that slides past the touch slop still counts as a tap',
      (WidgetTester tester) async {
    // Compose's `clickable` bottoms out in `waitForUpOrCancellation`, which
    // fails only when another node consumes the event — there is no distance
    // test. Flutter's TapGestureRecognizer self-rejects past kTouchSlop (18px),
    // which on a button whose whole point is that it slides under your finger
    // silently swallowed the press.
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidButton(
              onPressed: () => taps++,
              backdrop: emptyBackdrop,
              children: const <Widget>[Text('Push me')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('Push me')));
    // Well past kTouchSlop.
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(9, 3));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(taps, 1, reason: 'a dragged press must still fire');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('releasing the pill on the tab it started on reports nothing',
      (WidgetTester tester) async {
    // Compose reports the selection through a snapshotFlow on the index, which
    // only emits on an actual change. Reporting on every release would re-fire
    // navigation or analytics each time the pill is merely touched.
    final List<int> reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LiquidBottomTabs(
                selectedTabIndex: 0,
                onTabSelected: reported.add,
                backdrop: emptyBackdrop,
                tabsCount: 3,
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    LiquidBottomTab(
                      onPressed: () {},
                      children: <Widget>[Text('Tab ${i + 1}')],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Press and release the pill without moving it off tab 0.
    final Offset onPill =
        tester.getTopLeft(find.byType(LiquidBottomTabs)) + const Offset(60, 32);
    final TestGesture gesture = await tester.startGesture(onPill);
    await tester.pump(const Duration(milliseconds: 32));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));

    expect(reported, isEmpty,
        reason: 'the index did not change, so nothing should be reported');
  });

  testWidgets('a drag that does change tab still reports exactly once',
      (WidgetTester tester) async {
    final List<int> reported = <int>[];
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return LiquidBottomTabs(
                    selectedTabIndex: selected,
                    onTabSelected: (int i) {
                      reported.add(i);
                      setState(() => selected = i);
                    },
                    backdrop: emptyBackdrop,
                    tabsCount: 3,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        LiquidBottomTab(
                          onPressed: () {},
                          children: <Widget>[Text('Tab ${i + 1}')],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset onPill =
        tester.getTopLeft(find.byType(LiquidBottomTabs)) + const Offset(60, 32);
    final TestGesture gesture = await tester.startGesture(onPill);
    for (int i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));

    expect(reported, <int>[2]);
  });

  testWidgets('the drag ends only when the last finger lifts',
      (WidgetTester tester) async {
    // Compose's inspectDragGestures hands the drag to a surviving pointer when
    // the tracked one goes up. Ending on the first lift would run the whole
    // release choreography with a finger still on the control.
    int ends = 0;
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return LiquidBottomTabs(
                    selectedTabIndex: selected,
                    onTabSelected: (int i) {
                      ends++;
                      setState(() => selected = i);
                    },
                    backdrop: emptyBackdrop,
                    tabsCount: 3,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        LiquidBottomTab(
                          onPressed: () {},
                          children: <Widget>[Text('Tab ${i + 1}')],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset onPill =
        tester.getTopLeft(find.byType(LiquidBottomTabs)) + const Offset(60, 32);
    final TestGesture first = await tester.startGesture(onPill);
    await tester.pump(const Duration(milliseconds: 16));
    // A second finger lands on the pill, then the first lifts.
    final TestGesture second = await tester.startGesture(onPill);
    await tester.pump(const Duration(milliseconds: 16));
    await first.up();
    await tester.pump(const Duration(milliseconds: 16));

    // The drag is still live on the second finger, so it can still move tabs.
    for (int i = 0; i < 20; i++) {
      await second.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));

    expect(selected, 2,
        reason: 'the surviving finger must keep dragging the pill');
    expect(ends, 1);
  });
}
