import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A control in the middle of a vertical list, the way a settings page holds
/// one: the list scrolls, the control is dragged sideways.
Widget _inList(ScrollController controller, Widget control) => MaterialApp(
  home: Scaffold(
    body: ListView(
      controller: controller,
      children: <Widget>[
        const SizedBox(height: 200),
        Center(child: SizedBox(width: 300, child: control)),
        const SizedBox(height: 2000),
      ],
    ),
  ),
);

/// The centre of the glass part — the thumb or the knob — of [control].
Offset _grip(WidgetTester tester, Type control) => tester.getCenter(
  find.descendant(
    of: find.byType(control),
    matching: find.byType(DrawBackdrop),
  ),
);

/// Moves in small steps, as a finger does: the arena decides on the step that
/// passes the slop, so one big jump would hide which axis got there first.
Future<void> _drag(TestGesture gesture, Offset by, {int steps = 20}) async {
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(by / steps.toDouble());
  }
}

void main() {
  group('LiquidSlider in a vertical list', () {
    testWidgets('a sideways drag keeps the list still, even as it drifts', (
      tester,
    ) async {
      final controller = ScrollController();
      final values = <double>[];
      var ends = 0;
      await tester.pumpWidget(
        _inList(
          controller,
          LiquidSlider(
            value: 0,
            backdrop: emptyBackdrop,
            onValueChanged: values.add,
            onChangeEnd: (_) => ends++,
          ),
        ),
      );

      final gesture = await tester.startGesture(_grip(tester, LiquidSlider));
      // Sideways first, past the slop …
      await _drag(gesture, const Offset(40, 0));
      // … then the thumb wanders well past the list's own slop vertically.
      await _drag(gesture, const Offset(80, -60));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.offset, 0, reason: 'the list must not scroll');
      expect(values, isNotEmpty);
      expect(values.last, greaterThan(0.2));
      expect(ends, 1);
    });

    testWidgets(
      'a vertical swipe from the thumb scrolls and leaves the value',
      (tester) async {
        final controller = ScrollController();
        final values = <double>[];
        var starts = 0;
        var ends = 0;
        await tester.pumpWidget(
          _inList(
            controller,
            LiquidSlider(
              value: 0.5,
              backdrop: emptyBackdrop,
              onValueChanged: values.add,
              onChangeStart: (_) => starts++,
              onChangeEnd: (_) => ends++,
            ),
          ),
        );

        final gesture = await tester.startGesture(_grip(tester, LiquidSlider));
        // A thumb's swipe up is never quite straight.
        await _drag(gesture, const Offset(10, -120));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.offset, greaterThan(0), reason: 'the list scrolls');
        expect(values, isEmpty, reason: 'the wobble must not reach the caller');
        expect(starts, 0);
        expect(ends, 0);
      },
    );

    testWidgets('standing alone, a drag reports from its first movement', (
      tester,
    ) async {
      final values = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: LiquidSlider(
                  value: 0,
                  backdrop: emptyBackdrop,
                  onValueChanged: values.add,
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(_grip(tester, LiquidSlider));
      await tester.pump();
      // Well under the touch slop: with nothing to compete with, the slider
      // owns the drag from the start and does not wait for it.
      await gesture.moveBy(const Offset(6, 0));
      expect(values, isNotEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('LiquidToggle in a vertical list', () {
    testWidgets('dragging the knob across keeps the list still and switches', (
      tester,
    ) async {
      final controller = ScrollController();
      final selections = <bool>[];
      await tester.pumpWidget(
        _inList(
          controller,
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidToggle(
              selected: false,
              backdrop: emptyBackdrop,
              onSelect: selections.add,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(_grip(tester, LiquidToggle));
      await _drag(gesture, const Offset(30, 0));
      await _drag(gesture, const Offset(10, -40));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
      expect(selections, <bool>[true]);
    });

    testWidgets('a vertical swipe from the knob scrolls and switches nothing', (
      tester,
    ) async {
      final controller = ScrollController();
      final selections = <bool>[];
      await tester.pumpWidget(
        _inList(
          controller,
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidToggle(
              selected: false,
              backdrop: emptyBackdrop,
              onSelect: selections.add,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(_grip(tester, LiquidToggle));
      await _drag(gesture, const Offset(8, -120));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(selections, isEmpty);
    });

    testWidgets('a tap on the knob in a list still switches', (tester) async {
      final controller = ScrollController();
      final selections = <bool>[];
      await tester.pumpWidget(
        _inList(
          controller,
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidToggle(
              selected: false,
              backdrop: emptyBackdrop,
              onSelect: selections.add,
            ),
          ),
        ),
      );

      await tester.tapAt(_grip(tester, LiquidToggle));
      await tester.pumpAndSettle();

      expect(selections, <bool>[true]);
    });
  });

  group('LiquidToggle in a tappable row', () {
    Widget row({required List<bool> selections, required VoidCallback onRow}) =>
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                ListTile(
                  title: const Text('Notifications'),
                  onTap: onRow,
                  trailing: LiquidToggle(
                    selected: false,
                    backdrop: emptyBackdrop,
                    onSelect: selections.add,
                  ),
                ),
              ],
            ),
          ),
        );

    testWidgets('a tap on the knob flips it once and does not reach the row', (
      tester,
    ) async {
      final selections = <bool>[];
      var rowTaps = 0;
      await tester.pumpWidget(
        row(selections: selections, onRow: () => rowTaps++),
      );

      await tester.tapAt(_grip(tester, LiquidToggle));
      await tester.pumpAndSettle();

      expect(selections, <bool>[true]);
      expect(rowTaps, 0);
    });

    testWidgets('a tap on the track does not reach the row either', (
      tester,
    ) async {
      final selections = <bool>[];
      var rowTaps = 0;
      await tester.pumpWidget(
        row(selections: selections, onRow: () => rowTaps++),
      );

      // The far end of the track, away from the knob.
      final Rect toggle = tester.getRect(find.byType(LiquidToggle));
      await tester.tapAt(Offset(toggle.right - 6, toggle.center.dy));
      await tester.pumpAndSettle();

      expect(selections, <bool>[true]);
      expect(rowTaps, 0);
    });

    testWidgets('the row itself is still tappable beside the switch', (
      tester,
    ) async {
      final selections = <bool>[];
      var rowTaps = 0;
      await tester.pumpWidget(
        row(selections: selections, onRow: () => rowTaps++),
      );

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      expect(rowTaps, 1);
      expect(selections, isEmpty);
    });
  });

  testWidgets('a knob dragged and let go on its own side reports nothing', (
    tester,
  ) async {
    final selections = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidToggle(
              selected: false,
              backdrop: emptyBackdrop,
              onSelect: selections.add,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(_grip(tester, LiquidToggle));
    // Past the slop so it is a drag, then most of the way back.
    await _drag(gesture, const Offset(24, 0));
    await _drag(gesture, const Offset(-22, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selections, isEmpty);
  });

  testWidgets(
    'a segmented control in a list keeps a sideways drag from the list',
    (tester) async {
      final controller = ScrollController();
      final selected = <int>[];
      await tester.pumpWidget(
        _inList(
          controller,
          LiquidSegmentedControl(
            selectedIndex: 0,
            onSelected: selected.add,
            backdrop: emptyBackdrop,
            segments: const <Widget>[Text('A'), Text('B'), Text('C')],
          ),
        ),
      );

      // From the first segment: a press there slides the thumb along.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A').first),
      );
      await _drag(gesture, const Offset(60, 0));
      await _drag(gesture, const Offset(140, -50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
      expect(selected, isNotEmpty);
      expect(selected.last, 2);
    },
  );
}
