import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 200;
const int _h = 200;

/// Inside the glass, clear of its edges.
const Rect _inside = Rect.fromLTRB(80, 80, 120, 120);

/// Outside it, on the raw source.
const Rect _outside = Rect.fromLTRB(10, 10, 50, 50);

bool _hasBackdropFilterLayer(Layer? layer) {
  if (layer == null) return false;
  if (layer is BackdropFilterLayer) return true;
  if (layer is! ContainerLayer) return false;
  for (Layer? child = layer.firstChild;
      child != null;
      child = child.nextSibling) {
    if (_hasBackdropFilterLayer(child)) return true;
  }
  return false;
}

Layer? _sceneLayer(WidgetTester tester) =>
    (tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary)
        .debugLayer;

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

/// How much the luminance varies across [box]: a filtered region is smooth.
double _spread(Uint8List p, Rect box) {
  final List<double> values = <double>[];
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      values.add((p[i] + p[i + 1] + p[i + 2]) / 3);
    }
  }
  final double mean =
      values.reduce((double a, double b) => a + b) / values.length;
  return values
          .map((double v) => (v - mean) * (v - mean))
          .reduce((double a, double b) => a + b) /
      values.length;
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final Paint black = Paint()..color = const Color(0xFF000000);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glass on [nativeBackdrop] over stripes painted *beneath* it.
Widget _host() {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(child: CustomPaint(painter: _Stripes())),
                Positioned(
                  left: 60,
                  top: 60,
                  child: DrawBackdrop.plain(
                    backdrop: nativeBackdrop,
                    shape: () => const Rectangle(),
                    effects: (BackdropEffectScope scope) => scope.blur(8),
                    child: const SizedBox(width: 80, height: 80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => GlassDeviceTier.instance.reset());
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('the chain becomes a compositor filter, with no capture', (
    WidgetTester tester,
  ) async {
    // Even with the liquid tier forced: a compositor-only backdrop has no
    // texture for the lens to bend, so the element must not try to sample it.
    GlassDeviceTier.instance
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(_hasBackdropFilterLayer(_sceneLayer(tester)), isTrue);
  });

  testWidgets('it blurs what is painted beneath it', (
    WidgetTester tester,
  ) async {
    GlassDeviceTier.instance
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;

    await tester.pumpWidget(_host());
    await tester.pump();

    final Uint8List p = await _pixels(tester);
    expect(
      _spread(p, _outside),
      greaterThan(1000),
      reason: 'the raw stripes keep their contrast',
    );
    expect(
      _spread(p, _inside),
      lessThan(400),
      reason: 'inside the glass they are flattened',
    );
  });

  testWidgets('nativeBackdrop is a value', (WidgetTester tester) async {
    expect(nativeBackdrop, const NativeBackdrop());
    expect(nativeBackdrop.isCompositorOnly, isTrue);
    expect(nativeBackdrop.isPaintedBehindConsumer, isTrue);
    expect(nativeBackdrop.isCoordinatesDependent, isFalse);
  });
}
