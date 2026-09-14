import 'dart:ui' as ui;

import 'package:fluid_glass/src/internal/glass_painters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('short pauses during geometry animation do not restart baking', () {
    final BakedDecoration cache = BakedDecoration();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    int bakes = 0;
    bool paint(int key) => cache.paint(
      canvas,
      ui.Offset.zero,
      key,
      const ui.Rect.fromLTWH(0, 0, 16, 16),
      1,
      alpha: 1,
      blendMode: ui.BlendMode.srcOver,
      bake: (ui.Canvas canvas) {
        bakes++;
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 16, 16), ui.Paint());
      },
    );
    try {
      expect(paint(0), isTrue);
      expect(paint(1), isTrue);
      expect(paint(2), isFalse);
      for (int key = 3; key < 33; key++) {
        expect(paint(key), isFalse);
        expect(
          paint(key),
          isFalse,
          reason: 'a one-frame pause must still use the direct path',
        );
      }
      expect(bakes, 2);
      expect(cache.isBypassed, isTrue);
      expect(
        paint(32),
        isTrue,
        reason: 'two stable frames should restore the cache',
      );
      expect(bakes, 3);
      expect(cache.isBypassed, isFalse);
      expect(paint(32), isTrue);
      expect(bakes, 3, reason: 'stable geometry must reuse its texture');
    } finally {
      recorder.endRecording().dispose();
      cache.dispose();
    }
  });

  test('bypassed frames preserve direct drawing pixels', () async {
    final BakedDecoration cache = BakedDecoration();
    const ui.Rect bounds = ui.Rect.fromLTWH(0, 0, 32, 32);
    void draw(ui.Canvas canvas) {
      canvas.drawCircle(
        const ui.Offset(16, 16),
        8,
        ui.Paint()
          ..color = const ui.Color(0xA0336699)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
      );
    }

    Future<List<int>> render(int key, {required bool useCache}) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      if (!useCache ||
          !cache.paint(
            canvas,
            ui.Offset.zero,
            key,
            bounds,
            1,
            alpha: 1,
            blendMode: ui.BlendMode.srcOver,
            bake: draw,
          )) {
        draw(canvas);
      }
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(32, 32);
      try {
        return (await image.toByteData())!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
        picture.dispose();
      }
    }

    try {
      await render(0, useCache: true);
      await render(1, useCache: true);
      final List<int> direct = await render(2, useCache: false);
      expect(direct.any((int value) => value != 0), isTrue);
      expect(await render(2, useCache: true), direct);
      expect(await render(2, useCache: true), direct);
    } finally {
      cache.dispose();
    }
  });
}
