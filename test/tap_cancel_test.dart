import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A press is Compose's `clickable`: it fires on lifting over the element,
// however far the finger wandered inside it, and it is cancelled — for good —
// once the finger leaves the element or something else takes the gesture over.

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('sliding off a button and lifting does not fire it', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await tester.pumpWidget(
      _host(
        LiquidButton(
          onPressed: () => pressed++,
          backdrop: emptyBackdrop,
          children: const <Widget>[SizedBox(width: 80, height: 24)],
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidButton)),
    );
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await _settle(tester);
    expect(pressed, 0);
  });

  testWidgets('a press that left the button stays cancelled', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await tester.pumpWidget(
      _host(
        LiquidButton(
          onPressed: () => pressed++,
          backdrop: emptyBackdrop,
          children: const <Widget>[SizedBox(width: 80, height: 24)],
        ),
      ),
    );
    final Offset centre = tester.getCenter(find.byType(LiquidButton));
    final TestGesture gesture = await tester.startGesture(centre);
    await gesture.moveTo(centre + const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(centre);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await _settle(tester);
    expect(pressed, 0);
  });

  testWidgets('a finger wandering inside the button still fires it', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await tester.pumpWidget(
      _host(
        LiquidButton(
          onPressed: () => pressed++,
          backdrop: emptyBackdrop,
          children: const <Widget>[SizedBox(width: 120, height: 40)],
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidButton)),
    );
    // Well past the touch slop, and still on the button.
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(8, 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await _settle(tester);
    expect(pressed, 1);
  });

  testWidgets(
    'pressing one group action and lifting on another fires neither',
    (WidgetTester tester) async {
      final List<String> pressed = <String>[];
      await tester.pumpWidget(
        _host(
          LiquidButtonGroup(
            backdrop: emptyBackdrop,
            actions: <LiquidGroupAction>[
              LiquidGroupAction(
                label: 'Cancel',
                onPressed: () => pressed.add('cancel'),
              ),
              LiquidGroupAction(
                label: 'OK',
                onPressed: () => pressed.add('ok'),
              ),
            ],
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Cancel')),
      );
      await gesture.moveTo(tester.getCenter(find.text('OK')));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await _settle(tester);
      expect(pressed, isEmpty);
    },
  );

  testWidgets('a scroll that starts on a button does not fire it', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              for (int i = 0; i < 20; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: LiquidButton(
                    onPressed: () => pressed++,
                    backdrop: emptyBackdrop,
                    children: <Widget>[Text('Row $i')],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('Row 2')),
    );
    // A small vertical drag, lifting where it started: the list scrolled.
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await _settle(tester);
    expect(pressed, 0);
  });

  testWidgets('a sheet row a scroll started on is not selected', (
    WidgetTester tester,
  ) async {
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 320,
              child: LiquidSheet(
                backdrop: emptyBackdrop,
                items: <LiquidSheetItem>[
                  for (int i = 0; i < 30; i++)
                    LiquidSheetItem(
                      label: 'Option $i',
                      onSelected: () => picked.add('$i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('Option 2')),
    );
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await _settle(tester);
    expect(picked, isEmpty);

    // And a plain tap still selects.
    await tester.tap(find.text('Option 3'));
    await _settle(tester);
    expect(picked, <String>['3']);
  });
}
