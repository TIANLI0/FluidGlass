import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A component that is rebuilt with a different configuration has to follow
// it. Several were fixed to the one they were first built with.

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

/// The narrowest glass element under [ancestor] — the pill, the thumb, the
/// knob: the one that moves.
Rect _narrowestGlass(WidgetTester tester, Finder ancestor) {
  final Iterable<Element> glass = find
      .descendant(of: ancestor, matching: find.byType(DrawBackdrop))
      .evaluate();
  Rect? narrowest;
  for (final Element element in glass) {
    final RenderBox box = element.renderObject! as RenderBox;
    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    if (narrowest == null || rect.width < narrowest.width) narrowest = rect;
  }
  return narrowest!;
}

void main() {
  testWidgets('bottom tabs follow a new tab count', (
    WidgetTester tester,
  ) async {
    Widget tabs(int count, int selected) => _host(
      SizedBox(
        width: 400,
        child: LiquidBottomTabs(
          selectedTabIndex: selected,
          onTabSelected: (_) {},
          backdrop: emptyBackdrop,
          tabsCount: count,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              LiquidBottomTab(onPressed: () {}, children: <Widget>[Text('$i')]),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tabs(3, 0));
    await tester.pumpAndSettle();

    // Tabs added after, say, sign-in; the new last one selected.
    await tester.pumpWidget(tabs(5, 4));
    await tester.pumpAndSettle();
    final Rect bar = tester.getRect(find.byType(LiquidBottomTabs));
    final Rect pill = _narrowestGlass(tester, find.byType(LiquidBottomTabs));
    expect(
      pill.center.dx,
      closeTo(bar.left + bar.width * 4.5 / 5, bar.width / 10),
      reason: 'the pill sits over the fifth tab, not the third',
    );
  });

  testWidgets('a segmented control follows a new segment count', (
    WidgetTester tester,
  ) async {
    Widget control(int count, int selected) => _host(
      SizedBox(
        width: 400,
        child: LiquidSegmentedControl(
          selectedIndex: selected,
          onSelected: (_) {},
          backdrop: emptyBackdrop,
          segments: <Widget>[for (int i = 0; i < count; i++) Text('$i')],
        ),
      ),
    );
    await tester.pumpWidget(control(3, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(control(4, 3));
    await tester.pumpAndSettle();
    final Rect bar = tester.getRect(find.byType(LiquidSegmentedControl));
    final Rect thumb = _narrowestGlass(
      tester,
      find.byType(LiquidSegmentedControl),
    );
    expect(
      thumb.center.dx,
      closeTo(bar.left + bar.width * 3.5 / 4, bar.width / 8),
      reason: 'the thumb sits over the fourth segment, not the third',
    );
  });

  // Regression: any parent rebuild during a drag found the knob away from
  // `selected` and sprang it back off the finger.
  testWidgets('a parent rebuilding mid-drag leaves the knob with the finger', (
    WidgetTester tester,
  ) async {
    // A fresh configuration every pump, as a parent on a clock gives it.
    Widget toggle() => _host(
      LiquidToggle(selected: false, onSelect: (_) {}, backdrop: emptyBackdrop),
    );
    await tester.pumpWidget(toggle());
    await tester.pumpAndSettle();
    final Finder knobArea = find.byType(LiquidToggle);
    final double restX = _narrowestGlass(tester, knobArea).center.dx;

    final TestGesture gesture = await tester.startGesture(
      _narrowestGlass(tester, knobArea).center,
    );
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(1, 0));
      await tester.pumpWidget(toggle());
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (int i = 0; i < 20; i++) {
      await tester.pumpWidget(toggle());
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      _narrowestGlass(tester, knobArea).center.dx - restX,
      greaterThan(4),
      reason: 'half-way along the drag, with the finger still down',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  // Regression: the luminance notifies on every tick of its smoothing, and the
  // caller's builder was rebuilt on every one of them for a colour that only
  // ever takes two values.
  testWidgets('the adaptive panel rebuilds its content only when it flips', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<Color> wallpaper = ValueNotifier<Color>(
      const Color(0xFF404040),
    );
    addTearDown(wallpaper.dispose);
    int builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidAdaptivePanel(
            backdrop: CanvasBackdrop(
              (Canvas canvas, Size size) => canvas.drawRect(
                Offset.zero & size,
                Paint()..color = wallpaper.value,
              ),
            ),
            repaint: wallpaper,
            interval: const Duration(milliseconds: 100),
            builder: (BuildContext context, Color content) {
              builds++;
              return const SizedBox(width: 120, height: 120);
            },
          ),
        ),
      ),
    );
    // The readback is asynchronous and native: real time has to pass for it,
    // and pumps have to run what it hands back to the test's fake zone.
    Future<void> run(int frames) async {
      for (int i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await run(150);
    final int settled = builds;

    // Darker, but still dark: the reading moves and the colour does not.
    wallpaper.value = const Color(0xFF202020);
    await run(150);
    expect(builds, settled);
  });
}
