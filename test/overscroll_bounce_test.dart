import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pull-down that springs back is a live source like any other, but it is
/// the one that reaches the glass through the fewest signals. Scrolling always
/// dispatches a `ScrollNotification`; a *bounce* may dispatch none at all —
/// `StretchingOverscrollIndicator` leaves the scroll position at zero and
/// animates a transform of its own, so the only thing that can notice it is
/// the source repainting or the layer fingerprint.
///
/// Each test below drags down, releases, and watches the glass across the
/// spring-back. The bar is black-and-white bands, so "is the glass still
/// sampling" is a question about brightness.

const Key _boundary = Key('boundary');
const int _w = 200;
const int _h = 400;

Widget _scene(LayerBackdrop backdrop, Widget source, {required bool barAtTop}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: BackdropLayer(backdrop: backdrop, child: source),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: barAtTop ? 0 : null,
                  bottom: barAtTop ? null : 0,
                  child: DrawBackdrop.plain(
                    backdrop: backdrop,
                    shape: () => const Rectangle(),
                    effects: (BackdropEffectScope scope) => scope.blur(2),
                    child: const SizedBox(height: 60, width: double.infinity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

Widget _bands({int count = 60}) => ListView.builder(
      itemExtent: 40,
      itemCount: count,
      itemBuilder: (BuildContext context, int index) => ColoredBox(
        color: index.isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      ),
    );

/// Mean brightness of the strip the bar occupies.
Future<double> _bar(WidgetTester tester, {required bool atTop}) async {
  final RenderRepaintBoundary box =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = box.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  final int y0 = atTop ? 10 : _h - 50;
  final int y1 = atTop ? 50 : _h - 10;
  int total = 0;
  int count = 0;
  for (int y = y0; y < y1; y++) {
    for (int x = 0; x < _w; x++) {
      total += p[(y * _w + x) * 4];
      count += 1;
    }
  }
  return total / count;
}

/// Drags down past the top edge, releases, and samples the bar on every frame
/// of the spring-back.
Future<List<double>> _dragAndRelease(
  WidgetTester tester, {
  required bool atTop,
  int frames = 20,
}) async {
  final TestGesture gesture = await tester.startGesture(const Offset(100, 200));
  for (int i = 0; i < 6; i++) {
    await gesture.moveBy(const Offset(0, 14));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  final List<double> samples = <double>[];
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    samples.add(await _bar(tester, atTop: atTop));
  }
  return samples;
}

void _expectTracking(List<double> samples, double atLeast, String what) {
  final double min = samples.reduce((double a, double b) => a < b ? a : b);
  final double max = samples.reduce((double a, double b) => a > b ? a : b);
  expect(max - min, greaterThan(atLeast),
      reason: 'the glass must keep sampling while $what, but its brightness '
          'only moved between $min and $max across $samples');
}

class _Stretch extends ScrollBehavior {
  const _Stretch();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      StretchingOverscrollIndicator(
          axisDirection: details.direction, child: child);
}

class _NoIndicator extends ScrollBehavior {
  const _NoIndicator();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

void main() {
  setUp(() {
    // The sampled path, not the native `BackdropFilter` fallback: see
    // `dynamic_backdrop_test.dart` for why this pin is needed under
    // `flutter_test`.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  void configure(WidgetTester tester) {
    tester.view.physicalSize = Size(_w.toDouble(), _h.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the glass tracks a list bouncing back from an overscroll',
      (WidgetTester tester) async {
    // iOS physics: the position itself runs past the edge and a ballistic
    // simulation brings it back, so scroll notifications keep arriving.
    configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    await tester.pumpWidget(_scene(
      backdrop,
      ScrollConfiguration(
        behavior: const _NoIndicator(),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemExtent: 40,
          itemCount: 60,
          itemBuilder: (BuildContext context, int index) => ColoredBox(
            color:
                index.isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          ),
        ),
      ),
      barAtTop: false,
    ));
    await tester.pump();
    _expectTracking(await _dragAndRelease(tester, atTop: false), 20,
        'a list bounces back');
    await tester.pumpAndSettle();
  });

  testWidgets('the glass tracks the android stretch springing back',
      (WidgetTester tester) async {
    // The harder half: the scroll position never leaves zero, so there is no
    // `ScrollNotification` during the spring-back at all. Only the source
    // repainting — or the layer fingerprint — can see this.
    configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    await tester.pumpWidget(_scene(
      backdrop,
      ScrollConfiguration(behavior: const _Stretch(), child: _bands()),
      barAtTop: false,
    ));
    await tester.pump();
    _expectTracking(await _dragAndRelease(tester, atTop: false), 10,
        'the android stretch springs back');
    await tester.pumpAndSettle();
  });

  testWidgets('the glass tracks a cupertino refresh control',
      (WidgetTester tester) async {
    configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    await tester.pumpWidget(_scene(
      backdrop,
      ScrollConfiguration(
        behavior: const _NoIndicator(),
        child: CustomScrollView(
          physics:
              const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: <Widget>[
            CupertinoSliverRefreshControl(onRefresh: () async {}),
            SliverFixedExtentList(
              itemExtent: 40,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => ColoredBox(
                  color: index.isEven
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF),
                ),
                childCount: 60,
              ),
            ),
          ],
        ),
      ),
      barAtTop: true,
    ));
    await tester.pump();
    _expectTracking(await _dragAndRelease(tester, atTop: true), 20,
        'a refresh control springs back');
    await tester.pumpAndSettle();
  });

  testWidgets('the glass tracks the source itself springing back',
      (WidgetTester tester) async {
    // A page that is dragged down and released as a whole: the source moves
    // rather than its content, so nothing inside it repaints and no scroll
    // notification is dispatched. The capture is taken in the source's own
    // coordinates, so this must re-place what the glass reads without
    // re-capturing anything.
    configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);
    final AnimationController spring = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );
    addTearDown(spring.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: _boundary,
          child: SizedBox(
            width: _w.toDouble(),
            height: _h.toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: spring,
                    builder: (BuildContext context, Widget? child) =>
                        Transform.translate(
                      offset: Offset(0, -60 * spring.value),
                      child: child,
                    ),
                    child: BackdropLayer(
                      backdrop: backdrop,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (int i = 0; i < 10; i++)
                            SizedBox(
                              height: 40,
                              width: _w.toDouble(),
                              child: ColoredBox(
                                color: i.isEven
                                    ? const Color(0xFF000000)
                                    : const Color(0xFFFFFFFF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: DrawBackdrop.plain(
                    backdrop: backdrop,
                    shape: () => const Rectangle(),
                    effects: (BackdropEffectScope scope) => scope.blur(2),
                    child: const SizedBox(height: 60, width: double.infinity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    spring.reverse();
    final List<double> samples = <double>[];
    for (int i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      samples.add(await _bar(tester, atTop: true));
    }
    _expectTracking(samples, 100, 'the source itself springs back');
    await tester.pumpAndSettle();
  });
}
