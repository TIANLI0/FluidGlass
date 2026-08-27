import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');

/// A 200×200 view holding a 100×100 opaque glass element at the top left,
/// transformed by [block].
Widget _host(GlassLayerBlock block) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _boundary,
        child: Container(
          width: 200,
          height: 200,
          color: const Color(0xFFFFFFFF),
          child: Align(
            alignment: Alignment.topLeft,
            child: DrawBackdrop.plain(
              backdrop: emptyBackdrop,
              shape: () => const RoundedRectangle(0),
              effects: (BackdropEffectScope scope) {},
              layerBlock: block,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Color(0xFF000000)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<_Coverage> _coverage(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List pixels = data!.buffer.asUint8List();
  int? left, top, right, bottom;
  for (int y = 0; y < 200; y++) {
    for (int x = 0; x < 200; x++) {
      // Anything appreciably darker than the white ground is the element.
      if (pixels[(y * 200 + x) * 4] < 200) {
        left = left == null || x < left ? x : left;
        right = right == null || x > right ? x : right;
        top = top == null || y < top ? y : top;
        bottom = bottom == null || y > bottom ? y : bottom;
      }
    }
  }
  return _Coverage(left, top, right, bottom);
}

class _Coverage {
  const _Coverage(this.left, this.top, this.right, this.bottom);
  final int? left;
  final int? top;
  final int? right;
  final int? bottom;
  bool get isEmpty => left == null;
  @override
  String toString() => 'l=$left t=$top r=$right b=$bottom';
}

void main() {
  // Regression: `pushOpacity` appends a layer to the enclosing *container*
  // layer, so it never saw a matrix that `pushTransform` had applied straight
  // to the canvas. An element that scaled and faded at once therefore painted
  // its child at full size — a menu blooming out of its anchor snapped between
  // 61% and 100% the instant its alpha crossed 1.0, twice per open/close.
  testWidgets('a glass element that scales and fades scales its child too',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(200, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host((GlassLayer layer) {
      layer.transformOrigin = Offset.zero;
      layer.scaleX = 0.5;
      layer.scaleY = 0.5;
      layer.alpha = 1.0;
    }));
    final _Coverage opaque = await _coverage(tester);
    expect(opaque.isEmpty, isFalse);
    expect(opaque.right, lessThan(55), reason: 'opaque: scaled to 50×50');
    expect(opaque.bottom, lessThan(55));

    await tester.pumpWidget(_host((GlassLayer layer) {
      layer.transformOrigin = Offset.zero;
      layer.scaleX = 0.5;
      layer.scaleY = 0.5;
      layer.alpha = 0.6;
    }));
    final _Coverage faded = await _coverage(tester);
    expect(faded.isEmpty, isFalse);
    expect(faded.right, lessThan(55),
        reason: 'the fade must not undo the scale — $faded');
    expect(faded.bottom, lessThan(55),
        reason: 'the fade must not undo the scale — $faded');
  });
}
