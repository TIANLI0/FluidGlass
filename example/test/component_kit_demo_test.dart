import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/catalog/destinations/component_kit_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(
  WidgetTester tester, {
  Size size = const Size(1200, 1000),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: ComponentKitContent(initialDark: dark)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
  bool settleBefore = true,
}) async {
  if (settleBefore) await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pump();
  if (settleBefore) await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'workspace validates, cancels and saves without losing form state',
    (tester) async {
      await _show(tester);
      final name = find.descendant(
        of: find.byKey(const ValueKey('workspace-name')),
        matching: find.byType(TextField),
      );
      await tester.enterText(name, '');
      await _tapVisible(tester, find.text('Save changes'));
      expect(find.text('A workspace name is required.'), findsOneWidget);
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Blue room');
      await _tapVisible(tester, find.text('Save changes'), settle: false);
      expect(find.text('Saving your preview'), findsOneWidget);
      await _tapVisible(
        tester,
        find.text('Cancel'),
        settle: false,
        settleBefore: false,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Everything is in place'), findsNothing);
      await _tapVisible(tester, find.text('Save changes'), settle: false);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('Everything is in place'), findsOneWidget);
      expect(
        find.textContaining(
          'Blue room is ready for this session.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(name).controller!.text, 'Blue room');
      // Finish the native notification before leaving the page.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Reset defaults'));
      expect(tester.widget<TextField>(name).controller!.text, 'Fluid studio');
      expect(find.text('Everything is in place'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project choices and search compose; empty state clears all filters',
    (tester) async {
      await _show(tester);
      await _tapVisible(tester, find.text('Notes'));
      expect(find.text('Small discoveries'), findsOneWidget);
      expect(find.text('Blue hour'), findsNothing);
      await _tapVisible(tester, find.text('Pinned only'));
      expect(find.byType(LiquidEmptyState), findsOneWidget);
      await _tapVisible(tester, find.text('Clear filters'));
      expect(find.text('Blue hour'), findsOneWidget);
      final search = find.descendant(
        of: find.byType(LiquidSearchField),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'no such project');
      await tester.pumpAndSettle();
      expect(find.byType(LiquidEmptyState), findsOneWidget);
      await _tapVisible(tester, find.byTooltip('Clear search'));
      expect(find.text('Small discoveries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('kit supports narrow dark layout, large text and theme changes', (
    tester,
  ) async {
    await _show(tester, size: const Size(360, 800), dark: true, scale: 2);
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, find.byTooltip('Switch appearance'));
    await _tapVisible(tester, find.text('Stay in the loop'));
    await _tapVisible(tester, find.text('Pinned only'));
    expect(find.text('Blue hour'), findsOneWidget);
    expect(find.text('Small discoveries'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
