import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a glass element with a layerBlock still receives gestures',
      (WidgetTester tester) async {
    // The playground and the adaptive-luminance demo put their gestures inside
    // the glass so the touch target follows the transform.
    Offset pan = Offset.zero;
    double zoom = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Positioned.fill(child: ColoredBox(color: Color(0xFF224466))),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return DrawBackdrop(
                    backdrop: emptyBackdrop,
                    shape: () => const RoundedRectangle(24),
                    effects: (BackdropEffectScope scope) {},
                    layerBlock: (GlassLayer layer) {
                      layer.translationX = pan.dx;
                      layer.translationY = pan.dy;
                      layer.scaleX = zoom;
                      layer.scaleY = zoom;
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleUpdate: (ScaleUpdateDetails details) {
                        setState(() {
                          pan += details.focalPointDelta;
                          zoom *= details.scale == 0 ? 1 : 1;
                        });
                      },
                      child: const SizedBox(width: 160, height: 160),
                    ),
                  );
                },
              ),
              // The scaffold puts a full-size Align over everything for its
              // bottom button; it must not swallow the gesture.
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 56,
                    child: ColoredBox(color: const Color(0xFF0088FF)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset centre = tester.getCenter(find.byType(DrawBackdrop));
    final TestGesture gesture = await tester.startGesture(centre);
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(6, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(pan.dx, greaterThan(20), reason: 'the glass must pan under a drag');
    expect(pan.dy, greaterThan(10));

    // And it must still be grabbable at its new position.
    final Offset moved = centre + pan;
    final TestGesture second = await tester.startGesture(moved);
    final Offset before = pan;
    for (int i = 0; i < 10; i++) {
      await second.moveBy(const Offset(-6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.pump();

    expect(pan.dx, lessThan(before.dx),
        reason: 'the transformed glass must be grabbable where it is drawn');
  });
}
