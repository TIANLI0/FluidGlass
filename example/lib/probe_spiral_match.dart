// Throwaway: can a one-pass BackdropFilter shader MATCH the capture path's
// sigma-8 Gaussian, and what does matching it cost?
//
// probe_onepass_glass established that the lens runs correctly in a
// BackdropFilter with zero capture (net 0.0 ms against the capture path's
// +1.7 ms), but its two-ring 17-tap blur stayed 11.51 away from the capture
// picture and widening the rings made it worse, not better -- ring sampling
// undersamples angularly as the radius grows.
//
// This sweeps a golden-angle spiral kernel (equal-area points over 2.5 sigma,
// true Gaussian weights, optional per-pixel rotation so residual banding
// becomes noise) over tap count and dither, finds what actually matches, and
// then times it. A config that matches the picture but costs more than 1.7 ms
// kills the whole idea; one that matches under it settles the trade-off.
//
//   flutter build apk --release -t lib/probe_spiral_match.dart
//   adb install -r build/app/outputs/flutter-apk/app-release.apk
//   adb shell am start -n com.tianli.fluid_glass_example/.MainActivity
//   adb logcat -v brief | grep "SPM|"
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

enum _Mode {
  none,
  capture,
  spiral,
  // Let the ENGINE blur and the shader only refract, without ImageFilter
  // .compose (which snapshots the shader's input and breaks screen-space
  // uniforms). Two stacked BackdropFilters: the inner one's backdrop is the
  // outer one's filtered output, i.e. blur-then-lens, the same order the
  // capture path uses.
  nestedIn, // clip outside both, lens told SCREEN-space geometry
  nestedLocal, // clip outside both, lens told ELEMENT-local geometry
  nestedTexSize, // diagnostic: what texture does the nested lens actually get?
  nestedMid, // clip only around the inner lens
  plain,
}

const double _barW = 320;
const double _barH = 110;
const double _radius = 30;
// scope.blur() takes an Android-style RADIUS and converts it internally with
// blurRadiusToSigma. Feeding that same 8 to ImageFilter.blur(sigmaX:) as a
// sigma over-blurs by ~1.7x at dpr 4 -- which is what made the first sweep
// converge on an over-blurred `plain` instead of on `capture`.
const double _blurRadius = 8;
double _sigma = 8;
const double _lensHeight = 16;
const double _lensAmount = 28;

const List<int> _tapSweep = <int>[8, 12, 16, 24, 32, 48];

ui.FragmentProgram? _spiralProgram;
ui.FragmentProgram? _texSizeProgram;
final GlobalKey _captureKey = GlobalKey();
final ScrollController _scroll = ScrollController();

int _taps = 24;
double _dither = 1;

class _Config extends ChangeNotifier {
  _Mode mode = _Mode.none;
  bool stripes = true;
  int epoch = 0;
  void set({_Mode? mode, bool? stripes}) {
    if (mode != null) this.mode = mode;
    if (stripes != null) this.stripes = stripes;
    epoch++;
    notifyListeners();
  }
}

final _Config _config = _Config();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  try {
    _spiralProgram = await ui.FragmentProgram.fromAsset(
      'shaders/probe_glass_spiral.frag',
    );
    _texSizeProgram = await ui.FragmentProgram.fromAsset(
      'shaders/probe_texsize.frag',
    );
  } catch (e) {
    debugPrint('SPM| FATAL shader load: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

ui.ImageFilter _lensOnly(Rect r, Size layer) {
  final double keep = _sigma;
  _sigma = 0; // uSigma 0 skips the in-shader blur: refraction only
  final ui.ImageFilter f = _spiral(r, layer);
  _sigma = keep;
  return f;
}

ui.ImageFilter _spiral(Rect r, Size layer) {
  final ui.FragmentShader s = _spiralProgram!.fragmentShader();
  s
    ..setFloat(0, 0) // uTextureSize, engine-set
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
    ..setFloat(14, 0)
    ..setFloat(15, _sigma)
    ..setFloat(16, _taps.toDouble())
    ..setFloat(17, _dither);
  return ui.ImageFilter.shader(s);
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
    _config.addListener(_on);
  }

  void _on() => setState(() {});

  @override
  void dispose() {
    _config.removeListener(_on);
    super.dispose();
  }

  Widget _stripesBg() => CustomPaint(painter: _Stripes(), size: Size.infinite);

  Widget _feed() => ListView.builder(
    controller: _scroll,
    itemCount: 400,
    itemBuilder: (BuildContext _, int i) => Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Color(0xFF000000 | (i * 3719 + 0x204060) % 0xFFFFFF),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final _Mode mode = _config.mode;
    final ui.FlutterView view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final Size screen = view.physicalSize / view.devicePixelRatio;
    final Rect r = Rect.fromLTWH(
      (screen.width - _barW) / 2,
      _config.stripes
          ? (screen.height - _barH) / 2
          : screen.height - 40 - _barH,
      _barW,
      _barH,
    );
    const Widget hole = SizedBox(width: _barW, height: _barH);

    final Widget content = _config.stripes ? _stripesBg() : _feed();
    final Widget src = mode == _Mode.capture
        ? BackdropLayer(backdrop: _backdrop, child: content)
        : content;

    Widget? bar;
    switch (mode) {
      case _Mode.none:
        bar = null;
      case _Mode.capture:
        bar = DrawBackdrop(
          backdrop: _backdrop,
          shape: () => const RoundedRectangle(_radius),
          effects: (BackdropEffectScope scope) => scope
            ..blur(_blurRadius)
            ..lens(_lensHeight, _lensAmount),
          child: hole,
        );
      case _Mode.spiral:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(filter: _spiral(r, screen), child: hole),
        );
      case _Mode.nestedIn:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            child: BackdropFilter(filter: _lensOnly(r, screen), child: hole),
          ),
        );
      case _Mode.nestedLocal:
        // If the nested lens is handed the CLIPPED region rather than the
        // screen, then element-local geometry is what describes it: the layer
        // IS the element, so the origin is the element's own top-left.
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            child: BackdropFilter(
              filter: _lensOnly(Offset.zero & r.size, r.size),
              child: hole,
            ),
          ),
        );
      case _Mode.nestedTexSize:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            child: BackdropFilter(
              filter: ui.ImageFilter.shader(
                _texSizeProgram!.fragmentShader()
                  ..setFloat(0, 0)
                  ..setFloat(1, 0),
              ),
              child: hole,
            ),
          ),
        );
      case _Mode.nestedMid:
        bar = BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(filter: _lensOnly(r, screen), child: hole),
          ),
        );
      case _Mode.plain:
        bar = ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            child: hole,
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
            if (bar != null)
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
  final String d =
      Platform.environment['PROBE_DIR'] ??
      (Platform.isAndroid
          ? '/sdcard/Android/data/com.tianli.fluid_glass_example/files'
          : '.');
  try {
    Directory(d).createSync(recursive: true);
  } catch (_) {}
  return d;
}

Future<Uint8List?> _shoot(String name, Rect r) async {
  final RenderRepaintBoundary? b =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return null;
  final ui.Image img = await b.toImage(pixelRatio: 1.0);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png != null) {
    try {
      File(
        '$_outDir/spm_$name.png',
      ).writeAsBytesSync(png.buffer.asUint8List(), flush: true);
    } catch (_) {}
  }
  final ByteData? raw = await img.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int w = img.width;
  final int h = img.height;
  img.dispose();
  if (raw == null) return null;
  final int x0 = (r.left + 4).round();
  final int y0 = (r.top + 4).round();
  final int cw = (r.width - 8).round();
  final int ch = (r.height - 8).round();
  final Uint8List src = raw.buffer.asUint8List();
  final Uint8List out = Uint8List(cw * ch * 4);
  for (int y = 0; y < ch; y++) {
    out.setRange(y * cw * 4, (y + 1) * cw * 4, src, ((y0 + y) * w + x0) * 4);
  }
  _cw = cw;
  _ch = ch;
  _lastFull = src;
  _fullW = w;
  _fullH = h;
  return out;
}

Uint8List? _lastFull;
int _fullW = 0;
int _fullH = 0;

/// Mean |diff| over everything OUTSIDE the bar (plus a margin).
///
/// A BackdropFilter with no ClipRect filters the WHOLE screen. nestedMid
/// leaves its outer blur unclipped on purpose -- that is what keeps the inner
/// lens on a full-screen texture -- so the crop-based comparison would never
/// see it wreck the rest of the page. This does.
double _diffOutside(Uint8List a, Uint8List b, Rect bar) {
  final int x0 = (bar.left - 8).round();
  final int y0 = (bar.top - 8).round();
  final int x1 = (bar.right + 8).round();
  final int y1 = (bar.bottom + 8).round();
  double sum = 0;
  int n = 0;
  for (int y = 0; y < _fullH; y += 2) {
    for (int x = 0; x < _fullW; x += 2) {
      if (x >= x0 && x < x1 && y >= y0 && y < y1) continue;
      final int i = (y * _fullW + x) * 4;
      for (int k = 0; k < 3; k++) {
        sum += (a[i + k] - b[i + k]).abs();
        n++;
      }
    }
  }
  return n == 0 ? 0 : sum / n;
}

int _cw = 0;
int _ch = 0;

/// Mean |diff| split into a band along the element's edge and the rest.
///
/// The lens only bends a [_lensHeight]-deep band, so a variant that has the
/// refraction differs from a pure blur mostly in the rim; one that lost it
/// differs evenly. Comparing the two numbers says which, without eyeballing.
({double rim, double core}) _diffSplit(Uint8List a, Uint8List b, int w, int h) {
  const int band = 22; // _lensHeight plus a little for the blur's reach
  double rs = 0, cs = 0;
  int rn = 0, cn = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = (y * w + x) * 4;
      double d = 0;
      for (int k = 0; k < 3; k++) {
        d += (a[i + k] - b[i + k]).abs();
      }
      final bool isRim = x < band || y < band || x >= w - band || y >= h - band;
      if (isRim) {
        rs += d;
        rn += 3;
      } else {
        cs += d;
        cn += 3;
      }
    }
  }
  return (rim: rn == 0 ? 0 : rs / rn, core: cn == 0 ? 0 : cs / cn);
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

final List<int> _total = <int>[];
final List<int> _raster = <int>[];
bool _collect = false;
int _pointer = 1;

void _onTimings(List<FrameTiming> t) {
  if (!_collect) return;
  for (final FrameTiming f in t) {
    _total.add(f.totalSpan.inMicroseconds);
    _raster.add(f.rasterDuration.inMicroseconds);
  }
}

Future<void> _fling(Size screen) async {
  final double x = screen.width / 2;
  final double from = screen.height * 0.75;
  final double to = screen.height * 0.25;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: ++_pointer,
      position: Offset(x, from),
      kind: PointerDeviceKind.touch,
    ),
  );
  Offset last = Offset(x, from);
  for (int i = 1; i <= 14; i++) {
    final Offset next = Offset(x, from + (to - from) * i / 14);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: _pointer,
        position: next,
        delta: next - last,
        kind: PointerDeviceKind.touch,
      ),
    );
    last = next;
    await _settle(8);
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: _pointer,
      position: last,
      kind: PointerDeviceKind.touch,
    ),
  );
}

Future<double> _measure(String label, Size screen) async {
  _scroll.jumpTo(0);
  await _settle(400);
  _total.clear();
  _raster.clear();
  _collect = true;
  for (int i = 0; i < 5; i++) {
    await _fling(screen);
    await _settle(700);
  }
  _collect = false;
  if (_total.isEmpty) {
    debugPrint('SPM| $label NO FRAMES');
    return 0;
  }
  final double mt =
      _total.reduce((int a, int b) => a + b) / _total.length / 1000;
  final double mr =
      _raster.reduce((int a, int b) => a + b) / _raster.length / 1000;
  debugPrint(
    'SPM| $label n=${_total.length.toString().padLeft(3)} '
    'raster=${mr.toStringAsFixed(2)} total=${mt.toStringAsFixed(2)}',
  );
  return mt;
}

Future<void> _drive() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  _sigma = blurRadiusToSigma(
    _blurRadius,
    devicePixelRatio: view.devicePixelRatio,
  );
  debugPrint(
    'SPM| blur radius=$_blurRadius -> sigma=${_sigma.toStringAsFixed(3)}',
  );
  debugPrint(
    'SPM| screen=${screen.width.toStringAsFixed(0)}x'
    '${screen.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio} '
    'hz=${view.display.refreshRate.toStringAsFixed(0)}',
  );

  // ---- Phase 1: how close can the spiral get to the capture picture? ------
  _config.set(stripes: true);
  final Rect still = Rect.fromLTWH(
    (screen.width - _barW) / 2,
    (screen.height - _barH) / 2,
    _barW,
    _barH,
  );

  _config.set(mode: _Mode.none);
  await _settle(900);
  await _shoot('none', still);
  final Uint8List? pageRef = _lastFull;

  _config.set(mode: _Mode.capture);
  await _settle(900);
  final Uint8List? ref = await _shoot('capture', still);
  final Uint8List? pageCapture = _lastFull;
  _config.set(mode: _Mode.plain);
  await _settle(900);
  final Uint8List? flat = await _shoot('plain', still);
  final Uint8List? pagePlain = _lastFull;
  if (ref == null || flat == null) {
    debugPrint('SPM| FATAL no reference shots');
    exit(1);
  }
  final ({double rim, double core}) cp = _diffSplit(ref, flat, _cw, _ch);
  debugPrint(
    'SPM| capture vs plain = ${_diff(ref, flat).toStringAsFixed(2)} '
    '(rim ${cp.rim.toStringAsFixed(1)} core ${cp.core.toStringAsFixed(1)}) '
    '<- this IS the refraction, and it is rim-weighted',
  );
  debugPrint(
    'SPM| --- PICTURE: spiral vs the capture path (lower = closer) ---',
  );
  debugPrint('SPM| for scale: the old 2-ring 17-tap kernel scored 11.51');

  if (pageRef != null && pageCapture != null && pagePlain != null) {
    debugPrint(
      'SPM| --- LEAKAGE: does the effect escape the bar? '
      '(vs the no-glass page, outside the bar) ---',
    );
    debugPrint(
      'SPM| capture  outside=${_diffOutside(pageCapture, pageRef, still).toStringAsFixed(2)}'
      '   plain  outside=${_diffOutside(pagePlain, pageRef, still).toStringAsFixed(2)}',
    );
  }

  // Diagnostic first: decode the texture the nested lens is handed, so the
  // right uniforms are a measurement rather than a guess.
  _config.set(mode: _Mode.nestedTexSize);
  await _settle(850);
  await _shoot('nestedTexSize', still);
  if (_lastFull != null) {
    final int cx = (still.center.dx).round();
    final int cy = (still.center.dy).round();
    final int i = (cy * _fullW + cx) * 4;
    final int tx = _lastFull![i] * 256 + _lastFull![i + 1];
    final double ty = _lastFull![i + 2] / 255.0 * 2048.0;
    debugPrint(
      'SPM| nested lens is handed a ${tx}x${ty.toStringAsFixed(0)} texture '
      '(screen is ${(still.width + 0).toStringAsFixed(0)}-wide bar on a '
      '${_fullW}x$_fullH frame)',
    );
  }

  for (final _Mode m in <_Mode>[
    _Mode.nestedIn,
    _Mode.nestedLocal,
    _Mode.nestedMid,
    _Mode.spiral,
  ]) {
    _config.set(mode: m);
    await _settle(850);
    final Uint8List? px = await _shoot(m.name, still);
    if (px == null) continue;
    if (pageRef != null && _lastFull != null) {
      debugPrint(
        'SPM| ${m.name.padRight(9)} outside='
        '${_diffOutside(_lastFull!, pageRef, still).toStringAsFixed(2)}'
        '  <- must be ~0, or the effect is escaping the element',
      );
    }
    final ({double rim, double core}) vc = _diffSplit(px, ref, _cw, _ch);
    final ({double rim, double core}) vp = _diffSplit(px, flat, _cw, _ch);
    debugPrint(
      'SPM| ${m.name.padRight(9)}    '
      'vsCapture=${_diff(px, ref).toStringAsFixed(2).padLeft(5)} '
      '(rim ${vc.rim.toStringAsFixed(1)} core ${vc.core.toStringAsFixed(1)})'
      '  vsPlain=${_diff(px, flat).toStringAsFixed(2).padLeft(5)} '
      '(rim ${vp.rim.toStringAsFixed(1)} core ${vp.core.toStringAsFixed(1)})',
    );
  }

  int bestTaps = _tapSweep.first;
  double bestDiff = double.infinity;
  for (final double dith in <double>[0, 1]) {
    for (final int taps in _tapSweep) {
      _taps = taps;
      _dither = dith;
      _config.set(mode: _Mode.spiral);
      await _settle(650);
      final Uint8List? px = await _shoot(
        'spiral_${taps}_d${dith.toInt()}',
        still,
      );
      if (px == null) continue;
      final double d = _diff(px, ref);
      if (d < bestDiff) {
        bestDiff = d;
        bestTaps = taps;
        _dither = dith;
      }
      final ({double rim, double core}) vc = _diffSplit(px, ref, _cw, _ch);
      final ({double rim, double core}) vp = _diffSplit(px, flat, _cw, _ch);
      debugPrint(
        'SPM| taps=${taps.toString().padLeft(2)} d=${dith.toInt()} '
        'vsCapture=${d.toStringAsFixed(2).padLeft(5)} '
        '(rim ${vc.rim.toStringAsFixed(1)} core ${vc.core.toStringAsFixed(1)})'
        '  vsPlain=${_diff(px, flat).toStringAsFixed(2).padLeft(5)} '
        '(rim ${vp.rim.toStringAsFixed(1)} core ${vp.core.toStringAsFixed(1)})',
      );
    }
  }
  final double bestDither = _dither;
  debugPrint(
    'SPM| best: taps=$bestTaps dither=${bestDither.toInt()} '
    'vsCapture=${bestDiff.toStringAsFixed(2)}',
  );

  // ---- Phase 2: what does matching cost? ----------------------------------
  _config.set(stripes: false);
  await _settle(600);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  debugPrint('SPM| --- COST (the capture path costs ~1.7 ms net here) ---');

  final Map<String, List<double>> got = <String, List<double>>{};
  // nestedMid is the candidate now: it matched the capture picture to 0.36,
  // so the only open question is what its second BackdropFilter costs. plain
  // is the floor (one BackdropFilter, no lens); the gap between them is the
  // price of the refraction on this path.
  _taps = bestTaps;
  _dither = bestDither;
  const List<_Mode> timed = <_Mode>[
    _Mode.none,
    _Mode.capture,
    _Mode.nestedLocal,
    _Mode.plain,
    _Mode.spiral,
  ];
  for (int pass = 0; pass < 3; pass++) {
    final String tag = pass == 0 ? 'warmup' : 'PASS $pass';
    for (final _Mode m in timed) {
      _config.set(mode: m);
      await _settle(600);
      final double v = await _measure('$tag ${m.name.padRight(10)}', screen);
      if (pass > 0) (got[m.name] ??= <double>[]).add(v);
    }
  }
  SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  final List<double>? base = got['none'];
  if (base != null && base.isNotEmpty) {
    final double b = base.reduce((double a, double c) => a + c) / base.length;
    debugPrint('SPM| --- NET cost over no-glass (mean totalSpan) ---');
    for (final MapEntry<String, List<double>> e in got.entries) {
      final double m =
          e.value.reduce((double a, double c) => a + c) / e.value.length;
      debugPrint(
        'SPM| ${e.key.padRight(11)} total=${m.toStringAsFixed(2)} '
        'net=${(m - b).toStringAsFixed(2)} ms',
      );
    }
  }
  debugPrint('SPM| done');
  await _settle(300);
  exit(0);
}
