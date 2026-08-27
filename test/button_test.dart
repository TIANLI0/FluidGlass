import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _frame(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

void main() {
  testWidgets('the default box is the catalog capsule: 48 tall, 16 either side',
      (WidgetTester tester) async {
    await tester.pumpWidget(_frame(
      LiquidButton(
        onPressed: () {},
        backdrop: emptyBackdrop,
        children: const <Widget>[SizedBox(width: 24, height: 24)],
      ),
    ));

    expect(tester.getSize(find.byType(LiquidButton)), const Size(56, 48));
  });

  testWidgets('a square button is a circle: height with no padding',
      (WidgetTester tester) async {
    await tester.pumpWidget(_frame(
      LiquidButton(
        onPressed: () {},
        backdrop: emptyBackdrop,
        height: 40,
        padding: EdgeInsets.zero,
        children: const <Widget>[SizedBox(width: 40, height: 40)],
      ),
    ));

    // The shape is a capsule, so a 40x40 box is a 40px circle.
    expect(tester.getSize(find.byType(LiquidButton)), const Size(40, 40));
  });

  testWidgets('spacing sits between the children', (WidgetTester tester) async {
    await tester.pumpWidget(_frame(
      LiquidButton(
        onPressed: () {},
        backdrop: emptyBackdrop,
        padding: EdgeInsets.zero,
        spacing: 12,
        children: const <Widget>[
          SizedBox(width: 10, height: 10),
          SizedBox(width: 10, height: 10),
        ],
      ),
    ));

    expect(tester.getSize(find.byType(LiquidButton)).width, 32);
  });

  group('a null onPressed', () {
    testWidgets('reports nothing and still draws', (WidgetTester tester) async {
      await tester.pumpWidget(_frame(
        const LiquidButton(
          onPressed: null,
          backdrop: emptyBackdrop,
          children: <Widget>[SizedBox(width: 24, height: 24)],
        ),
      ));

      await tester.tap(find.byType(LiquidButton), warnIfMissed: false);
      await tester.pump();

      expect(find.byType(LiquidButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is inert, not absorbing: the tap reaches what is behind',
        (WidgetTester tester) async {
      var behind = 0;
      await tester.pumpWidget(_frame(
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => behind += 1,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              const Positioned(
                left: 50,
                top: 50,
                child: LiquidButton(
                  onPressed: null,
                  backdrop: emptyBackdrop,
                  children: <Widget>[SizedBox(width: 24, height: 24)],
                ),
              ),
            ],
          ),
        ),
      ));

      await tester.tapAt(tester.getCenter(find.byType(LiquidButton)));
      await tester.pump();

      expect(behind, 1);
    });

    testWidgets('does not leave a press animation running',
        (WidgetTester tester) async {
      await tester.pumpWidget(_frame(
        const LiquidButton(
          onPressed: null,
          backdrop: emptyBackdrop,
          children: <Widget>[SizedBox(width: 24, height: 24)],
        ),
      ));

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(LiquidButton)),
      );
      await tester.pump();
      await gesture.up();

      // pumpAndSettle would time out on a spring that never got told to stop.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('an enabled button still reports its press',
      (WidgetTester tester) async {
    var pressed = 0;
    await tester.pumpWidget(_frame(
      LiquidButton(
        onPressed: () => pressed += 1,
        backdrop: emptyBackdrop,
        children: const <Widget>[SizedBox(width: 24, height: 24)],
      ),
    ));

    await tester.tap(find.byType(LiquidButton));
    await tester.pump();

    expect(pressed, 1);
  });
}
