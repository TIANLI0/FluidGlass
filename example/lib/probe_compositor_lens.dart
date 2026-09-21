// Device validation for RenderDrawBackdrop.useCompositorLens.
//
// The flag moves a liquid-tier element off the capture path and onto nested
// BackdropFilterLayers. Probes established the arrangement works in isolation;
// this checks it on a real component (LiquidPanel: vibrancy + blur + lens,
// highlight, shadow) and answers the three questions that decide whether the
// default can ever be flipped:
//
//   1. PICTURE   does it still look like the capture path?
//   2. LEAKAGE   does the effect stay inside the element? (an unclipped
//                BackdropFilter filters the whole screen -- this already
//                caught one arrangement that scored a near-perfect picture
//                while blurring the entire page)
//   3. COST      measured on a flung feed, both paths alternated in ONE build,
//                because raster timings track GPU clock state.
//
// The flag is read outside paint (alwaysNeedsCompositing), so switching it
// re-keys the subtree rather than flipping it under live render objects.
//
//   flutter build apk --release -t lib/probe_compositor_lens.dart
//   adb install -r build/app/outputs/flutter-apk/app-release.apk
//   adb shell am start -n com.tianli.fluid_glass_example/.MainActivity
//   adb logcat -v brief | grep "CLP|"
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

const double _w = 300;
const double _h = 110;
const double _radius = 30;

final GlobalKey _captureKey = GlobalKey();
final ScrollController _scroll = ScrollController();

class _Config extends ChangeNotifier {
  bool compositor = false;
  bool glass = true;
  bool stripes = true;
  int epoch = 0;
  void set({bool? compositor, bool? glass, bool? stripes}) {
    if (compositor != null) {
      this.compositor = compositor;
      RenderDrawBackdrop.useCompositorLens = compositor;
    }
    if (glass != null) this.glass = glass;
    if (stripes != null) this.stripes = stripes;
    epoch++;
    notifyListeners();
  }
}

final _Config _config = _Config();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_drive());
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
    final ui.FlutterView view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final Size screen = view.physicalSize / view.devicePixelRatio;
    final Rect r = Rect.fromLTWH(
      (screen.width - _w) / 2,
      _config.stripes ? (screen.height - _h) / 2 : screen.height - 40 - _h,
      _w,
      _h,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _captureKey,
        // Re-key on the flag: RenderDrawBackdrop reads useCompositorLens
        // outside paint, so the render objects have to be rebuilt rather than
        // repainted for the switch to be coherent.
        child: KeyedSubtree(
          key: ValueKey<bool>(_config.compositor),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: _backdrop,
                  child: _config.stripes ? _stripesBg() : _feed(),
                ),
              ),
              if (_config.glass)
                Positioned(
                  left: r.left,
                  top: r.top,
                  width: _w,
                  height: _h,
                  child: LiquidPanel(
                    backdrop: _backdrop,
                    shape: const RoundedRectangle(_radius),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
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
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 12, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

Future<void> _settle(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

String get _outDir {
  const String d = '/sdcard/Android/data/com.tianli.fluid_glass_example/files';
  try {
    Directory(d).createSync(recursive: true);
    return d;
  } catch (_) {
    return '.';
  }
}

Uint8List? _lastFull;
int _fullW = 0, _fullH = 0, _cw = 0, _ch = 0;

Future<Uint8List?> _shoot(String name, Rect r) async {
  final RenderRepaintBoundary? b =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return null;
  final ui.Image img = await b.toImage(pixelRatio: 1.0);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  if (png != null) {
    try {
      File(
        '$_outDir/clp_$name.png',
      ).writeAsBytesSync(png.buffer.asUint8List(), flush: true);
    } catch (_) {}
  }
  final ByteData? raw = await img.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int w = img.width, h = img.height;
  img.dispose();
  if (raw == null) return null;
  final Uint8List src = raw.buffer.asUint8List();
  _lastFull = src;
  _fullW = w;
  _fullH = h;
  final int x0 = (r.left + 3).round();
  final int y0 = (r.top + 3).round();
  _cw = (r.width - 6).round();
  _ch = (r.height - 6).round();
  final Uint8List out = Uint8List(_cw * _ch * 4);
  for (int y = 0; y < _ch; y++) {
    out.setRange(y * _cw * 4, (y + 1) * _cw * 4, src, ((y0 + y) * w + x0) * 4);
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

({double rim, double core}) _split(Uint8List a, Uint8List b, int w, int h) {
  const int band = 24;
  double rs = 0, cs = 0;
  int rn = 0, cn = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = (y * w + x) * 4;
      double d = 0;
      for (int k = 0; k < 3; k++) {
        d += (a[i + k] - b[i + k]).abs();
      }
      if (x < band || y < band || x >= w - band || y >= h - band) {
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

/// Mean |diff| over everything OUTSIDE the element, against the no-glass page.
double _outside(Uint8List a, Uint8List b, Rect bar) {
  final int x0 = (bar.left - 10).round();
  final int y0 = (bar.top - 10).round();
  final int x1 = (bar.right + 10).round();
  final int y1 = (bar.bottom + 10).round();
  double s = 0;
  int n = 0;
  for (int y = 0; y < _fullH; y += 2) {
    for (int x = 0; x < _fullW; x += 2) {
      if (x >= x0 && x < x1 && y >= y0 && y < y1) continue;
      final int i = (y * _fullW + x) * 4;
      for (int k = 0; k < 3; k++) {
        s += (a[i + k] - b[i + k]).abs();
        n++;
      }
    }
  }
  return n == 0 ? 0 : s / n;
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
    debugPrint('CLP| $label NO FRAMES');
    return 0;
  }
  final double mt =
      _total.reduce((int a, int b) => a + b) / _total.length / 1000;
  final double mr =
      _raster.reduce((int a, int b) => a + b) / _raster.length / 1000;
  debugPrint(
    'CLP| $label n=${_total.length.toString().padLeft(3)} '
    'raster=${mr.toStringAsFixed(2)} total=${mt.toStringAsFixed(2)}',
  );
  return mt;
}

Future<void> _drive() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint(
    'CLP| screen=${screen.width.toStringAsFixed(0)}x'
    '${screen.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio} '
    'hz=${view.display.refreshRate.toStringAsFixed(0)}',
  );
  debugPrint('CLP| tier: ${GlassDeviceTier.instance.describe()}');

  final Rect still = Rect.fromLTWH(
    (screen.width - _w) / 2,
    (screen.height - _h) / 2,
    _w,
    _h,
  );

  // ---- 1 + 2: picture and leakage ----------------------------------------
  _config.set(stripes: true, glass: false, compositor: false);
  await _settle(900);
  await _shoot('page', still);
  final Uint8List? page = _lastFull;

  _config.set(glass: true, compositor: false);
  await _settle(1000);
  final Uint8List? captureShot = await _shoot('capture', still);
  final Uint8List? pageCapture = _lastFull;

  _config.set(compositor: true);
  await _settle(1000);
  final Uint8List? compositorShot = await _shoot('compositor', still);
  final Uint8List? pageCompositor = _lastFull;

  if (captureShot != null && compositorShot != null) {
    final ({double rim, double core}) s = _split(
      compositorShot,
      captureShot,
      _cw,
      _ch,
    );
    debugPrint(
      'CLP| PICTURE compositor vs capture = '
      '${_diff(compositorShot, captureShot).toStringAsFixed(2)} '
      '(rim ${s.rim.toStringAsFixed(1)} core ${s.core.toStringAsFixed(1)})',
    );
  }
  if (page != null && pageCapture != null && pageCompositor != null) {
    debugPrint(
      'CLP| LEAKAGE outside the panel, vs the no-glass page: '
      'capture=${_outside(pageCapture, page, still).toStringAsFixed(2)}  '
      'compositor=${_outside(pageCompositor, page, still).toStringAsFixed(2)}'
      '  <- compositor must not be far above capture',
    );
  }

  // ---- 3: cost -----------------------------------------------------------
  _config.set(stripes: false);
  await _settle(600);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  debugPrint('CLP| --- COST ---');
  final Map<String, List<double>> got = <String, List<double>>{};
  for (int pass = 0; pass < 3; pass++) {
    final String tag = pass == 0 ? 'warmup' : 'PASS $pass';

    _config.set(glass: false, compositor: false);
    await _settle(600);
    final double n = await _measure('$tag none       ', screen);
    if (pass > 0) (got['none'] ??= <double>[]).add(n);

    _config.set(glass: true, compositor: false);
    await _settle(600);
    final double c = await _measure('$tag capture    ', screen);
    if (pass > 0) (got['capture'] ??= <double>[]).add(c);

    _config.set(glass: true, compositor: true);
    await _settle(600);
    final double k = await _measure('$tag compositor ', screen);
    if (pass > 0) (got['compositor'] ??= <double>[]).add(k);
  }
  SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  final List<double>? base = got['none'];
  if (base != null && base.isNotEmpty) {
    final double b = base.reduce((double a, double c) => a + c) / base.length;
    debugPrint('CLP| --- NET over no-glass ---');
    for (final MapEntry<String, List<double>> e in got.entries) {
      final double m =
          e.value.reduce((double a, double c) => a + c) / e.value.length;
      debugPrint(
        'CLP| ${e.key.padRight(11)} total=${m.toStringAsFixed(2)} '
        'net=${(m - b).toStringAsFixed(2)} ms',
      );
    }
  }
  debugPrint('CLP| done');
  await _settle(300);
  exit(0);
}
