// Throwaway: can the lens run inside a BackdropFilter, and is it cheaper?
//
// The liquid tier captures the source with `OffsetLayer.toImageSync` because
// draw_backdrop.dart:769 says a shader in a backdrop filter "is handed the
// whole screen rather than the element's texture, so the lens would have
// nothing to anchor its geometry to".
//
// probe_backdrop_shader_size confirmed the first half: a ClipRect does NOT
// shrink the texture -- the shader always sees the whole screen (plus any
// blur margin). But the second half does not follow. refraction.frag already
// maps texture space -> layer space through uniforms, so feeding it
//
//     uLayerSize = the screen, uSize = the element, uOffset = -elementTopLeft
//
// anchors the SDF in screen space with no shader change at all. The only open
// question is cost: does Impeller shade the whole screen through that filter,
// or only the clipped region?
//
// Four paths over one live scrolling source, alternated in one run:
//   none     no glass
//   capture  today's liquid tier (toImageSync + lens on the element texture)
//   bdShader the candidate (BackdropFilter + lens anchored in screen space)
//   plain    today's cheap tier (BackdropFilter + blur, no lens)
//
//   flutter build windows --release -t lib/probe_backdrop_lens_perf.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum _Mode { none, capture, bdShader, plain }

const double _barW = 320;
const double _barH = 84;
const double _barBottom = 40;
const double _radius = 28;
const double _blurSigma = 8;
const double _lensHeight = 12;
const double _lensAmount = 24;

ui.FragmentProgram? _refraction;

class _Config extends ChangeNotifier {
  _Mode mode = _Mode.none;
  void set(_Mode m) {
    mode = m;
    notifyListeners();
  }
}

final _Config _config = _Config();
final ScrollController _scroll = ScrollController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  try {
    _refraction = await ui.FragmentProgram.fromAsset(
      'packages/fluid_glass/shaders/refraction.frag',
    );
  } catch (e) {
    debugPrint('BDLENS| FATAL could not load refraction.frag: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

/// The lens, anchored in screen space instead of in the element's own texture.
ui.ImageFilter _screenSpaceLens(Rect elementRect, Size screen) {
  final ui.FragmentShader s = _refraction!.fragmentShader();
  s
    // 0..1 are uTextureSize; the engine overwrites them.
    ..setFloat(0, 0)
    ..setFloat(1, 0)
    // The filtered layer IS the screen here, not a padded element texture.
    ..setFloat(2, screen.width)
    ..setFloat(3, screen.height)
    ..setFloat(4, elementRect.width)
    ..setFloat(5, elementRect.height)
    // coord + uOffset must land in element space, so uOffset = -topLeft.
    ..setFloat(6, -elementRect.left)
    ..setFloat(7, -elementRect.top)
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
    _config.addListener(_onCfg);
  }

  void _onCfg() => setState(() {});

  @override
  void dispose() {
    _config.removeListener(_onCfg);
    super.dispose();
  }

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
    final Rect barRect = Rect.fromLTWH(
      (screen.width - _barW) / 2,
      screen.height - _barBottom - _barH,
      _barW,
      _barH,
    );

    // Only the capture path needs the source wrapped; wrapping it for the
    // others would measure a BackdropLayer nobody reads.
    final Widget feed = mode == _Mode.capture
        ? BackdropLayer(backdrop: _backdrop, child: _feed())
        : _feed();

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
      home: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: feed),
            if (bar != null)
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

int _pointer = 1;
final List<int> _raster = <int>[];
final List<int> _build = <int>[];
final List<int> _total = <int>[];
bool _collect = false;

void _onTimings(List<FrameTiming> timings) {
  if (!_collect) return;
  for (final FrameTiming t in timings) {
    _raster.add(t.rasterDuration.inMicroseconds);
    _build.add(t.buildDuration.inMicroseconds);
    _total.add(t.totalSpan.inMicroseconds);
  }
}

Future<void> _settle(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _fling(Size screen) async {
  final double x = screen.width / 2;
  final double from = screen.height * 0.8;
  final double to = screen.height * 0.2;
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
  return '$name mean=${mean.toStringAsFixed(2)} '
      'p90=${at(0.9).toStringAsFixed(2)}';
}

Future<void> _measure(String label, Size screen) async {
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
  if (_raster.isEmpty) {
    debugPrint('BDLENS| $label no frames');
    return;
  }
  debugPrint(
    'BDLENS| $label frames=${_raster.length}  ${_one("raster", _raster)}  '
    '${_one("build", _build)}  ${_one("total", _total)}',
  );
}

Future<void> _drive() async {
  await _settle(2500);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint(
    'BDLENS| screen=${screen.width.toStringAsFixed(0)}x'
    '${screen.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio} '
    'hz=${view.display.refreshRate}',
  );

  // Pass 0 is warm-up; GPU clock state makes the first phase measured look
  // worst whatever it is. Only pass 1 and 2 are read, and only as a ratio.
  for (int pass = 0; pass < 3; pass++) {
    final String tag = pass == 0 ? 'warmup ' : 'PASS $pass ';
    for (final _Mode m in _Mode.values) {
      _config.set(m);
      await _settle(600);
      await _measure('$tag${m.name.padRight(9)}', screen);
    }
  }

  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('BDLENS| done');
  await _settle(200);
  exit(0);
}
