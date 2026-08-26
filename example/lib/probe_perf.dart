// A throwaway harness: drags the bottom-tabs pill back and forth continuously
// and prints frame-timing statistics, to compare before/after optimisations.
//
// Run with:  flutter run -d windows --release -t lib/probe_perf.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'catalog/components/liquid_bottom_tabs.dart';
import 'catalog/flight_icon.dart';

final GlobalKey _tabsKey = GlobalKey();
const int _tabsCount = 3;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _ProbeApp());
  unawaited(_drive());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();
  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  int _index = 0;

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
                child: SizedBox.expand(
                  child: Image.asset('assets/wallpaper_light.webp',
                      fit: BoxFit.cover),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: LiquidBottomTabs(
                  key: _tabsKey,
                  selectedTabIndex: _index,
                  onTabSelected: (int i) => setState(() => _index = i),
                  backdrop: _backdrop,
                  tabsCount: _tabsCount,
                  children: <Widget>[
                    for (int i = 0; i < _tabsCount; i++)
                      LiquidBottomTab(
                        onPressed: () => setState(() => _index = i),
                        children: <Widget>[
                          const FlightIcon(size: 28, color: Color(0xFF000000)),
                          Text('Tab ${i + 1}',
                              style: const TextStyle(
                                  color: Color(0xFF000000), fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

int _pointer = 1;

Rect _tabsRect() {
  final RenderBox box =
      _tabsKey.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

double _tabWidth() => (_tabsRect().width - 8.0) / _tabsCount;

Offset _pillCentre(double value) {
  final Rect rect = _tabsRect();
  return Offset(
    rect.left + 4 + (value + 0.5) * _tabWidth(),
    rect.top + 32,
  );
}

Offset _last = Offset.zero;

void _down(Offset p) {
  _last = p;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
        pointer: ++_pointer, position: p, kind: PointerDeviceKind.touch),
  );
}

void _move(Offset p) {
  GestureBinding.instance.handlePointerEvent(
    PointerMoveEvent(
      pointer: _pointer,
      position: p,
      delta: p - _last,
      kind: PointerDeviceKind.touch,
    ),
  );
  _last = p;
}

void _up() {
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
        pointer: _pointer, position: _last, kind: PointerDeviceKind.touch),
  );
}

Future<void> _settle([int ms = 700]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Maximizes the native window, so the glass covers a full-screen backdrop.
///
/// The freshly launched probe window is the foreground window, so no window
/// lookup by title is needed.
void _maximizeWindow() {
  final DynamicLibrary user32 = DynamicLibrary.open('user32.dll');
  final int hwnd = user32.lookupFunction<IntPtr Function(),
      int Function()>('GetForegroundWindow')();
  if (hwnd != 0) {
    const int swMaximize = 3;
    user32.lookupFunction<Int32 Function(IntPtr, Int32),
        int Function(int, int)>('ShowWindow')(hwnd, swMaximize);
  }
}

Future<void> _drive() async {
  await _settle(1000);
  if (Platform.environment['PROBE_MAX'] == '1') {
    _maximizeWindow();
  }
  await _settle(1000);

  // Press the pill, then slide it sinusoidally across the bar.
  _down(_pillCentre(0));
  await _settle(500);

  final List<int> build = <int>[];
  final List<int> raster = <int>[];
  final List<int> total = <int>[];
  void onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      build.add(t.buildDuration.inMicroseconds);
      raster.add(t.rasterDuration.inMicroseconds);
      total.add(t.totalSpan.inMicroseconds);
    }
  }

  SchedulerBinding.instance.addTimingsCallback(onTimings);

  const int seconds = 6;
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsedMilliseconds < seconds * 1000) {
    final double phase = clock.elapsedMilliseconds / 1400.0 * 2 * math.pi;
    final double value =
        (1 - math.cos(phase)) / 2 * (_tabsCount - 1); // 0 -> 2 -> 0
    _move(_pillCentre(value));
    await _settle(8);
  }

  SchedulerBinding.instance.removeTimingsCallback(onTimings);
  _up();
  await _settle(500);

  String stats(String label, List<int> xs) {
    if (xs.isEmpty) return '$label: no frames';
    xs.sort();
    final double mean = xs.reduce((int a, int b) => a + b) / xs.length / 1000;
    final double p50 = xs[xs.length ~/ 2] / 1000;
    final double p90 =
        xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)] / 1000;
    final double p99 =
        xs[(xs.length * 0.99).floor().clamp(0, xs.length - 1)] / 1000;
    return '$label mean=${mean.toStringAsFixed(2)}ms '
        'p50=${p50.toStringAsFixed(2)}ms p90=${p90.toStringAsFixed(2)}ms '
        'p99=${p99.toStringAsFixed(2)}ms';
  }

  final FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  _report('window=${view.physicalSize} dpr=${view.devicePixelRatio}');
  _report('frames=${build.length} over ${seconds}s '
      '(${(build.length / seconds).toStringAsFixed(0)} fps)');
  _report(stats('build ', build));
  _report(stats('raster', raster));
  _report(stats('total ', total));
  await stdout.flush();
  exit(0);
}

/// Emits a line on desktop and on Android alike.
///
/// A release Android build's `stdout` does not reach logcat; `debugPrint` does,
/// under the `flutter` tag. Desktop wants the real stdout, so both are used.
void _report(String line) {
  final String text = 'PERF| $line';
  debugPrint(text);
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    stdout.writeln(text);
  }
}
