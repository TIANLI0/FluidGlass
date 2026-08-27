// Throwaway: what does a live (scrolling) backdrop actually cost, and where?
//
// Flings a feed under pinned glass chrome at three capture resolutions and
// prints raster percentiles for each. The point is to find out whether the
// full-screen `toImageSync` dominates, before optimising anything.
//
//   flutter build apk --release -t lib/probe_live_perf.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

final _Config _config = _Config();

class _Config extends ChangeNotifier {
  double? captureRatio;
  bool chrome = true;
  bool itemBoundaries = true;

  /// Forces the whole-source capture path: a consumer with a layer transform
  /// cannot describe the region it reads, so it asks for everything. A no-op
  /// block is therefore an A/B switch for the region-capture optimisation.
  bool wholeSourceCapture = false;

  void set({
    double? ratio,
    bool? withChrome,
    bool? boundaries,
    bool? wholeSource,
  }) {
    captureRatio = ratio;
    if (withChrome != null) chrome = withChrome;
    if (boundaries != null) itemBoundaries = boundaries;
    if (wholeSource != null) wholeSourceCapture = wholeSource;
    notifyListeners();
  }
}

final ScrollController _scroll = ScrollController();

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
    _config.addListener(_onConfig);
  }

  void _onConfig() => setState(() {});

  @override
  void dispose() {
    _config.removeListener(_onConfig);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: _backdrop,
                pixelRatio: _config.captureRatio,
                child: ListView.builder(
                  controller: _scroll,
                  // The thing under test: a repaint boundary per item inside a
                  // captured subtree.
                  addRepaintBoundaries: _config.itemBoundaries,
                  itemExtent: 120,
                  itemCount: 200,
                  itemBuilder: (BuildContext context, int i) => Padding(
                    padding: const EdgeInsets.all(6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(colors: <Color>[
                          Color(0xFF000000 | (i * 3719 % 0xFFFFFF)),
                          Color(0xFF000000 | (i * 8231 % 0xFFFFFF)),
                        ]),
                      ),
                      child: Center(
                        child: Text('Row $i',
                            style: const TextStyle(
                                color: Color(0xFFFFFFFF), fontSize: 22)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_config.chrome) ...<Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidPanel(
                  backdrop: _backdrop,
                  shape: const RoundedRectangle(0),
                  layerBlock:
                      _config.wholeSourceCapture ? (GlassLayer l) {} : null,
                  child: const SizedBox(height: 96, width: double.infinity),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: LiquidPanel(
                  backdrop: _backdrop,
                  shape: const RoundedRectangle(28),
                  layerBlock:
                      _config.wholeSourceCapture ? (GlassLayer l) {} : null,
                  child: const SizedBox(height: 72, width: double.infinity),
                ),
              ),
            ],
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

Future<void> _settle(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _fling(Size screen) async {
  final double x = screen.width / 2;
  final double from = screen.height * 0.8;
  final double to = screen.height * 0.2;
  GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: ++_pointer,
      position: Offset(x, from),
      kind: PointerDeviceKind.touch));
  Offset last = Offset(x, from);
  for (int i = 1; i <= 14; i++) {
    final Offset next = Offset(x, from + (to - from) * i / 14);
    GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
      pointer: _pointer,
      position: next,
      delta: next - last,
      kind: PointerDeviceKind.touch,
    ));
    last = next;
    await _settle(8);
  }
  GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: _pointer, position: last, kind: PointerDeviceKind.touch));
}

String _one(String name, List<int> src) {
  final List<int> x = List<int>.of(src)..sort();
  double at(double f) => x[(x.length * f).floor().clamp(0, x.length - 1)] / 1000;
  final double mean = x.reduce((int a, int b) => a + b) / x.length / 1000;
  return '$name mean=${mean.toStringAsFixed(2)} '
      'p90=${at(0.9).toStringAsFixed(2)} max=${(x.last / 1000).toStringAsFixed(2)}';
}

String _stats(String label) {
  if (_raster.isEmpty) return '$label no frames';
  return '$label frames=${_raster.length}  ${_one("raster", _raster)}  '
      '${_one("build", _build)}  ${_one("total", _total)}';
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
  debugPrint('LIVE| ${_stats(label)}');
}

Future<void> _drive() async {
  await _settle(2500);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint('LIVE| screen=${screen.width}x${screen.height} '
      'dpr=${view.devicePixelRatio} hz=${view.display.refreshRate}');

  // Two passes. The first is warm-up — on a software-rendered emulator the
  // first phase measured came out worst regardless of what it was — so only
  // the second pass means anything, and even then only as a ratio.
  for (int pass = 0; pass < 2; pass++) {
    final String tag = pass == 0 ? 'warmup' : 'PASS 2';

    _config.set(ratio: null, withChrome: false);
    await _settle(600);
    await _measure('$tag no glass              ', screen);

    // Whole-source capture: what this did before the region cache.
    _config.set(ratio: null, withChrome: true, wholeSource: true);
    await _settle(600);
    await _measure('$tag capture whole source  ', screen);

    // Region capture: only the strips the chrome actually reads.
    _config.set(ratio: null, withChrome: true, wholeSource: false);
    await _settle(600);
    await _measure('$tag capture regions only  ', screen);

    _config.set(ratio: 0.5, withChrome: true, wholeSource: false);
    await _settle(600);
    await _measure('$tag regions + pixelRatio ½', screen);
  }

  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('LIVE| done');
}
