import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/internal/shader_programs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A LiquidFusion over the compositor (nativeBackdrop): the blur is the
// compositor's, clipped to the fused outline traced on the CPU, and the tint,
// rim and press are the fusion program drawn as a paint. Nothing is captured,
// so there is no screen limit to measure — the route that left a control cut
// short for a tenth of a second after every page transition.

const List<LiquidBlob> _rest = <LiquidBlob>[
  LiquidBlob(Rect.fromLTWH(0, 0, 144, 48)),
  LiquidBlob(Rect.fromLTWH(152, 0, 48, 48)),
];

Widget _fusion(List<LiquidBlob> blobs) => MaterialApp(
  home: Center(
    child: SizedBox(
      width: 200,
      height: 48,
      child: LiquidFusion(backdrop: nativeBackdrop, blobs: blobs),
    ),
  ),
);

bool _has(WidgetTester tester, String type) => find
    .byWidgetPredicate((Widget w) => w.runtimeType.toString() == type)
    .evaluate()
    .isNotEmpty;

Future<void> _loadPrograms(WidgetTester tester) async {
  await tester.pumpWidget(_fusion(_rest));
  for (int i = 0; i < 100 && !FluidGlassPrograms.instance.isReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(FluidGlassPrograms.instance.isReady, isTrue);
}

void main() {
  group('liquidFusionOutline', () {
    test('far apart: the rounded rectangles themselves', () {
      const List<LiquidBlob> far = <LiquidBlob>[
        LiquidBlob(Rect.fromLTWH(0, 0, 100, 48)),
        LiquidBlob(Rect.fromLTWH(140, 0, 48, 48)),
      ];
      final Path path = liquidFusionOutline(far);
      expect(path.contains(const Offset(50, 24)), isTrue);
      expect(path.contains(const Offset(164, 24)), isTrue);
      expect(path.contains(const Offset(120, 24)), isFalse);
      // The capsule's rounded end is round, not a box corner.
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 188, 48));
    });

    test('at rest the gap stays open; pressed together, a neck closes it', () {
      final Path rest = liquidFusionOutline(_rest, devicePixelRatio: 3);
      expect(rest.contains(const Offset(72, 24)), isTrue);
      expect(rest.contains(const Offset(176, 24)), isTrue);
      expect(rest.contains(const Offset(148, 24)), isFalse);

      const List<LiquidBlob> pressed = <LiquidBlob>[
        LiquidBlob(Rect.fromLTWH(0, 0, 150, 48)),
        LiquidBlob(Rect.fromLTWH(152, 0, 48, 48)),
      ];
      final Path neck = liquidFusionOutline(pressed, devicePixelRatio: 3);
      expect(neck.contains(const Offset(151, 24)), isTrue);
      // The neck is concave: narrower at the gap than the shapes beside it.
      expect(neck.contains(const Offset(151, 2)), isFalse);
      expect(neck.contains(const Offset(100, 2)), isTrue);
    });
  });

  group('over nativeBackdrop', () {
    setUp(
      () => GlassDeviceTier.instance
        ..reset()
        ..debugCeiling = GlassQuality.liquid
        ..pinnedQuality = GlassQuality.liquid,
    );
    tearDown(() => GlassDeviceTier.instance.reset());

    testWidgets('the compositor blurs the fused outline; nothing measured', (
      WidgetTester tester,
    ) async {
      await _loadPrograms(tester);
      await tester.pumpWidget(_fusion(_rest));
      await tester.pump();

      expect(_has(tester, '_PlainFusion'), isFalse);
      // The sampled route's screen-limit watcher is what lagged a landing
      // page; the compositor route has nothing to place.
      expect(_has(tester, '_MeasuredFusion'), isFalse);
      final Finder blur = find.descendant(
        of: find.byType(LiquidFusion),
        matching: find.byType(BackdropFilter),
      );
      expect(blur, findsOneWidget);
      expect(
        find.ancestor(of: blur, matching: find.byType(ClipPath)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('plain tier: separate frosted panels, no program', (
      WidgetTester tester,
    ) async {
      GlassDeviceTier.instance.pinnedQuality = GlassQuality.plain;
      await tester.pumpWidget(_fusion(_rest));
      await tester.pump();
      expect(_has(tester, '_PlainFusion'), isTrue);
    });
  });
}
