import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/soft_demo.dart';
import 'package:fluid_glass_example/soft_demo/reference_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  Future<void> pumpDemo(WidgetTester tester, {required bool dark}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SoftDemoApp(initialDark: dark));
    await settle(tester);
  }

  for (final bool dark in <bool>[false, true]) {
    testWidgets('the navigation demo lays out and answers (dark: $dark)', (
      tester,
    ) async {
      await pumpDemo(tester, dark: dark);
      expect(find.byType(SoftFloatingNavigationBar), findsWidgets);

      // Switch tabs from the page bar (the last bar in the tree).
      final Finder pageBar = find.byType(SoftFloatingNavigationBar).last;
      await tester.tap(find.descendant(of: pageBar, matching: find.text('组件')));
      await settle(tester);
      expect(find.byType(SoftReferencePage), findsOneWidget);
      await tester.tap(find.descendant(of: pageBar, matching: find.text('首页')));
      await settle(tester);

      // Press and slide along the capsule: it follows the finger, and the
      // selection follows it from item to item.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(
          find.descendant(of: pageBar, matching: find.text('配色')),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(6, -3));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);
      // The finger moved on 「配色」, which was not selected: it went there.
      expect(find.text('配色 1'), findsOneWidget);
      await tester.tap(find.descendant(of: pageBar, matching: find.text('首页')));
      await settle(tester);

      // Scroll through the page, hiding and showing the round views.
      for (int i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
