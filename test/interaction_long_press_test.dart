import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Widget _cell(
  String label, {
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  ValueChanged<bool>? onPressedChanged,
}) => SizedBox(
  width: 80,
  height: 80,
  child: LiquidInteraction(
    onTap: onTap,
    onLongPress: onLongPress,
    onPressedChanged: onPressedChanged,
    semanticLabel: label,
    child: Center(child: Text(label)),
  ),
);

void main() {
  group('LiquidInteraction on its own', () {
    testWidgets('a long press fires once, ends the press, and its lift does '
        'not tap', (tester) async {
      var taps = 0;
      var longPresses = 0;
      final pressed = <bool>[];
      await tester.pumpWidget(
        _host(
          _cell(
            'A',
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            onPressedChanged: pressed.add,
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(longPresses, 1);
      expect(pressed, <bool>[true, false], reason: 'the light goes out');

      await gesture.moveBy(const Offset(4, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(longPresses, 1);
      expect(pressed, <bool>[true, false]);
    });

    testWidgets('a finger that moves past the slop is not a long press', (
      tester,
    ) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        _host(
          _cell('A', onTap: () => taps++, onLongPress: () => longPresses++),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(LiquidInteraction)) + const Offset(5, 5),
      );
      await gesture.moveBy(const Offset(30, 30));
      await tester.pump(kLongPressTimeout * 2);
      expect(longPresses, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'still lifted on the control');
    });

    testWidgets('a screen reader can tap and long-press it', (tester) async {
      var taps = 0;
      var longPresses = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          _cell('A', onTap: () => taps++, onLongPress: () => longPresses++),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(LiquidInteraction),
      );
      final SemanticsData data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.longPress), isTrue);
      tester.semantics.tap(find.semantics.byAction(SemanticsAction.tap));
      tester.semantics.longPress(
        find.semantics.byAction(SemanticsAction.longPress),
      );
      expect(taps, 1);
      expect(longPresses, 1);
      handle.dispose();
    });
  });

  group('LiquidInteractionGroup', () {
    testWidgets('a long press, then a slide to a neighbour and a lift, taps '
        'nothing', (tester) async {
      final taps = <String>[];
      final longPresses = <String>[];
      await tester.pumpWidget(
        _host(
          LiquidInteractionGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String label in <String>['A', 'B'])
                  _cell(
                    label,
                    onTap: () => taps.add(label),
                    onLongPress: () => longPresses.add(label),
                  ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(longPresses, <String>['A']);

      await gesture.moveTo(tester.getCenter(find.text('B')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
    });

    testWidgets('a plain tap still goes to the member it lifts on', (
      tester,
    ) async {
      final taps = <String>[];
      final longPresses = <String>[];
      await tester.pumpWidget(
        _host(
          LiquidInteractionGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String label in <String>['A', 'B'])
                  _cell(
                    label,
                    onTap: () => taps.add(label),
                    onLongPress: () => longPresses.add(label),
                  ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      await gesture.moveTo(tester.getCenter(find.text('B')));
      await tester.pump(kLongPressTimeout * 2);
      expect(longPresses, isEmpty, reason: 'the finger did not rest');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, <String>['B']);
    });

    testWidgets('a member removed under the finger lets its press go', (
      tester,
    ) async {
      final pressed = <bool>[];
      var longPresses = 0;
      var showA = true;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          LiquidInteractionGroup(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return showA
                    ? _cell(
                        'A',
                        onLongPress: () => longPresses++,
                        onPressedChanged: pressed.add,
                      )
                    : const SizedBox(width: 80, height: 80);
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      expect(pressed, <bool>[true]);
      update(() => showA = false);
      await tester.pump();
      await tester.pump(kLongPressTimeout * 2);
      expect(longPresses, 0, reason: 'its long press went with it');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
