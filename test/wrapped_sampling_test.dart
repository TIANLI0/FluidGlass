import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements LayerBackdropSource {
  Rect? requested;
  @override
  Size get sourceSize => const Size(64, 28);
  @override
  Offset get sourceGlobalOffset => Offset.zero;
  @override
  bool get hasContent => true;
  @override
  void invalidateSnapshot() {}
  @override
  void drawSource(
    Canvas canvas,
    double devicePixelRatio, {
    double clampMargin = 0,
    Rect? region,
  }) {
    requested = region;
    // Emulate a region capture: pixels beyond the request do not exist.
    canvas.drawRect(
      region!.intersect(Offset.zero & sourceSize),
      Paint()..color = const Color(0xFF00FF00),
    );
  }
}

void main() {
  testWidgets('shrinking a wrapped track does not expose its capture edge', (
    WidgetTester tester,
  ) async {
    const Key key = Key('consumer');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(key: key, width: 40, height: 24),
        ),
      ),
    );
    final RenderBox consumer = tester.renderObject(find.byKey(key));
    final _Source source = _Source();
    final LayerBackdrop layer = LayerBackdrop(extendEdges: false)
      ..attachSource(source);
    final WrappedBackdrop wrapped = WrappedBackdrop(layer, (context, draw) {
      context.canvas.save();
      context.canvas.translate(20, 12);
      context.canvas.scale(0.75, 0.75);
      context.canvas.translate(-20, -12);
      draw();
      context.canvas.restore();
    });
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    wrapped.drawBackdrop(
      BackdropDrawContext(
        canvas: canvas,
        size: const Size(40, 24),
        textDirection: TextDirection.ltr,
        devicePixelRatio: 1,
        consumer: consumer,
        layerBlock: null,
        backdrop: wrapped,
      ),
    );
    expect(source.requested!.left, closeTo(-20 / 3, 0.0001));
    expect(source.requested!.right, closeTo(140 / 3, 0.0001));
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(40, 24);
    final data = await tester.runAsync(() => image.toByteData());
    // Previously the crop ended at x=40, which shrank to x=35. This pixel
    // went transparent and the refraction magnified that straight edge.
    expect(data!.getUint8((12 * 40 + 38) * 4 + 3), 255);
    image.dispose();
    picture.dispose();
    layer.dispose();
  });

  test('nested wrappers inverse-map bounds and tolerate a collapsed track', () {
    Rect? requested;
    final Backdrop source = _BoundsBackdrop((Rect? value) => requested = value);
    Backdrop scale(Backdrop child, double x, double y) =>
        WrappedBackdrop(child, (context, draw) {
          context.canvas.save();
          context.canvas.scale(x, y);
          draw();
          context.canvas.restore();
        });
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(3, 3);
    void draw(Backdrop backdrop) => backdrop.drawBackdrop(
      BackdropDrawContext(
        canvas: canvas,
        size: const Size(40, 24),
        sampleMargin: 4,
        textDirection: TextDirection.ltr,
        devicePixelRatio: 3,
        consumer: null,
        layerBlock: null,
        backdrop: backdrop,
      ),
    );
    draw(scale(scale(source, 0.5, 0.5), 0.5, 0.5));
    expect(requested, const Rect.fromLTRB(-16, -16, 176, 112));
    requested = null;
    draw(scale(source, 0.75, 0));
    expect(requested, isNull);
    recorder.endRecording().dispose();
  });
}

class _BoundsBackdrop extends Backdrop {
  const _BoundsBackdrop(this.record);
  final void Function(Rect?) record;
  @override
  bool get isCoordinatesDependent => false;
  @override
  void drawBackdrop(BackdropDrawContext context) =>
      record(context.sampleBounds);
}
