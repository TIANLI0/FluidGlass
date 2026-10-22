import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/internal/sampling_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A glass element whose source has not changed still costs its whole effect
// chain on every frame something *else* on the page repaints — the frame is
// composited again around it, and a reused picture replays every blur. These
// tests pin the way out: from the second unchanged frame the glass is drawn
// from one rasterised image, the image is exactly what the live chain draws,
// and content that changes every frame never pays for a rasterisation.

const double _w = 240;
const double _h = 240;

/// A repaint well away from the glass, behind its own repaint boundary: an
/// animated sticker in the middle of a chat, a spinner at the top of a page.
Widget _pulse(ValueNotifier<double> t) => RepaintBoundary(
  child: ValueListenableBuilder<double>(
    valueListenable: t,
    builder: (BuildContext context, double v, Widget? _) => ColoredBox(
      color: Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
    ),
  ),
);

Widget _stripes(ScrollController controller) => ListView.builder(
  controller: controller,
  itemExtent: 23,
  itemCount: 60,
  itemBuilder: (BuildContext context, int i) =>
      ColoredBox(color: Color(0xFF000000 | (i * 0x2F1B37 & 0xFFFFFF))),
);

Widget _page({
  required LayerBackdrop backdrop,
  required ValueNotifier<double> pulse,
  required ScrollController controller,
  double barTop = _h - 47.3,
  double blur = 6,
  ValueNotifier<double>? underGlass,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: RepaintBoundary(
        key: const Key('screen'),
        child: SizedBox(
          width: _w,
          height: _h,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: backdrop,
                  child: Stack(
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          SizedBox(height: 50, width: _w, child: _pulse(pulse)),
                          Expanded(child: _stripes(controller)),
                        ],
                      ),
                      if (underGlass != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: barTop,
                          height: 36,
                          child: _pulse(underGlass),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10.4,
                right: 10.4,
                top: barTop,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => const RoundedRectangle(14),
                  effects: (BackdropEffectScope scope) {
                    if (blur > 0) scope.blur(blur);
                  },
                  child: const SizedBox(height: 36, width: double.infinity),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<SamplingLayer> _samplingLayers(WidgetTester tester) {
  final List<SamplingLayer> found = <SamplingLayer>[];
  void visit(Layer? layer) {
    while (layer != null) {
      if (layer is SamplingLayer) found.add(layer);
      if (layer is ContainerLayer) visit(layer.firstChild);
      layer = layer.nextSibling;
    }
  }

  visit(tester.binding.renderViews.first.debugLayer);
  return found;
}

Future<Uint8List> _screenPixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject(find.byKey(const Key('screen')))
          as RenderRepaintBoundary;
  // Real async: rasterising and reading back do not run under fake time.
  final Uint8List? pixels = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final ByteData? bytes = await image.toByteData();
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  return pixels!;
}

void main() {
  setUp(() {
    // The sampled path. Under `flutter_test` the tier would resolve to `plain`,
    // which draws through the compositor and never samples.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  Future<(LayerBackdrop, ValueNotifier<double>, ScrollController)> pumpPage(
    WidgetTester tester, {
    double dpr = 3,
    double blur = 6,
  }) async {
    tester.view.physicalSize = Size(_w * dpr, _h * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> pulse = ValueNotifier<double>(0);
    addTearDown(pulse.dispose);
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _page(
        backdrop: backdrop,
        pulse: pulse,
        controller: controller,
        blur: blur,
      ),
    );
    await tester.pump();
    return (backdrop, pulse, controller);
  }

  testWidgets(
    'a repaint elsewhere: from the second unchanged frame the glass is an image',
    (WidgetTester tester) async {
      final (_, ValueNotifier<double> pulse, _) = await pumpPage(tester);
      final SamplingLayer layer = _samplingLayers(tester).single;

      final List<bool> drewFromImage = <bool>[];
      for (int i = 1; i <= 5; i++) {
        pulse.value = i / 5;
        await tester.pump();
        drewFromImage.add(layer.debugDrewFromImage);
      }
      expect(drewFromImage, everyElement(isTrue));
    },
  );

  testWidgets('content moving under the glass is drawn live, every frame', (
    WidgetTester tester,
  ) async {
    final (_, _, ScrollController controller) = await pumpPage(tester);
    final SamplingLayer layer = _samplingLayers(tester).single;

    final List<bool> drewFromImage = <bool>[];
    for (int i = 1; i <= 6; i++) {
      controller.jumpTo(i * 7.0);
      await tester.pump();
      drewFromImage.add(layer.debugDrewFromImage);
    }
    expect(drewFromImage, everyElement(isFalse));

    // It settles: the next unchanged frame goes back to the image.
    await tester.pump();
    await tester.pump();
    expect(layer.debugDrewFromImage, isTrue);
  });

  group('how many unchanged frames it takes', () {
    /// Composites [layer] once, the way a frame does.
    void composite(SamplingLayer layer) {
      final ui.SceneBuilder builder = ui.SceneBuilder();
      layer.addToScene(builder);
      builder.build().dispose();
    }

    SamplingLayer layerWith(int Function() signature) =>
        SamplingLayer()..configure(
          bounds: const Rect.fromLTWH(0, 0, 40, 20),
          signature: signature,
          draw: (Canvas canvas) => canvas.drawRect(
            const Rect.fromLTWH(0, 0, 40, 20),
            Paint()..color = const Color(0xFF336699),
          ),
          layerToDevice: () => Matrix4.diagonal3Values(3, 3, 1),
        );

    test('unchanged content is rasterised once and reused', () {
      final SamplingLayer layer = layerWith(() => 1);
      addTearDown(layer.dispose);
      for (int i = 0; i < 20; i++) {
        composite(layer);
      }
      expect(layer.debugRasterizations, 1);
      expect(layer.debugDrewFromImage, isTrue);
    });

    test('content that changes every other frame stops being rasterised', () {
      // Two animations taking turns, one of them under the glass: every
      // second frame sees the glass unchanged, and the next one changes it.
      int frame = 0;
      final SamplingLayer layer = layerWith(() => frame ~/ 2);
      addTearDown(layer.dispose);
      for (frame = 0; frame < 80; frame++) {
        composite(layer);
      }
      expect(layer.debugRasterizations, lessThanOrEqualTo(6));
    });

    test('once the content settles, an image that lasts resets the wait', () {
      int frame = 0;
      int signature() => frame < 40 ? frame ~/ 2 : 1000;
      final SamplingLayer layer = layerWith(signature);
      addTearDown(layer.dispose);
      for (frame = 0; frame < 40; frame++) {
        composite(layer);
      }
      final int before = layer.debugRasterizations;
      // Settled: one image, which lasts.
      for (frame = 40; frame < 100; frame++) {
        composite(layer);
      }
      expect(layer.debugRasterizations - before, 1);
      expect(layer.debugDrewFromImage, isTrue);
    });
  });

  for (final double blur in <double>[0, 6]) {
    for (final double dpr in <double>[1, 2.625, 3]) {
      testWidgets('the image lands on the live pixels (dpr $dpr, blur $blur)', (
        WidgetTester tester,
      ) async {
        await pumpPage(tester, dpr: dpr, blur: blur);
        final SamplingLayer layer = _samplingLayers(tester).single;

        // Live: the picture replayed through the effect chain.
        layer.invalidate();
        final Uint8List live = await _screenPixels(tester);
        expect(layer.debugDrewFromImage, isFalse);
        // Cached: the same content, drawn from the rasterised image.
        final Uint8List cached = await _screenPixels(tester);
        expect(layer.debugDrewFromImage, isTrue);

        // A misplaced image would shift every stripe edge under the glass:
        // hundreds of levels off, on every edge row. What two render paths
        // may disagree on is how an edge between device pixels is
        // anti-aliased — a few levels, on a row or two.
        int maxDiff = 0;
        final int widthPx = (_w * dpr).round();
        final Set<int> rows = <int>{};
        for (int i = 0; i < live.length; i++) {
          final int d = (live[i] - cached[i]).abs();
          if (d > maxDiff) maxDiff = d;
          if (d > 6) rows.add((i ~/ 4) ~/ widthPx);
        }
        expect(maxDiff, lessThanOrEqualTo(32));
        expect(rows.length, lessThanOrEqualTo(4));
      });
    }
  }
}
