import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a spring retargeted every frame still advances', (
    WidgetTester tester,
  ) async {
    late SpringValue spring;
    await tester.pumpWidget(
      MaterialApp(
        home: _Vsync(
          builder: (TickerProvider vsync) {
            spring = SpringValue(
              vsync: vsync,
              value: 0,
              visibilityThreshold: 0.001,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    // Retarget on every frame, as dragging does.
    for (int i = 0; i < 20; i++) {
      spring.animateTo(1, springOf(1, 1000));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      spring.value,
      greaterThan(0.5),
      reason: 'a spring retargeted each frame must keep advancing',
    );
    spring.dispose();
  });

  testWidgets('DampedDragAnimation presses and tracks a drag', (
    WidgetTester tester,
  ) async {
    late DampedDragAnimation animation;
    final List<Offset> drags = <Offset>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _Vsync(
          builder: (TickerProvider vsync) {
            animation = DampedDragAnimation(
              vsync: vsync,
              initialValue: 0,
              valueRange: (start: 0, end: 2),
              visibilityThreshold: 0.001,
              initialScale: 1,
              pressedScale: 1.4,
              onDrag: (Size size, Offset delta) {
                drags.add(delta);
                animation.updateValue(animation.targetValue + delta.dx / 100);
              },
            );
            return Center(
              child: animation.wrapGestures(
                child: const SizedBox(width: 200, height: 60),
              ),
            );
          },
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox).first),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      drags,
      isNotEmpty,
      reason: 'the pointer down must report a zero drag',
    );

    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(drags.length, greaterThan(5));
    expect(
      animation.targetValue,
      greaterThan(1.0),
      reason: 'drag must move the target',
    );
    expect(
      animation.value,
      greaterThan(0.5),
      reason: 'the value must follow the target',
    );
    expect(
      animation.pressProgress,
      greaterThan(0.5),
      reason: 'press must engage',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 2));
    animation.dispose();
  });

  testWidgets('the bottom-tabs pill follows a drag', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return LiquidBottomTabs(
                    selectedTabIndex: selected,
                    onTabSelected: (int index) =>
                        setState(() => selected = index),
                    backdrop: emptyBackdrop,
                    tabsCount: 3,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        LiquidBottomTab(
                          onPressed: () => setState(() => selected = i),
                          children: <Widget>[Text('Tab ${i + 1}')],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Grab the pill: it starts over the first tab.
    final Offset start =
        tester.getTopLeft(find.byType(LiquidBottomTabs)) + const Offset(60, 32);
    final TestGesture gesture = await tester.startGesture(start);
    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));

    expect(
      selected,
      greaterThan(0),
      reason: 'dragging the pill must change tabs',
    );
  });

  testWidgets('the bottom-tabs bar is never clipped at either end', (
    WidgetTester tester,
  ) async {
    // The panel is offset by up to 4dp of give once dragged, and the pill
    // carries a shadow and grows to 1.39x while pressed, so both paint outside
    // their boxes. A Stack clips as soon as a positioned child overflows, and
    // the pill's `left` lands on the panel's bounds exactly at either end, so
    // rounding alone decided whether the clip engaged and sheared the panel's
    // rounded cap off. Compose's Box does not clip.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  int selected = 0;
                  return LiquidBottomTabs(
                    selectedTabIndex: selected,
                    onTabSelected: (int index) =>
                        setState(() => selected = index),
                    backdrop: emptyBackdrop,
                    tabsCount: 3,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        LiquidBottomTab(
                          onPressed: () {},
                          children: <Widget>[Text('Tab ${i + 1}')],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderStack stack = tester.renderObject<RenderStack>(
      find.descendant(
        of: find.byType(LiquidBottomTabs),
        matching: find.byType(Stack),
      ),
    );

    void expectNoClip(String state) {
      expect(
        stack.clipBehavior,
        Clip.none,
        reason: 'the bar must not clip ($state)',
      );
      RenderBox? child = stack.firstChild;
      while (child != null) {
        expect(
          stack.describeApproximatePaintClip(child),
          isNull,
          reason: 'no child may be clipped ($state)',
        );
        child = (child.parentData! as StackParentData).nextSibling;
      }
    }

    expectNoClip('at rest');

    final Offset centre = tester.getCenter(find.byType(LiquidBottomTabs));
    for (final double direction in <double>[1, -1]) {
      final TestGesture gesture = await tester.startGesture(
        centre - Offset(direction * 96, 0),
      );
      for (int i = 0; i < 16; i++) {
        await gesture.moveBy(Offset(direction * 24, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Held at the end, where the panel's give is fully wound up.
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expectNoClip(
        direction > 0 ? 'held at the right end' : 'held at the left end',
      );
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('a LiquidButton still reports taps through its press handling', (
    WidgetTester tester,
  ) async {
    // Regression: the press handling must not enter the gesture arena, or it
    // wins as the innermost competitor and swallows the tap.
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidButton(
              onPressed: () => taps++,
              backdrop: emptyBackdrop,
              children: const <Widget>[Text('Tap me')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tap me'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(taps, 1);

    await tester.tap(find.text('Tap me'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(taps, 2, reason: 'a second tap must work too');

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the pill stays grabbable after it has moved', (
    WidgetTester tester,
  ) async {
    // Regression: the pill used to be painted through a transform inside a
    // one-tab-wide Padding. Flutter bounds-checks every ancestor, so once the
    // pill left the first tab it stopped receiving touches entirely — it could
    // only ever be dragged from its resting position.
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return LiquidBottomTabs(
                    selectedTabIndex: selected,
                    onTabSelected: (int index) =>
                        setState(() => selected = index),
                    backdrop: emptyBackdrop,
                    tabsCount: 3,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        LiquidBottomTab(
                          onPressed: () => setState(() => selected = i),
                          children: <Widget>[Text('Tab ${i + 1}')],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset barTopLeft = tester.getTopLeft(find.byType(LiquidBottomTabs));
    // Send the pill to the last tab.
    final TestGesture first = await tester.startGesture(
      barTopLeft + const Offset(60, 32),
    );
    for (int i = 0; i < 20; i++) {
      await first.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(selected, 2, reason: 'the drag should have reached the last tab');

    // Now grab it where it actually sits and drag it back.
    const double tabWidth = (360 - 8) / 3;
    final Offset onMovedPill =
        barTopLeft + Offset(4 + tabWidth * 2 + tabWidth / 2, 32);
    final TestGesture second = await tester.startGesture(onMovedPill);
    for (int i = 0; i < 20; i++) {
      await second.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));

    expect(
      selected,
      0,
      reason: 'the pill must respond to a drag started at its current position',
    );
  });

  testWidgets('the moved pill stays grabbable in right-to-left layouts', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return LiquidBottomTabs(
                      selectedTabIndex: selected,
                      onTabSelected: (int index) =>
                          setState(() => selected = index),
                      backdrop: emptyBackdrop,
                      tabsCount: 3,
                      children: <Widget>[
                        for (int i = 0; i < 3; i++)
                          LiquidBottomTab(
                            onPressed: () => setState(() => selected = i),
                            children: <Widget>[Text('RTL ${i + 1}')],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset barTopLeft = tester.getTopLeft(find.byType(LiquidBottomTabs));
    const double tabWidth = (360 - 8) / 3;

    // Index zero starts at the right in RTL; drag left to reach index two.
    final TestGesture first = await tester.startGesture(
      barTopLeft + Offset(4 + tabWidth * 2 + tabWidth / 2, 32),
    );
    for (int i = 0; i < 20; i++) {
      await first.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await tester.pump(const Duration(seconds: 1));
    expect(selected, 2);

    // Grab the pill at its new, leftmost position and drag it back right.
    final TestGesture second = await tester.startGesture(
      barTopLeft + Offset(4 + tabWidth / 2, 32),
    );
    for (int i = 0; i < 20; i++) {
      await second.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pump(const Duration(seconds: 1));
    expect(selected, 0);
  });
}

class _Vsync extends StatefulWidget {
  const _Vsync({required this.builder});

  final Widget Function(TickerProvider vsync) builder;

  @override
  State<_Vsync> createState() => _VsyncState();
}

class _VsyncState extends State<_Vsync> with TickerProviderStateMixin {
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    return _child ??= widget.builder(this);
  }
}
