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
  }) => MaterialApp(
    home: Scaffold(
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
              onTitlePressed: onTitle,
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
}
