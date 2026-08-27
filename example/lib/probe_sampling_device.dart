// Throwaway: on Impeller, does a rounded card inside the source actually reach
// the glass?
//
// Widget tests run on Skia, so they cannot answer this. Renders known strong
// colours behind glass, reads the framebuffer back in-app, and prints what
// arrived. Reports through debugPrint, the only channel a release Android build
// has.
//
//   flutter build apk --release -t lib/probe_sampling_device.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final GlobalKey _captureKey = GlobalKey();

/// Each case names what it puts in the source and the colour it should produce.
enum _Case {
  plainBox('plain ColoredBox'),
  decoratedCard('rounded BoxDecoration card'),
  clippedCard('rounded ClipRRect card'),
  cardInList('rounded card inside a ListView'),
  cardInListBlurred('rounded card inside a ListView, blurred');

  const _Case(this.label);
  final String label;
}

final ValueNotifier<_Case> _current = ValueNotifier<_Case>(_Case.plainBox);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_drive());
}

const Color _target = Color(0xFFFF2020);

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
    _current.addListener(_onCase);
  }

  void _onCase() => setState(() {});

  @override
  void dispose() {
    _current.removeListener(_onCase);
    super.dispose();
  }

  Widget _source(_Case c) {
    switch (c) {
      case _Case.plainBox:
        return const ColoredBox(color: _target);
      case _Case.decoratedCard:
        return ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: _target,
              ),
            ),
          ),
        );
      case _Case.clippedCard:
        return ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: const SizedBox(
                width: 320,
                height: 320,
                child: ColoredBox(color: _target),
              ),
            ),
          ),
        );
      case _Case.cardInList:
      case _Case.cardInListBlurred:
        return ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: ListView.builder(
            itemExtent: 400,
            itemCount: 6,
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: _target,
                ),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Case c = _current.value;
    return RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(backdrop: _backdrop, child: _source(c)),
              ),
              Center(
                child: DrawBackdrop.plain(
                  backdrop: _backdrop,
                  shape: () => const RoundedRectangle(24),
                  effects: (BackdropEffectScope scope) {
                    if (c == _Case.cardInListBlurred) scope.blur(10);
                  },
                  child: const SizedBox(width: 160, height: 160),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _settle(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Mean RGB of the middle of the glass.
Future<List<double>?> _sampleGlass() async {
  final RenderRepaintBoundary? boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final int w = image.width;
  final int h = image.height;
  image.dispose();
  if (data == null) return null;
  final Uint8List p = data.buffer.asUint8List();
  // A 40x40 block at the centre, comfortably inside the 160x160 glass.
  final int cx = w ~/ 2;
  final int cy = h ~/ 2;
  double r = 0, g = 0, b = 0;
  int n = 0;
  for (int y = cy - 20; y < cy + 20; y++) {
    for (int x = cx - 20; x < cx + 20; x++) {
      final int i = (y * w + x) * 4;
      r += p[i];
      g += p[i + 1];
      b += p[i + 2];
      n += 1;
    }
  }
  return <double>[r / n, g / n, b / n];
}

Future<void> _drive() async {
  await _settle(2500);
  debugPrint('SAMPLE| target is rgb(255,32,32); glass has no tint, so the '
      'sampled colour should come through');

  bool allOk = true;
  for (final _Case c in _Case.values) {
    _current.value = c;
    await _settle(900);
    final List<double>? rgb = await _sampleGlass();
    if (rgb == null) {
      debugPrint('SAMPLE| ${c.label}: no capture');
      allOk = false;
      continue;
    }
    final bool ok = rgb[0] > 180 && rgb[1] < 110 && rgb[2] < 110;
    if (!ok) allOk = false;
    debugPrint('SAMPLE| ${ok ? "OK  " : "FAIL"} ${c.label}: '
        'r=${rgb[0].toStringAsFixed(0)} g=${rgb[1].toStringAsFixed(0)} '
        'b=${rgb[2].toStringAsFixed(0)}');
  }
  debugPrint('SAMPLE| RESULT ${allOk ? "PASS" : "FAIL"}');
  debugPrint('SAMPLE| done');
}
