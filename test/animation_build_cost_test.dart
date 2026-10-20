import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Widget Function()> controls = <String, Widget Function()>{
    'slider': () => SizedBox(
      width: 300,
      child: LiquidSlider(
        value: 0.5,
        backdrop: emptyBackdrop,
        onValueChanged: (_) {},
      ),
    ),
    'toggle': () => LiquidToggle(
      selected: false,
      backdrop: emptyBackdrop,
      onSelect: (_) {},
    ),
    'segments': () => SizedBox(
      width: 300,
      child: LiquidSegmentedControl(
        selectedIndex: 0,
        backdrop: emptyBackdrop,
        onSelected: (_) {},
        segments: const <Widget>[Text('Day'), Text('Week')],
      ),
    ),
  };
  for (final entry in controls.entries) {
    testWidgets(
      '${entry.key} moves without building widgets on animation ticks',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: entry.value())),
          ),
        );
        await tester.pumpAndSettle();
        final Finder thumb = find.byType(DrawBackdrop).last;
        final Offset before = tester.getCenter(thumb);
        final TestGesture gesture = await tester.startGesture(before);
        await gesture.moveBy(const Offset(15, 0));
        // Pointer feedback may schedule its own build. Count only the spring's
        // subsequent ticks, when no new input or parent rebuild arrives.
        await tester.pump();
        final List<String> builds = <String>[];
        final RebuildDirtyWidgetCallback? previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
          previous?.call(element, builtOnce);
          builds.add(element.widget.runtimeType.toString());
        };
        try {
          for (int i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        } finally {
          debugOnRebuildDirtyWidget = previous;
        }
        expect(builds, isEmpty, reason: builds.join(', '));
        expect(tester.getCenter(thumb).dx, greaterThan(before.dx));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
