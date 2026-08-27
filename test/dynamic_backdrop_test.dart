import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 200;
const int _h = 400;

/// A glass bar pinned over a list that scrolls underneath it.
///
/// The bar samples the list, so its pixels must change as the list moves. The
/// list rows are pure black and pure white bands, so "did the sampled backdrop
/// change" is a question about brightness, not about anything subtle.
Widget _host(ScrollController controller) {
  final LayerBackdrop backdrop = LayerBackdrop();
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: RepaintBoundary(
        key: _boundary,
        child: SizedBox(
          width: _w.toDouble(),
          height: _h.toDouble(),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  child: ListView.builder(
                    controller: controller,
                    itemExtent: 40,
                    itemCount: 60,
                    itemBuilder: (BuildContext context, int index) => ColoredBox(
                      color: index.isEven
                          ? const Color(0xFF000000)
                          : const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
              // The pinned bar, sampling the list behind it.
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
          ),
        ),
      ),
    ),
  );
}

/// Mean brightness of the bar's own strip of pixels.
Future<double> _barBrightness(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  int total = 0;
  int count = 0;
  // Rows 10..50: inside the bar, clear of its edges.
  for (int y = 10; y < 50; y++) {
    for (int x = 0; x < _w; x++) {
      total += p[(y * _w + x) * 4];
      count += 1;
    }
  }
  return total / count;
}

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

  testWidgets('a glass bar tracks a list scrolling underneath it',
      (WidgetTester tester) async {
    // Regression: `RenderBackdropLayer` only invalidated its captured snapshot
    // inside its own `paint`, and only told its consumers to repaint from
    // there. Nothing marks a pinned glass element dirty when unrelated content
    // scrolls, so the bar kept drawing a stale capture — the backdrop looked
    // frozen while the list moved behind it. Every other catalog screen puts
    // glass over a still wallpaper, where a stale capture is the right answer,
    // which is why it went unnoticed.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    final List<double> samples = <double>[await _barBrightness(tester)];

    // Scroll by half a row at a time, so the bands under the bar invert.
    for (int i = 1; i <= 6; i++) {
      controller.jumpTo(i * 20.0);
      await tester.pump();
      samples.add(await _barBrightness(tester));
    }

    final double min = samples.reduce((double a, double b) => a < b ? a : b);
    final double max = samples.reduce((double a, double b) => a > b ? a : b);
    expect(max - min, greaterThan(20.0),
        reason: 'the bar must re-sample as the list moves, but its brightness '
            'only moved between $min and $max across $samples');
  });

  testWidgets('a still source is not re-captured for an animating consumer',
      (WidgetTester tester) async {
    // The other half of the contract, and the reason invalidation is driven by
    // signals rather than by the frame counter: a full-screen `toImageSync`
    // every frame would be correct and would also undo the whole point of
    // caching the capture. Glass animating over a still wallpaper must not
    // retake it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> spin = ValueNotifier<double>(0);
    addTearDown(spin.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: const ColoredBox(color: Color(0xFF808080)),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: DrawBackdrop.plain(
                backdrop: backdrop,
                shape: () => const Rectangle(),
                repaint: spin,
                layerBlock: (GlassLayer layer) {
                  layer.scaleX = 1 + spin.value * 0.001;
                },
                effects: (BackdropEffectScope scope) => scope.blur(2),
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    // Wrap the attached source so retakes can be counted, then animate only
    // the glass.
    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer).first)
            as RenderBackdropLayer;
    final _CountingSource counting = _CountingSource(source);
    backdrop.attachSource(counting);
    await tester.pump();

    counting.invalidations = 0;
    for (int i = 1; i <= 10; i++) {
      spin.value = i.toDouble();
      await tester.pump();
    }
    expect(counting.invalidations, 0,
        reason: 'nothing about the source changed, so nothing should have '
            'invalidated its capture');
  });
}
