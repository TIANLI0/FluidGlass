// Throwaway: inside a BackdropFilter, what texture does a fragment shader get?
//
// draw_backdrop.dart:769 states the reason the liquid tier must capture:
//
//   "a fragment shader in a backdrop filter is handed the whole screen rather
//    than the element's texture, so the lens would have nothing to anchor its
//    geometry to."
//
// If that is wrong -- if a ClipRect'd BackdropFilter hands the shader a texture
// the size of the element -- then refraction can run with no `toImageSync` at
// all, which is 12 of the 14 ms a live backdrop costs today.
//
// The probe shader encodes the engine-supplied uTextureSize into its output
// colour; this reads the framebuffer back and decodes it. Widget tests run on
// Skia and skip ImageFilter.shader entirely, so this has to be a real build:
//
//   flutter build windows --release -t lib/probe_backdrop_shader_size.dart
//   ./build/windows/x64/runner/Release/fluid_glass_example.exe
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final GlobalKey _captureKey = GlobalKey();

/// Each case is one way of putting the probe shader on screen.
enum _Case {
  clipped('ClipRect + BackdropFilter(shader)', 200, 120),
  clippedWide('ClipRect + BackdropFilter(shader), wider', 360, 120),
  clippedTall('ClipRect + BackdropFilter(shader), taller', 200, 240),
  clippedBlur('ClipRect + BackdropFilter(blur(8) then shader)', 200, 120),
  unclipped('BackdropFilter(shader), no ClipRect', 200, 120),
  imageFiltered('ImageFiltered(shader) control', 200, 120);

  const _Case(this.label, this.w, this.h);
  final String label;
  final double w;
  final double h;
}

final ValueNotifier<_Case> _current = ValueNotifier<_Case>(_Case.clipped);

ui.FragmentProgram? _program;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _program = await ui.FragmentProgram.fromAsset('shaders/probe_texsize.frag');
  } catch (e) {
    debugPrint('TEXSIZE| FATAL could not load probe shader: $e');
    exit(1);
  }
  runApp(const _App());
  unawaited(_drive());
}

ui.ImageFilter _shaderFilter() {
  final ui.FragmentShader shader = _program!.fragmentShader();
  // uTextureSize is uniform 0; the engine overwrites it. Nothing else to set.
  return ui.ImageFilter.shader(shader);
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  @override
  void initState() {
    super.initState();
    _current.addListener(_onCase);
  }

  void _onCase() => setState(() {});

  @override
  void dispose() {
    _current.removeListener(_onCase);
    super.dispose();
  }

  Widget _element(_Case c) {
    final Widget box = SizedBox(width: c.w, height: c.h);
    switch (c) {
      case _Case.clipped:
      case _Case.clippedWide:
      case _Case.clippedTall:
        return ClipRect(
          child: BackdropFilter(filter: _shaderFilter(), child: box),
        );
      case _Case.clippedBlur:
        return ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: _shaderFilter(),
              inner: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            ),
            child: box,
          ),
        );
      case _Case.unclipped:
        return BackdropFilter(filter: _shaderFilter(), child: box);
      case _Case.imageFiltered:
        return ImageFiltered(
          imageFilter: _shaderFilter(),
          child: Container(width: c.w, height: c.h, color: Colors.white),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Case c = _current.value;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // A backdrop with structure, so an unfiltered region is obvious.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF203040), Color(0xFF8090A0)],
                ),
              ),
            ),
            Center(child: _element(c)),
          ],
        ),
      ),
    );
  }
}

Future<void> _settle(int ms) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// The exact centre pixel, plus whether the block around it is uniform.
Future<({int r, int g, int b, bool uniform})?> _readCentre() async {
  final RenderRepaintBoundary? boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final int w = image.width;
  final int h = image.height;
  image.dispose();
  if (data == null) return null;
  final Uint8List p = data.buffer.asUint8List();
  final int cx = w ~/ 2;
  final int cy = h ~/ 2;
  final int i = (cy * w + cx) * 4;
  final int r = p[i], g = p[i + 1], b = p[i + 2];
  bool uniform = true;
  for (int y = cy - 12; y <= cy + 12 && uniform; y++) {
    for (int x = cx - 12; x <= cx + 12; x++) {
      final int j = (y * w + x) * 4;
      if (p[j] != r || p[j + 1] != g || p[j + 2] != b) {
        uniform = false;
        break;
      }
    }
  }
  return (r: r, g: g, b: b, uniform: uniform);
}

Future<void> _drive() async {
  await _settle(2500);

  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final double dpr = view.devicePixelRatio;
  final Size logical = view.physicalSize / dpr;
  debugPrint(
    'TEXSIZE| runtime shaders supported: ${isRuntimeShaderSupported()}',
  );
  debugPrint(
    'TEXSIZE| window logical=${logical.width.toStringAsFixed(0)}x'
    '${logical.height.toStringAsFixed(0)} dpr=$dpr '
    'physical=${view.physicalSize.width.toStringAsFixed(0)}x'
    '${view.physicalSize.height.toStringAsFixed(0)}',
  );
  debugPrint('TEXSIZE| --- decoded uTextureSize, in DEVICE pixels ---');

  for (final _Case c in _Case.values) {
    _current.value = c;
    await _settle(700);
    final ({int r, int g, int b, bool uniform})? px = await _readCentre();
    if (px == null) {
      debugPrint('TEXSIZE| ${c.label}: no capture');
      continue;
    }
    final int tx = px.r * 256 + px.g;
    final double ty = px.b / 255.0 * 2048.0;
    final double elemW = c.w * dpr;
    final double elemH = c.h * dpr;
    debugPrint(
      'TEXSIZE| ${c.label}\n'
      '         element ${c.w.toStringAsFixed(0)}x${c.h.toStringAsFixed(0)} '
      'logical = ${elemW.toStringAsFixed(0)}x${elemH.toStringAsFixed(0)} device\n'
      '         shader saw ${tx}x${ty.toStringAsFixed(0)} device  '
      '(raw rgb ${px.r},${px.g},${px.b}${px.uniform ? "" : ", NOT UNIFORM"})',
    );
  }
  debugPrint('TEXSIZE| done');
  await _settle(200);
  exit(0);
}
