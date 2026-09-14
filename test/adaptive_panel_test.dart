import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _wallpaper(Canvas canvas, Size size) => canvas.drawRect(
  Offset.zero & size,
  Paint()..color = const Color(0xFF404040),
);

void main() {
  testWidgets('the panel builds its content with a legible colour', (
    WidgetTester tester,
  ) async {
    final List<Color> seen = <Color>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidAdaptivePanel(
            backdrop: const CanvasBackdrop(_wallpaper),
            builder: (BuildContext context, Color contentColor) {
              seen.add(contentColor);
              return const SizedBox(width: 160, height: 160);
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(seen, isNotEmpty);
    expect(seen.last, anyOf(const Color(0xFF000000), const Color(0xFFFFFFFF)));
  });

  testWidgets('disposing leaves no timer behind', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidAdaptivePanel(
            backdrop: const CanvasBackdrop(_wallpaper),
            interval: const Duration(milliseconds: 50),
            builder: (BuildContext context, Color _) =>
                const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    // Replacing the subtree disposes the panel. A pending `Future.delayed`
    // would fail the test here rather than merely leak.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  test('content colour follows the reading', () {
    final BackdropLuminance dark = BackdropLuminance(
      vsync: const TestVSync(),
      initialValue: 0.1,
    );
    final BackdropLuminance light = BackdropLuminance(
      vsync: const TestVSync(),
      initialValue: 0.9,
    );

    expect(dark.value, closeTo(0.1, 1e-9));
    expect(dark.contentColor, const Color(0xFFFFFFFF));
    expect(light.contentColor, const Color(0xFF000000));

    dark.dispose();
    light.dispose();
  });

  test('resolution has to be positive', () {
    expect(
      () => BackdropLuminance(vsync: const TestVSync(), resolution: 0),
      throwsAssertionError,
    );
  });
}
