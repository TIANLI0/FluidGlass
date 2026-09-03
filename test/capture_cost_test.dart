import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

// What a live backdrop costs per frame, and when it may cost nothing.
//
// Every capture is an `OffsetLayer.toImageSync` — a rasterisation of the
// source that flushes the pipeline mid-frame and scales with the pixels it
// covers. These tests pin three ways of not paying for one:
//
//  * two pieces of glass reading overlapping strips share one capture;
//  * a change to the source that lands nowhere any glass reads is left alone;
//  * a source in motion is captured at `motionPixelRatio`, and sharpens back
//    up the moment it stops.

const int _w = 240;
const int _h = 240;

Widget _frame(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: SizedBox(width: _w.toDouble(), height: _h.toDouble(), child: child),
  ),
);

/// A glass strip pinned across the source, [height] tall, its top at [top].
Widget _bar(LayerBackdrop backdrop, {required double top, double height = 40}) {
  return Positioned(
    left: 0,
    right: 0,
    top: top,
    child: DrawBackdrop.plain(
      backdrop: backdrop,
      shape: () => const Rectangle(),
      effects: (BackdropEffectScope scope) => scope.blur(2),
      child: SizedBox(height: height, width: double.infinity),
    ),
  );
}

Widget _stripes(ScrollController controller, {Axis axis = Axis.vertical}) {
  return ListView.builder(
    controller: controller,
    scrollDirection: axis,
    itemExtent: 40,
    itemCount: 60,
    itemBuilder: (BuildContext context, int i) => ColoredBox(
      color: i.isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    ),
  );
}

/// A box that repaints behind a repaint boundary of its own whenever [t]
/// moves, without anything around it repainting.
Widget _pulse(ValueNotifier<double> t) {
  return RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (BuildContext context, double v, Widget? _) => ColoredBox(
        color: Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
      ),
    ),
  );
}

RenderBackdropLayer _source(WidgetTester tester) =>
    tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;

void main() {
  setUp(() {
    // The sampled path. Under `flutter_test` the tier would resolve to `plain`,
    // which never captures.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('glass reading overlapping strips shares one capture a frame', (
    WidgetTester tester,
  ) async {
    // A bottom bar, and a copy of it a few pixels taller on both sides — what
    // a tab bar and the accent copy its selection pill magnifies ask for. The
    // first capture did not quite contain the second request, so every frame
    // of a scroll used to cost two captures of almost the same strip.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: _stripes(controller),
              ),
            ),
            _bar(backdrop, top: _h - 40.0),
            _bar(backdrop, top: _h - 48.0, height: 56),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source = _source(tester);
    source.debugCaptureCount = 0;
    const int frames = 6;
    for (int i = 1; i <= frames; i++) {
      controller.jumpTo(i * 13.0);
      await tester.pump();
    }
    expect(
      source.debugCaptureCount,
      frames,
      reason: 'two overlapping strips must be served by one capture a frame',
    );
  });

  testWidgets(
    'a repaint that lands nowhere under the glass is not re-captured',
    (WidgetTester tester) async {
      // A spinner, a marquee, a pulsing dot: something at the top of a page
      // repainting on every frame behind its own repaint boundary, while the
      // glass is a bar along the bottom. The change is seen — the layers are
      // still walked — and left alone, because nothing the glass reads is in it.
      tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final LayerBackdrop backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);
      final ValueNotifier<double> t = ValueNotifier<double>(0);
      addTearDown(t.dispose);

      await tester.pumpWidget(
        _frame(
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 60,
                        width: _w.toDouble(),
                        child: _pulse(t),
                      ),
                      const Expanded(
                        child: ColoredBox(color: Color(0xFF808080)),
                      ),
                    ],
                  ),
                ),
              ),
              _bar(backdrop, top: _h - 40.0),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderBackdropLayer source = _source(tester);
      source.debugCaptureCount = 0;
      source.debugIgnoredChanges = 0;
      const int steps = 6;
      for (int i = 1; i <= steps; i++) {
        t.value = i / steps;
        await tester.pump();
        await tester.pump();
      }
      expect(
        source.debugIgnoredChanges,
        greaterThanOrEqualTo(steps),
        reason: 'the repaints must have been noticed to be ruled out',
      );
      expect(
        source.debugCaptureCount,
        0,
        reason: 'a change 140 pixels above the glass cost it a re-capture',
      );
      expect(
        SchedulerBinding.instance.hasScheduledFrame,
        isFalse,
        reason: 'nothing here should keep frames coming',
      );
    },
  );

  testWidgets('the same repaint under the glass is followed', (
    WidgetTester tester,
  ) async {
    // The control: put the pulsing box where the bar reads, and every step
    // costs exactly the re-capture it should.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);

    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: Column(
                  children: <Widget>[
                    const Expanded(child: ColoredBox(color: Color(0xFF808080))),
                    SizedBox(
                      height: 60,
                      width: _w.toDouble(),
                      child: _pulse(t),
                    ),
                  ],
                ),
              ),
            ),
            _bar(backdrop, top: _h - 40.0),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source = _source(tester);
    source.debugCaptureCount = 0;
    const int steps = 6;
    for (int i = 1; i <= steps; i++) {
      t.value = i / steps;
      await tester.pump();
      await tester.pump();
    }
    expect(
      source.debugCaptureCount,
      steps,
      reason: 'each change under the glass is one re-capture, no more',
    );
  });

  testWidgets(
    'a scroll that lands nowhere under the glass is not re-captured',
    (WidgetTester tester) async {
      // The other way a source announces a change: a scroll notification. It
      // names the scrollable, so a carousel across the top of a page can be
      // ruled out before the frame is even built — and the items it brings into
      // view or drops as it goes are ruled out by where they draw.
      tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final LayerBackdrop backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 60,
                        width: _w.toDouble(),
                        child: _stripes(controller, axis: Axis.horizontal),
                      ),
                      const Expanded(
                        child: ColoredBox(color: Color(0xFF808080)),
                      ),
                    ],
                  ),
                ),
              ),
              _bar(backdrop, top: _h - 40.0),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final RenderBackdropLayer source = _source(tester);
      source.debugCaptureCount = 0;
      const int frames = 6;
      for (int i = 1; i <= frames; i++) {
        controller.jumpTo(i * 13.0);
        await tester.pump();
        await tester.pump();
      }
      expect(
        source.debugCaptureCount,
        0,
        reason:
            'a carousel scrolling 140 pixels above the glass cost it a '
            're-capture',
      );
    },
  );

  testWidgets(
    'a source in motion is captured at motionPixelRatio and sharpens at rest',
    (WidgetTester tester) async {
      tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final LayerBackdrop backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  pixelRatio: 1.0,
                  motionPixelRatio: 0.5,
                  child: _stripes(controller),
                ),
              ),
              _bar(backdrop, top: _h - 40.0),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        _source(tester).debugLastCapturePixelRatio,
        1.0,
        reason: 'a still source is captured at full resolution',
      );

      final RenderBackdropLayer source = _source(tester);
      source.debugCaptureCount = 0;
      final List<double?> ratios = <double?>[];
      const int frames = 6;
      for (int i = 1; i <= frames; i++) {
        controller.jumpTo(i * 13.0);
        await tester.pump();
        ratios.add(source.debugLastCapturePixelRatio);
      }
      // The first two frames of a run are not yet "motion": a one-off change,
      // or a two-frame one, never costs sharpness.
      expect(ratios.sublist(0, 2), everyElement(1.0), reason: '$ratios');
      expect(ratios.sublist(2), everyElement(0.5), reason: '$ratios');
      expect(source.debugCaptureCount, frames);

      // The scroll stops. One frame to notice the source went quiet, one to
      // re-capture at full resolution, then nothing.
      await tester.pump();
      expect(
        source.debugCaptureCount,
        frames,
        reason: 'noticing the source went quiet is not itself a capture',
      );
      await tester.pump();
      expect(
        source.debugCaptureCount,
        frames + 1,
        reason: 'a source that came to rest is captured once more, sharp',
      );
      expect(source.debugLastCapturePixelRatio, 1.0);
      await tester.pump();
      await tester.pump();
      expect(
        source.debugCaptureCount,
        frames + 1,
        reason: 'and then it is left alone',
      );
      expect(
        SchedulerBinding.instance.hasScheduledFrame,
        isFalse,
        reason: 'settling must not keep frames coming',
      );
    },
  );

  testWidgets('a change that is not motion never drops resolution', (
    WidgetTester tester,
  ) async {
    // A tap that recolours a row, a badge that updates: one repaint, two
    // frames apart from the next. Nothing about that is a run, so the capture
    // stays sharp throughout.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                pixelRatio: 1.0,
                motionPixelRatio: 0.5,
                child: _stripes(controller),
              ),
            ),
            _bar(backdrop, top: _h - 40.0),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source = _source(tester);
    source.debugCaptureCount = 0;
    for (int i = 1; i <= 4; i++) {
      controller.jumpTo(i * 13.0);
      await tester.pump();
      expect(source.debugLastCapturePixelRatio, 1.0, reason: 'step $i');
      // A quiet frame in between: no run.
      await tester.pump();
      await tester.pump();
    }
    expect(source.debugCaptureCount, 4);
  });

  testWidgets('bottom tabs do not own a synchronous capture', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    int index = 0;

    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Stack(
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  child: const ColoredBox(color: Color(0xFF808080)),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: LiquidBottomTabs(
                  selectedTabIndex: index,
                  onTabSelected: (int value) => setState(() => index = value),
                  backdrop: backdrop,
                  tabsCount: 3,
                  children: <Widget>[
                    for (int i = 0; i < 3; i++)
                      LiquidBottomTab(
                        onPressed: () => setState(() => index = i),
                        children: <Widget>[
                          Text('$i', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The page is the only live source. The accent glass behind the moving
    // pill is a recorded picture, so the pill's spring never performs its own
    // `OffsetLayer.toImageSync` pipeline flush.
    expect(find.byType(BackdropLayer), findsOneWidget);

    final RenderBackdropLayer source = _source(tester)..debugCaptureCount = 0;
    await tester.tapAt(const Offset(_w / 2, _h - 32));
    await tester.pumpAndSettle();
    expect(index, 1);
    expect(
      source.debugCaptureCount,
      lessThanOrEqualTo(2),
      reason: 'the moving pill must reuse the still page capture',
    );
  });
}
