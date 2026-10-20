import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bar owns the finger: a press travels across the islands and fires the
/// one it lifts on.
void main() {
  Widget bar({
    required VoidCallback onBack,
    required VoidCallback onMore,
    VoidCallback? onTitle,
    bool isInteractive = true,
    Widget? titleLeading,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: ColoredBox(key: Key('page'), color: Color(0xFFCCCCCC)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LiquidNavigationBar(
                backdrop: emptyBackdrop,
                includeTopPadding: false,
                title: const Text('Title'),
                titleLeading: titleLeading,
                onTitlePressed: onTitle,
                isInteractive: isInteractive,
                leading: LiquidNavigationAction(
                  backdrop: emptyBackdrop,
                  icon: Icons.arrow_back,
                  label: 'Back',
                  onPressed: onBack,
                ),
                trailing: LiquidNavigationAction(
                  backdrop: emptyBackdrop,
                  icon: Icons.more_horiz,
                  label: 'More',
                  onPressed: onMore,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('a tap on an island fires it once', (tester) async {
    int back = 0;
    int more = 0;
    await tester.pumpWidget(bar(onBack: () => back++, onMore: () => more++));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(back, 1);
    expect(more, 0);
  });

  testWidgets('down on one island, lift on another fires the other', (
    tester,
  ) async {
    int back = 0;
    int more = 0;
    await tester.pumpWidget(bar(onBack: () => back++, onMore: () => more++));
    await tester.pump();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_back)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Title')));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.more_horiz)));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(back, 0);
    expect(more, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifting in a gap fires nothing', (tester) async {
    int back = 0;
    int more = 0;
    int title = 0;
    await tester.pumpWidget(
      bar(onBack: () => back++, onMore: () => more++, onTitle: () => title++),
    );
    await tester.pump();
    final Offset backCentre = tester.getCenter(find.byIcon(Icons.arrow_back));
    final Offset titleLeft = tester.getTopLeft(find.text('Title'));
    // Between the back island and the title island.
    final Offset gap = Offset(
      (tester.getTopRight(find.byIcon(Icons.arrow_back)).dx + titleLeft.dx) / 2,
      backCentre.dy,
    );
    final TestGesture gesture = await tester.startGesture(backCentre);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(gap);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(back, 0);
    expect(more, 0);
    expect(title, 0);
  });

  testWidgets('a title island with a callback fires on lift too', (
    tester,
  ) async {
    int title = 0;
    await tester.pumpWidget(
      bar(onBack: () {}, onMore: () {}, onTitle: () => title++),
    );
    await tester.pump();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.more_horiz)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Title')));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(title, 1);
  });

  // Regression: with the bar's motion turned off it installs no pointer
  // listener, while an action left at its own default went on waiting for the
  // bar's finger — so a reader who asked for reduced motion could not go back.
  testWidgets('a bar with its motion off still fires its actions', (
    tester,
  ) async {
    int back = 0;
    int more = 0;
    int title = 0;
    await tester.pumpWidget(
      bar(
        onBack: () => back++,
        onMore: () => more++,
        onTitle: () => title++,
        isInteractive: false,
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(back, 1);
    expect(more, 1);
    expect(title, 1);
  });

  // Regression: the press deformation returned the bare child at rest and a
  // `Transform` under a press, so the island's content was torn down and
  // rebuilt at both ends of every press.
  testWidgets('a press keeps the island content alive', (tester) async {
    final List<String> lifecycle = <String>[];
    await tester.pumpWidget(
      bar(
        onBack: () {},
        onMore: () {},
        onTitle: () {},
        titleLeading: _Lifecycle(lifecycle),
      ),
    );
    await tester.pump();
    expect(lifecycle, <String>['init']);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('Title')),
    );
    // Frame by frame: a spring starts its clock on its first tick, so one
    // long pump would leave the press exactly where it began.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(lifecycle, <String>['init']);
  });

  // Regression: the islands were placed by screen side, so in a right-to-left
  // layout the back action stayed on the left while the title read from the
  // right.
  testWidgets('leading and trailing follow the reading direction', (
    tester,
  ) async {
    int back = 0;
    await tester.pumpWidget(
      bar(onBack: () => back++, onMore: () {}, direction: TextDirection.rtl),
    );
    await tester.pump();
    final double width = tester.getSize(find.byType(LiquidNavigationBar)).width;
    expect(
      tester.getCenter(find.byIcon(Icons.arrow_back)).dx,
      greaterThan(width / 2),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.more_horiz)).dx,
      lessThan(width / 2),
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(back, 1);
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
