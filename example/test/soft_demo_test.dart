import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/soft_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page runs spinners forever, so it never settles: pump a second of
/// frames instead.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  Future<void> pumpDemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SoftDemoApp());
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the whole page lays out, top to bottom, light and dark', (
    tester,
  ) async {
    await pumpDemo(tester);
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 0; i < 30; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      // Back to the top and into dark mode.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 20000));
      await settle(tester);
      await tester.tap(find.byType(SoftBarAction).first);
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog, sheet and menu open and close', (tester) async {
    await pumpDemo(tester);
    Future<void> scrollTo(String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
    }

    await scrollTo('Dialog');
    await tester.tap(find.text('Dialog'));
    await settle(tester);
    expect(find.text('Delete this record?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Delete this record?'), findsNothing);

    await tester.tap(find.text('Sheet'));
    await settle(tester);
    expect(find.text('Share report'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Share report'), findsNothing);

    await tester.tap(find.text('Menu'));
    await settle(tester);
    expect(find.text('Pin to top'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await settle(tester);
    expect(find.text('Pin to top'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
