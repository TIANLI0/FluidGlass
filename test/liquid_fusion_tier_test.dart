import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/internal/shader_programs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Which body a LiquidFusion builds — the shader's, or the plain fallback — is
// decided by things that change without the widget being rebuilt: the
// fragment programs finishing their load, the device tier, and the reader's
// contrast setting. Each has to reach it.

void _fill(Canvas canvas, Size size) => canvas.drawRect(
  Offset.zero & size,
  Paint()..color = const Color(0xFFEEEEEE),
);

Widget _fusion({GlassQuality? quality, bool highContrast = false}) {
  return MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 48,
          child: LiquidFusion(
            backdrop: const CanvasBackdrop(_fill),
            quality: quality,
            blobs: const <LiquidBlob>[
              LiquidBlob(Rect.fromLTWH(0, 0, 144, 48)),
              LiquidBlob(Rect.fromLTWH(152, 0, 48, 48)),
            ],
          ),
        ),
      ),
    ),
  );
}

bool _isPlain(WidgetTester tester) => find
    .byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_PlainFusion')
    .evaluate()
    .isNotEmpty;

/// Builds a body and waits for the programs its build kicked off to load.
///
/// Their native half completes in real time, and their continuations run in
/// the test's fake zone, which only a pump turns — awaiting the load future
/// directly never returns.
Future<void> _loadPrograms(WidgetTester tester) async {
  await tester.pumpWidget(_fusion());
  for (int i = 0; i < 100 && _isPlain(tester); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(_isPlain(tester), isFalse, reason: 'the programs loaded');
}

void main() {
  setUp(
    () => GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid,
  );
  tearDown(() => GlassDeviceTier.instance.reset());

  // First in the file, while nothing in this isolate has loaded the programs.
  // Regression: the body was chosen once, at build, and nothing listened for
  // the load — so without `ensureInitialized` a first screen stayed three
  // separate panels until something unrelated rebuilt it.
  testWidgets('the fused body arrives once the programs have loaded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_fusion());
    expect(_isPlain(tester), isTrue, reason: 'no programs yet');

    // Waiting on the load itself, with pumps that rebuild nothing: whatever
    // makes the body appear has to be the load arriving.
    for (int i = 0; i < 100 && !FluidGlassPrograms.instance.isReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(FluidGlassPrograms.instance.isReady, isTrue);
    await tester.pump();
    expect(_isPlain(tester), isFalse);
  });

  testWidgets('a tier change reaches the fused body', (
    WidgetTester tester,
  ) async {
    await _loadPrograms(tester);
    await tester.pumpWidget(_fusion());
    expect(_isPlain(tester), isFalse);

    GlassDeviceTier.instance.pinnedQuality = GlassQuality.plain;
    await tester.pump();
    expect(_isPlain(tester), isTrue);
  });

  // Regression: the fused body pinned its inner element to the tier it had
  // resolved, and a pinned tier outranks high contrast, so the lens — and its
  // capture — kept running to paint an opaque tint.
  testWidgets('high contrast drops the fused body to plain', (
    WidgetTester tester,
  ) async {
    await _loadPrograms(tester);
    await tester.pumpWidget(_fusion(highContrast: true));
    expect(_isPlain(tester), isTrue);
  });

  testWidgets('a tier pinned on the widget still wins over high contrast', (
    WidgetTester tester,
  ) async {
    await _loadPrograms(tester);
    await tester.pumpWidget(
      _fusion(quality: GlassQuality.liquid, highContrast: true),
    );
    expect(_isPlain(tester), isFalse);
  });
}
