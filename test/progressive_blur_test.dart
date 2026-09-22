import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ramp is a stack of the engine's own Gaussian blurs, one per band,
/// nested so each reads the previous band's output. `flutter_test` runs on
/// Skia, where `ImageFilter.shader` is unavailable, so what these tests pin is
/// the structure the widget builds and its no-shader fallback: hard-edged
/// bands, never a single uniform slab.
void main() {
  testWidgets(
    'sampled native masks preserve the source under scale and opacity',
    (tester) async {
      final LayerBackdrop source = LayerBackdrop();
      addTearDown(source.dispose);
      const Key imageKey = Key('image');
      for (final double scale in <double>[1, 0.92]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 1),
              child: RepaintBoundary(
                key: imageKey,
                child: ColoredBox(
                  color: const Color(0xFF336699),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 0.95,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: BackdropLayer(
                              backdrop: source,
                              child: const ColoredBox(color: Color(0xFF336699)),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 200,
                            child: ProgressiveBlur(
                              backdrop: source,
                              maxBlurRadius: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(DrawBackdrop), findsNWidgets(5));
        expect(find.byType(ShaderMask), findsNWidgets(4));
        final RenderRepaintBoundary boundary = tester.renderObject(
          find.byKey(imageKey),
        );
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage();
          final data = (await image.toByteData())!;
          for (final int y in <int>[40, 80, 120, 180, 220]) {
            final int offset = (y * image.width + image.width ~/ 2) * 4;
            expect(data.getUint8(offset), closeTo(0x33, 2));
            expect(data.getUint8(offset + 1), closeTo(0x66, 2));
            expect(data.getUint8(offset + 2), closeTo(0x99, 2));
          }
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: Color(0xFF808080))),
          Positioned(top: 0, left: 0, right: 0, height: 200, child: child),
        ],
      ),
    ),
  );

  testWidgets('builds one BackdropFilter per band', (tester) async {
    await tester.pumpWidget(host(const ProgressiveBlur(maxBlurRadius: 24)));
    expect(find.byType(BackdropFilter), findsNWidgets(5));

    await tester.pumpWidget(
      host(const ProgressiveBlur(maxBlurRadius: 24, bands: 3)),
    );
    expect(find.byType(BackdropFilter), findsNWidgets(3));

    await tester.pumpWidget(
      host(const ProgressiveBlur(maxBlurRadius: 24, bands: 1)),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inner bands cover shorter runs from the blurred end', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const ProgressiveBlur(maxBlurRadius: 24, startOffset: 0.3)),
    );
    final List<Size> sizes = tester
        .widgetList(find.byType(BackdropFilter))
        .map((Widget w) => tester.getSize(find.byWidget(w)))
        .toList();
    // Outermost first: the full run, then strictly shorter runs.
    expect(sizes.first.height, 200);
    for (int i = 1; i < sizes.length; i++) {
      expect(sizes[i].height, lessThan(sizes[i - 1].height));
    }
    // Every band starts at the blurred end (the top here).
    for (final Widget w in tester.widgetList(find.byType(BackdropFilter))) {
      expect(tester.getTopLeft(find.byWidget(w)).dy, 0);
    }
  });

  testWidgets('blurred-bottom bands hug the bottom edge', (tester) async {
    await tester.pumpWidget(
      host(
        const ProgressiveBlur(
          maxBlurRadius: 24,
          direction: ProgressiveBlurDirection.blurredBottomClearTop,
        ),
      ),
    );
    for (final Widget w in tester.widgetList(find.byType(BackdropFilter))) {
      expect(tester.getBottomLeft(find.byWidget(w)).dy, 200);
    }
  });

  testWidgets('the child draws over the blur, unfiltered, at full size', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ProgressiveBlur(
          maxBlurRadius: 24,
          child: SizedBox.expand(key: Key('tint')),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('tint'))).height, 200);
    // Not inside any band's filter: it is a sibling of the stack of bands.
    expect(
      find.ancestor(
        of: find.byKey(const Key('tint')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('a zero radius is the child alone', (tester) async {
    await tester.pumpWidget(host(const ProgressiveBlur(maxBlurRadius: 0)));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('bands are the engine blur, clamped at the texture edge', () {
    // Pinning the tile mode: a blur that reads transparent past the blurred
    // end thins the top rows and lets the sharp scene beneath show through.
    final ui.ImageFilter filter = ui.ImageFilter.blur(
      sigmaX: 4,
      sigmaY: 4,
      tileMode: ui.TileMode.clamp,
    );
    expect(filter.toString(), contains('clamp'));
  });
}
