// Throwaway: which part of coucou-mobile's shape stops the glass sampling an
// Android stretch-overscroll springing back?
//
// The instrument is differential, because an absolute one lies: a strip of the
// backdrop read through a blur responds to a small shift far less than a bare
// strip does, so "the bar moved less than the page" proves nothing. Instead the
// bottom bar is split in half over the same page — the left half is FluidGlass's
// sampled `DrawBackdrop`, the right half a plain `BackdropFilter`, which the
// compositor always keeps live. Same backdrop, same blur, same pixels: if the
// native half moves and the FluidGlass half does not, the glass is frozen, and
// no amount of band phase or blur damping can fake that.
//
// The page is a vertical sawtooth rather than bands, so its mean responds
// linearly to a shift of a couple of pixels instead of in steps.
//
// coucou differs from a bare `BackdropLayer` over a `ListView` in three ways at
// once, so this varies them one at a time:
//
//   A  ListView, plain                          the case already known to work
//   B  ListView + motionPixelRatio dpr*0.5      CoucouGlassHost sets this
//   C  SingleChildScrollView, clipBehavior none what the home page scrolls
//   D  C + RefreshIndicator + motionPixelRatio  the whole coucou shape
//
// Every case runs the Android pairing — `ClampingScrollPhysics` plus
// `StretchingOverscrollIndicator` — the one where the scroll position never
// leaves zero and nothing reports the spring-back.
//
//   flutter build windows --release -t lib/probe_coucou_shape.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

const double _w = 300;
const double _h = 420;
const double _tooth = 40;
const double _barH = 60;
const double _blur = 2;

final GlobalKey _shot = GlobalKey();

/// Drives the control case, which must move the position while the frames are
/// being grabbed rather than during the drag.
final ScrollController _controller = ScrollController();

enum _Case {
  listView('A  ListView, no motionPixelRatio'),
  motionRatio('B  ListView + motionPixelRatio dpr*0.5'),
  singleChild('C  SingleChildScrollView, clipBehavior: none'),
  coucou('D  C + RefreshIndicator + motionPixelRatio'),

  /// The control. An ordinary scroll moves the scroll position, which reports
  /// itself and repaints the source, so the glass must track it. If this one
  /// reads frozen the instrument is broken, not the library.
  control('E  ListView, ordinary scroll  (must track)');

  const _Case(this.label);
  final String label;

  bool get halfMotion => this == motionRatio || this == coucou;
  bool get single => this == singleChild || this == coucou;
  bool get refresh => this == coucou;
  bool get overscroll => this != control;
}

final ValueNotifier<_Case> _which = ValueNotifier<_Case>(_Case.listView);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_drive());
}

Future<void> _drive() async {
  await _settle(30);
  debugPrint('tier: ${GlassDeviceTier.instance.quality}   '
      'shader filters: ${ui.ImageFilter.isShaderFilterSupported}');
  for (final _Case which in _Case.values) {
    _which.value = which;
    await _settle(40);
    await _run(which);
  }
  exit(0);
}

Future<void> _settle(int frames) async {
  for (int i = 0; i < frames; i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
}

int _pointer = 1;

Future<void> _run(_Case which) async {
  final int id = _pointer++;
  final RenderBox box = _shot.currentContext!.findRenderObject()! as RenderBox;
  final Offset origin = box.localToGlobal(Offset.zero);
  Offset at(double x, double y) => origin + Offset(x, y);
  void send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);

  if (which.overscroll) {
    send(PointerDownEvent(pointer: id, position: at(150, 200)));
    await _settle(1);
    for (int i = 0; i < 10; i++) {
      send(
        PointerMoveEvent(
          pointer: id,
          position: at(150, 200 + (i + 1) * 12),
          delta: const Offset(0, 12),
        ),
      );
      await _settle(1);
    }
    send(PointerUpEvent(pointer: id, position: at(150, 320)));
  } else {
    // No gesture: an ordinary animated scroll, which is guaranteed to still be
    // running while the frames below are grabbed.
    unawaited(
      _controller.animateTo(
        240,
        duration: const Duration(milliseconds: 600),
        curve: Curves.linear,
      ),
    );
  }

  // Grab frames at the real frame rate and decode afterwards: `toByteData` is
  // async and takes longer than a frame, so converting inline samples every
  // third frame at best and the spring is over before the instrument notices.
  final List<ui.Image> frames = <ui.Image>[];
  for (int i = 0; i < 40; i++) {
    await _settle(1);
    final RenderRepaintBoundary boundary =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    frames.add(boundary.toImageSync());
  }

  final List<double> glass = <double>[];
  final List<double> native = <double>[];
  for (final ui.Image image in frames) {
    final (double g, double n) = await _read(image);
    glass.add(g);
    native.add(n);
    image.dispose();
  }
  double spread(List<double> v) =>
      v.reduce((double a, double b) => a > b ? a : b) -
      v.reduce((double a, double b) => a < b ? a : b);

  final double live = spread(native);
  final double saw = spread(glass);
  debugPrint('--- ${which.label}');
  debugPrint('  native half moved ${live.toStringAsFixed(1)}   '
      'FluidGlass half moved ${saw.toStringAsFixed(1)}   '
      '${live > 12 && saw < live / 4 ? '<<< FROZEN' : 'tracking'}');
  debugPrint('  glass : ${glass.map((double v) => v.round()).join(' ')}');
  debugPrint('  native: ${native.map((double v) => v.round()).join(' ')}');

  // Let the spring finish before the next case takes over the scene.
  await _settle(40);
}

/// The mean of the FluidGlass half and of the native half, over the same rows.
Future<(double, double)> _read(ui.Image image) async {
  final int w = image.width;
  final double scale = w / _w;
  final ByteData? raw = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (raw == null) return (0.0, 0.0);
  final Uint8List p = raw.buffer.asUint8List();
  double mean(double x0, double x1) {
    double total = 0;
    int n = 0;
    for (
      int y = ((_h - _barH + 20) * scale).round();
      y < ((_h - _barH + 40) * scale).round();
      y++
    ) {
      for (int x = (x0 * scale).round(); x < (x1 * scale).round(); x++) {
        total += p[(y * w + x) * 4];
        n++;
      }
    }
    return total / n;
  }

  // Inset from both the outer edges and the seam, so neither half sees the
  // other's blur reaching across.
  return (mean(12, _w / 2 - 12), mean(_w / 2 + 12, _w - 12));
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF404040),
        child: Center(
          child: SizedBox(
            width: _w,
            height: _h,
            child: RepaintBoundary(
              key: _shot,
              child: ValueListenableBuilder<_Case>(
                valueListenable: _which,
                builder: (BuildContext context, _Case which, Widget? _) =>
                    Scaffold(
                      body: _Host(
                        backdrop: _backdrop,
                        which: which,
                        child: _Scroller(which: which),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What `CoucouGlassHost` does: the page under a `BackdropLayer`, the glass over
/// it as a sibling, and a halved capture resolution while the page is moving.
class _Host extends StatelessWidget {
  const _Host({
    required this.backdrop,
    required this.which,
    required this.child,
  });

  final LayerBackdrop backdrop;
  final _Case which;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double sigma = blurRadiusToSigma(_blur, devicePixelRatio: dpr);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            motionPixelRatio: which.halfMotion ? dpr * 0.5 : null,
            child: child,
          ),
        ),
        // Left: the sampled path under test.
        Positioned(
          left: 0,
          bottom: 0,
          width: _w / 2,
          child: DrawBackdrop.plain(
            backdrop: backdrop,
            shape: () => const Rectangle(),
            effects: (BackdropEffectScope scope) => scope.blur(_blur),
            child: const SizedBox(height: _barH, width: double.infinity),
          ),
        ),
        // Right: the compositor's own, which is live by construction.
        Positioned(
          right: 0,
          bottom: 0,
          width: _w / 2,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: const SizedBox(height: _barH, width: double.infinity),
            ),
          ),
        ),
      ],
    );
  }
}

class _Scroller extends StatelessWidget {
  const _Scroller({required this.which});
  final _Case which;

  @override
  Widget build(BuildContext context) {
    const ScrollPhysics physics = AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );
    final Widget body = which.single
        ? const SingleChildScrollView(
            physics: physics,
            clipBehavior: Clip.none,
            child: SizedBox(
              height: _h * 3,
              width: double.infinity,
              child: CustomPaint(painter: _Teeth()),
            ),
          )
        : ListView.builder(
            controller: which == _Case.control ? _controller : null,
            physics: physics,
            itemExtent: _tooth,
            itemCount: 200,
            itemBuilder: (BuildContext context, int index) => const SizedBox(
              height: _tooth,
              child: CustomPaint(painter: _Teeth()),
            ),
          );

    return ScrollConfiguration(
      behavior: const _Android(),
      child: which.refresh
          ? RefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 50));
              },
              child: body,
            )
          : body,
    );
  }
}

/// A vertical sawtooth: a mean that moves linearly with a shift of a pixel or
/// two, which black-and-white bands do not.
class _Teeth extends CustomPainter {
  const _Teeth();

  @override
  void paint(Canvas canvas, Size size) {
    for (double y = 0; y < size.height; y += _tooth) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, _tooth),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, y),
            Offset(0, y + _tooth),
            const <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_Teeth oldDelegate) => false;
}

/// The overscroll Android actually gets from `MaterialScrollBehavior`.
class _Android extends ScrollBehavior {
  const _Android();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => StretchingOverscrollIndicator(
    axisDirection: details.direction,
    child: child,
  );
}
