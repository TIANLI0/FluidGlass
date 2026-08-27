// A throwaway harness: opens a LiquidMenu with synthetic pointer events and
// captures a PNG partway through the opening spring and once it has settled.
//
// Run with:  flutter run -d windows --release -t lib/probe_menu.dart
// Set PROBE_DIR to choose where the PNGs land.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


final String _dir = Platform.environment['PROBE_DIR'] ?? 'probe_menu_out';

// The boundary wraps the whole app, not the route: OverlayPortal puts the
// panel in the Navigator's Overlay, which sits above anything inside `home`.
final GlobalKey _captureKey = GlobalKey();
final GlobalKey _anchorKey = GlobalKey();

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
  int _sort = 1;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Stack(
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
                child: LiquidMenu(
                  backdrop: _backdrop,
                  panelWidth: 260,
                  anchorBuilder: (
                    BuildContext context,
                    bool isOpen,
                    VoidCallback toggle,
                  ) {
                    return SizedBox(
                      key: _anchorKey,
                      child: LiquidButton(
                        onPressed: toggle,
                        backdrop: _backdrop,
                        tint: isOpen ? const Color(0xFF0088FF) : null,
                        children: <Widget>[
                          Text(
                            'Sort by',
                            style: TextStyle(
                              color: isOpen
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF000000),
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: isOpen
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000),
                          ),
                        ],
                      ),
                    );
                  },
                  items: <LiquidMenuItem>[
                    LiquidMenuItem(
                      label: 'Name',
                      isSelected: _sort == 0,
                      onSelected: () => setState(() => _sort = 0),
                    ),
                    LiquidMenuItem(
                      label: 'Date modified',
                      isSelected: _sort == 1,
                      onSelected: () => setState(() => _sort = 1),
                    ),
                    LiquidMenuItem(
                      label: 'Size',
                      isSelected: _sort == 2,
                      onSelected: () => setState(() => _sort = 2),
                    ),
                    const LiquidMenuItem(
                      label: 'Delete all',
                      icon: Icons.delete_outline,
                      isDestructive: true,
                    ),
                  ],
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

Offset _anchorCentre() {
  final RenderBox box =
      _anchorKey.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

Future<void> _tap(Offset p) async {
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
        pointer: ++_pointer, position: p, kind: PointerDeviceKind.touch),
  );
  await _settle(40);
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: _pointer, position: p, kind: PointerDeviceKind.touch),
  );
}

Future<void> _settle([int ms = 700]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _drive() async {
  await _settle(1500);
  await _shoot('00_closed');

  // Frame-locked capture of the opening bloom: instead of sleeping wall-clock
  // milliseconds (screenshot readback skews those), tap and then capture on
  // consecutive frame boundaries.
  await _tap(_anchorCentre());
  for (int i = 0; i < 5; i++) {
    await WidgetsBinding.instance.endOfFrame;
    await _shoot('01_opening_f$i');
  }

  await _settle(900);
  await _shoot('02_open');

  // Hold a press on the second row: the wash must be an inset rounded
  // rectangle, clear of the panel's corners.
  final RenderBox anchor =
      _anchorKey.currentContext!.findRenderObject()! as RenderBox;
  final Offset anchorBottomLeft =
      anchor.localToGlobal(Offset(0, anchor.size.height));
  final Offset secondRow = anchorBottomLeft + const Offset(120, 8 + 6 + 44 + 22);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
        pointer: ++_pointer, position: secondRow, kind: PointerDeviceKind.touch),
  );
  await _settle(300);
  await _shoot('03_row_pressed');
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
        pointer: _pointer, position: secondRow, kind: PointerDeviceKind.touch),
  );
  await _settle(400);

  // And on the LAST row: the wash must not collide with the bottom corners.
  await _tap(_anchorCentre());
  await _settle(900);
  final Offset lastRow = anchorBottomLeft + const Offset(120, 8 + 6 + 44 * 3 + 22);
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
        pointer: ++_pointer, position: lastRow, kind: PointerDeviceKind.touch),
  );
  await _settle(300);
  await _shoot('04_last_row_pressed');
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
        pointer: _pointer, position: lastRow, kind: PointerDeviceKind.touch),
  );
  await _settle(300);

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
