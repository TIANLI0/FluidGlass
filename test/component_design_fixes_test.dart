import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ColorBackdrop compares by colour', () {
    // ignore: prefer_const_constructors — the point is two separate instances.
    final ColorBackdrop a = ColorBackdrop(const Color(0xFFFAF7F2));
    // ignore: prefer_const_constructors
    final ColorBackdrop b = ColorBackdrop(const Color(0xFFFAF7F2));
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const ColorBackdrop(Color(0xFF000000)), isFalse);
  });

  testWidgets('a disabled toggle is drawn dimmed', (tester) async {
    Future<void> pump(ValueChanged<bool>? onSelect) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidToggle(
              selected: true,
              onSelect: onSelect,
              backdrop: const ColorBackdrop(Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ),
    );

    await pump((_) {});
    expect(
      find.descendant(
        of: find.byType(LiquidToggle),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );

    await pump(null);
    final Opacity dim = tester.widget(
      find.descendant(
        of: find.byType(LiquidToggle),
        matching: find.byType(Opacity),
      ),
    );
    expect(dim.opacity, lessThan(1));
  });

  testWidgets('a sheet taller than the screen stays below the status bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 120);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showLiquidSheet<void>(
                  context: context,
                  backdrop: const ColorBackdrop(Color(0xFFFFFFFF)),
                  title: 'Many',
                  plain: true,
                  items: <LiquidSheetItem>[
                    for (int i = 0; i < 40; i++)
                      LiquidSheetItem(label: 'Row $i', onSelected: () {}),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final double statusBar = 120 / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.byType(LiquidSheet)).dy,
      greaterThanOrEqualTo(statusBar),
    );
  });

  test('the navigation bar publishes its island gap', () {
    expect(LiquidNavigationBar.gap, 8);
  });
}
