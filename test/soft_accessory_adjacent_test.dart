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
  required double width,
  SoftFloatingAccessoryPlacement placement =
      SoftFloatingAccessoryPlacement.adjacentCentered,
}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: SoftThemeData.light(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SoftFloatingNavigationBar(
            items: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            accessoryPlacement: placement,
            expansion: SoftFloatingAccessory(
              icon: const SizedBox.square(dimension: 24),
              semanticLabel: 'Share',
              visible: out,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget, double width) async {
  tester.view.physicalSize = Size(width, 800);
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

Rect _ball(WidgetTester tester) =>
    tester.getRect(find.bySemanticsLabel('Share'));

void main() {
  const double gap = SoftFloatingNavigationBarDefaults.sideSpacing;
  const double ball = SoftFloatingNavigationBarDefaults.accessorySize;

  for (final double width in <double>[360, 411]) {
    testWidgets(
      'adjacentCentered @ $width: capsule + 12 + round view centred',
      (WidgetTester tester) async {
        await _pump(tester, _host(out: false, width: width), width);
        await _settle(tester);
        final Rect alone = tester.getRect(_capsule());
        // Without the round view the capsule is centred at its full width.
        expect(alone.center.dx, closeTo(width / 2, 0.5));

        await _pump(tester, _host(out: true, width: width), width);
        await _settle(tester);
        final Rect capsule = tester.getRect(_capsule());
        final Rect icon = _ball(tester);
        // Narrower while the round view is out.
        expect(capsule.width, lessThan(alone.width));
        // The round view sits 12 from the capsule's end.
        final double ballLeft = icon.center.dx - ball / 2;
        expect(ballLeft - capsule.right, closeTo(gap, 0.5));
        // The group is centred.
        final double groupLeft = capsule.left;
        final double groupRight = ballLeft + ball;
        expect((groupLeft + groupRight) / 2, closeTo(width / 2, 0.5));

        // Back in: full width, centred again.
        await _pump(tester, _host(out: false, width: width), width);
        await _settle(tester);
        final Rect back = tester.getRect(_capsule());
        expect(back.width, closeTo(alone.width, 0.5));
        expect(back.center.dx, closeTo(width / 2, 0.5));
      },
    );

    testWidgets('adjacentCapsuleCentered @ $width: centre never moves', (
      WidgetTester tester,
    ) async {
      const SoftFloatingAccessoryPlacement p =
          SoftFloatingAccessoryPlacement.adjacentCapsuleCentered;
      await _pump(tester, _host(out: false, width: width, placement: p), width);
      await _settle(tester);
      final Rect alone = tester.getRect(_capsule());
      expect(alone.center.dx, closeTo(width / 2, 0.5));
      await _pump(tester, _host(out: true, width: width, placement: p), width);
      await _settle(tester);
      final Rect capsule = tester.getRect(_capsule());
      final double ballLeft = _ball(tester).center.dx - ball / 2;
      expect(capsule.center.dx, closeTo(width / 2, 0.5));
      expect(ballLeft - capsule.right, closeTo(gap, 0.5));
      // Narrowed just enough (or not at all) to keep the round view inside.
      const double pad =
          SoftFloatingNavigationBarDefaults.adjacentPaddingHorizontal;
      final double inner = width - 2 * pad;
      final double fits = inner - 2 * (gap + ball);
      expect(
        capsule.width,
        closeTo(alone.width < fits ? alone.width : fits, 1),
      );
      expect(ballLeft + ball, lessThanOrEqualTo(width - pad + 0.5));
    });
  }

  testWidgets('adjacentCapsuleCentered, wide enough: no narrowing at all', (
    WidgetTester tester,
  ) async {
    // 520 is still compact; 3 items need 250 and 520-32-136 = 352 fits.
    const double width = 520;
    const SoftFloatingAccessoryPlacement p =
        SoftFloatingAccessoryPlacement.adjacentCapsuleCentered;
    await _pump(tester, _host(out: false, width: width, placement: p), width);
    await _settle(tester);
    final Rect alone = tester.getRect(_capsule());
    await _pump(tester, _host(out: true, width: width, placement: p), width);
    await _settle(tester);
    expect(tester.getRect(_capsule()), alone);
  });

  testWidgets(
    'adjacentCapsuleCentered: start and end views sit symmetrically',
    (WidgetTester tester) async {
      const double width = 411;
      tester.view.physicalSize = const Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(width, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SoftTheme(
              data: SoftThemeData.light(),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SoftFloatingNavigationBar(
                  items: _items,
                  selectedIndex: 0,
                  onSelected: (_) {},
                  accessoryPlacement:
                      SoftFloatingAccessoryPlacement.adjacentCapsuleCentered,
                  start: SoftFloatingAccessory(
                    icon: const SizedBox.square(dimension: 24),
                    semanticLabel: 'L',
                    onTap: () {},
                  ),
                  end: SoftFloatingAccessory(
                    icon: const SizedBox.square(dimension: 24),
                    semanticLabel: 'R',
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final Rect capsule = tester.getRect(_capsule());
      final double l = tester.getRect(find.bySemanticsLabel('L')).center.dx;
      final double r = tester.getRect(find.bySemanticsLabel('R')).center.dx;
      expect(capsule.center.dx, closeTo(width / 2, 0.5));
      expect((l + r) / 2, closeTo(width / 2, 0.5));
      expect(capsule.left - (l + ball / 2), closeTo(gap, 0.5));
      expect((r - ball / 2) - capsule.right, closeTo(gap, 0.5));
    },
  );

  testWidgets('edge stays the default: round view at the bar edge', (
    WidgetTester tester,
  ) async {
    const double width = 360;
    await _pump(
      tester,
      _host(
        out: true,
        width: width,
        placement: SoftFloatingAccessoryPlacement.edge,
      ),
      width,
    );
    await _settle(tester);
    final Rect icon = _ball(tester);
    final double ballRight = icon.center.dx + ball / 2;
    expect(
      ballRight,
      closeTo(width - SoftFloatingNavigationBarDefaults.paddingHorizontal, 0.5),
    );
  });

  for (final double width in <double>[600, 800, 1024]) {
    for (final SoftFloatingAccessoryPlacement p
        in <SoftFloatingAccessoryPlacement>[
          SoftFloatingAccessoryPlacement.adjacentCentered,
          SoftFloatingAccessoryPlacement.adjacentCapsuleCentered,
        ]) {
      testWidgets('${p.name} @ $width: content-wide capsule, view inside', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          _host(out: true, width: width, placement: p),
          width,
        );
        await _settle(tester);
        final Rect capsule = tester.getRect(_capsule());
        final Rect icon = _ball(tester);
        final double ballLeft = icon.center.dx - ball / 2;
        // No large-screen fill: three items at their 70 cap (or the
        // adjacent cap while the view is out).
        expect(capsule.width, lessThanOrEqualTo(3 * 70 + 2 * 8 + 2 * 12 + 0.5));
        expect(ballLeft - capsule.right, closeTo(gap, 0.5));
        expect(ballLeft + ball, lessThanOrEqualTo(width));
        if (p == SoftFloatingAccessoryPlacement.adjacentCapsuleCentered) {
          expect(capsule.center.dx, closeTo(width / 2, 0.5));
        } else {
          expect((capsule.left + ballLeft + ball) / 2, closeTo(width / 2, 0.5));
        }
      });
    }
  }

  for (final SoftFloatingAccessoryPlacement p
      in <SoftFloatingAccessoryPlacement>[
        SoftFloatingAccessoryPlacement.adjacentCentered,
        SoftFloatingAccessoryPlacement.adjacentCapsuleCentered,
      ]) {
    for (final bool out in <bool>[true, false]) {
      testWidgets('${p.name} ${out ? 'out' : 'in'}: no frame jumps', (
        WidgetTester tester,
      ) async {
        const double width = 360;
        await _pump(
          tester,
          _host(out: !out, width: width, placement: p),
          width,
        );
        await _settle(tester);
        await _pump(tester, _host(out: out, width: width, placement: p), width);
        Rect previous = tester.getRect(_capsule());
        for (int i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final Rect now = tester.getRect(_capsule());
          // A spring moves a few pixels a frame; a jump is tens.
          expect((now.left - previous.left).abs(), lessThan(8), reason: '$i');
          expect((now.width - previous.width).abs(), lessThan(8), reason: '$i');
          previous = now;
        }
      });
    }
  }

  Widget sides({required bool out, required double width}) => MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: SoftThemeData.light(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SoftFloatingNavigationBar(
            items: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            accessoryPlacement:
                SoftFloatingAccessoryPlacement.adjacentCapsuleCentered,
            start: SoftFloatingAccessory(
              icon: const SizedBox.square(dimension: 24),
              semanticLabel: 'L',
              visible: out,
              onTap: () {},
            ),
            end: SoftFloatingAccessory(
              icon: const SizedBox.square(dimension: 24),
              semanticLabel: 'R',
              visible: out,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );

  for (final double width in <double>[360, 411]) {
    testWidgets('both sides out @ $width: symmetric, centre fixed', (
      WidgetTester tester,
    ) async {
      await _pump(tester, sides(out: false, width: width), width);
      await _settle(tester);
      final Rect alone = tester.getRect(_capsule());
      expect(alone.center.dx, closeTo(width / 2, 0.5));
      await _pump(tester, sides(out: true, width: width), width);
      await _settle(tester);
      final Rect capsule = tester.getRect(_capsule());
      expect(capsule.center.dx, closeTo(width / 2, 0.5));
      final double l = tester.getRect(find.bySemanticsLabel('L')).center.dx;
      final double r = tester.getRect(find.bySemanticsLabel('R')).center.dx;
      expect(capsule.left - (l + ball / 2), closeTo(gap, 0.5));
      expect((r - ball / 2) - capsule.right, closeTo(gap, 0.5));
      const double pad =
          SoftFloatingNavigationBarDefaults.adjacentPaddingHorizontal;
      expect(l - ball / 2, greaterThanOrEqualTo(pad - 0.5));
      // Back in: the capsule widens back to where it was.
      await _pump(tester, sides(out: false, width: width), width);
      await _settle(tester);
      expect(tester.getRect(_capsule()).width, closeTo(alone.width, 0.5));
    });
  }

  for (final bool out in <bool>[true, false]) {
    testWidgets('both sides ${out ? 'out' : 'in'}: no frame jumps', (
      WidgetTester tester,
    ) async {
      const double width = 360;
      await _pump(tester, sides(out: !out, width: width), width);
      await _settle(tester);
      await _pump(tester, sides(out: out, width: width), width);
      Rect previous = tester.getRect(_capsule());
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final Rect now = tester.getRect(_capsule());
        expect((now.left - previous.left).abs(), lessThan(8), reason: '$i');
        expect((now.width - previous.width).abs(), lessThan(8), reason: '$i');
        expect(now.center.dx, closeTo(width / 2, 0.5), reason: '$i');
        previous = now;
      }
    });
  }

  // The views rest beside the capsule's *moving* ends. Resting them beside
  // the target capsule threw them outwards on the first frame of melting in
  // wherever the capsule had narrowed: the target widened at once, the
  // capsule only by spring, so each view leapt by half the difference.
  for (final double width in <double>[320, 360]) {
    for (final bool out in <bool>[true, false]) {
      testWidgets(
        'both sides ${out ? 'out' : 'in'} @ $width: the views do not jump',
        (WidgetTester tester) async {
          double? centre(String label) {
            final Finder f = find.bySemanticsLabel(label);
            return f.evaluate().isEmpty ? null : tester.getRect(f).center.dx;
          }

          await _pump(tester, sides(out: !out, width: width), width);
          await _settle(tester);
          // Measured before the change: the leap was on the very frame the
          // views turned in.
          double? l = centre('L');
          double? r = centre('R');
          await _pump(tester, sides(out: out, width: width), width);
          for (int i = 0; i < 60; i++) {
            final double? nl = centre('L');
            final double? nr = centre('R');
            if (l != null && nl != null) {
              expect((nl - l).abs(), lessThan(8), reason: 'L $i');
              // Melting in only ever moves a view inwards.
              if (!out) expect(nl, greaterThanOrEqualTo(l - 0.01));
            }
            if (r != null && nr != null) {
              expect((nr - r).abs(), lessThan(8), reason: 'R $i');
              if (!out) expect(nr, lessThanOrEqualTo(r + 0.01));
            }
            l = nl;
            r = nr;
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
      );
    }
  }

  testWidgets('both sides out @ 411: the capsule does not move or narrow', (
    WidgetTester tester,
  ) async {
    const double width = 411;
    await _pump(tester, sides(out: false, width: width), width);
    await _settle(tester);
    final Rect alone = tester.getRect(_capsule());
    await _pump(tester, sides(out: true, width: width), width);
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final Rect now = tester.getRect(_capsule());
      expect(now.left, closeTo(alone.left, 0.5), reason: '$i');
      expect(now.width, closeTo(alone.width, 0.5), reason: '$i');
    }
  });

  testWidgets(
    'both sides out where they cannot fit: narrows about the centre',
    (WidgetTester tester) async {
      const double width = 320;
      await _pump(tester, sides(out: false, width: width), width);
      await _settle(tester);
      final Rect alone = tester.getRect(_capsule());
      await _pump(tester, sides(out: true, width: width), width);
      await _settle(tester);
      final Rect capsule = tester.getRect(_capsule());
      expect(capsule.width, lessThan(alone.width - 1));
      expect(capsule.center.dx, closeTo(width / 2, 0.5));
      const double pad =
          SoftFloatingNavigationBarDefaults.adjacentPaddingHorizontal;
      final double l = tester.getRect(find.bySemanticsLabel('L')).center.dx;
      final double r = tester.getRect(find.bySemanticsLabel('R')).center.dx;
      expect(l - ball / 2, closeTo(pad, 0.5));
      expect(r + ball / 2, closeTo(width - pad, 0.5));
    },
  );
}
