import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One finger, many controls: the press — and the commit — follow the finger
/// across the members of a group.
void main() {
  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );

  Widget member(String key, VoidCallback onTap) => LiquidInteraction(
    key: Key(key),
    onTap: onTap,
    child: const SizedBox(width: 100, height: 100),
  );

  testWidgets('a tap on a member fires that member, once', (tester) async {
    int a = 0;
    int b = 0;
    await tester.pumpWidget(
      host(
        LiquidInteractionGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[member('a', () => a++), member('b', () => b++)],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    expect(a, 1);
    expect(b, 0);
  });

  testWidgets('down on one member, lift on another fires the other', (
    tester,
  ) async {
    int a = 0;
    int b = 0;
    await tester.pumpWidget(
      host(
        LiquidInteractionGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[member('a', () => a++), member('b', () => b++)],
          ),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('a'))),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('b'))));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(a, 0);
    expect(b, 1);
  });

  testWidgets('lifting on nothing fires nothing', (tester) async {
    int a = 0;
    await tester.pumpWidget(
      host(
        LiquidInteractionGroup(
          child: SizedBox(
            width: 300,
            height: 300,
            child: Align(
              alignment: Alignment.topLeft,
              child: member('a', () => a++),
            ),
          ),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('a'))),
    );
    await gesture.moveTo(
      tester.getBottomRight(find.byType(LiquidInteractionGroup)) -
          const Offset(10, 10),
    );
    await gesture.up();
    await tester.pump();
    expect(a, 0);
  });

  testWidgets('a scroll under the finger cancels the press', (tester) async {
    int fired = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          height: 300,
          child: LiquidInteractionGroup(
            child: ListView(
              children: List<Widget>.generate(
                20,
                (int i) => member('m$i', () => fired++),
              ),
            ),
          ),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('m1'))),
    );
    await tester.pump();
    // Drag far enough for the list to scroll.
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('outside a group, onTap fires on a lift inside the control', (
    tester,
  ) async {
    int a = 0;
    await tester.pumpWidget(host(member('a', () => a++)));
    final Offset centre = tester.getCenter(find.byKey(const Key('a')));
    // Wander past any slop and come back: still a tap here.
    final TestGesture gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveTo(centre);
    await gesture.up();
    await tester.pump();
    expect(a, 1);

    // Lift outside: nothing.
    final TestGesture away = await tester.startGesture(centre);
    await away.moveBy(const Offset(200, 0));
    await away.up();
    await tester.pump();
    expect(a, 1);
  });

  testWidgets('the glow follows the group finger onto the member it is over', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LiquidInteractionGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[member('a', () {}), member('b', () {})],
          ),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('a'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(tester.getCenter(find.byKey(const Key('b'))));
    await tester.pump(const Duration(milliseconds: 300));
    // Both members are still mounted and painting without error while the
    // press is handed from one to the other.
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
