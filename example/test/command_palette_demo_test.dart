import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/catalog/destinations/command_palette_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('studio commands update the workspace, retry and open a modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CommandPaletteContent())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a canvas'));
    await tester.pumpAndSettle();
    expect(
      find.text('Canvas 4 is ready. Make something good.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'retry');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test a retry'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('That did not finish. Try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('Recovered. Your work is safe.'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidCommandPalette), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidCommandPalette), findsOneWidget);
  });

  testWidgets('studio remains usable on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CommandPaletteContent())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Switch appearance'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
