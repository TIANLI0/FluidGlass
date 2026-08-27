import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 240;
const int _h = 240;

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Mean red channel of a box, which is all "how bright is it" needs over
/// black-and-white content.
double _meanRed(Uint8List p, Rect box) {
  int total = 0;
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      total += p[(y * _w + x) * 4];
      count += 1;
    }
  }
  return total / count;
}

Widget _frame(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: child,
          ),
        ),
      ),
    );

/// Alternating 40px bands, so "which part of the source is the glass showing"
/// is a question about brightness.
Widget get _bands => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 6; i++)
          SizedBox(
            height: 40,
            width: _w.toDouble(),
            child: ColoredBox(
              color: i.isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
            ),
          ),
      ],
    );

/// Counts how often the capture is actually retaken.
class _CountingSource implements LayerBackdropSource {
  _CountingSource(this.inner);

  final LayerBackdropSource inner;
  int invalidations = 0;

  @override
  Size get sourceSize => inner.sourceSize;
  @override
  Offset get sourceGlobalOffset => inner.sourceGlobalOffset;
  @override
  bool get hasContent => inner.hasContent;
  @override
  void drawSource(Canvas canvas, double devicePixelRatio,
          {double clampMargin = 0.0, Rect? region}) =>
      inner.drawSource(canvas, devicePixelRatio,
          clampMargin: clampMargin, region: region);
  @override
  void invalidateSnapshot() {
    invalidations += 1;
    inner.invalidateSnapshot();
  }
}

void main() {
  setUp(() {
    // These tests are about the *sampled* path — the capture, where it is read
    // from, when it is retaken. `ImageFilter.shader` is unavailable under
    // `flutter_test`, so the tier would otherwise resolve to
    // `GlassQuality.plain`, which does not sample at all: it hands the chain to
    // a `BackdropFilterLayer` and the assertions below would pass without ever
    // exercising the code they were written for.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('glass tracks an animation that repaints behind a RepaintBoundary',
      (WidgetTester tester) async {
    // The half of "live backdrop" that scroll notifications do not cover.
    // `markNeedsPaint` stops at the nearest repaint boundary, so a background
    // that animates inside one of its own repaints while `RenderBackdropLayer`
    // sleeps through it — and the glass was left showing a frozen capture of a
    // moving background. Nothing here scrolls and nothing passes `liveness`;
    // the source's layers are watched instead.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);

    await tester.pumpWidget(_frame(Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: t,
                builder: (BuildContext context, double v, Widget? _) => ColoredBox(
                  color: Color.lerp(
                      const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(2),
            child: const SizedBox(height: 60, width: double.infinity),
          ),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump();

    const Rect inside = Rect.fromLTWH(20, 10, 200, 40);
    final List<double> samples = <double>[_meanRed(await _pixels(tester), inside)];
    for (int i = 1; i <= 4; i++) {
      t.value = i / 4;
      // Two frames: one for the background to repaint, one for the glass to
      // notice and re-sample it.
      await tester.pump();
      await tester.pump();
      samples.add(_meanRed(await _pixels(tester), inside));
    }

    expect(samples.last - samples.first, greaterThan(150.0),
        reason: 'the glass must follow the background it covers, but its '
            'brightness only moved across $samples');
  });

  testWidgets('a source that only moves is re-placed, not re-captured',
      (WidgetTester tester) async {
    // A background sliding under pinned glass — a page transition, an
    // `InteractiveViewer` being panned. Nothing inside the source repaints, so
    // its capture stays valid; what changes is where the glass has to read it,
    // and the glass is behind a repaint boundary of its own so nothing else
    // will tell it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> dy = ValueNotifier<double>(0);
    addTearDown(dy.dispose);

    await tester.pumpWidget(_frame(Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: AnimatedBuilder(
            animation: dy,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(offset: Offset(0, dy.value), child: child),
            child: BackdropLayer(backdrop: backdrop, child: _bands),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: RepaintBoundary(
            child: DrawBackdrop.plain(
              backdrop: backdrop,
              shape: () => const Rectangle(),
              effects: (BackdropEffectScope scope) {},
              child: const SizedBox(height: 40, width: double.infinity),
            ),
          ),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;
    final _CountingSource counting = _CountingSource(source);
    backdrop.attachSource(counting);
    await tester.pump();
    await tester.pump();
    counting.invalidations = 0;

    const Rect inside = Rect.fromLTWH(20, 5, 200, 30);
    final List<double> samples = <double>[_meanRed(await _pixels(tester), inside)];
    for (int i = 1; i <= 4; i++) {
      dy.value = -i * 20.0;
      await tester.pump();
      await tester.pump();
      samples.add(_meanRed(await _pixels(tester), inside));
    }

    final double min = samples.reduce((double a, double b) => a < b ? a : b);
    final double max = samples.reduce((double a, double b) => a > b ? a : b);
    expect(max - min, greaterThan(100.0),
        reason: 'the glass must follow the source sliding under it, but its '
            'brightness only moved between $min and $max across $samples');
    expect(counting.invalidations, 0,
        reason: 'the source did not repaint, so its capture was still good; '
            'only where to read it changed');
  });

  testWidgets('glass over a scaled source samples the same pixels it covers',
      (WidgetTester tester) async {
    // The capture is taken in the source's own coordinates, so placing it takes
    // the whole transform between the two — not the offset between their
    // origins, which is right up until an ancestor scales, rotates or zooms
    // either of them. With no effects at all the glass has to be invisible: it
    // must show exactly what would be there without it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    Widget host({required bool withGlass}) => _frame(Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: ClipRect(
                child: Transform.scale(
                  scale: 2.0,
                  alignment: Alignment.topLeft,
                  child: BackdropLayer(backdrop: backdrop, child: _bands),
                ),
              ),
            ),
            if (withGlass)
              Positioned(
                left: 40,
                top: 40,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => const Rectangle(),
                  effects: (BackdropEffectScope scope) {},
                  child: const SizedBox(width: 160, height: 160),
                ),
              ),
          ],
        ));

    await tester.pumpWidget(host(withGlass: false));
    await tester.pump();
    await tester.pump();
    final Uint8List bare = await _pixels(tester);

    await tester.pumpWidget(host(withGlass: true));
    await tester.pump();
    await tester.pump();
    final Uint8List glazed = await _pixels(tester);

    // Three bands, sampled well inside so the capture's resampling at the
    // boundaries cannot decide the answer.
    final List<Rect> probes = <Rect>[
      const Rect.fromLTWH(60, 50, 120, 20),
      const Rect.fromLTWH(60, 110, 120, 20),
      const Rect.fromLTWH(60, 170, 120, 20),
    ];
    for (final Rect probe in probes) {
      expect((_meanRed(glazed, probe) - _meanRed(bare, probe)).abs(), lessThan(8.0),
          reason: 'at $probe the glass showed ${_meanRed(glazed, probe)} where '
              'the source itself shows ${_meanRed(bare, probe)}');
    }
  });

  testWidgets('glass inside its own source is reported, and does not spin',
      (WidgetTester tester) async {
    // `BackdropLayer(child: everything)` with the glass in `everything` is the
    // natural thing to write and cannot work: the capture is taken while the
    // source is halfway through painting, and the two mark each other dirty
    // forever. Both halves are pinned here — the diagnosis, and the app going
    // quiet afterwards rather than burning a frame every 16ms.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(_frame(BackdropLayer(
      backdrop: backdrop,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: Color(0xFF808080))),
          Positioned(
            left: 0,
            top: 0,
            child: DrawBackdrop.plain(
              backdrop: backdrop,
              shape: () => const Rectangle(),
              effects: (BackdropEffectScope scope) => scope.blur(2),
              child: const SizedBox(width: 100, height: 60),
            ),
          ),
        ],
      ),
    )));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final Object? error = tester.takeException();
    expect(error, isFlutterError);
    expect(error.toString(), contains('inside of'));

    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse,
        reason: 'the source and its consumer are still repainting each other');
  });

  testWidgets('a scrolling source is captured once per glass strip per frame',
      (WidgetTester tester) async {
    // What a live backdrop actually costs. Each capture is an
    // `OffsetLayer.toImageSync`, a synchronous rasterisation that flushes the
    // pipeline mid-frame; the number of them per frame is the number worth
    // watching, and every mechanism that notices a change has to be careful not
    // to add one of its own on top of the mechanism that already noticed.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    Widget bar(double top) => Positioned(
          left: 0,
          right: 0,
          top: top,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(2),
            child: const SizedBox(height: 40, width: double.infinity),
          ),
        );

    await tester.pumpWidget(_frame(Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            child: ListView.builder(
              controller: controller,
              itemExtent: 40,
              itemCount: 60,
              itemBuilder: (BuildContext context, int i) => ColoredBox(
                color: i.isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
        bar(0),
        bar(_h - 40.0),
      ],
    )));
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;

    // Idle: nothing changes, so nothing is captured.
    source.debugCaptureCount = 0;
    await tester.pump();
    await tester.pump();
    expect(source.debugCaptureCount, 0,
        reason: 'a still source must not be re-captured');

    // Scrolling: two bars, two strips, one capture each per frame. Not three,
    // and not one per bar per mechanism that noticed the scroll.
    const int frames = 6;
    for (int i = 1; i <= frames; i++) {
      controller.jumpTo(i * 13.0);
      await tester.pump();
    }
    expect(source.debugCaptureCount, lessThanOrEqualTo(2 * frames),
        reason: 'two glass bars over $frames scrolled frames should cost two '
            'captures a frame, not ${source.debugCaptureCount}');
    expect(source.debugCaptureCount, greaterThanOrEqualTo(frames),
        reason: 'the bars did not re-sample the scrolling list at all');

    // And it settles: once the scroll stops, so does the capturing.
    await tester.pumpAndSettle();
    source.debugCaptureCount = 0;
    await tester.pump();
    await tester.pump();
    expect(source.debugCaptureCount, 0,
        reason: 'the source went still, so the captures must stop');
  });

  testWidgets('glass tracks a fade between two repaint boundaries',
      (WidgetTester tester) async {
    // The case pictures alone do not catch. A repaint boundary that repaints
    // hands `pushOpacity` back the layer it used last time, so a fade sitting
    // between two boundaries changes the `OpacityLayer`'s alpha while every
    // picture under it stays exactly where it was. What the layers *do* is part
    // of the fingerprint for that reason, not only what they hold.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> fade = ValueNotifier<double>(0.15);
    addTearDown(fade.dispose);

    await tester.pumpWidget(_frame(Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                    child: ColoredBox(color: Color(0xFF000000))),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: fade,
                      builder: (BuildContext context, double v, Widget? child) =>
                          Opacity(opacity: v, child: child),
                      child: const RepaintBoundary(
                        child: ColoredBox(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) {},
            child: const SizedBox(height: 60, width: double.infinity),
          ),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump();

    const Rect inside = Rect.fromLTWH(20, 10, 200, 40);
    final double dark = _meanRed(await _pixels(tester), inside);
    // Never to 0 or 1: `Opacity` skips painting its child entirely at 0, which
    // would change the layer *structure* and prove nothing about alpha.
    fade.value = 0.9;
    await tester.pump();
    await tester.pump();
    final double light = _meanRed(await _pixels(tester), inside);

    expect(light - dark, greaterThan(150.0),
        reason: 'the glass showed $dark then $light while the background under '
            'it faded from black to white');
  });
}
