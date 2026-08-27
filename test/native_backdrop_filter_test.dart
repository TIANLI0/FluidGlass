import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 200;
const int _h = 200;

/// Whether anything in [layer]'s subtree is a [BackdropFilterLayer].
bool _hasBackdropFilterLayer(Layer? layer) {
  if (layer == null) return false;
  if (layer is BackdropFilterLayer) return true;
  if (layer is! ContainerLayer) return false;
  for (Layer? child = layer.firstChild; child != null; child = child.nextSibling) {
    if (_hasBackdropFilterLayer(child)) return true;
  }
  return false;
}

/// The layer subtree the scene was composited from.
///
/// `RenderDrawBackdrop` is not a repaint boundary, so its own `layer` is null:
/// the clip and the backdrop filter are appended to the enclosing container
/// layer, which is the test's own boundary.
Layer? _sceneLayer(WidgetTester tester) =>
    (tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary).debugLayer;

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

List<double> _meanRgb(Uint8List p, Rect box) {
  final List<double> sum = <double>[0, 0, 0];
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      sum[0] += p[i];
      sum[1] += p[i + 1];
      sum[2] += p[i + 2];
      count += 1;
    }
  }
  return <double>[sum[0] / count, sum[1] / count, sum[2] / count];
}

Widget _frame(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: child,
          ),
        ),
      ),
    );

/// Glass in the middle of a source, clear of every edge.
const Rect _inside = Rect.fromLTWH(85, 85, 30, 30);

Widget _host({required Widget source, required LayerBackdrop backdrop}) {
  final LayerBackdrop layerBackdrop = backdrop;
  return _frame(Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      Positioned.fill(
        child: BackdropLayer(backdrop: layerBackdrop, child: source),
      ),
      Positioned(
        left: 60,
        top: 60,
        child: DrawBackdrop.plain(
          backdrop: layerBackdrop,
          shape: () => const Rectangle(),
          effects: (BackdropEffectScope scope) => scope.blur(4),
          child: const SizedBox(width: 80, height: 80),
        ),
      ),
    ],
  ));
}

void main() {
  setUp(() => GlassDeviceTier.instance.reset());
  tearDown(() => GlassDeviceTier.instance.reset());

  void pin(GlassQuality quality) {
    GlassDeviceTier.instance
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = quality;
  }

  testWidgets('the cheap tier filters the scene in place instead of capturing it',
      (WidgetTester tester) async {
    // What dropping the refraction does *not* fix on its own: the lens is a
    // fragment pass over the element's own texture, while the capture is an
    // `OffsetLayer.toImageSync` of the whole source that flushes the pipeline
    // mid-frame. For a backdrop that changes every frame the capture is the
    // whole cost, so the cheap tier stops sampling altogether and hands the
    // chain to the compositor as Flutter's own `BackdropFilter`.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pin(GlassQuality.plain);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(_host(
      backdrop: backdrop,
      source: const ColoredBox(color: Color(0xFFFF0000)),
    ));
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;
    expect(source.debugCaptureCount, 0,
        reason: 'the cheap tier must not rasterise the source at all');
    expect(backdrop.hasConsumers, isFalse,
        reason: 'an element on the native path must not hold the source open — '
            'a subscriber is exactly what keeps it capturing itself');

    expect(_hasBackdropFilterLayer(_sceneLayer(tester)), isTrue,
        reason: 'the effect chain should have become a BackdropFilterLayer');

    // And it is still glass: what is behind shows through it.
    final List<double> rgb = _meanRgb(await _pixels(tester), _inside);
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[1], lessThan(60), reason: 'green channel: $rgb');
  });

  testWidgets('it tracks a moving background with nothing to invalidate',
      (WidgetTester tester) async {
    // The compositor reads the backdrop as it composites, so there is no
    // capture to go stale and no signal to miss — the frozen-backdrop class of
    // bug cannot happen on this path at all.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pin(GlassQuality.plain);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final ValueNotifier<double> t = ValueNotifier<double>(0);
    addTearDown(t.dispose);

    await tester.pumpWidget(_host(
      backdrop: backdrop,
      // Behind a repaint boundary, which is the case that needed the whole
      // layer-watching machinery on the sampled path.
      source: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: t,
          builder: (BuildContext context, double v, Widget? _) => ColoredBox(
            color: Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), v)!,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final double dark = _meanRgb(await _pixels(tester), _inside)[0];
    t.value = 1.0;
    await tester.pump();
    final double light = _meanRgb(await _pixels(tester), _inside)[0];

    expect(light - dark, greaterThan(150.0),
        reason: 'the glass showed $dark then $light while the background under '
            'it went from black to white');

    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;
    expect(source.debugCaptureCount, 0,
        reason: 'and it did it without a single capture');
  });

  testWidgets('the liquid tier still samples', (WidgetTester tester) async {
    // The native path cannot replace the refraction: a fragment shader inside a
    // backdrop filter is handed the whole screen rather than the element's own
    // texture, so the lens would have no geometry to anchor to. The tier that
    // has given up the shaders is exactly the tier that can use it.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pin(GlassQuality.liquid);

    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(_host(
      backdrop: backdrop,
      source: const ColoredBox(color: Color(0xFFFF0000)),
    ));
    await tester.pump();
    await tester.pump();

    final RenderBackdropLayer source =
        tester.renderObject(find.byType(BackdropLayer)) as RenderBackdropLayer;
    expect(source.debugCaptureCount, greaterThan(0));
    expect(backdrop.hasConsumers, isTrue);

    expect(_hasBackdropFilterLayer(_sceneLayer(tester)), isFalse);
  });

  testWidgets('a backdrop the element draws itself keeps sampling',
      (WidgetTester tester) async {
    // There is nothing behind the element for the compositor to filter: the
    // backdrop is a callback, not content in the scene. Falling back to a
    // BackdropFilter here would blur whatever happened to be underneath, which
    // is not what was asked for.
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pin(GlassQuality.plain);

    await tester.pumpWidget(_frame(Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        const Positioned.fill(child: ColoredBox(color: Color(0xFF0000FF))),
        Positioned(
          left: 60,
          top: 60,
          child: DrawBackdrop.plain(
            backdrop: CanvasBackdrop((Canvas canvas, Size size) {
              canvas.drawRect(
                Rect.fromLTWH(-200, -200, 600, 600),
                Paint()..color = const Color(0xFFFF0000),
              );
            }),
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(4),
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ],
    )));
    await tester.pump();
    await tester.pump();

    expect(_hasBackdropFilterLayer(_sceneLayer(tester)), isFalse,
        reason: 'a CanvasBackdrop has to be drawn, not filtered in place');

    // Red is what the callback drew; blue is what is actually behind.
    final List<double> rgb = _meanRgb(await _pixels(tester), _inside);
    expect(rgb[0], greaterThan(200), reason: 'red channel: $rgb');
    expect(rgb[2], lessThan(60), reason: 'blue channel: $rgb');
  });
}
