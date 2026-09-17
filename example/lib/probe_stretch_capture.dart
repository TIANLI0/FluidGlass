// Throwaway: does `toImageSync` of the source layer tree apply a fragment
// shader `ImageFilter` that sits inside it?
//
// The subtree check already proves the library *notices* an Android stretch —
// instrumenting `_checkSubtree` shows `changed=true relevant=true` on every
// frame of the spring-back, so the capture is being retaken. Yet the glass shows
// unstretched pixels. That leaves one suspect: the capture itself.
//
// Three wrappers, all driven by the same hand-written spring, all inside the
// `BackdropLayer`:
//
//   1  Flutter's own `StretchEffect`   -> ImageFilter.shader on this backend
//   2  ImageFiltered(ImageFilter.matrix) -> a non-shader image filter
//   3  Transform                        -> no filter at all
//
// Measured differentially: the bottom bar is half FluidGlass, half native
// `BackdropFilter`. The native half is the compositor's own answer and is live
// by construction, so "native moved, FluidGlass did not" is the only reading
// that means anything.
//
//   flutter build windows --release -t lib/probe_stretch_capture.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

const double _w = 300;
const double _h = 420;
const double _tooth = 40;
const double _barH = 60;
const double _blur = 2;

final GlobalKey _shot = GlobalKey();

enum _Wrap {
  stretchEffect('1  StretchEffect          (ImageFilter.shader here)'),
  matrixFilter('2  ImageFiltered(matrix)  (non-shader image filter)'),
  transform('3  Transform               (no filter)'),

  /// The same shader filter, but read by a glass element that covers the whole
  /// source instead of a strip of it. If the capture region is what the shader
  /// is being evaluated against, this one tracks and the strip does not.
  stretchFull('4  StretchEffect, glass covers the whole source');

  const _Wrap(this.label);
  final String label;

  bool get shader => this == stretchEffect || this == stretchFull;
  bool get fullHeight => this == stretchFull;
}

final ValueNotifier<_Wrap> _wrap = ValueNotifier<_Wrap>(_Wrap.stretchEffect);

/// The stretch, driven by hand: no gesture, no physics, no scroll position.
/// The only thing that changes between frames is this number.
final ValueNotifier<double> _amount = ValueNotifier<double>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_drive());
}

Future<void> _drive() async {
  await _settle(30);
  debugPrint(
    'tier: ${GlassDeviceTier.instance.quality}   '
    'shader filters: ${ui.ImageFilter.isShaderFilterSupported}',
  );
  for (final _Wrap wrap in _Wrap.values) {
    _wrap.value = wrap;
    _amount.value = 0;
    await _settle(30);
    await _run(wrap);
  }
  exit(0);
}

Future<void> _settle(int frames) async {
  for (int i = 0; i < frames; i++) {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }
}

Future<void> _run(_Wrap wrap) async {
  const int steps = 30;
  final List<ui.Image> frames = <ui.Image>[];
  for (int i = 0; i < steps; i++) {
    // A spring-back: full stretch decaying to nothing.
    _amount.value = 0.35 * (1 - i / (steps - 1));
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
  debugPrint('--- ${wrap.label}');
  debugPrint(
    '  native moved ${live.toStringAsFixed(1)}   '
    'FluidGlass moved ${saw.toStringAsFixed(1)}   '
    '${live > 12 && saw < live / 4 ? '<<< FROZEN' : 'tracking'}',
  );
  debugPrint('  glass : ${glass.map((double v) => v.round()).join(' ')}');
  debugPrint('  native: ${native.map((double v) => v.round()).join(' ')}');
}

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
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double sigma = blurRadiusToSigma(_blur, devicePixelRatio: dpr);
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
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropLayer(
                      backdrop: _backdrop,
                      child: ValueListenableBuilder<_Wrap>(
                        valueListenable: _wrap,
                        builder:
                            (BuildContext context, _Wrap wrap, Widget? _) =>
                                _Wrapped(wrap: wrap, child: const _Teeth()),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<_Wrap>(
                    valueListenable: _wrap,
                    builder: (BuildContext context, _Wrap wrap, Widget? _) =>
                        Positioned(
                          left: 0,
                          bottom: 0,
                          width: _w / 2,
                          child: DrawBackdrop.plain(
                            backdrop: _backdrop,
                            shape: () => const Rectangle(),
                            effects: (BackdropEffectScope scope) =>
                                scope.blur(_blur),
                            child: SizedBox(
                              height: wrap.fullHeight ? _h : _barH,
                              width: double.infinity,
                            ),
                          ),
                        ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: _w / 2,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: const SizedBox(
                          height: _barH,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wrapped extends StatelessWidget {
  const _Wrapped({required this.wrap, required this.child});
  final _Wrap wrap;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: _amount,
    child: child,
    builder: (BuildContext context, double v, Widget? child) => switch (wrap) {
      _Wrap.stretchEffect || _Wrap.stretchFull => StretchEffect(
        stretchStrength: v,
        axis: Axis.vertical,
        child: child!,
      ),
      _Wrap.matrixFilter => ImageFiltered(
        imageFilter: ui.ImageFilter.matrix(
          (Matrix4.identity()..setEntry(1, 1, 1 + v)).storage,
        ),
        child: child,
      ),
      _Wrap.transform => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()..setEntry(1, 1, 1 + v),
        filterQuality: FilterQuality.medium,
        child: child,
      ),
    },
  );
}

class _Teeth extends StatelessWidget {
  const _Teeth();
  @override
  Widget build(BuildContext context) => const CustomPaint(
    size: Size(_w, _h),
    painter: _TeethPainter(),
    child: SizedBox(width: _w, height: _h),
  );
}

/// A vertical sawtooth: its mean moves linearly with a shift of a pixel or two,
/// which black-and-white bands do not.
class _TeethPainter extends CustomPainter {
  const _TeethPainter();

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
  bool shouldRepaint(_TeethPainter oldDelegate) => false;
}
