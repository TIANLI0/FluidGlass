import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// With the platform asking for reduced motion, a control moving to a value on
// its own lands there at once instead of springing across.

Widget _host(Widget child, {bool reduce = true}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The narrowest glass under [of]: the knob or thumb that moves.
double _glassX(WidgetTester tester, Type of) {
  double? x;
  double? width;
  for (final Element element
      in find
          .descendant(of: find.byType(of), matching: find.byType(DrawBackdrop))
          .evaluate()) {
    final RenderBox box = element.renderObject! as RenderBox;
    if (width == null || box.size.width < width) {
      width = box.size.width;
      x = box.localToGlobal(box.size.center(Offset.zero)).dx;
    }
  }
  return x!;
}

Future<int> _framesUntilIdle(WidgetTester tester) async {
  int frames = 0;
  while (tester.binding.hasScheduledFrame && frames < 300) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  return frames;
}

void main() {
  for (final bool reduce in <bool>[true, false]) {
    testWidgets('a toggle set by its caller, reduce motion $reduce', (
      WidgetTester tester,
    ) async {
      Widget toggle(bool on) => _host(
        LiquidToggle(selected: on, onSelect: (_) {}, backdrop: emptyBackdrop),
        reduce: reduce,
      );
      await tester.pumpWidget(toggle(false));
      await tester.pumpAndSettle();
      final double off = _glassX(tester, LiquidToggle);
      await tester.pumpWidget(toggle(true));
      await tester.pumpAndSettle();
      final double on = _glassX(tester, LiquidToggle);

      await tester.pumpWidget(toggle(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(toggle(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final double firstFrame = _glassX(tester, LiquidToggle);
      if (reduce) {
        expect(firstFrame, closeTo(on, 0.5), reason: 'there at once');
        expect(await _framesUntilIdle(tester), lessThan(3));
      } else {
        expect(firstFrame, lessThan(on - 1), reason: 'still springing');
        expect(firstFrame, greaterThan(off - 1));
      }
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a segmented control set by its caller jumps', (
    WidgetTester tester,
  ) async {
    Widget control(int selected) => _host(
      SizedBox(
        width: 300,
        child: LiquidSegmentedControl(
          selectedIndex: selected,
          onSelected: (_) {},
          backdrop: emptyBackdrop,
          segments: const <Widget>[Text('A'), Text('B'), Text('C')],
        ),
      ),
    );
    await tester.pumpWidget(control(2));
    await tester.pumpAndSettle();
    final double last = _glassX(tester, LiquidSegmentedControl);
    await tester.pumpWidget(control(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(control(2));
    await tester.pump();
    expect(_glassX(tester, LiquidSegmentedControl), closeTo(last, 0.5));
    expect(await _framesUntilIdle(tester), lessThan(3));
  });

  testWidgets('a slider set by its caller jumps', (WidgetTester tester) async {
    Widget slider(double value) => _host(
      SizedBox(
        width: 300,
        child: LiquidSlider(
          value: value,
          valueRange: (start: 0, end: 1),
          visibilityThreshold: 0.001,
          backdrop: emptyBackdrop,
          onValueChanged: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(slider(0.9));
    await tester.pumpAndSettle();
    final double high = _glassX(tester, LiquidSlider);
    await tester.pumpWidget(slider(0.1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(slider(0.9));
    await tester.pump();
    expect(_glassX(tester, LiquidSlider), closeTo(high, 0.5));
    expect(await _framesUntilIdle(tester), lessThan(3));
  });
}
