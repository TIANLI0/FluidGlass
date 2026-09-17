import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const double _w = 300;
const double _h = 80;

/// Inside the thumb over the first of two segments, clear of its rim.
const Rect _thumb = Rect.fromLTRB(30, 30, 120, 50);

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary render =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = render.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Mean channel values over [box].
(double, double, double) _mean(Uint8List p, Rect box) {
  double r = 0;
  double g = 0;
  double b = 0;
  int n = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w.round() + x) * 4;
      r += p[i];
      g += p[i + 1];
      b += p[i + 2];
      n++;
    }
  }
  return (r / n, g / n, b / n);
}

Future<void> _pump(WidgetTester tester, {Color? thumbColor}) async {
  tester.view.physicalSize = const Size(_w, _h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // A mid-grey ground: a white thumb reads lighter than it, a coloured
        // one reads as its own hue. Both are measurable against this.
        backgroundColor: const Color(0xFF808080),
        body: RepaintBoundary(
          key: _boundary,
          child: Center(
            child: SizedBox(
              width: 260,
              child: LiquidSegmentedControl(
                selectedIndex: 0,
                onSelected: (_) {},
                backdrop: emptyBackdrop,
                thumbColor: thumbColor,
                segments: const <Widget>[Text('A'), Text('B')],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the default thumb is the white it always was', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    final (double r, double g, double b) = _mean(await _pixels(tester), _thumb);

    // Neutral — no channel pulls away from the others.
    expect((r - g).abs(), lessThan(4));
    expect((g - b).abs(), lessThan(4));
    // And lighter than the grey ground it is drawn over.
    expect(r, greaterThan(0x80 + 16));
  });

  testWidgets('a supplied thumb colour is what gets washed over it', (
    WidgetTester tester,
  ) async {
    await _pump(tester, thumbColor: const Color(0xFFCC3311));
    final (double r, double g, double b) = _mean(await _pixels(tester), _thumb);

    // The wash carries its own hue: red dominates, and it is no longer neutral.
    expect(r, greaterThan(g + 30));
    expect(r, greaterThan(b + 30));
  });
}
