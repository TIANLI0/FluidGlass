import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _fill(Canvas canvas, Size size) => canvas.drawRect(
  Offset.zero & size,
  Paint()..color = const Color(0xFFEEEEEE),
);

/// A pill and a circle eight apart, in a box exactly their size.
Widget _body({double? clipHeight, double shift = 0}) => MaterialApp(
  home: GlassQualityScope(
    quality: GlassQuality.liquid,
    child: Transform.translate(
      offset: Offset(shift, 0),
      child: Center(
        child: _maybeClip(
          clipHeight,
          SizedBox(
            width: 200,
            height: 48,
            child: LiquidFusion(
              backdrop: const CanvasBackdrop(_fill),
              blobs: const <LiquidBlob>[
                LiquidBlob(Rect.fromLTWH(0, 0, 144, 48)),
                LiquidBlob(Rect.fromLTWH(152, 0, 48, 48)),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

/// A clip [height] tall around the box, the box at its bottom — a card that
/// ends a little under the button it holds.
Widget _maybeClip(double? height, Widget child) => height == null
    ? child
    : ClipRect(
        child: SizedBox(
          width: 240,
          height: height,
          child: Align(alignment: const Alignment(0, 0.6), child: child),
        ),
      );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FluidGlass.ensureInitialized();
  });
  // `ImageFilter.shader` is unavailable under flutter_test, so the tier would
  // resolve to plain — which draws each shape as its own panel and never
  // measures a limit at all.
  setUp(
    () => GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid,
  );
  tearDown(() => GlassDeviceTier.instance.reset());

  /// Regression: the limit used to be reported only once two paints agreed,
  /// so a body painted exactly once — a button on a page that then sits still
  /// — never reported one, and kept its own box as the limit for good. That
  /// box is the shapes and nothing else: the shadow was cut off square at it
  /// and a press swelled into a hard edge.
  testWidgets('a body painted once still gets room around its shapes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_body());
    expect(
      find.byType(DrawBackdrop),
      findsOneWidget,
      reason: 'the shader path, not the plain fallback',
    );
    // The report lands after the frame; the rebuild it causes is the next one.
    await tester.pump();

    final Rect element = tester.getRect(find.byType(DrawBackdrop));
    final Rect box = tester.getRect(find.byType(LiquidFusion));
    expect(element.height, greaterThan(box.height + 40));
    expect(element.contains(box.center), isTrue);
  });

  /// A layer cut short by a clip hands the shader a smaller texture than the
  /// element it was told about, and the body comes out shifted and stretched
  /// off the content on it — so the element is kept inside the clip exactly as
  /// it is kept inside the screen.
  testWidgets('the room around the shapes stops at an enclosing clip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_body(clipHeight: 120));
    await tester.pump();

    final Rect element = tester.getRect(find.byType(DrawBackdrop));
    final Rect clip = tester.getRect(find.byType(ClipRect));
    final Rect box = tester.getRect(find.byType(LiquidFusion));
    expect(element.bottom, lessThanOrEqualTo(clip.bottom + 0.01));
    expect(element.top, greaterThanOrEqualTo(clip.top - 0.01));
    // Still room where the clip leaves some: above the shapes.
    expect(element.top, lessThan(box.top - 20));
  });

  /// Regression (2026-09-23, on the emulator): a page that slides in is first
  /// painted — and snapshotted for the transition — while it is still off to
  /// the right, and then painted exactly once more, at rest. The first limit
  /// was measured off-screen and cut the body with a straight vertical edge,
  /// the circle at the right end not drawn at all; with only one paint at rest
  /// there was never a second one to agree with, so it stayed cut for the life
  /// of the page.
  testWidgets('a body that lands after sliding in is never cut, and settles', (
    WidgetTester tester,
  ) async {
    // Most of the body off the right edge of an 800-wide screen.
    await tester.pumpWidget(_body(shift: 560));
    await tester.pump();
    final Rect box = tester.getRect(find.byType(LiquidFusion));
    Rect element = tester.getRect(find.byType(DrawBackdrop));
    expect(
      element.left <= box.left + 0.01 && element.right >= box.right - 0.01,
      isTrue,
      reason: 'a stale limit may trim the room around the shapes, never them',
    );

    // Landed: one paint at rest, then nothing moves.
    await tester.pumpWidget(_body());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    final Rect landed = tester.getRect(find.byType(LiquidFusion));
    element = tester.getRect(find.byType(DrawBackdrop));
    expect(
      element.right,
      greaterThan(landed.right + 20),
      reason: 'the room on the right comes back once it has settled',
    );
    expect(element.left, lessThan(landed.left - 20));
  });
}
