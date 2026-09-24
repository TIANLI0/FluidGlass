import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({this.origin, this.reduceMotion = false});

  final Rect? origin;
  final bool reduceMotion;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 100, top: 200),
            child: LiquidMorph(
              progress: controller,
              origin: widget.origin,
              radius: 28,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 300, height: 200),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  RenderLiquidMorph morphOf(WidgetTester tester) =>
      tester.renderObject(find.byType(LiquidMorph));

  AnimationController controllerOf(WidgetTester tester) =>
      tester.state<_HostState>(find.byType(_Host)).controller;

  testWidgets('starts at the origin, in local coordinates', (
    WidgetTester tester,
  ) async {
    // The button sits at (120, 520) on screen; the surface at (100, 200).
    await tester.pumpWidget(
      const _Host(origin: Rect.fromLTWH(120, 520, 60, 40)),
    );
    final Rect clip = morphOf(tester).debugClipRect!;
    expect(clip.left, closeTo(20, 0.01));
    expect(clip.top, closeTo(320, 0.01));
    expect(clip.width, closeTo(60, 0.01));
    expect(clip.height, closeTo(40, 0.01));
  });

  testWidgets('width leads, height follows, then the clip goes away', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Host(origin: Rect.fromLTWH(120, 520, 60, 40)),
    );
    controllerOf(tester).value = 0.4;
    await tester.pump();
    final Rect mid = morphOf(tester).debugClipRect!;
    final double widthDone = (mid.width - 60) / (300 - 60);
    final double heightDone = (mid.height - 40) / (200 - 40);
    expect(widthDone, greaterThan(heightDone));

    controllerOf(tester).value = 1;
    await tester.pump();
    expect(morphOf(tester).debugClipRect, isNull);
  });

  testWidgets('with no origin it grows out of its own centre', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Host());
    final Rect clip = morphOf(tester).debugClipRect!;
    expect(clip.center.dx, closeTo(150, 0.01));
    expect(clip.center.dy, closeTo(100, 0.01));
    expect(clip.width, lessThan(100));
  });

  testWidgets('what the clip hides cannot be tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Host(origin: Rect.fromLTWH(120, 520, 60, 40)),
    );
    controllerOf(tester).value = 0.05;
    await tester.pump();
    final HitTestResult hidden = HitTestResult();
    // Top-left of the surface: far from the origin, still clipped away.
    tester.binding.hitTestInView(
      hidden,
      const Offset(105, 205),
      tester.view.viewId,
    );
    expect(
      hidden.path.any((HitTestEntry e) => e.target is RenderLiquidMorph),
      isFalse,
    );
  });

  testWidgets('originFor is asked where the child landed, and wins', (
    WidgetTester tester,
  ) async {
    Rect? asked;
    final AnimationController controller = AnimationController(
      vsync: const TestVSync(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 60),
            child: LiquidMorph(
              progress: controller,
              origin: const Rect.fromLTWH(0, 0, 10, 10),
              originFor: (Rect bounds) {
                asked = bounds;
                return Rect.fromLTWH(
                  bounds.left + 10,
                  bounds.bottom - 20,
                  30,
                  20,
                );
              },
              radius: 20,
              child: const SizedBox(width: 160, height: 120),
            ),
          ),
        ),
      ),
    );
    final Rect clip = morphOf(tester).debugClipRect!;
    expect(asked, const Rect.fromLTWH(40, 60, 160, 120));
    expect(clip, const Rect.fromLTWH(10, 100, 30, 20));
  });

  testWidgets('with motion reduced it is simply there', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Host(origin: Rect.fromLTWH(120, 520, 60, 40), reduceMotion: true),
    );
    expect(morphOf(tester).debugClipRect, isNull);
  });

  testWidgets('a dialog with a morph grows on the animation of its route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showGeneralDialog<void>(
                context: context,
                pageBuilder: (BuildContext context, _, _) => const LiquidDialog(
                  backdrop: emptyBackdrop,
                  title: 'Sure?',
                  morph: LiquidDialogMorph(
                    origin: Rect.fromLTWH(10, 10, 40, 40),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LiquidMorph), findsOneWidget);
    expect(morphOf(tester).debugClipRect, isNotNull);
    await tester.pumpAndSettle();
    expect(morphOf(tester).debugClipRect, isNull);
  });
}
