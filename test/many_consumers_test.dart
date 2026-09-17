// Reproduces, without a device, the cost that a screen of many glass tiles
// pays: the control centre demo has thirteen consumers over one source, and
// the whole point of the capture cache is that they share images rather than
// each flushing the pipeline with its own `toImageSync`.
import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _size = Size(400, 800);

/// Thirteen tiles laid out like the control centre: two columns, stacked.
///
/// [shift] slides them the way the demo's spacers do while it is dragged, so
/// every consumer asks for a slightly different region each frame.
List<Widget> _tiles(LayerBackdrop backdrop, int count, {double shift = 0}) {
  return <Widget>[
    for (int i = 0; i < count; i++)
      Positioned(
        left: (i.isEven ? 20 : 210) + 0.0,
        top: 60.0 + (i ~/ 2) * 100 + shift * (i ~/ 2),
        child: DrawBackdrop.plain(
          backdrop: backdrop,
          shape: () => const RoundedRectangle(20),
          effects: (BackdropEffectScope scope) => scope..vibrancy(),
          child: const SizedBox(width: 160, height: 80),
        ),
      ),
  ];
}

Widget _frame(LayerBackdrop backdrop, Widget background, List<Widget> glass) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(backdrop: backdrop, child: background),
            ),
            ...glass,
          ],
        ),
      ),
    );

void main() {
  setUp(() {
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('many consumers over a changing source share one capture', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    // A source that changes every frame, like the wallpaper blur animating
    // under the control centre while it is dragged.
    final ValueNotifier<int> tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);

    Widget build(double shift) => _frame(
      backdrop,
      ListenableBuilder(
        listenable: tick,
        builder: (BuildContext context, Widget? _) => ColoredBox(
          color: Color(0xFF000000 | (tick.value * 7919 % 0xFFFFFF)),
          child: const SizedBox.expand(),
        ),
      ),
      _tiles(backdrop, 13, shift: shift),
    );

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();

    final RenderBackdropLayer source = tester.renderObject(
      find.byType(BackdropLayer),
    );

    source.debugCaptureCount = 0;
    const int frames = 10;
    for (int i = 1; i <= frames; i++) {
      tick.value = i;
      await tester.pumpWidget(build(i * 1.5));
    }

    final double perFrame = source.debugCaptureCount / frames;
    // ignore: avoid_print
    print(
      'MANY| captures=${source.debugCaptureCount} '
      'frames=$frames perFrame=${perFrame.toStringAsFixed(2)}',
    );

    expect(
      perFrame,
      lessThan(1.2),
      reason:
          'thirteen tiles must share one capture per changed frame, '
          'not flush the pipeline several times',
    );
  });
}
