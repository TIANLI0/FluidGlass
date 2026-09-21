// Throwaway: the lens IS anchored correctly inside a BackdropFilter
// (probe_sdf_anchor paints a green band exactly on the rim), yet composing it
// with a blur renders a plain blur and no refraction at all. That is the shape
// of flutter/flutter#170820, "ImageFilter.blur breaks ImageFilter.shader in a
// BackdropFilter together".
//
// So: try every way of getting blur AND lens out of a backdrop filter.
//
//   capture     today's liquid tier, the reference picture
//   lensOnly    BackdropFilter(lens) -- no blur at all
//   composed    BackdropFilter(compose(outer: lens, inner: blur))
//   nested      BackdropFilter(blur) wrapping BackdropFilter(lens)
//   nestedFlip  BackdropFilter(lens) wrapping BackdropFilter(blur)
//
//   flutter build windows --release -t lib/probe_bdlens_variants.dart
//   PROBE_DIR=... ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum _Mode {
  capture('today liquid tier (reference)'),
  lensOnly('BackdropFilter(lens), no blur'),
  composed('BackdropFilter(compose(lens, blur))'),
  nested('BackdropFilter(blur) > BackdropFilter(lens)'),
  nestedFlip('BackdropFilter(lens) > BackdropFilter(blur)'),
  plain('BackdropFilter(blur) only');

  const _Mode(this.label);
  final String label;
}

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
    debugPrint('BDV| FATAL $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

ui.ImageFilter _lens(Rect r, Size layer) {
  final ui.FragmentShader s = _refraction!.fragmentShader();
  s
    ..setFloat(0, 0)
    ..setFloat(1, 0)
    ..setFloat(2, layer.width)
    ..setFloat(3, layer.height)
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
  return ui.ImageFilter.shader(s);
}

ui.ImageFilter get _blur =>
    ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma);

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
    _current.addListener(_on);
  }

  void _on() => setState(() {});

  @override
  void dispose() {
    _current.removeListener(_on);
    super.dispose();
  }

  Widget _source() => CustomPaint(painter: _Stripes(), size: Size.infinite);

  Widget _clip(Widget child) =>
      ClipRRect(borderRadius: BorderRadius.circular(_radius), child: child);

  @override
  Widget build(BuildContext context) {
    final _Mode mode = _current.value;
    final ui.FlutterView view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final Size screen = view.physicalSize / view.devicePixelRatio;
    final Rect r = Rect.fromLTWH(
      (screen.width - _barW) / 2,
      (screen.height - _barH) / 2,
      _barW,
      _barH,
    );
    const Widget hole = SizedBox(width: _barW, height: _barH);

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
          child: hole,
        );
      case _Mode.lensOnly:
        bar = _clip(BackdropFilter(filter: _lens(r, screen), child: hole));
      case _Mode.composed:
        bar = _clip(
          BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: _lens(r, screen),
              inner: _blur,
            ),
            child: hole,
          ),
        );
      case _Mode.nested:
        bar = _clip(
          BackdropFilter(
            filter: _blur,
            child: BackdropFilter(filter: _lens(r, screen), child: hole),
          ),
        );
      case _Mode.nestedFlip:
        bar = _clip(
          BackdropFilter(
            filter: _lens(r, screen),
            child: BackdropFilter(filter: _blur, child: hole),
          ),
        );
      case _Mode.plain:
        bar = _clip(BackdropFilter(filter: _blur, child: hole));
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: src),
            Positioned(
              left: r.left,
              top: r.top,
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

Future<Uint8List?> _shoot(String name, Rect r, double dpr) async {
  final RenderRepaintBoundary? b =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return null;
  final ui.Image img = await b.toImage(pixelRatio: dpr);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png != null) {
    File(
      '$_outDir/bdv_$name.png',
    ).writeAsBytesSync(png.buffer.asUint8List(), flush: true);
  }
  final ByteData? raw = await img.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int w = img.width;
  img.dispose();
  if (raw == null) return null;
  final int x0 = ((r.left + 4) * dpr).round();
  final int y0 = ((r.top + 4) * dpr).round();
  final int cw = ((r.width - 8) * dpr).round();
  final int ch = ((r.height - 8) * dpr).round();
  final Uint8List src = raw.buffer.asUint8List();
  final Uint8List out = Uint8List(cw * ch * 4);
  for (int y = 0; y < ch; y++) {
    out.setRange(y * cw * 4, (y + 1) * cw * 4, src, ((y0 + y) * w + x0) * 4);
  }
  return out;
}

double _diff(Uint8List a, Uint8List b) {
  final int n = math.min(a.length, b.length);
  double s = 0;
  int c = 0;
  for (int i = 0; i < n; i += 4) {
    for (int k = 0; k < 3; k++) {
      s += (a[i + k] - b[i + k]).abs();
      c++;
    }
  }
  return s / c;
}

Future<void> _drive() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final double dpr = view.devicePixelRatio;
  final Size screen = view.physicalSize / dpr;
  final Rect r = Rect.fromLTWH(
    (screen.width - _barW) / 2,
    (screen.height - _barH) / 2,
    _barW,
    _barH,
  );

  final Map<_Mode, Uint8List> shots = <_Mode, Uint8List>{};
  for (final _Mode m in _Mode.values) {
    _current.value = m;
    await _settle(900);
    final Uint8List? px = await _shoot(m.name, r, dpr);
    if (px != null) shots[m] = px;
  }

  final Uint8List? ref = shots[_Mode.capture];
  final Uint8List? flat = shots[_Mode.plain];
  if (ref == null || flat == null) {
    debugPrint('BDV| missing reference shots');
    exit(1);
  }
  debugPrint('BDV| how far each variant is from the two poles:');
  debugPrint('BDV| (refracting => far from plain; a no-op => ~0 from plain)');
  for (final _Mode m in _Mode.values) {
    final Uint8List? px = shots[m];
    if (px == null) continue;
    debugPrint(
      'BDV| ${m.name.padRight(11)} vsPlain=${_diff(px, flat).toStringAsFixed(2).padLeft(6)}  '
      'vsCapture=${_diff(px, ref).toStringAsFixed(2).padLeft(6)}   ${m.label}',
    );
  }
  debugPrint('BDV| done');
  await _settle(200);
  exit(0);
}
