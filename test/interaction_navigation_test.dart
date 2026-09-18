import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget menu(List<String> picked, {bool liquidAnchor = false}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: LiquidMenu(
        backdrop: emptyBackdrop,
        items: [
          for (final label in ['One', 'Two', 'Three'])
            LiquidMenuItem(label: label, onSelected: () => picked.add(label)),
        ],
        anchorBuilder: (context, open, toggle) => liquidAnchor
            ? LiquidButton(
                backdrop: emptyBackdrop,
                onPressed: toggle,
                children: const [Text('Open')],
              )
            : TextButton(onPressed: toggle, child: const Text('Open')),
      ),
    ),
  ),
);

void main() {
  testWidgets('drag moves the menu elastically and cancellation springs home', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(menu(picked));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final rest = tester.getCenter(find.text('One'));
    final gesture = await tester.startGesture(rest);
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveTo(
      tester.getCenter(find.text('Two')) + const Offset(36, 0),
    );
    await tester.pump();
    final before = tester.getCenter(find.text('One'));
    await tester.pump(const Duration(milliseconds: 80));
    final moving = tester.getCenter(find.text('One'));
    expect((moving - before).distance, greaterThan(0.1));
    expect((moving - rest).distance, lessThan(12));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect((tester.getCenter(find.text('One')) - rest).distance, lessThan(0.1));
    expect(picked, isEmpty);
  });

  testWidgets(
    'global ink feedback releases and cancels without changing actions',
    (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: LiquidInkHighlight.splashFactory),
          home: Scaffold(
            body: TextButton(
              onPressed: () => taps++,
              child: const Text('Action'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'segment drag starts anywhere and cancellation restores selection',
    (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: LiquidSegmentedControl(
                  backdrop: emptyBackdrop,
                  selectedIndex: 0,
                  onSelected: selected.add,
                  segments: const [Text('Day'), Text('Week'), Text('Month')],
                ),
              ),
            ),
          ),
        ),
      );
      var gesture = await tester.startGesture(
        tester.getCenter(find.text('Week')),
      );
      await gesture.moveTo(tester.getCenter(find.text('Month')));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      gesture = await tester.startGesture(tester.getCenter(find.text('Week')));
      await gesture.moveTo(tester.getCenter(find.text('Month')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, [2]);
    },
  );

  testWidgets(
    'menu tracks the release row, leaving cancels, cancel never commits',
    (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(menu(picked));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      var gesture = await tester.startGesture(
        tester.getCenter(find.text('One')),
      );
      await gesture.moveTo(tester.getCenter(find.text('Three')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(picked, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked, ['Three']);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      gesture = await tester.startGesture(tester.getCenter(find.text('One')));
      await gesture.moveTo(const Offset(10, 10));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked, ['Three']);
      gesture = await tester.startGesture(tester.getCenter(find.text('Two')));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(picked, ['Three']);
    },
  );

  testWidgets(
    'long press liquid anchor slides into menu without toggling closed',
    (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(menu(picked, liquidAnchor: true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Open')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      await gesture.moveTo(tester.getCenter(find.text('Two')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picked, ['Two']);
      expect(find.text('Two'), findsNothing);
    },
  );

  testWidgets(
    'navigation centers its title with asymmetric actions at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final capture = GlobalKey();
      final backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: capture,
            child: Scaffold(
              body: Stack(
                children: [
                  BackdropLayer(
                    backdrop: backdrop,
                    child: ListView.builder(
                      itemCount: 24,
                      itemBuilder: (_, i) => ListTile(
                        leading: CircleAvatar(child: Text('$i')),
                        title: Text('Photos from the weekend $i'),
                        subtitle: const Text('Shared library · Just now'),
                      ),
                    ),
                  ),
                  LiquidNavigationBar(
                    backdrop: backdrop,
                    title: const Text('Library'),
                    leading: const Text('Back'),
                    trailing: const Icon(Icons.more_horiz),
                  ),
                  Center(
                    child: LiquidMenu(
                      backdrop: backdrop,
                      items: const [
                        LiquidMenuItem(label: 'All photos', isSelected: true),
                        LiquidMenuItem(
                          label: 'Favorites',
                          icon: Icons.favorite_border,
                        ),
                        LiquidMenuItem(
                          label: 'Delete',
                          isDestructive: true,
                          icon: Icons.delete_outline,
                        ),
                      ],
                      anchorBuilder: (_, open, toggle) => LiquidButton(
                        backdrop: backdrop,
                        onPressed: toggle,
                        children: const [Text('Options')],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Library')).dx, closeTo(195, 0.1));
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
