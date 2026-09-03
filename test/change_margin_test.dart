import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// `BackdropLayer.changeMargin`: how far outside what the glass reads a repaint
// is still taken to reach it.
//
// A change is placed by the box of the render object that repainted, and a
// render object may paint past its box, so a margin is added. The default is
// generous; an app whose widgets overflow less can lower it, and a card deck
// animating just above a glass bar then stops costing the bar a capture per
// frame.

const int _w = 240;
const int _h = 240;

Widget _frame(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: SizedBox(width: _w.toDouble(), height: _h.toDouble(), child: child),
  ),
);

/// A box that repaints behind a repaint boundary of its own whenever [t]
/// moves, without anything around it repainting.
Widget _pulse(ValueNotifier<double> t) {
  return RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (BuildContext context, double v, Widget? _) => ColoredBox(
        color: Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
      ),
    ),
  );
}

/// A source with a glass bar along its bottom 40 pixels and a pulsing box
/// ending [gap] pixels above the bar.
Widget _host(
  LayerBackdrop backdrop,
  ValueNotifier<double> t, {
  required double gap,
  required double changeMargin,
}) {
  return _frame(
    Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            changeMargin: changeMargin,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: _h - 40.0 - gap,
                  width: _w.toDouble(),
                  child: _pulse(t),
                ),
                const Expanded(child: ColoredBox(color: Color(0xFF808080))),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _h - 40.0,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(2),
            child: const SizedBox(height: 40, width: double.infinity),
          ),
        ),
      ],
    ),
  );
}

Future<int> _capturesOverPulses(
  WidgetTester tester, {
  required double gap,
  required double changeMargin,
}) async {
  tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final LayerBackdrop backdrop = LayerBackdrop();
  addTearDown(backdrop.dispose);
  final ValueNotifier<double> t = ValueNotifier<double>(0);
  addTearDown(t.dispose);

  await tester.pumpWidget(
    _host(backdrop, t, gap: gap, changeMargin: changeMargin),
  );
  await tester.pump();
  await tester.pump();

  final RenderBackdropLayer source =
      tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;
  source.debugCaptureCount = 0;
  for (int i = 1; i <= 6; i++) {
    t.value = i / 6;
    await tester.pump();
    // The post-frame watch invalidates a frame late; give it that frame.
    await tester.pump();
  }
  return source.debugCaptureCount;
}

void main() {
  setUp(() {
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('a repaint inside the default margin costs a capture', (
    WidgetTester tester,
  ) async {
    // 40 pixels above the bar is within the 64 the default allows for a
    // widget painting past its box.
    final int captures = await _capturesOverPulses(
      tester,
      gap: 40,
      changeMargin: RenderBackdropLayer.defaultChangeMargin,
    );
    expect(captures, greaterThanOrEqualTo(6));
  });

  testWidgets('lowering changeMargin lets the same repaint be ignored', (
    WidgetTester tester,
  ) async {
    final int captures = await _capturesOverPulses(
      tester,
      gap: 40,
      changeMargin: 16,
    );
    expect(
      captures,
      0,
      reason:
          'the box ends 40 pixels above the bar; with a 16 pixel margin '
          'its repaints land nowhere the glass reads',
    );
  });

  testWidgets('a repaint within a lowered margin is still followed', (
    WidgetTester tester,
  ) async {
    final int captures = await _capturesOverPulses(
      tester,
      gap: 8,
      changeMargin: 16,
    );
    expect(captures, greaterThanOrEqualTo(6));
  });
}
