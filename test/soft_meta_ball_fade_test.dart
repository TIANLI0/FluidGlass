import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<SoftFloatingNavigationItem> _items = <SoftFloatingNavigationItem>[
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'A'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'B'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'C'),
];

Widget _frame(Widget child, {double width = 400}) => MediaQuery(
  data: MediaQueryData(size: Size(width, 800), devicePixelRatio: 3),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SoftTheme(data: SoftThemeData.light(), child: child),
  ),
);

/// A capsule-centred bar with a round view at either end, as an app shows
/// them on one tab and tucks them away on the others.
Widget _bar({required bool out, required int index, required double width}) {
  SoftFloatingAccessory view(String label) => SoftFloatingAccessory(
    icon: const SizedBox.square(dimension: 24),
    semanticLabel: label,
    visible: out,
    onTap: () {},
  );
  return _frame(
    Align(
      alignment: Alignment.bottomCenter,
      child: SoftFloatingNavigationBar(
        items: _items,
        selectedIndex: index,
        onSelected: (_) {},
        accessoryPlacement:
            SoftFloatingAccessoryPlacement.adjacentCapsuleCentered,
        start: view('Start'),
        end: view('End'),
      ),
    ),
    width: width,
  );
}

/// The capsule and two round views half melted into its ends, fading: a
/// frame from a field crash ("Path.combine() failed"), every value finite.
const List<SoftMetaBallParticle> _melting = <SoftMetaBallParticle>[
  SoftMetaBallParticle(
    center: Offset(188.49999999999983, 28),
    size: Size(247.44623692437023, 56),
    cornerRadius: 28,
  ),
  SoftMetaBallParticle(
    center: Offset(73.47683645605778, 28),
    size: Size.square(36),
    alpha: 0.5166691712087192,
  ),
  SoftMetaBallParticle(
    center: Offset(303.5231635439419, 28),
    size: Size.square(36),
    alpha: 0.5166691712087186,
  ),
];

void main() {
  group('a fading round view over the capsule', () {
    // The fading part of the body is the merged outline less the opaque
    // capsule. The two outlines run along each other for most of their
    // length, and taking one from the other with Path.combine threw on
    // device as the views melted in and out on a tab switch.
    testWidgets('builds the frame that crashed', (tester) async {
      await tester.pumpWidget(
        _frame(
          const SoftMetaBallSurface(particles: _melting, compositor: true),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('frosts only what the views add to the capsule', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          const SoftMetaBallSurface(particles: _melting, compositor: true),
        ),
      );
      // The fading frost is the one drawn at the views' opacity.
      final Finder fading = find.byWidgetPredicate(
        (Widget w) =>
            w is Opacity && (w.opacity - _melting[1].alpha).abs() < 1e-9,
      );
      expect(fading, findsOneWidget);
      final RenderBox box = tester.renderObject(fading);
      bool frosted(Offset p) => tester
          .widgetList<ClipPath>(
            find.descendant(of: fading, matching: find.byType(ClipPath)),
          )
          .every((ClipPath c) => c.clipper!.getClip(box.size).contains(p));
      // Where the start view sticks out past the capsule's end.
      expect(frosted(const Offset(60, 28)), isTrue);
      // Inside the capsule, which the opaque body already frosts.
      expect(frosted(const Offset(188, 28)), isFalse);
      expect(frosted(const Offset(100, 10)), isFalse);
      // Clear of everything.
      expect(frosted(const Offset(40, 28)), isFalse);
    });

    // Tab switches faster than the views settle: they reverse mid-melt,
    // over and over, at whatever frame the switch lands on.
    for (final double width in <double>[393, 402, 430]) {
      testWidgets('survives switching tabs mid-melt @ $width', (tester) async {
        tester.view.physicalSize = Size(width * 3, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final math.Random random = math.Random(width.toInt());
        bool out = false;
        await tester.pumpWidget(_bar(out: out, index: 0, width: width));
        for (int round = 0; round < 40; round++) {
          out = !out;
          final int index = out ? 1 : (random.nextBool() ? 0 : 2);
          await tester.pumpWidget(_bar(out: out, index: index, width: width));
          final int frames = 1 + random.nextInt(40);
          for (int f = 0; f < frames; f++) {
            await tester.pump(Duration(milliseconds: 8 + random.nextInt(10)));
            expect(tester.takeException(), isNull, reason: 'round $round #$f');
          }
        }
      });
    }
  });
}
