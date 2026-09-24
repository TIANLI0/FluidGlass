// Drives every interaction on the four lab screens and fails on any exception
// thrown along the way.
//
// This runs on Skia, where the glass is on the `plain` tier, so it says
// nothing about what the pictures look like — only that no gesture, spring or
// timer on these screens throws. The scroll-velocity bug that shipped in the
// first build (a frame timestamp read from a pointer callback) is the kind of
// thing it is here for: it threw on every scroll update of a real drag.
import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass_example/catalog/destinations/lab_light_spill_content.dart';
import 'package:fluid_glass_example/catalog/destinations/lab_light_state_content.dart';
import 'package:fluid_glass_example/catalog/destinations/lab_morph_content.dart';
import 'package:fluid_glass_example/catalog/destinations/lab_velocity_blur_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLab(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: LiquidInkHighlight.splashFactory),
      home: Scaffold(body: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const Duration frame = Duration(milliseconds: 16);
  for (Duration t = Duration.zero; t < total; t += frame) {
    await tester.pump(frame);
  }
}

void main() {
  testWidgets('morph opens, turns round mid-flight and drags shut', (
    WidgetTester tester,
  ) async {
    await _pumpLab(tester, const LabMorphContent());

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);

    // Tap the scrim: back into the button.
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsNothing);

    // Interrupted: open, and turn it round before it lands.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await _frames(tester, const Duration(milliseconds: 120));
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsNothing);

    // Dragged back towards its anchor.
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your changes?'), findsOneWidget);
    final Offset panel = tester.getTopLeft(find.text('Keep your changes?'));
    await tester.flingFrom(
      panel + const Offset(8, 8),
      const Offset(0, 260),
      1600,
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep your changes?'), findsNothing);

    // Search opens downwards, and a row puts it away.
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Recipes'), findsNothing);

    await tester.tap(find.text('Slow ×6'));
    await tester.pump();
    await tester.tap(find.text('Slow ×6 on'));
    await tester.pumpAndSettle();
  });

  testWidgets('velocity blur survives a scroll, a drag and a fling', (
    WidgetTester tester,
  ) async {
    await _pumpLab(tester, const LabVelocityBlurContent());

    await tester.fling(find.byType(ListView), const Offset(0, -500), 2400);
    await _frames(tester, const Duration(milliseconds: 600));
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    final Finder puck = find.text('Drag\nor fling');
    await tester.drag(puck, const Offset(-160, 120));
    await tester.pumpAndSettle();
    await tester.fling(puck, const Offset(-200, -300), 3000);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LiquidToggle));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -400), 2000);
    await tester.pumpAndSettle();
  });

  testWidgets('light as state runs every state and a whole download', (
    WidgetTester tester,
  ) async {
    await _pumpLab(tester, const LabLightStateContent());

    await tester.tap(find.text('Email'));
    await _frames(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Password'));
    await _frames(tester, const Duration(milliseconds: 600));

    await tester.tap(find.text('Load'));
    await _frames(tester, const Duration(milliseconds: 900));
    // Out of loading: the sweep leaves from the comet's head.
    await tester.tap(find.text('Succeed'));
    await _frames(tester, const Duration(milliseconds: 1600));
    await tester.tap(find.text('Fail'));
    await _frames(tester, const Duration(milliseconds: 1200));

    await tester.tap(find.text('Download'));
    await _frames(tester, const Duration(seconds: 6));
    expect(find.text('Done — again?'), findsOneWidget);
    await tester.tap(find.text('Done — again?'));
    await _frames(tester, const Duration(milliseconds: 600));
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('light spill follows a held press and a dragged orb', (
    WidgetTester tester,
  ) async {
    await _pumpLab(tester, const LabLightSpillContent());

    final Offset tile = tester.getCenter(find.byIcon(Icons.wifi_rounded));
    final TestGesture press = await tester.startGesture(tile);
    await _frames(tester, const Duration(milliseconds: 300));
    await press.moveBy(const Offset(120, 140));
    await _frames(tester, const Duration(milliseconds: 300));
    await press.up();
    await tester.pumpAndSettle();

    final Finder orb = find.byWidgetPredicate(
      (Widget w) => w.runtimeType.toString() == '_Orb',
    );
    // The orb's own box has nothing to hit; the gesture detector around it
    // takes the finger, so drag from its centre and check it moved.
    final Offset before = tester.getCenter(orb);
    await tester.dragFrom(before, const Offset(-40, -300));
    await tester.pumpAndSettle();
    expect(tester.getCenter(orb), isNot(before));

    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.tap(find.byType(LiquidToggle));
    await tester.pumpAndSettle();
  });
}
