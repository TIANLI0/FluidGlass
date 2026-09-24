import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Finder _landings = find.byWidgetPredicate(
  (Widget w) => w.runtimeType.toString() == '_LightLanding',
);

Widget _buttons({GlassLightField? field, bool scoped = true}) {
  Widget row = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      LiquidButton(
        backdrop: emptyBackdrop,
        onPressed: () {},
        children: const <Widget>[Text('A')],
      ),
      const SizedBox(width: 24),
      LiquidButton(
        backdrop: emptyBackdrop,
        onPressed: () {},
        children: const <Widget>[Text('B')],
      ),
    ],
  );
  if (scoped) row = GlassLightScope(field: field, child: row);
  return MaterialApp(home: Scaffold(body: Center(child: row)));
}

/// A spring starts its clock on its first tick, so one long pump leaves it
/// where it began: step through frames instead.
Future<void> _frames(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('outside a scope nothing is added to the glass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buttons(scoped: false));
    expect(_landings, findsNothing);
  });

  testWidgets('inside a scope every glass element can be lit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buttons());
    expect(_landings, findsNWidgets(2));
  });

  testWidgets('a press is a light at the finger, and goes out after', (
    WidgetTester tester,
  ) async {
    final GlassLightField field = GlassLightField();
    addTearDown(field.dispose);
    await tester.pumpWidget(_buttons(field: field));
    expect(field.lights, isEmpty);

    final Offset at = tester.getCenter(find.text('A')) + const Offset(6, 3);
    final TestGesture gesture = await tester.startGesture(at);
    await _frames(tester, 12);
    final List<GlassLight> lit = field.lights.toList();
    expect(lit, hasLength(1));
    // In global coordinates, where the glow is drawn: at the finger, moved by
    // the fraction of a pixel the pressed button's deformation shifts it.
    expect(lit.single.position.dx, closeTo(at.dx, 2));
    expect(lit.single.position.dy, closeTo(at.dy, 2));
    expect(lit.single.strength, greaterThan(0.5));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(field.lights, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the light takes the theme\'s glow colour', (
    WidgetTester tester,
  ) async {
    final GlassLightField field = GlassLightField();
    addTearDown(field.dispose);
    const Color tint = Color(0xFFFFC0E0);
    await tester.pumpWidget(
      LiquidGlassTheme(
        colors: LiquidGlassColors.light.copyWith(glow: tint),
        child: _buttons(field: field),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('B')),
    );
    await _frames(tester, 12);
    expect(field.lights.single.color, tint);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a moving light repaints the light, not the glass', (
    WidgetTester tester,
  ) async {
    final GlassLightField field = GlassLightField();
    addTearDown(field.dispose);
    await tester.pumpWidget(_buttons(field: field));
    final List<RenderObject> glass = tester
        .renderObjectList(find.byType(DrawBackdrop))
        .toList();
    final RenderObject other = tester.renderObject(
      find.ancestor(of: find.text('B'), matching: find.byType(DrawBackdrop)),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('A')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // The neighbour's glass is untouched while its light repaints.
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(other.debugNeedsPaint, isFalse);
    }
    expect(glass, hasLength(2));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
