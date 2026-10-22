import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<SoftFloatingNavigationItem> _items = <SoftFloatingNavigationItem>[
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'A'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'B'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'C'),
];

Widget _host({
  required bool out,
  ValueChanged<int>? onSelected,
  VoidCallback? onAction,
  bool reduceMotion = false,
  bool blur = true,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: SoftThemeData.light(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SoftFloatingNavigationBar(
            items: _items,
            selectedIndex: 0,
            blur: blur,
            onSelected: onSelected ?? (_) {},
            expansion: SoftFloatingAccessory(
              icon: const SizedBox.square(dimension: 24),
              semanticLabel: 'Tap card',
              visible: out,
              onTap: onAction,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Finder _capsule() => find
    .descendant(
      of: find.byType(SoftFloatingNavigationBar),
      matching: find.byType(SoftTouchMotion),
    )
    .first;

Finder _surface() => find.byType(SoftMetaBallSurface);

/// The round view's icon, where it is drawn.
Rect _ball(WidgetTester tester) =>
    tester.getRect(find.bySemanticsLabel('Tap card'));

bool _contains(Path path, Offset p) => path.contains(p);

void main() {
  group('softMetaBallPath', () {
    SoftMetaBallParticle capsule(double right) => SoftMetaBallParticle(
      center: Offset(right - 100, 28),
      size: const Size(200, 56),
      cornerRadius: 28,
    );
    SoftMetaBallParticle ball(double x, {double scale = 1}) =>
        SoftMetaBallParticle(
          center: Offset(x, 28),
          size: Size.square(56 * scale),
        );

    test('apart, it is just the two outlines', () {
      final Path path = softMetaBallPath(<SoftMetaBallParticle>[
        capsule(200),
        ball(300),
      ], devicePixelRatio: 3);
      // The gap between them stays open.
      expect(_contains(path, const Offset(236, 28)), isFalse);
      expect(_contains(path, const Offset(100, 28)), isTrue);
      expect(_contains(path, const Offset(300, 28)), isTrue);
      expect(path.getBounds().left, closeTo(0, 0.01));
      expect(path.getBounds().right, closeTo(328, 0.01));
    });

    test('close together, a neck joins them into one body', () {
      // A gap of 2 logical px: well within the reach of the union.
      final Path path = softMetaBallPath(<SoftMetaBallParticle>[
        capsule(200),
        ball(230),
      ], devicePixelRatio: 3);
      expect(_contains(path, const Offset(201, 28)), isTrue);
      final ui.PathMetrics metrics = path.computeMetrics();
      expect(metrics.length, 1, reason: 'one closed outline');
      // The neck stays well inside the capsule's height.
      expect(path.getBounds().top, greaterThan(-1));
      expect(path.getBounds().bottom, lessThan(57));
    });

    test('a ball half inside the capsule bulges out of its end', () {
      final Path path = softMetaBallPath(<SoftMetaBallParticle>[
        capsule(200),
        ball(200, scale: 0.6),
      ], devicePixelRatio: 2.625);
      expect(_contains(path, const Offset(214, 28)), isTrue);
      expect(_contains(path, const Offset(220, 28)), isFalse);
      expect(path.computeMetrics().length, 1);
    });
  });

  group('the expansion without a captured backdrop', () {
    testWidgets('melts out through the compositor, then draws plainly', (
      tester,
    ) async {
      await _pump(tester, _host(out: false));
      expect(_surface(), findsNothing);
      final double centred = tester.getRect(_capsule()).center.dx;
      expect(centred, 200);

      await _pump(tester, _host(out: true));
      await tester.pump(const Duration(milliseconds: 48));
      // On its way out the ball and the capsule are one merged body, frosted
      // by the compositor, not a capture.
      final SoftMetaBallSurface surface = tester.widget(_surface());
      expect(surface.compositor, isTrue);
      expect(surface.backdrop, isNull);
      expect(surface.particles, hasLength(2));
      // The capsule is moving towards the start edge, not jumping there.
      final double moving = tester.getRect(_capsule()).left;
      expect(moving, inExclusiveRange(16, 200 - 125));

      await _settle(tester);
      expect(tester.getRect(_capsule()).left, 16);
      expect(_ball(tester).center.dx, closeTo(400 - 16 - 28, 0.5));
      expect(tester.takeException(), isNull);
      // Out and at rest the two are apart: the merged outline is just their
      // own outlines, nothing is traced.
      expect(tester.widget<SoftMetaBallSurface>(_surface()).compositor, isTrue);

      await _pump(tester, _host(out: false));
      await _settle(tester);
      expect(_surface(), findsNothing, reason: 'tucked away: no merged body');
      expect(tester.getRect(_capsule()).center.dx, 200);
    });

    testWidgets('reversing mid-flight carries on from where it is', (
      tester,
    ) async {
      await _pump(tester, _host(out: false));
      await _pump(tester, _host(out: true));
      // Far enough that the ball has come out past the capsule's end.
      for (int i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final double capsuleBefore = tester.getRect(_capsule()).left;
      final SoftMetaBallSurface before = tester.widget(_surface());
      final Offset ballBefore = before.particles[1].center;

      // Back in before it has settled.
      await _pump(tester, _host(out: false));
      await tester.pump(const Duration(milliseconds: 16));
      final double capsuleAfter = tester.getRect(_capsule()).left;
      final SoftMetaBallSurface after = tester.widget(_surface());
      final Offset ballAfter = after.particles[1].center;
      // One frame of motion, not a jump to either end.
      expect((capsuleAfter - capsuleBefore).abs(), lessThan(12));
      expect((ballAfter - ballBefore).distance, lessThan(12));

      // And out again, twice over.
      await _pump(tester, _host(out: true));
      await tester.pump(const Duration(milliseconds: 16));
      await _pump(tester, _host(out: false));
      await tester.pump(const Duration(milliseconds: 16));
      await _pump(tester, _host(out: true));
      await _settle(tester);
      expect(tester.getRect(_capsule()).left, 16);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduced motion it is there at once', (tester) async {
      await _pump(tester, _host(out: false, reduceMotion: true));
      await _pump(tester, _host(out: true, reduceMotion: true));
      await tester.pump();
      expect(tester.getRect(_capsule()).left, 16);
      expect(_ball(tester).center.dx, closeTo(400 - 16 - 28, 0.5));
    });

    testWidgets('opaque without blur, merged all the same', (tester) async {
      await _pump(tester, _host(out: false, blur: false));
      await _pump(tester, _host(out: true, blur: false));
      await tester.pump(const Duration(milliseconds: 48));
      final SoftMetaBallSurface surface = tester.widget(_surface());
      expect(surface.blur, isFalse);
      expect(surface.compositor, isTrue);
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its tap is its own, and it reads as a button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<int> selected = <int>[];
      int actions = 0;
      await _pump(
        tester,
        _host(out: false, onSelected: selected.add, onAction: () => actions++),
      );
      await _pump(
        tester,
        _host(out: true, onSelected: selected.add, onAction: () => actions++),
      );
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Tap card'));
      await tester.pump();
      expect(actions, 1);
      expect(selected, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tap card')),
        matchesSemantics(label: 'Tap card', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('a tucked-away view takes no taps', (tester) async {
      int actions = 0;
      await _pump(tester, _host(out: false, onAction: () => actions++));
      await tester.tapAt(const Offset(400 - 16 - 28, 800 - 16 - 28));
      await tester.pump();
      expect(actions, 0);
    });
  });
}
