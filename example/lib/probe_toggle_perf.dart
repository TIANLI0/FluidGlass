// Run on a physical device with --profile -t lib/probe_toggle_perf.dart.
// Same workload before/after: warmup, then two measured passes. No screenshots
// or logging occur inside a measured interval. TOGGLE_SHOT holds visual states.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const bool _shot = bool.fromEnvironment('TOGGLE_SHOT');
final GlobalKey<_BenchState> _bench = GlobalKey<_BenchState>();
final List<FrameTiming> _frames = <FrameTiming>[];
bool _collect = false;
int _pointer = 100;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  GlassDeviceTier.instance.pinnedQuality = GlassQuality.liquid;
  runApp(
    MaterialApp(debugShowCheckedModeBanner: false, home: _Bench(key: _bench)),
  );
  unawaited(_drive());
}

class _Bench extends StatefulWidget {
  const _Bench({super.key});
  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  final LayerBackdrop backdrop = LayerBackdrop();
  final List<GlobalKey> keys = List<GlobalKey>.generate(8, (_) => GlobalKey());
  int count = 1;
  bool selected = false;

  void configure({int? count, bool? selected}) => setState(() {
    this.count = count ?? this.count;
    this.selected = selected ?? this.selected;
  });

  @override
  void dispose() {
    backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            child: Image.asset(
              'assets/wallpaper_light.webp',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LiquidToggle(
                    key: keys[i],
                    selected: selected,
                    onSelect: (bool value) => configure(selected: value),
                    backdrop: backdrop,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _drag(int count, int ms) async {
  final List<Offset> starts = <Offset>[];
  final List<int> pointers = <int>[];
  for (int i = 0; i < count; i++) {
    final RenderBox box =
        _bench.currentState!.keys[i].currentContext!.findRenderObject()!
            as RenderBox;
    final Offset start = box.localToGlobal(const Offset(22, 14));
    starts.add(start);
    pointers.add(++_pointer);
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: pointers.last,
        position: start,
        kind: PointerDeviceKind.touch,
      ),
    );
  }
  double previous = 0;
  final Stopwatch watch = Stopwatch()..start();
  while (watch.elapsedMilliseconds < ms) {
    await SchedulerBinding.instance.endOfFrame;
    final double x =
        10 * (1 - math.cos(watch.elapsedMilliseconds / 700 * math.pi));
    for (int i = 0; i < count; i++) {
      GestureBinding.instance.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointers[i],
          position: starts[i] + Offset(x, 0),
          delta: Offset(x - previous, 0),
          kind: PointerDeviceKind.touch,
        ),
      );
    }
    previous = x;
  }
  for (int i = 0; i < count; i++) {
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        pointer: pointers[i],
        position: starts[i] + Offset(previous, 0),
        kind: PointerDeviceKind.touch,
      ),
    );
  }
}

Map<String, double> _stats(Iterable<Duration> values) {
  final List<int> sorted = values.map((d) => d.inMicroseconds).toList()..sort();
  return <String, double>{
    'mean': sorted.reduce((a, b) => a + b) / sorted.length / 1000,
    'p90': sorted[(sorted.length * 0.90).floor()] / 1000,
    'p99': sorted[(sorted.length * 0.99).floor()] / 1000,
  };
}

Future<void> _measure(String label, Future<void> Function() action) async {
  await _wait(1000);
  _frames.clear();
  _collect = true;
  final int begin = Timeline.now;
  await action();
  final int end = Timeline.now;
  await _wait(1100); // FrameTiming arrives in batches in profile mode.
  _collect = false;
  final List<FrameTiming> frames = _frames.where((f) {
    final int stamp = f.timestampInMicroseconds(ui.FramePhase.buildStart);
    return stamp >= begin && stamp <= end;
  }).toList();
  if (frames.isEmpty) {
    debugPrint('TOGGLE| no frames $label');
    return;
  }
  debugPrint(
    'TOGGLE| ${jsonEncode(<String, Object>{'label': label, 'frames': frames.length, 'build': _stats(frames.map((f) => f.buildDuration)), 'raster': _stats(frames.map((f) => f.rasterDuration)), 'total': _stats(frames.map((f) => f.totalSpan)), 'workOver8ms': frames.where((f) => f.buildDuration.inMicroseconds > 8333 || f.rasterDuration.inMicroseconds > 8333).length})}',
  );
}

Future<void> _drive() async {
  await _wait(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  debugPrint(
    'TOGGLE| dpr=${view.devicePixelRatio} hz=${view.display.refreshRate}',
  );
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  if (_shot) {
    for (final bool selected in <bool>[false, true]) {
      _bench.currentState!.configure(selected: selected);
      await _wait(1200);
      final RenderBox box =
          _bench.currentState!.keys[0].currentContext!.findRenderObject()!
              as RenderBox;
      final Offset point = box.localToGlobal(Offset(selected ? 42 : 22, 14));
      GestureBinding.instance.handlePointerEvent(
        PointerDownEvent(pointer: ++_pointer, position: point),
      );
      await _wait(1000);
      debugPrint('TOGGLE| HOLD $selected');
      await _wait(5000);
      GestureBinding.instance.handlePointerEvent(
        PointerCancelEvent(pointer: _pointer),
      );
    }
  } else {
    for (int pass = 0; pass < 3; pass++) {
      for (final int count in <int>[1, 8]) {
        _bench.currentState!.configure(count: count, selected: false);
        await _measure('pass=$pass count=$count switch', () async {
          for (int i = 0; i < 8; i++) {
            _bench.currentState!.configure(selected: i.isEven);
            await _wait(450);
          }
        });
        _bench.currentState!.configure(selected: false);
        await _measure(
          'pass=$pass count=$count drag',
          () => _drag(count, 3600),
        );
      }
    }
  }
  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('TOGGLE| done');
}

void _onTimings(List<FrameTiming> frames) {
  if (_collect) _frames.addAll(frames);
}
