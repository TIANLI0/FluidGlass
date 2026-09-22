import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The press glow on an ordinary Material control lasts exactly as long as the
/// finger does — the behaviour the glass controls have always had, and the
/// whole reason this splash factory exists.
///
/// The ink features paint into the enclosing `Material`, so what these tests
/// look at is whether that render object is still drawing a glow.
void main() {
  Widget app({VoidCallback? onTap, bool inList = false}) {
    final Widget tile = ListTile(
      key: const Key('tile'),
      title: const Text('Row'),
      onTap: onTap ?? () {},
    );
    return MaterialApp(
      theme: ThemeData(
        splashFactory: LiquidInkHighlight.splashFactory,
        splashColor: const Color(0x33FF0000),
        highlightColor: Colors.transparent,
      ),
      home: Scaffold(
        body: inList
            ? ListView(
                children: <Widget>[
                  const SizedBox(height: 200),
                  tile,
                  const SizedBox(height: 2000),
                ],
              )
            : Center(child: SizedBox(width: 300, child: tile)),
      ),
    );
  }

  /// The ink is painted by the `Material` above the tile.
  RenderObject inkHost(WidgetTester tester) =>
      tester.renderObject(find.byType(Material).last);

  /// A ticker's first callback arrives at t = 0, so the frame that starts a
  /// spring is never the frame that moves it. Every wait here is therefore
  /// several frames, which is also what a device gives it.
  Future<void> settle(WidgetTester tester, [int ms = 400]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump(Duration(milliseconds: ms));
  }

  testWidgets('the glow stays while the finger is held still', (tester) async {
    await tester.pumpWidget(app());
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('tile'))),
    );
    await settle(tester);
    expect(inkHost(tester), paints..circle());

    // Long past any tap timeout: Material has long since stopped caring.
    await settle(tester, 3000);
    expect(inkHost(tester), paints..circle());

    await gesture.up();
    await settle(tester, 1000);
    expect(inkHost(tester), isNot(paints..circle()));
  });

  testWidgets('the glow survives the finger wandering past the touch slop', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final Offset centre = tester.getCenter(find.byKey(const Key('tile')));
    final TestGesture gesture = await tester.startGesture(centre);
    await settle(tester);
    // Material's tap recognizer rejects itself here and calls cancel().
    await gesture.moveTo(centre + const Offset(60, 0));
    await settle(tester);
    expect(inkHost(tester), paints..circle());

    await gesture.up();
    await settle(tester, 1000);
    expect(inkHost(tester), isNot(paints..circle()));
  });

  testWidgets('the glow follows the finger', (tester) async {
    await tester.pumpWidget(app());
    final Offset centre = tester.getCenter(find.byKey(const Key('tile')));
    final TestGesture gesture = await tester.startGesture(
      centre - const Offset(100, 0),
    );
    await settle(tester);
    final List<Offset> centres = <Offset>[];
    void record() {
      expect(
        inkHost(tester),
        paints..something((Symbol method, List<Object?> arguments) {
          if (method != #drawCircle) return false;
          centres.add(arguments[0]! as Offset);
          return true;
        }),
      );
    }

    record();
    await gesture.moveTo(centre + const Offset(100, 0));
    await settle(tester);
    record();
    expect(centres.length, 2);
    expect(
      centres[1].dx,
      greaterThan(centres[0].dx + 50),
      reason: 'the glow moved with the finger',
    );
    await gesture.up();
    await settle(tester, 1000);
  });

  testWidgets('the very first press of the session is followed too', (
    tester,
  ) async {
    // The pointer tracker registers its global route lazily, and the first
    // gesture of an app's life is the one that registers it. That gesture has
    // no down event to claim, so it adopts its finger from the first move —
    // without which the first thing pressed in a session is the one control
    // whose glow dies at Material's cancel.
    await tester.pumpWidget(app());
    final Offset centre = tester.getCenter(find.byKey(const Key('tile')));
    final TestGesture gesture = await tester.startGesture(centre);
    await settle(tester);
    await gesture.moveTo(centre + const Offset(60, 0));
    await settle(tester);
    expect(inkHost(tester), paints..circle());
    await gesture.up();
    await settle(tester, 1000);
    expect(inkHost(tester), isNot(paints..circle()));
  });

  testWidgets('a scroll under the finger puts the glow out', (tester) async {
    await tester.pumpWidget(app(inList: true));
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('tile'))),
    );
    await settle(tester);
    expect(inkHost(tester), paints..circle());
    // Drag the list: this was a scroll, not a press. A finger reports its
    // travel in a stream of small moves, and it is the move *after* the list
    // has scrolled that shows the row has left it behind.
    for (int i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, 1000);
    expect(inkHost(tester), isNot(paints..circle()));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap still fires exactly once', (tester) async {
    int taps = 0;
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.tap(find.byKey(const Key('tile')));
    await settle(tester, 1000);
    expect(taps, 1);
  });
}
