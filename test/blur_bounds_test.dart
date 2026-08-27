import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 320;
const int _h = 320;
const double _blur = 24;

/// A hard black-and-white checkerboard: every pixel of the source is either
/// 0 or 255, so anything grey outside the glass can only have come from the
/// glass.
class _Checker extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 20;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final Paint black = Paint()..color = const Color(0xFF000000);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()).isEven) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), black);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Checker oldDelegate) => false;
}

/// Flat mid-grey. Clamping a uniform source is exactly itself, so any
/// darkening at an edge can only be transparency that was blurred in.
Widget _flatHost({required Rect glass}) {
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
                  child: const ColoredBox(color: Color(0xFF808080)),
                ),
              ),
              Positioned(
                left: glass.left,
                top: glass.top,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => const Rectangle(),
                  effects: (BackdropEffectScope scope) => scope.blur(_blur),
                  child: SizedBox(width: glass.width, height: glass.height),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _host({required Rect glass, required RoundedRectangularShape shape}) {
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
                  child: CustomPaint(painter: _Checker()),
                ),
              ),
              Positioned(
                left: glass.left,
                top: glass.top,
                child: DrawBackdrop.plain(
                  backdrop: backdrop,
                  shape: () => shape,
                  effects: (BackdropEffectScope scope) => scope
                    ..vibrancy()
                    ..blur(_blur),
                  child: SizedBox(width: glass.width, height: glass.height),
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

int _red(Uint8List p, int x, int y) => p[(y * _w + x) * 4];

double _meanRed(Uint8List p, Rect box) {
  int total = 0;
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      total += _red(p, x, y);
      count += 1;
    }
  }
  return total / count;
}

void main() {
  setUp(() {
    // Nothing here needs a real device tier; keep the ceiling honest.
    GlassDeviceTier.instance
      ..reset()
      // The padded layer and its clamped edges only exist on the sampled
      // path; the tier would otherwise be plain under `flutter_test`, which
      // filters the scene in place and has no padded layer at all.
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });

  testWidgets('a rectangular element does not bleed its blur outside itself',
      (WidgetTester tester) async {
    // Regression: the clip was skipped whenever the outline was a rectangle
    // covering the element — "a plain rectangle clips nothing away". True of
    // the element, false of what gets drawn: the backdrop goes into a layer
    // inflated by the blur radius so the blur has pixels to reach for, and
    // without the clip that layer bled `padding` logical pixels out on every
    // side, smearing whatever was behind it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      glass: const Rect.fromLTWH(80, 80, 160, 160),
      shape: const Rectangle(),
    ));
    await tester.pump();
    await tester.pump();
    final Uint8List p = await _pixels(tester);

    // A band just outside the element's right edge. Every source pixel there
    // is pure black or pure white; a bled blur shows up as grey.
    int greyish = 0;
    for (int x = 241; x < 241 + (_blur.round() - 2); x++) {
      for (int y = 100; y < 220; y++) {
        final int v = _red(p, x, y);
        if (v > 24 && v < 231) greyish += 1;
      }
    }
    expect(greyish, 0,
        reason: '$greyish pixels outside the element are neither black nor '
            'white, so the blur layer bled past its bounds');
  });

  testWidgets('blur is not starved at the edge of its source',
      (WidgetTester tester) async {
    // Regression: the capture covers the source and no more, so a blur reading
    // past it mixed in transparent black — a dark fringe along every edge where
    // the glass met the end of its source, which for app chrome is the edge of
    // the screen. The capture's outermost row and column are now extended
    // outwards, as TileMode.clamp would.
    //
    // The source is flat grey on purpose: clamping it is exactly itself, so the
    // whole element must come out that same grey. (Over a checkerboard the
    // corner legitimately darkens, because the pixel being replicated there is
    // black — that is clamping working, not starving.)
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Flush into the source's top-left corner.
    await tester.pumpWidget(_flatHost(glass: const Rect.fromLTWH(0, 0, 200, 200)));
    await tester.pump();
    await tester.pump();
    final Uint8List p = await _pixels(tester);

    final double interior = _meanRed(p, const Rect.fromLTWH(90, 90, 20, 20));
    expect(interior, closeTo(128, 6),
        reason: 'a blurred flat grey should still be that grey');

    for (final (Rect at, String where) probe in <(Rect, String)>[
      (const Rect.fromLTWH(0, 0, 8, 8), 'top-left corner'),
      (const Rect.fromLTWH(0, 96, 8, 8), 'left edge'),
      (const Rect.fromLTWH(96, 0, 8, 8), 'top edge'),
      (const Rect.fromLTWH(192, 0, 8, 8), 'top-right corner'),
      (const Rect.fromLTWH(0, 192, 8, 8), 'bottom-left corner'),
    ]) {
      final double v = _meanRed(p, probe.$1);
      expect((v - interior).abs(), lessThan(6.0),
          reason: 'the ${probe.$2} reads $v against an interior of $interior, '
              'so the blur is being starved where the source ends');
    }
  });
}
