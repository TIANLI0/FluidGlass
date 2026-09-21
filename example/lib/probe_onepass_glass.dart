// Throwaway: is one-pass glass (refraction + blur in a single BackdropFilter
// shader) both correct and cheaper than today's capture path?
//
// Established so far, all on real Impeller:
//  * a ClipRect does NOT shrink the texture a shader gets in a BackdropFilter
//    -- it is always the whole screen (probe_backdrop_shader_size);
//  * but the SDF anchors perfectly when fed the element's screen rect
//    (probe_sdf_anchor paints a green band exactly on the rim);
//  * the lens alone in a BackdropFilter refracts correctly, and composing it
//    with ImageFilter.blur silently drops the refraction
//    (probe_bdlens_variants) -- flutter/flutter#170820.
//
// So this tries the way round that avoids the compose: one shader that
// refracts and blurs together, the same argument shaders/fusion.frag makes.
//
// Phase 1 measures the PICTURE against the capture path. Phase 2 measures the
// COST. A variant that wins phase 2 but loses phase 1 is a no-op running fast,
// which is the trap that already caught this investigation once.
//
//   Windows: flutter build windows --release -t lib/probe_onepass_glass.dart
//   Android: flutter build apk --release -t lib/probe_onepass_glass.dart
//            adb install -r build/app/outputs/flutter-apk/app-release.apk
//            adb shell am start -n com.example.fluid_glass_example/.MainActivity
//            adb logcat -v brief | grep "OPG|"
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
  none('no glass at all'),
  capture('capture + lens (today liquid tier)'),
  onePass('BackdropFilter, one-pass lens+blur shader'),
  composed('BackdropFilter compose(lens, blur) [known broken]'),
  composeFlip('BackdropFilter compose(blur, lens) [untried order]'),
  plain('BackdropFilter blur only (today cheap tier)');

  const _Mode(this.label);
  final String label;
}

const double _barW = 320;
const double _barH = 110;
const double _radius = 30;
const double _blurSigma = 8;
// The one-pass kernel spans two rings at this spacing. Phase 1 sweeps it to
// find where the picture actually matches the capture path's sigma-8 Gaussian;
// comparing cost at a weaker blur would be comparing a cheaper effect.
const List<double> _tapSweep = <double>[3.2, 6.4, 9.6, 12.8];
double _blurTap = 3.2;
const double _lensHeight = 16;
const double _lensAmount = 28;

ui.FragmentProgram? _onePassProgram;
ui.FragmentProgram? _refractionProgram;
final GlobalKey _captureKey = GlobalKey();
final ScrollController _scroll = ScrollController();

class _Config extends ChangeNotifier {
  _Mode mode = _Mode.none;
  bool stripes = true;
  void set({_Mode? mode, bool? stripes}) {
    if (mode != null) this.mode = mode;
    if (stripes != null) this.stripes = stripes;
    notifyListeners();
  }
}

final _Config _config = _Config();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  try {
    _onePassProgram = await ui.FragmentProgram.fromAsset(
      'shaders/probe_glass_onepass.frag',
    );
    _refractionProgram = await ui.FragmentProgram.fromAsset(
      'packages/fluid_glass/shaders/refraction.frag',
    );
  } catch (e) {
    debugPrint('OPG| FATAL shader load: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

void _setGeometry(ui.FragmentShader s, Rect r, Size layer) {
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
    ..setFloat(14, 0);
}

ui.ImageFilter _onePass(Rect r, Size layer) {
  final ui.FragmentShader s = _onePassProgram!.fragmentShader();
  _setGeometry(s, r, layer);
  s.setFloat(15, _blurTap);
  return ui.ImageFilter.shader(s);
}

ui.ImageFilter _lensOnly(Rect r, Size layer) {
  final ui.FragmentShader s = _refractionProgram!.fragmentShader();
  _setGeometry(s, r, layer);
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
    _config.addListener(_on);
  }

  void _on() => setState(() {});

  @override
  void dispose() {
    _config.removeListener(_on);
    super.dispose();
  }

  Widget _stripes() => CustomPaint(painter: _Stripes(), size: Size.infinite);

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

  Widget _clip(Widget child) =>
      ClipRRect(borderRadius: BorderRadius.circular(_radius), child: child);

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

    final Widget content = _config.stripes ? _stripes() : _feed();
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
            ..blur(_blurSigma)
            ..lens(_lensHeight, _lensAmount),
          child: hole,
        );
      case _Mode.onePass:
        bar = _clip(BackdropFilter(filter: _onePass(r, screen), child: hole));
      case _Mode.composed:
        bar = _clip(
          BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: _lensOnly(r, screen),
              inner: _blur,
            ),
            child: hole,
          ),
        );
      case _Mode.composeFlip:
        bar = _clip(
          BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: _blur,
              inner: _lensOnly(r, screen),
            ),
            child: hole,
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
  final String d = Platform.environment['PROBE_DIR'] ?? '.';
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
        '$_outDir/opg_$name.png',
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
  final int x0 = (r.left + 4).round().clamp(0, w - 1);
  final int y0 = (r.top + 4).round().clamp(0, h - 1);
  final int cw = (r.width - 8).round().clamp(1, w - x0);
  final int ch = (r.height - 8).round().clamp(1, h - y0);
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

final List<int> _raster = <int>[];
final List<int> _build = <int>[];
final List<int> _total = <int>[];
bool _collect = false;
int _pointer = 1;

void _onTimings(List<FrameTiming> timings) {
  if (!_collect) return;
  for (final FrameTiming t in timings) {
    _raster.add(t.rasterDuration.inMicroseconds);
    _build.add(t.buildDuration.inMicroseconds);
    _total.add(t.totalSpan.inMicroseconds);
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

String _one(String name, List<int> src) {
  final List<int> x = List<int>.of(src)..sort();
  double at(double f) =>
      x[(x.length * f).floor().clamp(0, x.length - 1)] / 1000;
  final double mean = x.reduce((int a, int b) => a + b) / x.length / 1000;
  return '$name=${mean.toStringAsFixed(2)}/${at(0.9).toStringAsFixed(2)}';
}

Future<double> _measure(String label, Size screen) async {
  _scroll.jumpTo(0);
  await _settle(400);
  _raster.clear();
  _build.clear();
  _total.clear();
  _collect = true;
  for (int i = 0; i < 5; i++) {
    await _fling(screen);
    await _settle(700);
  }
  _collect = false;
  if (_total.isEmpty) {
    debugPrint('OPG| $label NO FRAMES (screen asleep?)');
    return 0;
  }
  final double meanTotal =
      _total.reduce((int a, int b) => a + b) / _total.length / 1000;
  debugPrint(
    'OPG| $label n=${_total.length.toString().padLeft(4)} '
    '${_one("raster", _raster)} ${_one("build", _build)} '
    '${_one("total", _total)}   (mean/p90 ms)',
  );
  return meanTotal;
}

Future<void> _drive() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final double dpr = view.devicePixelRatio;
  final Size screen = view.physicalSize / dpr;
  debugPrint(
    'OPG| screen=${screen.width.toStringAsFixed(0)}x'
    '${screen.height.toStringAsFixed(0)} dpr=$dpr '
    'hz=${view.display.refreshRate.toStringAsFixed(0)} out=$_outDir',
  );

  // ---- Phase 1: the picture ------------------------------------------------
  _config.set(stripes: true);
  final Rect still = Rect.fromLTWH(
    (screen.width - _barW) / 2,
    (screen.height - _barH) / 2,
    _barW,
    _barH,
  );
  final Map<_Mode, Uint8List> shots = <_Mode, Uint8List>{};
  for (final _Mode m in _Mode.values) {
    if (m == _Mode.none) continue;
    _config.set(mode: m);
    await _settle(900);
    final Uint8List? px = await _shoot(m.name, still);
    if (px != null) shots[m] = px;
  }
  final Uint8List? ref = shots[_Mode.capture];
  final Uint8List? flat = shots[_Mode.plain];
  debugPrint('OPG| --- PICTURE: distance from the two poles ---');
  debugPrint('OPG| refracting => far from plain. a no-op => ~0 from plain.');
  if (ref != null && flat != null) {
    for (final _Mode m in _Mode.values) {
      final Uint8List? px = shots[m];
      if (px == null) continue;
      debugPrint(
        'OPG| ${m.name.padRight(12)} vsPlain='
        '${_diff(px, flat).toStringAsFixed(2).padLeft(6)} vsCapture='
        '${_diff(px, ref).toStringAsFixed(2).padLeft(6)}  ${m.label}',
      );
    }

    // Comparing cost at a weaker blur would flatter the one-pass path, so find
    // the tap spacing whose picture is actually closest to the capture path
    // and time THAT.
    debugPrint('OPG| --- matching the blur: tap spacing sweep ---');
    double bestTap = _blurTap;
    double bestDiff = double.infinity;
    for (final double tap in _tapSweep) {
      _blurTap = tap;
      _config.set(mode: _Mode.onePass);
      _config.set(); // force a rebuild with the new tap
      await _settle(700);
      final Uint8List? px = await _shoot('onePass_tap$tap', still);
      if (px == null) continue;
      final double d = _diff(px, ref);
      if (d < bestDiff) {
        bestDiff = d;
        bestTap = tap;
      }
      debugPrint(
        'OPG| tap=${tap.toStringAsFixed(1).padLeft(5)} '
        'vsCapture=${d.toStringAsFixed(2).padLeft(6)} '
        'vsPlain=${_diff(px, flat).toStringAsFixed(2).padLeft(6)}',
      );
    }
    _blurTap = bestTap;
    debugPrint(
      'OPG| closest match tap=${bestTap.toStringAsFixed(1)} '
      '(vsCapture=${bestDiff.toStringAsFixed(2)}) -- timing this one',
    );
  }

  // ---- Phase 2: the cost ---------------------------------------------------
  _config.set(stripes: false);
  await _settle(600);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  debugPrint('OPG| --- COST: 5 flings of a live feed under the bar ---');
  const List<_Mode> timed = <_Mode>[
    _Mode.none,
    _Mode.capture,
    _Mode.onePass,
    _Mode.plain,
  ];
  // Two passes, alternating, because raster time tracks GPU clock state and a
  // number from a single phase is not comparable to anything.
  final Map<_Mode, List<double>> got = <_Mode, List<double>>{};
  for (int pass = 0; pass < 3; pass++) {
    for (final _Mode m in timed) {
      _config.set(mode: m);
      await _settle(600);
      final double t = await _measure(
        '${pass == 0 ? "warmup" : "PASS $pass"} ${m.name.padRight(9)}',
        screen,
      );
      if (pass > 0) (got[m] ??= <double>[]).add(t);
    }
  }
  SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  final List<double>? base = got[_Mode.none];
  if (base != null && base.isNotEmpty) {
    final double b = base.reduce((double a, double c) => a + c) / base.length;
    debugPrint('OPG| --- NET glass cost, mean totalSpan over no-glass ---');
    for (final _Mode m in timed) {
      final List<double>? v = got[m];
      if (v == null || v.isEmpty) continue;
      final double mean = v.reduce((double a, double c) => a + c) / v.length;
      debugPrint(
        'OPG| ${m.name.padRight(9)} total=${mean.toStringAsFixed(2)} '
        'net=${(mean - b).toStringAsFixed(2)} ms',
      );
    }
  }

  debugPrint('OPG| done');
  await _settle(300);
  exit(0);
}
