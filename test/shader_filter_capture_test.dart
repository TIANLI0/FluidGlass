import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A fragment-shader `ImageFilter` inside the source has to be rasterised
// against the source's own extent.
//
// Impeller can invert a blur, a matrix or a dilate to work out how much of the
// input a piece of output needs, so capturing one strip of the source still
// hands those filters the pixels they read. A fragment shader it cannot
// invert: the shader is handed whatever texture the pass rasterised into and
// reads that texture's size out of its first `vec2` uniform. Capture a strip
// and the shader is evaluated against the strip's extent, and draws something
// the screen never showed.
//
// Android's overscroll stretch is exactly this. `StretchEffect` picks
// `ImageFilter.shader` whenever `ImageFilter.isShaderFilterSupported`, which is
// every Impeller backend and so every Android device — and falls back to a
// plain `Transform` when it is false, which is what `flutter_test` runs. That
// split is why a bar pinned over a list showed a differently-stretched page all
// the way through a spring-back on a phone while every widget test passed.
//
// The end-to-end proof therefore cannot live here; it is
// `example/lib/probe_stretch_capture.dart`, which renders the real thing on the
// real backend and compares the glass against a native `BackdropFilter` frame
// by frame. What is pinned here is the two halves that test does not reach:
// which filters get classified as reading the extent, and what the capture path
// does once one is found.

const int _w = 240;
const int _h = 240;

Widget _frame(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: SizedBox(
      width: _w.toDouble(),
      height: _h.toDouble(),
      child: child,
    ),
  ),
);

Widget _bar(LayerBackdrop backdrop) => Positioned(
  left: 0,
  right: 0,
  bottom: 0,
  child: DrawBackdrop.plain(
    backdrop: backdrop,
    shape: () => const Rectangle(),
    effects: (BackdropEffectScope scope) => scope.blur(2),
    child: const SizedBox(height: 40, width: double.infinity),
  ),
);

Widget _page(ValueNotifier<double> t, {required bool filtered}) =>
    ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (BuildContext context, double v, Widget? child) {
        final Widget page = ColoredBox(
          color: Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
          child: const SizedBox.expand(),
        );
        if (!filtered) return page;
        // A filter that animates, so the walk sees a different filter object
        // every frame exactly as the overscroll stretch does.
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 1 + v, sigmaY: 1 + v),
          child: page,
        );
      },
    );

RenderBackdropLayer _source(WidgetTester tester) =>
    tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;

void main() {
  setUp(() {
    // The sampled path. Under `flutter_test` the tier would resolve to `plain`,
    // which never captures.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() {
    GlassDeviceTier.instance.reset();
    RenderBackdropLayer.debugImageFilterClassifier = null;
  });

  test('no filter that can be built here reads the capture extent', () {
    // If this ever stops being true, the stub the last test needs can be
    // replaced by a real `ImageFilter.shader` and the whole thing tested
    // end to end in one place.
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isFalse,
      reason: 'flutter_test is expected to run on Skia',
    );

    bool reads(ui.ImageFilter filter) =>
        RenderBackdropLayer.debugImageFilterReadsExtent(filter);

    final ui.ImageFilter blur = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4);
    final ui.ImageFilter matrix = ui.ImageFilter.matrix(
      Matrix4.identity().storage,
    );
    expect(reads(blur), isFalse);
    expect(reads(matrix), isFalse);
    expect(reads(ui.ImageFilter.dilate(radiusX: 2, radiusY: 2)), isFalse);
    expect(reads(ui.ImageFilter.erode(radiusX: 2, radiusY: 2)), isFalse);
    // A composed filter reports the descriptions of both halves, which is how a
    // shader hidden inside one is still seen.
    expect(
      reads(ui.ImageFilter.compose(outer: blur, inner: matrix)),
      isFalse,
    );
  });

  testWidgets('an ordinary image filter in the source still captures a strip', (
    WidgetTester tester,
  ) async {
    // The guard against overcorrecting: a blur, a matrix or anything else
    // Impeller can invert must not cost the whole source, or every app with an
    // `ImageFiltered` in its page pays for this fix on every frame.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);

    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: _page(t, filtered: true),
              ),
            ),
            _bar(backdrop),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source = _source(tester);
    t.value = 0.5;
    await tester.pump();
    await tester.pump();

    expect(source.debugLastCaptureRegion, isNotNull);
    expect(
      source.debugLastCaptureRegion!.height,
      lessThan(_h / 2),
      reason: 'the bar reads a 40dp strip, so that is all that should be taken',
    );
  });

  testWidgets('a shader filter in the source makes the capture the whole source', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);

    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: _page(t, filtered: true),
              ),
            ),
            _bar(backdrop),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source = _source(tester);
    final Rect? strip = source.debugLastCaptureRegion;
    expect(strip, isNotNull);
    expect(strip!.height, lessThan(_h / 2));

    // Now the same scene, with the one filter in it read as a shader. The strip
    // already held must not be reused — it holds pixels the shader was drawn
    // into at the wrong extent — and the capture that replaces it must cover
    // the source.
    RenderBackdropLayer.debugImageFilterClassifier = (ui.ImageFilter _) => true;
    t.value = 0.5;
    await tester.pump();
    await tester.pump();

    expect(
      source.debugLastCaptureRegion,
      Offset.zero & Size(_w.toDouble(), _h.toDouble()),
      reason: 'a shader filter has to be rasterised against the whole source',
    );
  });

  testWidgets('the whole-source capture lasts only while the filter is there', (
    WidgetTester tester,
  ) async {
    // The stretch is gone the moment the spring settles, and the capture has to
    // narrow again with it: this is not a latch.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);
    final ValueNotifier<bool> filtered = ValueNotifier<bool>(true);
    addTearDown(filtered.dispose);

    RenderBackdropLayer.debugImageFilterClassifier = (ui.ImageFilter _) => true;
    await tester.pumpWidget(
      _frame(
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: backdrop,
                child: ValueListenableBuilder<bool>(
                  valueListenable: filtered,
                  builder: (BuildContext context, bool on, Widget? _) =>
                      _page(t, filtered: on),
                ),
              ),
            ),
            _bar(backdrop),
          ],
        ),
      ),
    );
    await tester.pump();
    t.value = 0.3;
    await tester.pump();
    await tester.pump();
    expect(
      _source(tester).debugLastCaptureRegion,
      Offset.zero & Size(_w.toDouble(), _h.toDouble()),
    );

    filtered.value = false;
    await tester.pump();
    await tester.pump();
    t.value = 0.6;
    await tester.pump();
    await tester.pump();

    expect(
      _source(tester).debugLastCaptureRegion!.height,
      lessThan(_h / 2),
      reason: 'with the filter gone the capture must narrow back to the strip',
    );
  });
}
