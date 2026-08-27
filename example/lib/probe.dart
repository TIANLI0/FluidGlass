// A throwaway harness: drives the bottom-tabs pill with synthetic pointer
// events and captures a PNG at each interesting position.
//
// Run with:  flutter run -d windows --release -t lib/probe.dart
// Set PROBE_DIR to choose where the PNGs land.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'catalog/flight_icon.dart';

final String _dir = Platform.environment['PROBE_DIR'] ?? 'probe_out';
final GlobalKey _captureKey = GlobalKey();
final GlobalKey _tabsKey = GlobalKey();
const int _tabsCount = 3;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const _ProbeApp());
  unawaited(_drive());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();
  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: RepaintBoundary(
          key: _captureKey,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: _backdrop,
                  child: SizedBox.expand(
                    child: Image.asset('assets/wallpaper_light.webp',
                        fit: BoxFit.cover),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: LiquidBottomTabs(
                    key: _tabsKey,
                    selectedTabIndex: _index,
                    onTabSelected: (int i) => setState(() => _index = i),
                    backdrop: _backdrop,
                    tabsCount: _tabsCount,
                    children: <Widget>[
                      for (int i = 0; i < _tabsCount; i++)
                        LiquidBottomTab(
                          onPressed: () => setState(() => _index = i),
                          children: <Widget>[
                            const FlightIcon(size: 28, color: Color(0xFF000000)),
                            Text('Tab ${i + 1}',
                                style: const TextStyle(
                                    color: Color(0xFF000000), fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

int _pointer = 1;

Rect _tabsRect() {
  final RenderBox box =
      _tabsKey.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

double _tabWidth() => (_tabsRect().width - 8.0) / _tabsCount;

Offset _pillCentre(double value) {
  final Rect rect = _tabsRect();
  return Offset(
    rect.left + 4 + (value + 0.5) * _tabWidth(),
    rect.top + 32,
  );
}

Offset _last = Offset.zero;

void _down(Offset p) {
  _last = p;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: ++_pointer, position: p, kind: PointerDeviceKind.touch),
  );
}

void _move(Offset p) {
  GestureBinding.instance.handlePointerEvent(
    PointerMoveEvent(
      pointer: _pointer,
      position: p,
      delta: p - _last,
      kind: PointerDeviceKind.touch,
    ),
  );
  _last = p;
}

void _up() {
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: _pointer, position: _last, kind: PointerDeviceKind.touch),
  );
}

Future<void> _settle([int ms = 700]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _drive() async {
  await _settle(1500);
  await _shoot('00_idle_left');

  // Press on the pill at tab 0 and glide it right to the far end.
  _down(_pillCentre(0));
  await _settle(400);
  await _shoot('01_pressed_left');

  final double w = _tabWidth();
  // Over-drag hard to the left, so the panel takes its give.
  for (int i = 1; i <= 10; i++) {
    _move(_pillCentre(0) - Offset(w * 0.15 * i, 0));
    await _settle(16);
  }
  await _settle(600);
  await _shoot('02_dragged_past_left');

  // Glide across to the far right end.
  final Offset start = _last;
  for (int i = 1; i <= 30; i++) {
    _move(start + Offset(w * 0.15 * i, 0));
    await _settle(16);
  }
  await _settle(600);
  await _shoot('03_dragged_past_right');

  // Settle in the middle while still pressed.
  _move(_pillCentre(1));
  await _settle(700);
  await _shoot('04_pressed_middle');

  _up();
  await _settle(900);
  await _shoot('05_released_middle');

  stdout.writeln('PROBE| done');
  await stdout.flush();
  exit(0);
}

Future<void> _shoot(String name) async {
  final RenderRepaintBoundary? boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) return;
  final File file = File('$_dir/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png.buffer.asUint8List());
  stdout.writeln('PROBE| ${file.path}');
  await stdout.flush();
}
