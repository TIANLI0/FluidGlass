import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a button-group action fires even after the finger wanders',
      (WidgetTester tester) async {
    final List<String> pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidButtonGroup(
              backdrop: emptyBackdrop,
              actions: <LiquidGroupAction>[
                LiquidGroupAction(
                  icon: Icons.arrow_back_ios_new,
                  onPressed: () => pressed.add('back'),
                ),
                LiquidGroupAction(
                  label: 'Share',
                  onPressed: () => pressed.add('share'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // A clean tap on the second segment.
    await tester.tap(find.text('Share'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(pressed, <String>['share']);

    // A press that drifts well past the touch slop must still fire.
    final TestGesture gesture = await tester
        .startGesture(tester.getCenter(find.byIcon(Icons.arrow_back_ios_new)));
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(6, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(pressed, <String>['share', 'back']);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the button group drags with the finger and springs back',
      (WidgetTester tester) async {
    // The capsule must carry the same physics as LiquidButton: follow the
    // finger through a bounded tanh, stretch along the travel, and spring
    // home on release.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidButtonGroup(
              backdrop: emptyBackdrop,
              actions: <LiquidGroupAction>[
                LiquidGroupAction(label: 'One', onPressed: () {}),
                LiquidGroupAction(label: 'Two', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderObject box =
        tester.renderObject(find.byType(LiquidButtonGroup));
    Matrix4 transformOf(RenderObject node) {
      final Matrix4 m = Matrix4.identity();
      node.applyPaintTransform(
        (node as RenderObjectWithChildMixin<RenderObject>).child!,
        m,
      );
      return m;
    }

    // At rest the glass is untransformed.
    expect(transformOf(box).getTranslation().x, closeTo(0, 0.01));

    // Press and hold WITHOUT moving, and let the swell settle. The matrix's
    // translation also carries the scale-about-centre term
    // (pivotX * (1 - scaleX)), so this pressed-but-undragged reading is the
    // baseline that isolates the drag.
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('One')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    final double pressedOnly = transformOf(box).getTranslation().x;

    // Now drag off to one side and hold there.
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));
    final double dragged = transformOf(box).getTranslation().x;

    final double groupTravel = dragged - pressedOnly;
    expect(groupTravel, greaterThan(0.5),
        reason: 'the glass must follow the finger');
    expect(groupTravel, lessThan(120.0),
        reason: 'tanh must bound the travel well under the drag distance');

    // Release: it springs home to an untransformed capsule.
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 2));

    expect(transformOf(box).getTranslation().x, closeTo(0, 0.5),
        reason: 'releasing must spring the glass back');

    // The same gesture on a LiquidButton must move its glass by the same
    // amount: the group is meant to be a faithful reproduction of that feel.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidButton(
              onPressed: () {},
              backdrop: emptyBackdrop,
              children: const <Widget>[Text('One')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderObject buttonBox =
        tester.renderObject(find.byType(LiquidButton));
    final TestGesture g2 =
        await tester.startGesture(tester.getCenter(find.text('One')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    final double buttonPressed = transformOf(buttonBox).getTranslation().x;
    for (int i = 0; i < 10; i++) {
      await g2.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));
    final double buttonTravel =
        transformOf(buttonBox).getTranslation().x - buttonPressed;

    expect(groupTravel, closeTo(buttonTravel, buttonTravel.abs() * 0.25 + 0.5),
        reason: 'the group must drag like a LiquidButton');

    await g2.up();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the segmented control selects by tap and by dragging the thumb',
      (WidgetTester tester) async {
    final List<int> reported = <int>[];
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return LiquidSegmentedControl(
                    selectedIndex: selected,
                    onSelected: (int index) {
                      reported.add(index);
                      setState(() => selected = index);
                    },
                    backdrop: emptyBackdrop,
                    segments: const <Widget>[
                      Text('Day'),
                      Text('Week'),
                      Text('Month'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Month'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(reported, <int>[2]);

    // Drag the thumb from the last segment back to the first.
    final Offset controlTopLeft =
        tester.getTopLeft(find.byType(LiquidSegmentedControl));
    const double segmentWidth = (300 - 6) / 3;
    final Offset onThumb =
        controlTopLeft + Offset(3 + segmentWidth * 2.5, 20);
    final TestGesture gesture = await tester.startGesture(onThumb);
    for (int i = 0; i < 14; i++) {
      await gesture.moveBy(const Offset(-16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(reported, <int>[2, 0]);
  });

  testWidgets('re-selecting the same segment reports nothing',
      (WidgetTester tester) async {
    final List<int> reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: LiquidSegmentedControl(
                selectedIndex: 1,
                onSelected: reported.add,
                backdrop: emptyBackdrop,
                segments: const <Widget>[
                  Text('Day'),
                  Text('Week'),
                  Text('Month'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The thumb sits over the selected segment, so this lands on the thumb's
    // own inspector — releasing it must also report nothing.
    await tester.tap(find.text('Week'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(reported, isEmpty);
  });

  testWidgets('LiquidPanel hosts a child and reads its reveal at paint time',
      (WidgetTester tester) async {
    double reveal = 0.0;
    int reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidPanel(
              backdrop: emptyBackdrop,
              reveal: () {
                reads++;
                return reveal;
              },
              child: const SizedBox(
                width: 200,
                height: 80,
                child: Center(child: Text('Panel')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Panel'), findsOneWidget);
    expect(reads, greaterThan(0),
        reason: 'the reveal getter must drive the paint');

    reveal = 1.0;
    await tester.pump();
    expect(find.text('Panel'), findsOneWidget);
  });
}
