// flutter run --profile -d <device> -t lib/probe_soft_motion_perf.dart
// Drives one pointer move per rendered frame; prints frame work and rebound.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

final GlobalKey<_BenchState> _bench = GlobalKey<_BenchState>();
final List<FrameTiming> _timings = <FrameTiming>[];
bool _collect = false;
int _pointer = 300;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoftPrograms.instance.load();
  runApp(
    MaterialApp(home: _Bench(key: _bench), debugShowCheckedModeBanner: false),
  );
  unawaited(_drive());
}

class _Bench extends StatefulWidget {
  const _Bench({super.key});
  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  final GlobalKey target = GlobalKey();
  final SoftTouchMotionState motion = SoftTouchMotionState();
  bool navigation = false;

  void configure(bool value) => setState(() => navigation = value);

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SoftTheme(
    data: const SoftThemeData.light(),
    child: Scaffold(
      backgroundColor: const Color(0xFF92B5BF),
      body: Center(
        child: navigation
            ? SoftFloatingNavigationBar(
                key: target,
                backdrop: ColorBackdrop(const Color(0xFF92B5BF)),
                quality: GlassQuality.liquid,
                selectedIndex: 0,
                onSelected: (_) {},
                start: SoftFloatingAccessory(
                  icon: const Icon(Icons.search),
                  onTap: () {},
                ),
                end: SoftFloatingAccessory(
                  icon: const Icon(Icons.add),
                  onTap: () {},
                ),
                items: const <SoftFloatingNavigationItem>[
                  SoftFloatingNavigationItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  SoftFloatingNavigationItem(
                    icon: Icon(Icons.chat),
                    label: 'Chat',
                  ),
                  SoftFloatingNavigationItem(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              )
            : SoftTouchMotion(
                key: target,
                state: motion,
                color: const Color(0xFF526789),
                light: SoftSpotLightParams.capsule2Light,
                borderRadius: BorderRadius.circular(28),
                child: const SizedBox(
                  width: 220,
                  height: 80,
                  child: Center(child: Text('Drag')),
                ),
              ),
      ),
    ),
  );
}

Future<void> _gesture() async {
  final _BenchState state = _bench.currentState!;
  final RenderBox box =
      state.target.currentContext!.findRenderObject()! as RenderBox;
  final Offset start = box.localToGlobal(box.size.center(Offset.zero));
  final int pointer = ++_pointer;
  final Stopwatch clock = Stopwatch()..start();
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: pointer,
      position: start,
      timeStamp: clock.elapsed,
    ),
  );
  double previous = 0;
  for (int frame = 1; frame <= 48; frame++) {
    await SchedulerBinding.instance.endOfFrame;
    final double dx = 120 * frame / 48;
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        position: start + Offset(dx, 0),
        delta: Offset(dx - previous, 0),
        timeStamp: clock.elapsed,
      ),
    );
    previous = dx;
  }
  final double held = state.motion.translation.dx;
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      position: start + Offset(previous, 0),
      timeStamp: clock.elapsed,
    ),
  );
  double minimum = 0;
  for (int frame = 0; frame < 55; frame++) {
    await SchedulerBinding.instance.endOfFrame;
    minimum = math.min(minimum, state.motion.translation.dx);
  }
  if (!state.navigation) debugPrint('SOFT|held=$held reboundMin=$minimum');
}

double _p90(Iterable<Duration> values) {
  final List<int> sorted = values.map((Duration d) => d.inMicroseconds).toList()
    ..sort();
  return sorted.isEmpty ? 0 : sorted[(sorted.length * 0.9).floor()] / 1000;
}

Future<void> _drive() async {
  await Future<void>.delayed(const Duration(seconds: 2));
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  for (final bool navigation in <bool>[false, true]) {
    _bench.currentState!.configure(navigation);
    await Future<void>.delayed(const Duration(seconds: 1));
    await _gesture(); // Warm up shaders and raster caches.
    await Future<void>.delayed(const Duration(seconds: 1));
    _timings.clear();
    _collect = true;
    for (int cycle = 0; cycle < 3; cycle++) {
      await _gesture();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    _collect = false;
    debugPrint(
      'SOFT|${jsonEncode(<String, Object>{'case': navigation ? 'navigation' : 'surface', 'frames': _timings.length, 'buildP90ms': _p90(_timings.map((FrameTiming f) => f.buildDuration)), 'rasterP90ms': _p90(_timings.map((FrameTiming f) => f.rasterDuration)), 'workOver16ms': _timings.where((FrameTiming f) => f.buildDuration.inMicroseconds > 16667 || f.rasterDuration.inMicroseconds > 16667).length, 'backend': 'profile'})}',
    );
  }
  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('SOFT|done');
}

void _onTimings(List<FrameTiming> frames) {
  if (_collect) _timings.addAll(frames);
}
