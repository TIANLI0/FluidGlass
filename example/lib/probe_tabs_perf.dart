// Throwaway: what does `LiquidBottomTabs` cost per frame, in the two motions
// an app actually performs over it?
//
// A page laid out like a home screen — a header, a row of avatars, a
// horizontal card deck whose cards scale as they slide, a call-to-action — is
// wrapped in a `BackdropLayer`, and the tab bar floats over its bottom edge.
// Two things are then driven synthetically while frame timings are collected:
//
//  * the selected tab changes (the pill presses, springs across, releases);
//  * the card deck is flung sideways (the source changes on every frame).
//
// Each is measured with the glass bar and with a plain bar in its place, so the
// glass's own share is what is left after subtracting. Frames are reported as
// raster / build / total percentiles plus a count of frames over the 60 Hz
// budget.
//
//   flutter run --profile -d <device> -t lib/probe_tabs_perf.dart
//
// Set `--dart-define=TABS_SHOT=1` to instead capture PNGs of the pressed pill
// at fixed points of a slowed-down press, for pixel comparison across library
// versions. They land in the app's documents directory; pull them with adb.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

const String _shotDefine = String.fromEnvironment('TABS_SHOT');

/// `--dart-define=TABS_SHOT=1`: hold pill states for the host to screenshot
/// instead of measuring.
final bool _shotMode = _shotDefine.isNotEmpty;

final _Config _config = _Config();

class _Config extends ChangeNotifier {
  bool glass = true;
  int tab = 0;

  void set({bool? glass, int? tab}) {
    if (glass != null) this.glass = glass;
    if (tab != null) this.tab = tab;
    notifyListeners();
  }
}

final PageController _deck = PageController(viewportFraction: 0.94);
final GlobalKey _captureKey = GlobalKey();
final GlobalKey _pageLayerKey = GlobalKey();

/// The page's capture source, for the debug-only counters on it.
RenderBackdropLayer? get _pageSource {
  RenderObject? node = _pageLayerKey.currentContext?.findRenderObject();
  while (node != null && node is! RenderBackdropLayer) {
    if (node is! RenderObjectWithChildMixin<RenderObject>) return null;
    node = node.child;
  }
  return node as RenderBackdropLayer?;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  // The sampled path, whatever the emulator's core count says: this is the
  // tier a flagship phone runs, and the one whose cost is in question.
  GlassDeviceTier.instance.pinnedQuality = GlassQuality.liquid;
  runApp(const _App());
  unawaited(_shotMode ? _shoot() : _drive());
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
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      home: Builder(
        builder: (BuildContext context) {
          final double dpr = MediaQuery.devicePixelRatioOf(context);
          final double safe = MediaQuery.viewPaddingOf(context).bottom;
          return Scaffold(
            body: RepaintBoundary(
              key: _captureKey,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropLayer(
                      key: _pageLayerKey,
                      backdrop: _backdrop,
                      motionPixelRatio: dpr * 0.5,
                      child: _Page(bottomInset: 64 + 24 + safe),
                    ),
                  ),
                  if (_config.glass)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 12 + safe,
                      child: LiquidGlassTheme(
                        colors:
                            LiquidGlassColors.forBrightness(
                              Brightness.light,
                            ).copyWith(
                              accent: const Color(0xFFE0533A),
                              container: const Color(
                                0xFFFFFBF7,
                              ).withValues(alpha: 0.46),
                            ),
                        child: LiquidBottomTabs(
                          selectedTabIndex: _config.tab,
                          onTabSelected: (int i) => _config.set(tab: i),
                          backdrop: _backdrop,
                          tabsCount: 3,
                          children: <Widget>[
                            for (int i = 0; i < 3; i++)
                              LiquidBottomTab(
                                onPressed: () => _config.set(tab: i),
                                children: <Widget>[_tabNode(i)],
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 12 + safe,
                      child: _PlainBar(tab: _config.tab),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const List<IconData> _icons = <IconData>[
  Icons.home_outlined,
  Icons.devices_other_outlined,
  Icons.person_outline,
];
const List<String> _labels = <String>['Home', 'Devices', 'Me'];

Widget _tabNode(int i) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(_icons[i], size: 22, color: const Color(0xFF5B5550)),
      const SizedBox(height: 2),
      Text(
        _labels[i],
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF5B5550),
        ),
      ),
    ],
  );
}

/// The no-glass control: a flat bar of the same size, whose selection moves
/// with a plain animated container.
class _PlainBar extends StatelessWidget {
  const _PlainBar({required this.tab});

  final int tab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double w = c.maxWidth / 3;
              return Stack(
                children: <Widget>[
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: tab * w,
                    top: 0,
                    width: w,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x1A000000),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        Expanded(child: Center(child: _tabNode(i))),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final double screenH = MediaQuery.sizeOf(context).height;
    final double deckHeight = (screenH * 0.68).clamp(440.0, 600.0);
    return ColoredBox(
      color: const Color(0xFFFAF6F1),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Good evening',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.notifications_none, size: 26),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 8,
                itemBuilder: (BuildContext context, int i) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(
                      0xFF000000 | (i * 0x3A8F1D % 0xFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: deckHeight),
                        child: PageView.builder(
                          controller: _deck,
                          clipBehavior: Clip.none,
                          itemCount: 6,
                          itemBuilder: (BuildContext context, int index) {
                            return AnimatedBuilder(
                              animation: _deck,
                              builder: (BuildContext context, Widget? child) {
                                double delta = -index.toDouble();
                                if (_deck.position.haveDimensions) {
                                  delta = (_deck.page ?? 0) - index;
                                }
                                final double dist = delta.abs().clamp(0.0, 1.0);
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Transform.scale(
                                      scale: 1 - 0.06 * dist,
                                      child: AspectRatio(
                                        aspectRatio: 5 / 7,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: _Card(index: index),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0533A),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x40E0533A),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Start chatting',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF000000 | (index * 0x5A3F91 % 0xFFFFFF)),
            Color(0xFF000000 | (index * 0x2B7D13 % 0xFFFFFF)),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < 12; i++)
            Positioned(
              left: 16.0 + (i * 37) % 200,
              top: 24.0 + (i * 53) % 320,
              child: Container(
                width: 60 + (i * 17) % 80,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          Positioned(
            left: 20,
            bottom: 24,
            child: Text(
              'Character ${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Measurement.
// -----------------------------------------------------------------------------

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

Future<void> _flingDeck(Size screen, {required bool left}) async {
  final double y = screen.height * 0.5;
  final double from = left ? screen.width * 0.8 : screen.width * 0.2;
  final double to = left ? screen.width * 0.2 : screen.width * 0.8;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: ++_pointer,
      position: Offset(from, y),
      kind: PointerDeviceKind.touch,
    ),
  );
  Offset last = Offset(from, y);
  for (int i = 1; i <= 12; i++) {
    final Offset next = Offset(from + (to - from) * i / 12, y);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: _pointer,
        position: next,
        delta: next - last,
        kind: PointerDeviceKind.touch,
      ),
    );
    last = next;
    await _settle(16);
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
  return '$name mean=${mean.toStringAsFixed(2).padLeft(6)} '
      'p90=${at(0.9).toStringAsFixed(2).padLeft(6)} '
      'max=${(x.last / 1000).toStringAsFixed(2).padLeft(6)}';
}

String _stats(String label) {
  if (_raster.isEmpty) return '$label no frames';
  final int over = _total.where((int t) => t > 16700).length;
  return '$label frames=${_raster.length.toString().padLeft(3)} '
      'over16=${over.toString().padLeft(3)}  ${_one("raster", _raster)}  '
      '${_one("build", _build)}  ${_one("total", _total)}';
}

void _begin() {
  _raster.clear();
  _build.clear();
  _total.clear();
  _collect = true;
  final RenderBackdropLayer? page = _pageSource;
  if (page != null) {
    page.debugCaptureCount = 0;
    page.debugIgnoredChanges = 0;
  }
}

void _end(String label) {
  _collect = false;
  final RenderBackdropLayer? page = _pageSource;
  // Only meaningful in a debug build; asserts keep the counters in release.
  final String captures = page == null
      ? ''
      : '  pageCaptures=${page.debugCaptureCount} '
            'ignoredChanges=${page.debugIgnoredChanges}';
  debugPrint('TABS| ${_stats(label)}$captures');
}

Future<void> _measureTabs(String label) async {
  _config.set(tab: 0);
  await _settle(900);
  _begin();
  for (final int i in <int>[1, 2, 0, 2, 1, 0]) {
    _config.set(tab: i);
    await _settle(650);
  }
  _end(label);
}

Future<void> _measureSwipe(String label, Size screen) async {
  _deck.jumpToPage(0);
  await _settle(600);
  _begin();
  for (int i = 0; i < 6; i++) {
    await _flingDeck(screen, left: i.isEven);
    await _settle(650);
  }
  _end(label);
}

Future<void> _measureIdle(String label) async {
  await _settle(600);
  _begin();
  await _settle(1500);
  _end(label);
}

Future<void> _drive() async {
  await _settle(2500);
  SchedulerBinding.instance.addTimingsCallback(_onTimings);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint(
    'TABS| screen=${screen.width}x${screen.height} '
    'dpr=${view.devicePixelRatio} hz=${view.display.refreshRate} '
    'shaders=${isRuntimeShaderSupported()} '
    'tier=${GlassDeviceTier.instance.quality}',
  );

  for (int pass = 0; pass < 2; pass++) {
    final String tag = pass == 0 ? 'warmup' : 'PASS 2';
    _config.set(glass: true);
    await _measureIdle('$tag glass  idle      ');
    await _measureTabs('$tag glass  tab switch');
    await _measureSwipe('$tag glass  card swipe', screen);
    _config.set(glass: false);
    await _measureTabs('$tag plain  tab switch');
    await _measureSwipe('$tag plain  card swipe', screen);
  }

  SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  debugPrint('TABS| done');
}

// -----------------------------------------------------------------------------
// Screenshots of the pressed pill, for pixel comparison across versions.
//
// The app only *holds* each state and announces it; the host takes the picture
// with `adb exec-out screencap`. An in-app `toImage` is refused on Impeller's
// OpenGLES backend, and `toByteData` on a `toImageSync` image hangs there.
// -----------------------------------------------------------------------------

Future<void> _hold(String name) async {
  await _settle(600);
  debugPrint('TABS| hold $name');
  await _settle(3500);
}

Future<void> _shoot() async {
  await _settle(2500);
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final Size screen = view.physicalSize / view.devicePixelRatio;
  debugPrint('TABS| shot mode shaders=${isRuntimeShaderSupported()}');
  await _hold('rest_tab0');

  // Slow the springs fifty-fold so the switch is all but frozen while the
  // host takes its picture: four seconds of wall clock is 80 ms of press.
  timeDilation = 50.0;
  _config.set(tab: 1);
  await _settle(2500);
  await _hold('switch_early');
  await _settle(5000);
  await _hold('switch_mid');
  timeDilation = 1.0;
  await _settle(1500);
  await _hold('rest_tab1');

  // A held press on the pill: pressProgress goes to 1 and stays.
  final double safeBottom = MediaQuery.viewPaddingOf(
    _captureKey.currentContext!,
  ).bottom;
  final double barY = screen.height - 12 - safeBottom - 32;
  final double tabW = (screen.width - 40 - 8) / 3;
  final Offset pill = Offset(20 + 4 + tabW * 1.5, barY);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: ++_pointer,
      position: pill,
      kind: PointerDeviceKind.touch,
    ),
  );
  await _settle(1200);
  await _hold('held_tab1');
  // Drag halfway to the third tab and hold.
  Offset last = pill;
  for (int i = 1; i <= 10; i++) {
    final Offset next = pill + Offset(tabW * 0.5 * i / 10, 0);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: _pointer,
        position: next,
        delta: next - last,
        kind: PointerDeviceKind.touch,
      ),
    );
    last = next;
    await _settle(30);
  }
  await _settle(1200);
  await _hold('drag_half');
  // Past the last tab: the panel gives its 4dp.
  for (int i = 1; i <= 20; i++) {
    final Offset next = last + const Offset(12, 0);
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: _pointer,
        position: next,
        delta: next - last,
        kind: PointerDeviceKind.touch,
      ),
    );
    last = next;
    await _settle(30);
  }
  await _settle(1200);
  await _hold('drag_past_end');
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: _pointer,
      position: last,
      kind: PointerDeviceKind.touch,
    ),
  );
  await _settle(2000);
  await _hold('after_drag');
  debugPrint('TABS| done');
}
