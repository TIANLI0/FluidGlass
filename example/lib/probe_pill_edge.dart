// Throwaway: does the selection pill's blur reach its own edge, and is it the
// same blur the bar around it applies?
//
// The reported symptom is a fringe around the selected pill where the blur
// stops working and the backdrop shows through. Widget tests run on Skia and
// skip the fragment shaders, so they cannot show it. This renders the bar over
// hard black/white stripes on the real backend, with EMPTY tabs so nothing but
// glass is in frame, and reports the stripe contrast that survives inside the
// pill against the contrast that survives on the bar beside it. Same page,
// same nominal blur radius: any difference is the pill's own path.
//
//   flutter build windows --release -t lib/probe_pill_edge.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

const double _barWidth = 300;
const double _boxH = 120;
const double _barH = 56; // 48 row + 4 inset top and bottom
const double _barBottom = 20;
const double _inset = 4;
const double _stripe = 6;
const double _shotScale = 8;

final GlobalKey _shot = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_drive());
}

Future<void> _drive() async {
  await _settle(48);
  await _write();
  exit(0);
}

Future<void> _settle(int frames) async {
  for (int i = 0; i < frames; i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
}

Future<void> _write() async {
  final RenderRepaintBoundary boundary =
      _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = boundary.toImageSync(pixelRatio: _shotScale);
  final int w = image.width;
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png != null) {
    final File file = File('pill_edge.png');
    await file.writeAsBytes(png.buffer.asUint8List());
    debugPrint('wrote ${file.absolute.path}');
  }
  final ByteData? raw = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  if (raw != null) _report(raw, w);
}

void _report(ByteData raw, int w) {
  final Uint8List p = raw.buffer.asUint8List();
  int lum(double x, double y) =>
      p[(((y * _shotScale).round()) * w + (x * _shotScale).round()) * 4];

  /// Peak-to-peak over one stripe period, which is what "is it blurred" means.
  ({double pp, double mean}) band(double y, double x0, double x1) {
    double min = 255, max = 0, total = 0;
    int n = 0;
    for (double x = x0; x < x1; x += 1 / _shotScale) {
      final double v = lum(x, y).toDouble();
      if (v < min) min = v;
      if (v > max) max = v;
      total += v;
      n++;
    }
    return (pp: max - min, mean: total / n);
  }

  const double barTop = _boxH - _barBottom - _barH;
  const double rowTop = barTop + _inset;
  const double rowH = _barH - _inset * 2;
  final double tabW = (_barWidth - _inset * 2) / 3;
  // Pill on tab 1: the middle third of the bar.
  final double pillLeft = _inset + tabW;
  final double pillRight = pillLeft + tabW;

  // A row well inside the pill vertically, and the same row on the bar either
  // side of it.
  // Above a 20-tall icon centred in the 48-tall row, so only glass is sampled.
  final double y = rowTop + 6;
  assert(rowH > 0);
  final pill = band(y, pillLeft + 14, pillRight - 14);
  final left = band(y, _inset + 10, pillLeft - 10);
  final rawPage = band(8, 20, _barWidth - 20);

  debugPrint('stripe peak-to-peak (255 = untouched)');
  debugPrint('  raw page above the bar : ${rawPage.pp.toStringAsFixed(1)}');
  debugPrint('  bar beside the pill    : ${left.pp.toStringAsFixed(1)}'
      '  mean ${left.mean.toStringAsFixed(1)}');
  debugPrint('  inside the pill        : ${pill.pp.toStringAsFixed(1)}'
      '  mean ${pill.mean.toStringAsFixed(1)}');

  // How much stripe survives, as a map. `pp` over one stripe period at each
  // point: 0 is a working blur, 255 is none at all. Walked across and down the
  // whole bar so the failing region locates itself instead of being guessed at.
  ({double pp, double mean}) spot(double x, double y) => band(y, x - 6, x + 6);

  debugPrint('surviving stripe (pp) over the bar, y down / x across');
  final StringBuffer header = StringBuffer('     ');
  for (double x = 10; x < _barWidth - 6; x += 12) {
    header.write(x.toStringAsFixed(0).padLeft(5));
  }
  debugPrint(header.toString());
  for (double y = barTop - 4; y < barTop + _barH + 4; y += 3) {
    final StringBuffer line = StringBuffer(y.toStringAsFixed(0).padLeft(5));
    for (double x = 10; x < _barWidth - 6; x += 12) {
      line.write(spot(x, y).pp.round().toString().padLeft(5));
    }
    debugPrint(line.toString());
  }
  debugPrint('pill spans x ${pillLeft.toStringAsFixed(0)}..'
      '${pillRight.toStringAsFixed(0)}, bar y ${barTop.toStringAsFixed(0)}..'
      '${(barTop + _barH).toStringAsFixed(0)}');
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF808080),
        child: Center(
          child: RepaintBoundary(
            key: _shot,
            child: SizedBox(
              width: _barWidth,
              height: _boxH,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropLayer(
                      backdrop: _backdrop,
                      child: const CustomPaint(painter: _Stripes()),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _barBottom,
                    child: LiquidBottomTabs(
                      selectedTabIndex: 1,
                      onTabSelected: (int i) {},
                      backdrop: _backdrop,
                      tabsCount: 3,
                      children: <Widget>[
                        for (int i = 0; i < 3; i++)
                          LiquidBottomTab(
                            onPressed: () {},
                            children: const <Widget>[
                              Icon(Icons.circle,
                                  size: 20, color: Color(0xFFFFFFFF)),
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
    );
  }
}

class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final Paint black = Paint()..color = const Color(0xFF000000);
    for (double x = 0; x < size.width; x += _stripe * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, _stripe, size.height), black);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
