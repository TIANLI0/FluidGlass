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
  testWidgets(
    'single child wraps within narrow constraints and grows for large text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 220,
                  child: LiquidButton(
                    backdrop: emptyBackdrop,
                    onPressed: () {},
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: const Text(
                      'Save workspace changes',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(LiquidButton)).width, 220);
      expect(tester.getSize(find.byType(LiquidButton)).height, greaterThan(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the default box is the catalog capsule: 48 tall, 16 either side',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _frame(
          LiquidButton(
            onPressed: () {},
            backdrop: emptyBackdrop,
            children: const <Widget>[SizedBox(width: 24, height: 24)],
          ),
        ),
      );

      expect(tester.getSize(find.byType(LiquidButton)), const Size(56, 48));
    },
  );

  testWidgets('a square button is a circle: height with no padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        LiquidButton(
          onPressed: () {},
          backdrop: emptyBackdrop,
          height: 40,
          padding: EdgeInsets.zero,
          children: const <Widget>[SizedBox(width: 40, height: 40)],
        ),
      ),
    );

    // The shape is a capsule, so a 40x40 box is a 40px circle.
    expect(tester.getSize(find.byType(LiquidButton)), const Size(40, 40));
  });

  testWidgets('spacing sits between the children', (WidgetTester tester) async {
    await tester.pumpWidget(
      _frame(
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
      ),
    );

    expect(tester.getSize(find.byType(LiquidButton)).width, 32);
  });

  group('a null onPressed', () {
    testWidgets('reports nothing and still draws', (WidgetTester tester) async {
      await tester.pumpWidget(
        _frame(
          const LiquidButton(
            onPressed: null,
            backdrop: emptyBackdrop,
            children: <Widget>[SizedBox(width: 24, height: 24)],
          ),
        ),
      );

      await tester.tap(find.byType(LiquidButton), warnIfMissed: false);
      await tester.pump();

      expect(find.byType(LiquidButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is inert, not absorbing: the tap reaches what is behind', (
      WidgetTester tester,
    ) async {
      var behind = 0;
      await tester.pumpWidget(
        _frame(
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
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(LiquidButton)));
      await tester.pump();

      expect(behind, 1);
    });

    testWidgets('does not leave a press animation running', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          const LiquidButton(
            onPressed: null,
            backdrop: emptyBackdrop,
            children: <Widget>[SizedBox(width: 24, height: 24)],
          ),
        ),
      );

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

  testWidgets('an enabled button still reports its press', (
    WidgetTester tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _frame(
        LiquidButton(
          onPressed: () => pressed += 1,
          backdrop: emptyBackdrop,
          children: const <Widget>[SizedBox(width: 24, height: 24)],
        ),
      ),
    );

    await tester.tap(find.byType(LiquidButton));
    await tester.pump();

    expect(pressed, 1);
  });

  // Regression: a disabled button was left unwrapped, so enabling or
  // disabling it changed the tree above its children and rebuilt them.
  testWidgets('enabling a button keeps its children', (
    WidgetTester tester,
  ) async {
    final List<String> lifecycle = <String>[];
    Widget button(VoidCallback? onPressed) => MaterialApp(
      home: Center(
        child: LiquidButton(
          onPressed: onPressed,
          backdrop: emptyBackdrop,
          children: <Widget>[_Lifecycle(lifecycle)],
        ),
      ),
    );
    await tester.pumpWidget(button(null));
    await tester.pumpWidget(button(() {}));
    await tester.pumpWidget(button(null));
    expect(lifecycle, <String>['init']);
  });

  // Regression: disabling a button under a finger dropped the handler that
  // would have heard the finger lift, and the press stayed on for good.
  testWidgets('a button disabled mid-press lets the press go', (
    WidgetTester tester,
  ) async {
    int pressed = 0;
    Widget button(VoidCallback? onPressed) => MaterialApp(
      home: Center(
        child: LiquidButton(
          onPressed: onPressed,
          backdrop: emptyBackdrop,
          children: const <Widget>[SizedBox(width: 80, height: 24)],
        ),
      ),
    );
    await tester.pumpWidget(button(() => pressed++));
    await tester.pumpAndSettle();
    final Rect rest = tester.getRect(find.byType(SizedBox).last);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidButton)),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.getRect(find.byType(SizedBox).last),
      isNot(rest),
      reason: 'pressed: swollen',
    );

    await tester.pumpWidget(button(null));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed, 0);
    expect(tester.getRect(find.byType(SizedBox).last), rest);

    // Enabled again, it is at rest — not still holding the press it lost.
    await tester.pumpWidget(button(() => pressed++));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SizedBox).last), rest);
  });
}

class _Lifecycle extends StatefulWidget {
  const _Lifecycle(this.log);

  final List<String> log;

  @override
  State<_Lifecycle> createState() => _LifecycleState();
}

class _LifecycleState extends State<_Lifecycle> {
  @override
  void initState() {
    super.initState();
    widget.log.add('init');
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 24, height: 24);
}
