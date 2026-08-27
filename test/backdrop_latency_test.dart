import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 200;
const int _h = 400;
const double _extent = 400;

/// One solid colour per row, so "which row is the glass showing" is answerable
/// from a single pixel.
const List<Color> _rows = <Color>[
  Color(0xFFFF0000),
  Color(0xFF00FF00),
  Color(0xFF0000FF),
  Color(0xFFFFFF00),
  Color(0xFF00FFFF),
  Color(0xFFFF00FF),
];

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
                    itemExtent: _extent,
                    itemCount: _rows.length,
                    itemBuilder: (BuildContext context, int i) =>
                        ColoredBox(color: _rows[i]),
                  ),
                ),
              ),
              // No blur, no tint: the glass shows exactly what it sampled.
              Positioned(
                left: 50,
                top: 150,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => const Rectangle(),
                  effects: (BackdropEffectScope scope) {},
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The colour in the middle of the glass.
Future<List<int>> _glassRgb(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  const int x = 100;
  const int y = 200;
  final int i = (y * _w + x) * 4;
  return <int>[p[i], p[i + 1], p[i + 2]];
}

int _nearestRow(List<int> rgb) {
  int best = -1;
  int bestScore = 1 << 30;
  for (int i = 0; i < _rows.length; i++) {
    final Color c = _rows[i];
    final int score = ((c.r * 255 - rgb[0]).abs() +
            (c.g * 255 - rgb[1]).abs() +
            (c.b * 255 - rgb[2]).abs())
        .round();
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
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

  testWidgets('the glass shows the current frame, not the previous one',
      (WidgetTester tester) async {
    // "Rendering latency": during a scroll the content inside the glass trails
    // the content around it. The capture is taken while the glass paints, so
    // whether it is fresh depends on whether the source's layer has already
    // been repainted this frame — which is an ordering question, not a
    // throughput one, and no amount of making the capture cheaper fixes it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();
    await tester.pump();

    final List<String> log = <String>[];
    int lagging = 0;

    for (int step = 1; step < _rows.length; step++) {
      // Put row `step` squarely under the glass.
      controller.jumpTo(step * _extent);
      await tester.pump();
      final int shown = _nearestRow(await _glassRgb(tester));
      log.add('after jump to row $step the glass showed row $shown');
      if (shown != step) lagging += 1;
    }

    expect(lagging, 0, reason: log.join('\n'));
  });

  testWidgets('the glass keeps up during a real drag',
      (WidgetTester tester) async {
    // The path a finger takes: a drag updates the offset from a pointer event,
    // not from `jumpTo`. Compare what the glass shows against the row actually
    // under it on that same frame.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();
    await tester.pump();

    final TestGesture gesture =
        await tester.startGesture(const Offset(100, 200));
    final List<String> log = <String>[];
    int wrong = 0;

    // Drag upwards a row at a time; after each frame the glass must agree with
    // the offset that frame was laid out at.
    for (int step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(0, -_extent / 2));
      await tester.pump();
      final int shown = _nearestRow(await _glassRgb(tester));
      // The glass covers y 150..250 of the viewport; sample its centre, y=200.
      final int expected = ((controller.offset + 200) / _extent).floor();
      log.add('offset=${controller.offset.toStringAsFixed(0)} '
          'expected row $expected, glass showed $shown');
      if (shown != expected) wrong += 1;
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(wrong, 0, reason: log.join(' | '));
  });
}
