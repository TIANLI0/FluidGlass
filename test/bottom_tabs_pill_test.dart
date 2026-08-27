import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 320;
const int _h = 200;

/// The bar is 64 tall and sits at the bottom of the frame.
const double _barTop = _h - 64.0;

/// Inside the pill over the first tab, clear of its rim: the panel insets its
/// content by 4, and the pill is one tab wide.
const Rect _pill = Rect.fromLTRB(20, _barTop + 16, 80, _barTop + 48);

/// The same band under the *third* tab, where only the panel covers the source.
const Rect _panelOnly = Rect.fromLTRB(230, _barTop + 16, 290, _barTop + 48);

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary render =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = render.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  return data!.buffer.asUint8List();
}

/// How much the luminance varies across [box].
///
/// A filtered region is smooth; an unfiltered one carries the source's hard
/// edges, so its spread stays high.
double _spread(Uint8List p, Rect box) {
  final List<double> values = <double>[];
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      values.add((p[i] + p[i + 1] + p[i + 2]) / 3);
    }
  }
  final double mean =
      values.reduce((double a, double b) => a + b) / values.length;
  final double variance = values
          .map((double v) => (v - mean) * (v - mean))
          .reduce((double a, double b) => a + b) /
      values.length;
  return variance;
}

/// Vertical black-and-white stripes: the highest-frequency source there is, so
/// any blur in the chain shows up as a collapse in [_spread].
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StripePainter());
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final Paint black = Paint()..color = const Color(0xFF000000);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _host(LayerBackdrop backdrop) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Theme(
        data: ThemeData(brightness: Brightness.light),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: _w.toDouble(),
              height: _h.toDouble(),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropLayer(
                      backdrop: backdrop,
                      child: const _Stripes(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: _barTop,
                    width: _w.toDouble(),
                    child: LiquidBottomTabs(
                      selectedTabIndex: 0,
                      onTabSelected: (int _) {},
                      backdrop: backdrop,
                      tabsCount: 3,
                      children: <Widget>[
                        for (int i = 0; i < 3; i++)
                          LiquidBottomTab(
                            onPressed: () {},
                            children: const <Widget>[
                              SizedBox(width: 8, height: 8),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => GlassDeviceTier.instance.reset());
  tearDown(() => GlassDeviceTier.instance.reset());

  for (final GlassQuality quality in GlassQuality.values) {
    testWidgets('the selection pill filters its backdrop at rest on $quality',
        (WidgetTester tester) async {
      GlassDeviceTier.instance
        ..debugCeiling = quality
        ..pinnedQuality = quality;

      final LayerBackdrop backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);

      await tester.pumpWidget(_host(backdrop));
      await tester.pump();
      await tester.pump();

      final Uint8List p = await _pixels(tester);
      final double panel = _spread(p, _panelOnly);
      final double pill = _spread(p, _pill);

      // The panel blurs the stripes into a flat field.
      expect(
        panel,
        lessThan(400),
        reason: 'the panel should have flattened the stripes; got $panel',
      );

      // The pill must not be a hole. Its own effects ramp with the press, so at
      // rest everything it shows comes from the tab copy it magnifies — and
      // that copy carries the same blur the panel does.
      //
      // The cheap tier is where the copy used to vanish: its glass was handed
      // to the compositor as a BackdropFilterLayer, which filters what is
      // already beneath it, while `toImageSync` starts the capture on an empty
      // canvas. The copy then contributed nothing but its own plain draws and
      // the source showed through the pill untouched.
      expect(
        pill,
        lessThan(panel * 3),
        reason: 'the pill is showing the raw source: spread $pill against '
            'the panel of $panel',
      );
    });
  }
}
