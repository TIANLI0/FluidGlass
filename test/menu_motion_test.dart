import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 400;
const int _h = 500;

Widget _host() {
  return RepaintBoundary(
    key: _boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Align(
          alignment: Alignment.topLeft,
          child: LiquidMenu(
            backdrop: emptyBackdrop,
            panelWidth: 200,
            items: const <LiquidMenuItem>[
              LiquidMenuItem(label: 'One'),
              LiquidMenuItem(label: 'Two'),
              LiquidMenuItem(label: 'Three'),
            ],
            anchorBuilder:
                (BuildContext context, bool isOpen, VoidCallback toggle) {
              return GestureDetector(
                onTap: toggle,
                child: const SizedBox(
                  width: 120,
                  height: 48,
                  child: Center(child: Text('anchor')),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// The bounding box of everything the menu paints below the anchor, in pixels.
///
/// The rows' text is the only dark ink down there, and it is drawn inside the
/// panel, so this box tracks the panel's painted size — which is the thing the
/// bloom is supposed to animate.
Future<Rect?> _panelInk(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  double? l, t, r, b;
  for (int y = 56; y < _h; y++) {
    for (int x = 0; x < _w; x++) {
      if (p[(y * _w + x) * 4] < 160) {
        l = l == null || x < l ? x.toDouble() : l;
        r = r == null || x > r ? x.toDouble() : r;
        t = t == null || y < t ? y.toDouble() : t;
        b = b == null || y > b ? y.toDouble() : b;
      }
    }
  }
  if (l == null) return null;
  return Rect.fromLTRB(l, t!, r! + 1, b! + 1);
}

void main() {
  testWidgets('the bloom never jumps in size, opening or closing',
      (WidgetTester tester) async {
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump();

    Future<List<Rect>> record(int frames) async {
      final List<Rect> boxes = <Rect>[];
      for (int i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final Rect? ink = await _panelInk(tester);
        if (ink != null) boxes.add(ink);
      }
      return boxes;
    }

    void check(String phase, List<Rect> boxes, {required bool growing}) {
      expect(boxes.length, greaterThan(6), reason: '$phase: too few frames');
      final double span = boxes.last.height - boxes.first.height;
      expect(growing ? span > 0 : span < 0, isTrue,
          reason: '$phase must change size overall, got $span');
      for (int i = 1; i < boxes.length; i++) {
        final double step = boxes[i].height - boxes[i - 1].height;
        // A monotone spring: never reverse direction, and never jump by more
        // than a fifth of the panel in one frame. Before the fix the panel
        // snapped between 61% and 100% in a single frame the moment its alpha
        // crossed 1.0 — that one-frame jump is what read as a flash.
        expect(growing ? step >= -1.0 : step <= 1.0, isTrue,
            reason: '$phase reversed at frame $i: '
                '${boxes[i - 1].height} -> ${boxes[i].height}');
        expect(step.abs(), lessThan(boxes.last.height.abs() * 0.25 + 8),
            reason: '$phase jumped at frame $i: '
                '${boxes[i - 1].height} -> ${boxes[i].height}');
      }
    }

    await tester.tap(find.text('anchor'));
    await tester.pump();
    check('opening', await record(20), growing: true);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(const Offset(380, 480));
    await tester.pump();
    check('closing', await record(14), growing: false);

    await tester.pump(const Duration(seconds: 1));
  });
}
