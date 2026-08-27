import 'package:fluid_glass/fluid_glass.dart';
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
    // Not a geometry guard — `RenderGlassTransform` inverts its own matrix
    // when hit-testing, so a row is always live exactly where it is drawn.
    // It is an intent guard: a panel that has been on screen for one frame,
    // barely visible and still flying into place, is not something the finger
    // can have been aiming at.
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


  testWidgets('a row on a closing panel is dead to taps',
      (WidgetTester tester) async {
    // The panel keeps its full-size hit box for as long as the closing spring
    // runs, and the barrier stops intercepting the moment the close starts —
    // so a tap aimed at whatever the menu was covering used to land on a row
    // and select it, from a menu that was visibly going away.
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dismiss, then tap a row while it is still on screen animating away.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('One'), findsOneWidget,
        reason: 'the panel should still be mounted, animating out');

    await tester.tap(find.text('One'), warnIfMissed: false);
    await tester.pump();
    expect(picked, isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('one tap switches from one menu to another',
      (WidgetTester tester) async {
    // The dismiss barrier is opaque, so the tap that closes menu A never
    // reached menu B's anchor and switching cost two taps. The barrier now
    // resolves a press on a sibling anchor itself.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            // Far enough apart that A's open panel does not cover B's anchor —
            // otherwise the tap lands on a row, not on the barrier.
            spacing: 140,
            children: <Widget>[
              for (final String tag in <String>['A', 'B'])
                LiquidMenu(
                  backdrop: emptyBackdrop,
                  items: <LiquidMenuItem>[LiquidMenuItem(label: 'row $tag')],
                  anchorBuilder: (
                    BuildContext context,
                    bool isOpen,
                    VoidCallback toggle,
                  ) {
                    return GestureDetector(
                      onTap: toggle,
                      child: SizedBox(
                        width: 120,
                        height: 48,
                        child: Center(
                          child: Text('$tag ${isOpen ? "open" : "shut"}'),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('A shut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('A open'), findsOneWidget);

    // One tap on B's anchor, while A is open.
    await tester.tap(find.text('B shut'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('B open'), findsOneWidget,
        reason: 'the tap that dismissed A must also open B');
    expect(find.text('A shut'), findsOneWidget);
    expect(find.text('row B'), findsOneWidget);
    expect(find.text('row A'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
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
