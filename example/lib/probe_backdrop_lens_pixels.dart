// Throwaway: does the screen-space-anchored lens actually REFRACT?
//
// probe_backdrop_lens_perf found the BackdropFilter path costs a quarter of
// what the capture path costs. That number is only worth something if the
// picture is right -- and there is a failure mode that would produce exactly
// the same number by accident: if the uniforms mis-anchor the SDF, every
// fragment takes refraction.frag's early-out
//
//     if (-sd >= uRefractionHeight) { fragColor = evalContent(coord); return; }
//
// and the element renders as a plain blur, which is cheap for the wrong
// reason. So: render the same glass three ways over one static backdrop,
// write PNGs, and measure how far each is from the others.
//
// Expected if the lens works:  bdShader is FAR from plain, CLOSE to capture.
// Expected if it silently no-ops: bdShader is identical to plain.
//
//   flutter build windows --release -t lib/probe_backdrop_lens_pixels.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum _Mode { capture, bdShader, plain }

const double _barW = 320;
const double _barH = 120;
const double _radius = 32;
const double _blurSigma = 8;
const double _lensHeight = 16;
const double _lensAmount = 28;

ui.FragmentProgram? _refraction;
final GlobalKey _captureKey = GlobalKey();
final ValueNotifier<_Mode> _current = ValueNotifier<_Mode>(_Mode.capture);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  try {
    _refraction = await ui.FragmentProgram.fromAsset(
      'packages/fluid_glass/shaders/refraction.frag',
    );
  } catch (e) {
    debugPrint('BDPIX| FATAL could not load refraction.frag: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

ui.ImageFilter _screenSpaceLens(Rect r, Size screen) {
  final ui.FragmentShader s = _refraction!.fragmentShader();
  s
    ..setFloat(0, 0)
    ..setFloat(1, 0)
    ..setFloat(2, screen.width)
    ..setFloat(3, screen.height)
    ..setFloat(4, r.width)
    ..setFloat(5, r.height)
    ..setFloat(6, -r.left)
    ..setFloat(7, -r.top)
    ..setFloat(8, _radius)
    ..setFloat(9, _radius)
    ..setFloat(10, _radius)
    ..setFloat(11, _radius)
    ..setFloat(12, _lensHeight)
    ..setFloat(13, -_lensAmount)
    ..setFloat(14, 0);
  return ui.ImageFilter.compose(
    outer: ui.ImageFilter.shader(s),
    inner: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
  );
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  @override
  void initState() {
    super.initState();
    _current.addListener(_onCase);
  }

  void _onCase() => setState(() {});

  @override
  void dispose() {
    _current.removeListener(_onCase);
    super.dispose();
  }

  // Hard vertical stripes: refraction shows up as the stripes bending near
  // the rim, which a plain blur cannot imitate.
  Widget _source() => CustomPaint(painter: _Stripes(), size: Size.infinite);

  @override
  Widget build(BuildContext context) {
    final _Mode mode = _current.value;
    final ui.FlutterView view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final Size screen = view.physicalSize / view.devicePixelRatio;
    final Rect barRect = Rect.fromLTWH(
      (screen.width - _barW) / 2,
      (screen.height - _barH) / 2,
      _barW,
      _barH,
    );

    final Widget src = mode == _Mode.capture
        ? BackdropLayer(backdrop: _backdrop, child: _source())
        : _source();

    late final Widget bar;
    switch (mode) {
      case _Mode.capture:
        bar = DrawBackdrop(
          backdrop: _backdrop,
          shape: () => const RoundedRectangle(_radius),
          effects: (BackdropEffectScope scope) => scope
            ..blur(_blurSigma)
            ..lens(_lensHeight, _lensAmount),
          child: const SizedBox(width: _barW, height: _barH),
        );
      case _Mode.bdShader:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: _screenSpaceLens(barRect, screen),
            child: const SizedBox(width: _barW, height: _barH),
          ),
        );
      case _Mode.plain:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
            child: const SizedBox(width: _barW, height: _barH),
          ),
        );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: src),
            Positioned(
              left: barRect.left,
              top: barRect.top,
              width: _barW,
              height: _barH,
              child: bar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101418),
    );
    final Paint p = Paint()..color = const Color(0xFFFFCC33);
    const double period = 24;
    for (double x = 0; x < size.width; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, period / 2, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

Future<void> _settle(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

String get _outDir {
  final String d = Platform.environment['PROBE_DIR'] ?? '.';
  Directory(d).createSync(recursive: true);
  return d;
}

/// The element's own pixels, cropped out of a full-window capture.
Future<(Uint8List, int, int)?> _shoot(String name, Rect r, double dpr) async {
  final RenderRepaintBoundary? b =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return null;
  final ui.Image img = await b.toImage(pixelRatio: dpr);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png != null) {
    File(
      '$_outDir/bdpix_$name.png',
    ).writeAsBytesSync(png.buffer.asUint8List(), flush: true);
  }
  final ByteData? raw = await img.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int w = img.width;
  img.dispose();
  if (raw == null) return null;
  // Crop the bar, inset by the corner radius so the rounded clip's own
  // antialiasing does not dominate the comparison.
  final int x0 = ((r.left + 4) * dpr).round();
  final int y0 = ((r.top + 4) * dpr).round();
  final int cw = ((r.width - 8) * dpr).round();
  final int ch = ((r.height - 8) * dpr).round();
  final Uint8List src = raw.buffer.asUint8List();
  final Uint8List out = Uint8List(cw * ch * 4);
  for (int y = 0; y < ch; y++) {
    final int s = ((y0 + y) * w + x0) * 4;
    out.setRange(y * cw * 4, (y + 1) * cw * 4, src, s);
  }
  return (out, cw, ch);
}

double _meanAbsDiff(Uint8List a, Uint8List b) {
  final int n = math.min(a.length, b.length);
  double sum = 0;
  int count = 0;
  for (int i = 0; i < n; i += 4) {
    for (int c = 0; c < 3; c++) {
      sum += (a[i + c] - b[i + c]).abs();
      count++;
    }
  }
  return sum / count;
}

/// Column-mean profile across the bar: refraction bends the stripes, which
/// shows up as the profile near the rim differing from the middle.
String _profile(Uint8List px, int w, int h) {
  final List<int> cols = <int>[];
  for (final double f in <double>[0.02, 0.05, 0.10, 0.25, 0.5]) {
    cols.add((w * f).round().clamp(0, w - 1));
  }
  final StringBuffer sb = StringBuffer();
  for (final int x in cols) {
    double s = 0;
    for (int y = 0; y < h; y++) {
      final int i = (y * w + x) * 4;
      s += (px[i] + px[i + 1] + px[i + 2]) / 3;
    }
    sb.write('x${(x / w * 100).round()}%=${(s / h).toStringAsFixed(1)} ');
  }
  return sb.toString();
}

Future<void> _drive() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final double dpr = view.devicePixelRatio;
  final Size screen = view.physicalSize / dpr;
  final Rect barRect = Rect.fromLTWH(
    (screen.width - _barW) / 2,
    (screen.height - _barH) / 2,
    _barW,
    _barH,
  );
  debugPrint(
    'BDPIX| screen=${screen.width.toStringAsFixed(0)}x'
    '${screen.height.toStringAsFixed(0)} dpr=$dpr  out=$_outDir',
  );

  final Map<_Mode, Uint8List> shots = <_Mode, Uint8List>{};
  int cw = 0, ch = 0;
  for (final _Mode m in _Mode.values) {
    _current.value = m;
    await _settle(900);
    final (Uint8List, int, int)? got = await _shoot(m.name, barRect, dpr);
    if (got == null) {
      debugPrint('BDPIX| ${m.name}: no capture');
      continue;
    }
    shots[m] = got.$1;
    cw = got.$2;
    ch = got.$3;
    debugPrint(
      'BDPIX| ${m.name.padRight(9)} profile ${_profile(got.$1, cw, ch)}',
    );
  }

  if (shots.length == 3) {
    final double sp = _meanAbsDiff(shots[_Mode.bdShader]!, shots[_Mode.plain]!);
    final double sc = _meanAbsDiff(
      shots[_Mode.bdShader]!,
      shots[_Mode.capture]!,
    );
    final double cp = _meanAbsDiff(shots[_Mode.capture]!, shots[_Mode.plain]!);
    debugPrint(
      'BDPIX| mean|diff| bdShader vs plain   = ${sp.toStringAsFixed(2)}',
    );
    debugPrint(
      'BDPIX| mean|diff| bdShader vs capture = ${sc.toStringAsFixed(2)}',
    );
    debugPrint(
      'BDPIX| mean|diff| capture  vs plain   = ${cp.toStringAsFixed(2)}',
    );
    final bool refracts = sp > 2.0;
    final bool matchesCapture = sc < sp;
    debugPrint(
      'BDPIX| VERDICT lens is ${refracts ? "ACTIVE" : "NOT ACTIVE (no-op!)"}'
      ', and is ${matchesCapture ? "closer to capture than to plain" : "closer to PLAIN than to capture"}',
    );
  }
  debugPrint('BDPIX| done');
  await _settle(200);
  exit(0);
}
