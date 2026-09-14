import 'dart:typed_data';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the canvas transform the loupe hands its backdrop, which is where
/// the magnification and [LiquidMagnifier.focalOffset] actually live.
class _RecordingBackdrop extends Backdrop {
  Float64List? transform;

  @override
  bool get isCoordinatesDependent => false;

  @override
  void drawBackdrop(BackdropDrawContext context) {
    transform = context.canvas.getTransform();
  }
}

/// The loupe only ever scales uniformly and translates, so the two numbers that
/// describe what it did are enough — no matrix algebra needed, and no
/// dependency on the host's own scale (a device pixel ratio, a parent
/// transform) leaking into the assertions.
class _Affine {
  const _Affine(this.scale, this.dx, this.dy);

  factory _Affine.of(Float64List m) => _Affine(m[0], m[12], m[13]);

  final double scale;
  final double dx;
  final double dy;

  /// What this transform did on top of [base].
  _Affine relativeTo(_Affine base) => _Affine(
    scale / base.scale,
    (dx - base.dx) / base.scale,
    (dy - base.dy) / base.scale,
  );

  Offset map(Offset p) => Offset(scale * p.dx + dx, scale * p.dy + dy);
}

Widget _host(Widget loupe) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 200, height: 200, child: Center(child: loupe)),
  ),
);

/// What the loupe added on top of simply sitting where it sits.
Future<_Affine> _localTransform(
  WidgetTester tester, {
  required double magnification,
  required Offset focalOffset,
  Size size = const Size(128, 96),
}) async {
  final _RecordingBackdrop baseline = _RecordingBackdrop();
  await tester.pumpWidget(
    _host(
      LiquidMagnifier(
        backdrop: baseline,
        size: size,
        magnification: 1,
        focalOffset: Offset.zero,
      ),
    ),
  );

  final _RecordingBackdrop probe = _RecordingBackdrop();
  await tester.pumpWidget(
    _host(
      LiquidMagnifier(
        backdrop: probe,
        size: size,
        magnification: magnification,
        focalOffset: focalOffset,
      ),
    ),
  );

  return _Affine.of(
    probe.transform!,
  ).relativeTo(_Affine.of(baseline.transform!));
}

void main() {
  testWidgets('renders at the size asked for', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        LiquidMagnifier(
          backdrop: _RecordingBackdrop(),
          size: const Size(120, 80),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LiquidMagnifier)), const Size(120, 80));
  });

  testWidgets('magnifies about its own centre', (WidgetTester tester) async {
    const Size size = Size(128, 96);
    final _Affine local = await _localTransform(
      tester,
      magnification: 1.5,
      focalOffset: Offset.zero,
      size: size,
    );

    expect(local.scale, closeTo(1.5, 1e-9));
    // The centre is the fixed point: it maps to itself.
    final Offset centre = Offset(size.width / 2, size.height / 2);
    expect(local.map(centre).dx, closeTo(centre.dx, 1e-6));
    expect(local.map(centre).dy, closeTo(centre.dy, 1e-6));
  });

  testWidgets('focalOffset brings what lies at that offset into the middle', (
    WidgetTester tester,
  ) async {
    const Size size = Size(128, 96);
    const Offset focal = Offset(0, 80);
    final _Affine local = await _localTransform(
      tester,
      magnification: 1.5,
      focalOffset: focal,
      size: size,
    );

    // The point the loupe is told to look at is the one that ends up under its
    // centre — 80 below itself by default, so a finger on it is not in the way.
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final Offset mapped = local.map(centre + focal);
    expect(mapped.dx, closeTo(centre.dx, 1e-6));
    expect(mapped.dy, closeTo(centre.dy, 1e-6));
  });

  testWidgets('a child sizes the loupe and draws over the magnified pixels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LiquidMagnifier(
          backdrop: _RecordingBackdrop(),
          child: const SizedBox(width: 90, height: 60, child: Text('2x')),
        ),
      ),
    );

    expect(find.text('2x'), findsOneWidget);
    expect(tester.getSize(find.byType(LiquidMagnifier)), const Size(90, 60));
  });

  test('magnification has to be positive', () {
    expect(
      () => LiquidMagnifier(backdrop: _RecordingBackdrop(), magnification: 0),
      throwsAssertionError,
    );
  });
}
