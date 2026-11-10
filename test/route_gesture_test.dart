import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The iOS edge swipe is a recogniser in Flutter's own arena, not a system
/// gesture: nothing sends a pointer cancel when it takes the finger, and the
/// page — with every control on it — travels under that finger. A control that
/// commits from raw pointers has to notice for itself.
void main() {
  /// Pushes [page] over a home route, on a platform whose default transition
  /// carries the edge swipe.
  Future<void> push(WidgetTester tester, Widget page) async {
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => Scaffold(body: page)),
    );
    await tester.pumpAndSettle();
  }

  /// Down inside the edge strip at height [y], [travel] to the right, lift.
  Future<void> edgeSwipe(
    WidgetTester tester, {
    required double y,
    required double travel,
    double x = 5,
  }) async {
    final TestGesture swipe = await tester.startGesture(Offset(x, y));
    await tester.pump();
    for (int i = 0; i < 4; i++) {
      await swipe.moveBy(Offset(travel / 4, 0));
      await tester.pump();
    }
    await swipe.up();
    await tester.pumpAndSettle();
  }

  Widget cell(VoidCallback onTap) => LiquidInteraction(
    onTap: onTap,
    child: const SizedBox.square(dimension: 80),
  );

  testWidgets('a group member under an edge swipe does not fire', (
    tester,
  ) async {
    int taps = 0;
    await push(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: LiquidInteractionGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[cell(() => taps++), cell(() => taps++)],
          ),
        ),
      ),
    );

    // Sprung back: the page returns with the finger still over the member.
    await edgeSwipe(tester, y: 40, travel: 120);
    expect(find.text('home'), findsNothing);
    expect(taps, 0);

    // Carried through: the page leaves, and takes the press with it.
    await edgeSwipe(tester, y: 40, travel: 600);
    expect(find.text('home'), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets('a lone control under an edge swipe does not fire', (
    tester,
  ) async {
    int taps = 0;
    await push(
      tester,
      Align(alignment: Alignment.topLeft, child: cell(() => taps++)),
    );
    // Short enough to lift inside the control's own bounds.
    await edgeSwipe(tester, y: 40, travel: 40);
    expect(taps, 0);
  });

  testWidgets('a button under an edge swipe does not fire', (tester) async {
    int taps = 0;
    await push(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: LiquidButton(
          backdrop: emptyBackdrop,
          onPressed: () => taps++,
          children: const <Widget>[SizedBox(width: 120, height: 24)],
        ),
      ),
    );
    await edgeSwipe(tester, y: 20, travel: 40);
    expect(taps, 0);
  });

  testWidgets('a navigation bar under an edge swipe fires no island', (
    tester,
  ) async {
    int back = 0;
    int title = 0;
    await push(
      tester,
      Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LiquidNavigationBar(
              backdrop: emptyBackdrop,
              includeTopPadding: false,
              title: const Text('Title'),
              onTitlePressed: () => title++,
              leading: LiquidNavigationAction(
                backdrop: emptyBackdrop,
                icon: Icons.arrow_back,
                label: 'Back',
                onPressed: () => back++,
              ),
            ),
          ),
        ],
      ),
    );
    final Offset island = tester.getCenter(find.byIcon(Icons.arrow_back));

    // The leading island starts 16 in; the edge strip is 20 wide. Lifting
    // while still over the island it went down on…
    await edgeSwipe(tester, x: 18, y: island.dy, travel: 30);
    expect(back, 0);

    // …and after the finger has reached where the title island was drawn when
    // it went down.
    await edgeSwipe(tester, x: 18, y: island.dy, travel: 380);
    expect(back, 0);
    expect(title, 0);
  });

  testWidgets('a tap inside the edge strip still fires', (tester) async {
    int taps = 0;
    int back = 0;
    await push(
      tester,
      Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LiquidNavigationBar(
              backdrop: emptyBackdrop,
              includeTopPadding: false,
              title: const Text('Title'),
              leading: LiquidNavigationAction(
                backdrop: emptyBackdrop,
                icon: Icons.arrow_back,
                label: 'Back',
                onPressed: () => back++,
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 0,
            child: LiquidInteractionGroup(child: cell(() => taps++)),
          ),
        ],
      ),
    );
    // With nothing else in the arena the swipe recogniser wins the pointer the
    // moment it goes down, so the route gesture is "in progress" for a plain
    // tap too. It has not moved the page; the press is still the control's.
    await tester.tapAt(const Offset(10, 240));
    await tester.pumpAndSettle();
    expect(taps, 1);

    final Offset island = tester.getCenter(find.byIcon(Icons.arrow_back));
    await tester.tapAt(Offset(18, island.dy));
    await tester.pumpAndSettle();
    expect(back, 1);
    expect(find.text('home'), findsNothing);
  });
}
