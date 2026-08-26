import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/catalog/components/liquid_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required List<LiquidMenuItem> items,
  LiquidMenuSide side = LiquidMenuSide.below,
  Alignment alignment = Alignment.topLeft,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: LiquidMenu(
          backdrop: emptyBackdrop,
          side: side,
          alignment: alignment,
          items: items,
          anchorBuilder:
              (BuildContext context, bool isOpen, VoidCallback toggle) {
            return GestureDetector(
              onTap: toggle,
              child: SizedBox(
                width: 120,
                height: 48,
                child: Center(child: Text(isOpen ? 'Open' : 'Closed')),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the menu opens, reports a selection and closes',
      (WidgetTester tester) async {
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      _host(
        items: <LiquidMenuItem>[
          LiquidMenuItem(label: 'One', onSelected: () => picked.add('One')),
          LiquidMenuItem(label: 'Two', onSelected: () => picked.add('Two')),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('One'), findsNothing,
        reason: 'the panel must not be mounted while closed');

    await tester.tap(find.text('Closed'));
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);

    // Let the opening spring settle so the rows accept taps.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(picked, <String>['Two']);

    // The panel animates away, then unmounts.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Two'), findsNothing);
    expect(find.text('Closed'), findsOneWidget);
  });

  testWidgets('a row cannot be hit while the panel is still flying open',
      (WidgetTester tester) async {
    // The panel is scaled up by its layerBlock as it opens, so a row sits
    // somewhere other than where it is laid out until the spring has mostly
    // run. Accepting a tap before then would select the wrong row.
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      _host(
        items: <LiquidMenuItem>[
          LiquidMenuItem(label: 'One', onSelected: () => picked.add('One')),
          LiquidMenuItem(label: 'Two', onSelected: () => picked.add('Two')),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Closed'));
    // One frame in: the panel exists but is barely open.
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.text('One'), warnIfMissed: false);
    await tester.pump();
    expect(picked, isEmpty, reason: 'taps must be ignored until mostly open');

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping outside closes the menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        items: const <LiquidMenuItem>[
          LiquidMenuItem(label: 'One'),
          LiquidMenuItem(label: 'Two'),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Closed'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('One'), findsOneWidget);

    // The barrier fills the overlay, so a tap far from the panel hits it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('One'), findsNothing);
    expect(find.text('Closed'), findsOneWidget);
  });

  testWidgets('rapidly toggling the anchor never eats a tap',
      (WidgetTester tester) async {
    // Regression: the outside-tap barrier used to stay interactive for the
    // whole closing spring (~450ms), so the tap meant to reopen the menu hit
    // the barrier instead — quick toggling made the menu pop open and shut
    // out of step with the finger. The barrier now dismisses on pointer-down
    // and stops intercepting the moment the menu starts closing.
    await tester.pumpWidget(
      _host(
        items: const <LiquidMenuItem>[
          LiquidMenuItem(label: 'One'),
          LiquidMenuItem(label: 'Two'),
        ],
      ),
    );
    await tester.pump();

    // Open.
    await tester.tap(find.text('Closed'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open'), findsOneWidget);

    // Tap the anchor while open: the barrier covers it, so this dismisses.
    await tester.tap(find.text('Open'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Closed'), findsOneWidget);

    // Tap it again immediately, mid-closing-spring: this must REOPEN, not be
    // swallowed by a lingering barrier.
    await tester.tap(find.text('Closed'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Open'), findsOneWidget,
        reason: 'a tap during the closing animation must reach the anchor');

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('One'), findsOneWidget,
        reason: 'the reopened menu must stay open');
  });

  testWidgets('reopening during the closing spring never remounts the panel',
      (WidgetTester tester) async {
    // Regression: _show() used to call OverlayPortalController.show()
    // unconditionally. show() assigns a fresh z-order slot even when the
    // portal is already showing, which re-grafts the overlay child — the
    // panel flashed and its bloom replayed every time the menu was reopened
    // while the closing spring still ran. The portal must be left alone and
    // the spring simply retargeted.
    await tester.pumpWidget(
      _host(
        items: const <LiquidMenuItem>[
          LiquidMenuItem(label: 'One'),
          LiquidMenuItem(label: 'Two'),
        ],
      ),
    );
    await tester.pump();

    // Open fully. The extra zero-duration pump matters: a ticker's first tick
    // only starts its clock, so a single long pump would leave the spring at
    // t = 0.
    await tester.tap(find.text('Closed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final Element panelBefore = tester.element(find.text('One'));

    // Close, then reopen immediately, mid-spring.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Closed'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final Element panelAfter = tester.element(find.text('One'));
    expect(identical(panelBefore, panelAfter), isTrue,
        reason: 'the overlay child must survive a reopen — a remount is what '
            'made the bloom flash and replay');

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('an upward menu lays out above its anchor',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        side: LiquidMenuSide.above,
        alignment: Alignment.topRight,
        items: const <LiquidMenuItem>[
          LiquidMenuItem(label: 'One'),
          LiquidMenuItem(label: 'Two'),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Closed'));
    await tester.pump(const Duration(milliseconds: 400));

    final Rect anchor = tester.getRect(find.text('Open'));
    final Rect row = tester.getRect(find.text('One'));
    expect(row.bottom, lessThanOrEqualTo(anchor.top),
        reason: 'the panel must sit above the anchor');

    await tester.pump(const Duration(seconds: 1));
  });
}
