// Throwaway: does a press light the whole body, or only the control under the
// finger?
//
// The press cannot be photographed through the app — a screenshot harness has
// no finger — so this drives LiquidFusion with a synthetic press instead and
// renders the cases side by side. Each row is one press position; each column
// is a gap. What to look for:
//
//   * The glow under the finger spills across a neck into a merged neighbour,
//     instead of stopping at the pressed control edge.
//   * A control that is still separate answers the press on its facing edge:
//     the rim brightens on the side the press is on, and fades with distance
//     over the length of the group.
//   * The rim runs as one sweep around the body, not as three identical rims.
//
//   FLUID_GLASS_SHOT=<dir> flutter build windows --release -t lib/probe_fusion_light.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double _size = 56;
const List<double> _gaps = <double>[0, 6, 40];
const List<double> _presses = <double>[0, 1];

final GlobalKey _captureKey = GlobalKey();
final String? _shotDir = Platform.environment['FLUID_GLASS_SHOT'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _App());
  unawaited(_shoot());
}

Future<void> _shoot() async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final RenderRepaintBoundary? boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null || _shotDir == null) return;
  final ui.Image image = await boundary.toImage(pixelRatio: 2);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png != null) {
    final File file = File('$_shotDir/fusion_light.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png.buffer.asUint8List());
    stdout.writeln('LIGHT| ${file.path}');
    await stdout.flush();
  }
  exit(0);
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: RepaintBoundary(key: _captureKey, child: const _Grid()),
      ),
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid();

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(backdrop: _backdrop, child: const _Ruled()),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final double press in _presses)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 78,
                          child: Text(
                            press == 0 ? 'at rest' : 'pressed\n(left one)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                        for (final double gap in _gaps)
                          Expanded(
                            child: _Trio(
                              backdrop: _backdrop,
                              gap: gap,
                              press: press,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Three controls in a row, fused, with the press held on the left one.
class _Trio extends StatelessWidget {
  const _Trio({required this.backdrop, required this.gap, required this.press});

  final Backdrop backdrop;
  final double gap, press;

  @override
  Widget build(BuildContext context) {
    final double width = _size * 3 + gap * 2;
    return Center(
      child: SizedBox(
        width: width,
        height: _size,
        child: LiquidFusion(
          backdrop: backdrop,
          smoothing: 10,
          blobs: <LiquidBlob>[
            for (int i = 0; i < 3; i++)
              LiquidBlob(Rect.fromLTWH((_size + gap) * i, 0, _size, _size)),
          ],
          // The finger, in the middle of the left control.
          press: press == 0
              ? null
              : LiquidFusionPress(
                  position: const Offset(_size / 2, _size / 2),
                  progress: press,
                  radius: _size * 1.5,
                ),
        ),
      ),
    );
  }
}

/// A dark ruled ground: the light is what is being read here, so the backdrop
/// has to be dark enough for it to show.
class _Ruled extends StatelessWidget {
  const _Ruled();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101014),
      child: Column(
        children: <Widget>[
          for (int row = 0; row < 24; row++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (int col = 0; col < 40; col++)
                    Expanded(
                      child: ColoredBox(
                        color: (row + col).isEven
                            ? const Color(0xFF1B2A44)
                            : const Color(0xFF2A1B2E),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
