// Throwaway: what does the top chrome cost while the page scrolls under it?
//
// Flings the same feed under three headers and prints raster/build/total
// percentiles for each, because "islands over a scrim" only beats "one bar"
// if it is not quietly more expensive:
//
//   * none    — the floor.
//   * bar     — what [LiquidNavigationBar] used to be: one full-width pane of
//               glass, blurred hard, its whole height run through a ShaderMask
//               to fade the glass out at the bottom.
//   * islands — what it is now: three [LiquidButton]s over a plain gradient.
//
// The interesting difference is not the number of glass elements, it is the
// ShaderMask: a mask over the full width of the chrome is a saveLayer of that
// size on every frame of the scroll, and the bar needs one because it fades
// *the glass*. A gradient over an opaque page colour needs none.
//
//   flutter build windows --release -t lib/probe_nav_chrome.dart
//   flutter build apk --release -t lib/probe_nav_chrome.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum _Chrome { none, bar, island1, islands }

final _Config _config = _Config();

class _Config extends ChangeNotifier {
  _Chrome chrome = _Chrome.none;

  void set(_Chrome value) {
    chrome = value;
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
    _backdrop.dispose();
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
                pixelRatio: 0.5,
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: 96,
                  itemCount: 200,
                  itemBuilder: (BuildContext context, int i) => _Row(index: i),
                ),
              ),
            ),
            if (_config.chrome == _Chrome.bar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _OldBar(backdrop: _backdrop),
              ),
            // One island: separates "what an element costs" from "how many".
            if (_config.chrome == _Chrome.island1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidNavigationBar(
                  backdrop: _backdrop,
                  title: const Text('Mika'),
                  titleLeading: const CircleAvatar(radius: 16),
                ),
              ),
            if (_config.chrome == _Chrome.islands)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LiquidNavigationBar(
                  backdrop: _backdrop,
                  title: const Text('Mika'),
                  titleLeading: const CircleAvatar(radius: 16),
                  leading: LiquidNavigationAction(
                    backdrop: _backdrop,
                    icon: Icons.arrow_back_ios_new,
                    label: 'Back',
                    onPressed: () {},
                  ),
                  trailing: LiquidNavigationAction(
                    backdrop: _backdrop,
                    icon: Icons.tune,
                    label: 'Filter',
                    onPressed: () {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fine type and hairlines, so the blur has something to destroy.
class _Row extends StatelessWidget {
  const _Row({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(color: Color(0x1A101010), width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF000000 | (index * 3719 % 0xFFFFFF)),
              ),
              child: const SizedBox(width: 36, height: 36),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: <Widget>[
                  Text(
                    'Row $index — chrome over live content',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF101010),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Small type is what makes a blur read as a blur.',
                    maxLines: 1,
                    style: TextStyle(color: Color(0x9E101010), fontSize: 12),
                  ),
                  Row(
                    spacing: 3,
                    children: <Widget>[
                      for (int i = 0; i < 26; i++)
                        const ColoredBox(
                          color: Color(0x4D101010),
                          child: SizedBox(width: 1, height: 9),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar this replaced, kept only to be measured: one pane of glass across
/// the whole width, faded out at the bottom with a ShaderMask.
class _OldBar extends StatelessWidget {
  const _OldBar({required this.backdrop});

  final Backdrop backdrop;

  static const double _height = 56;
  static const double _fade = 32;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + _height + _fade,
      child: IgnorePointer(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: <double>[0, (top + _height) / bounds.height, 1],
          ).createShader(bounds),
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(16),
            onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
              Offset.zero & size,
              Paint()..color = const Color(0xFFF8F8FC).withValues(alpha: 0.72),
            ),
            child: const SizedBox.expand(),
          ),
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
  debugPrint('NAV| ${_stats(label)}');
}

Future<void> _drive() async {
  await _settle(2500);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint(
    'NAV| screen=${screen.width}x${screen.height} '
    'dpr=${view.devicePixelRatio} hz=${view.display.refreshRate}',
  );

  // Two passes: the first is warm-up, and on a cold GPU whichever phase runs
  // first measures worst whatever it is. Only the second pass means anything.
  for (int pass = 0; pass < 2; pass++) {
    final String tag = pass == 0 ? 'warmup' : 'PASS 2';
    for (final _Chrome chrome in _Chrome.values) {
      _config.set(chrome);
      await _settle(600);
      await _measure('$tag ${chrome.name.padRight(7)}', screen);
    }
  }

  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('NAV| done');
}
