import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _toggle = Key('toggle');

Widget _host({
  bool selected = false,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<bool>? onSelect,
  LiquidGlassColors? colors,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: LiquidGlassTheme(
        colors: colors ?? LiquidGlassColors.light,
        child: Center(
          child: LiquidToggle(
            key: _toggle,
            selected: selected,
            onSelect: onSelect ?? (_) {},
            backdrop: CanvasBackdrop(
              (canvas, size) => canvas.drawRect(
                (Offset.zero & size).inflate(30),
                Paint()..color = Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

LayerBackdrop _track(WidgetTester tester) {
  final DrawBackdrop knob = tester.widget(find.byType(DrawBackdrop));
  final CombinedBackdrop combined = knob.backdrop as CombinedBackdrop;
  return (combined.backdrops.last as WrappedBackdrop).backdrop as LayerBackdrop;
}

void main() {
  testWidgets('toggle draws its track without a captured widget layer', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final LayerBackdropSource source = _track(tester).source!;
    expect(source, isNot(isA<RenderBackdropLayer>()));
    expect(source.sourceSize, const Size(64, 28));

    // Compare the complete replayed source against the original clip + fill.
    Future<List<int>> pixels(void Function(Canvas) paint) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      paint(Canvas(recorder));
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = picture.toImageSync(64, 28);
      final bytes = await tester.runAsync(() => image.toByteData());
      final List<int> result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    final actual = await pixels((canvas) => source.drawSource(canvas, 1));
    final expected = await pixels((canvas) {
      canvas.clipPath(
        const GlassShapeClipper(Capsule()).getClip(const Size(64, 28)),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 64, 28),
        Paint()..color = LiquidGlassColors.light.track,
      );
    });
    expect(actual, expected);
  });

  testWidgets('press animation reuses the glass widget and detaches cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final DrawBackdrop knob = tester.widget(find.byType(DrawBackdrop));
    final LayerBackdrop track = _track(tester);
    final Offset point =
        tester.getTopLeft(find.byKey(_toggle)) + const Offset(22, 14);
    final gesture = await tester.startGesture(point);
    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(tester.widget(find.byType(DrawBackdrop)), knob), isTrue);
      expect(track.source, isNot(isA<RenderBackdropLayer>()));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(track.source, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final TextDirection direction in TextDirection.values) {
    testWidgets('toggle drag works in $direction after track optimisation', (
      tester,
    ) async {
      bool? selected;
      await tester.pumpWidget(
        _host(direction: direction, onSelect: (bool value) => selected = value),
      );
      await tester.pumpAndSettle();
      final Offset origin = tester.getTopLeft(find.byKey(_toggle));
      final bool ltr = direction == TextDirection.ltr;
      final gesture = await tester.startGesture(
        origin + Offset(ltr ? 22 : 42, 14),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(ltr ? 20 : -20, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
