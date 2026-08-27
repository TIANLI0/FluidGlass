import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 240;
const int _h = 240;

/// Glass over the middle of a source, so whatever the source draws there has
/// to show up inside the glass.
Widget _host(Widget sourceContent) {
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
                child: BackdropLayer(backdrop: backdrop, child: sourceContent),
              ),
              Positioned(
                left: 60,
                top: 60,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => const RoundedRectangle(20),
                  // No blur, no tint: whatever comes out is what was sampled.
                  effects: (BackdropEffectScope scope) {},
                  child: const SizedBox(width: 120, height: 120),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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

/// Mean RGB of a box, so "did the sampled colour arrive" is one number each.
List<double> _meanRgb(Uint8List p, Rect box) {
  final List<double> sum = <double>[0, 0, 0];
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      sum[0] += p[i];
      sum[1] += p[i + 1];
      sum[2] += p[i + 2];
      count += 1;
    }
  }
  return <double>[sum[0] / count, sum[1] / count, sum[2] / count];
}

/// Inside the glass, well clear of its rounded corners.
const Rect _inside = Rect.fromLTWH(90, 90, 60, 60);

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


  Future<List<double>> sampled(WidgetTester tester, Widget source) async {
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(source));
    await tester.pump();
    await tester.pump();
    return _meanRgb(await _pixels(tester), _inside);
  }

  testWidgets('a plain coloured box in the source is sampled',
      (WidgetTester tester) async {
    final List<double> rgb =
        await sampled(tester, const ColoredBox(color: Color(0xFFFF0000)));
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[1], lessThan(60), reason: 'green channel: $rgb');
  });

  testWidgets('a rounded card drawn with a BoxDecoration is sampled',
      (WidgetTester tester) async {
    final List<double> rgb = await sampled(
      tester,
      Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFFFF0000),
          ),
        ),
      ),
    );
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[1], lessThan(60), reason: 'green channel: $rgb');
  });

  testWidgets('a rounded card made with ClipRRect is sampled',
      (WidgetTester tester) async {
    // ClipRRect puts a real compositing layer inside the captured subtree,
    // which is the interesting case: `toImageSync` has to composite it rather
    // than replay one picture.
    final List<double> rgb = await sampled(
      tester,
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(color: Color(0xFFFF0000)),
          ),
        ),
      ),
    );
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[1], lessThan(60), reason: 'green channel: $rgb');
  });

  testWidgets('a rounded card inside a scrollable is sampled',
      (WidgetTester tester) async {
    // The real shape of the app-chrome case: cards in a list, so the capture
    // has to reach through a viewport and a repaint boundary per item.
    final List<double> rgb = await sampled(
      tester,
      ListView.builder(
        itemExtent: 240,
        itemCount: 4,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFFF0000),
            ),
          ),
        ),
      ),
    );
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[1], lessThan(60), reason: 'green channel: $rgb');
  });

  testWidgets('many consumers all sample correctly',
      (WidgetTester tester) async {
    // The capture is taken per region now, so a pinned bar reading one strip
    // does not cost a whole-screen capture. Past a handful of distinct regions
    // that stops paying and the whole source is captured once instead — this
    // exercises that fallback, and asserts every consumer still gets the right
    // pixels either side of it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    const List<Color> bands = <Color>[
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFF00),
      Color(0xFF00FFFF),
      Color(0xFFFF00FF),
    ];

    await tester.pumpWidget(Directionality(
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
                    child: Stack(
                      children: <Widget>[
                        for (int i = 0; i < bands.length; i++)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: i * (_h / bands.length),
                            height: _h / bands.length,
                            child: ColoredBox(color: bands[i]),
                          ),
                      ],
                    ),
                  ),
                ),
                for (int i = 0; i < bands.length; i++)
                  Positioned(
                    left: 80,
                    top: i * (_h / bands.length) + 8,
                    child: DrawBackdrop.plain(
                      backdrop: backdrop,
                      shape: () => const RoundedRectangle(6),
                      effects: (BackdropEffectScope scope) {},
                      child: const SizedBox(width: 80, height: 24),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final Uint8List p = await _pixels(tester);
    for (int i = 0; i < bands.length; i++) {
      final double y = i * (_h / bands.length) + 8;
      final List<double> rgb = _meanRgb(p, Rect.fromLTWH(100, y + 6, 40, 12));
      final Color want = bands[i];
      expect((rgb[0] - want.r * 255).abs(), lessThan(24),
          reason: 'consumer $i sampled $rgb, wanted $want');
      expect((rgb[1] - want.g * 255).abs(), lessThan(24),
          reason: 'consumer $i sampled $rgb, wanted $want');
      expect((rgb[2] - want.b * 255).abs(), lessThan(24),
          reason: 'consumer $i sampled $rgb, wanted $want');
    }
  });
}
