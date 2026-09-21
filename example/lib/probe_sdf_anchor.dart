// Throwaway: where does a shader inside a BackdropFilter think it is?
//
// The screen-space-anchored lens rendered as a plain blur -- the refraction
// never fired. Rather than guess which uniform is wrong, this paints the
// shader's own belief about the geometry:
//
//   green  the refraction band          blue  interior (early-out)
//   red    outside the shape
//
// Anchored right, the element is blue with a green ring hugging its rim.
//
//   flutter build windows --release -t lib/probe_sdf_anchor.dart
//   PROBE_DIR=... ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double _barW = 320;
const double _barH = 120;
const double _radius = 32;
const double _lensHeight = 16;

ui.FragmentProgram? _debug;
final GlobalKey _captureKey = GlobalKey();

/// How the debug shader is mounted, and what geometry it is told.
enum _Mode {
  // A BackdropFilter told the element sits at its real screen rect.
  backdropScreenSpace('BackdropFilter, uniforms in screen space'),
  // The same, but told the element is at the origin -- what the shader would
  // need if FlutterFragCoord were local to the filtered layer.
  backdropLocalSpace('BackdropFilter, uniforms in element-local space'),
  // ImageFiltered, which probe_backdrop_shader_size showed gets an
  // element-sized texture. This is the known-good control.
  imageFilteredLocal('ImageFiltered control, element-local');

  const _Mode(this.label);
  final String label;
}

final ValueNotifier<_Mode> _current = ValueNotifier<_Mode>(
  _Mode.backdropScreenSpace,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _debug = await ui.FragmentProgram.fromAsset('shaders/probe_sdf_debug.frag');
  } catch (e) {
    debugPrint('SDFA| FATAL could not load probe_sdf_debug.frag: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

ui.ImageFilter _debugFilter(Size layer, Size elem, Offset topLeft) {
  final ui.FragmentShader s = _debug!.fragmentShader();
  s
    ..setFloat(0, 0) // uTextureSize, engine-set
    ..setFloat(1, 0)
    ..setFloat(2, layer.width)
    ..setFloat(3, layer.height)
    ..setFloat(4, elem.width)
    ..setFloat(5, elem.height)
    ..setFloat(6, -topLeft.dx)
    ..setFloat(7, -topLeft.dy)
    ..setFloat(8, _radius)
    ..setFloat(9, _radius)
    ..setFloat(10, _radius)
    ..setFloat(11, _radius)
    ..setFloat(12, _lensHeight)
    ..setFloat(13, -24)
    ..setFloat(14, 0);
  return ui.ImageFilter.shader(s);
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<_Mode>(
        valueListenable: _current,
        builder: (BuildContext context, _Mode mode, Widget? _) {
          final ui.FlutterView view =
              WidgetsBinding.instance.platformDispatcher.views.first;
          final Size screen = view.physicalSize / view.devicePixelRatio;
          final Rect r = Rect.fromLTWH(
            (screen.width - _barW) / 2,
            (screen.height - _barH) / 2,
            _barW,
            _barH,
          );

          late final Widget bar;
          switch (mode) {
            case _Mode.backdropScreenSpace:
              bar = ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: BackdropFilter(
                  filter: _debugFilter(screen, r.size, r.topLeft),
                  child: const SizedBox(width: _barW, height: _barH),
                ),
              );
            case _Mode.backdropLocalSpace:
              bar = ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: BackdropFilter(
                  filter: _debugFilter(
                    const Size(_barW, _barH),
                    const Size(_barW, _barH),
                    Offset.zero,
                  ),
                  child: const SizedBox(width: _barW, height: _barH),
                ),
              );
            case _Mode.imageFilteredLocal:
              bar = ImageFiltered(
                imageFilter: _debugFilter(
                  const Size(_barW, _barH),
                  const Size(_barW, _barH),
                  Offset.zero,
                ),
                child: Container(
                  width: _barW,
                  height: _barH,
                  color: Colors.white,
                ),
              );
          }

          return RepaintBoundary(
            key: _captureKey,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF303030)),
                ),
                Positioned(
                  left: r.left,
                  top: r.top,
                  width: _barW,
                  height: _barH,
                  child: bar,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _settle(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

String get _outDir {
  final String d = Platform.environment['PROBE_DIR'] ?? '.';
  Directory(d).createSync(recursive: true);
  return d;
}

Future<void> _shoot(String name) async {
  final RenderRepaintBoundary? b =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (b == null) return;
  final ui.Image img = await b.toImage(pixelRatio: 1.0);
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (png != null) {
    File(
      '$_outDir/sdfa_$name.png',
    ).writeAsBytesSync(png.buffer.asUint8List(), flush: true);
    debugPrint('SDFA| wrote sdfa_$name.png');
  }
}

Future<void> _drive() async {
  await _settle(2500);
  for (final _Mode m in _Mode.values) {
    _current.value = m;
    await _settle(800);
    debugPrint('SDFA| ${m.label}');
    await _shoot(m.name);
  }
  debugPrint('SDFA| done');
  await _settle(200);
  exit(0);
}
