import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'catalog/catalog_destination.dart';
import 'catalog/main_content.dart';
import 'catalog/utils/demo_shaders.dart';

/// Set `FLUID_GLASS_SHOT=<dir>` — as an environment variable on desktop, or as
/// `--dart-define` on mobile — to render every screen to a PNG and exit. This is
/// the harness used to check every screen against reference screenshots.
const String _shotDefine = String.fromEnvironment('FLUID_GLASS_SHOT');
final String? _shotDir = _shotDefine.isNotEmpty
    ? _shotDefine
    : Platform.environment['FLUID_GLASS_SHOT'];
final GlobalKey _captureKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait<void>(<Future<void>>[
    FluidGlass.ensureInitialized(),
    DemoShaders.instance.load(),
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
    ),
  );
  runApp(const CatalogApp());
  if (_shotDir != null) {
    unawaited(_captureAll());
  }
  if (_perfScreen.isNotEmpty) {
    unawaited(_measureFrames());
  }
}

/// Set `--dart-define=FLUID_GLASS_PERF=<destination name>` to open that screen,
/// sample frame timings for a few seconds and print them.
const String _perfScreen = String.fromEnvironment('FLUID_GLASS_PERF');

Future<void> _measureFrames() async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final CatalogDestination target = CatalogDestination.values
      .firstWhere((CatalogDestination d) => d.name == _perfScreen);
  catalogDebugNavigate?.call(target);
  await Future<void>.delayed(const Duration(milliseconds: 2000));

  final List<int> build = <int>[];
  final List<int> raster = <int>[];
  void onTimings(List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      build.add(t.buildDuration.inMicroseconds);
      raster.add(t.rasterDuration.inMicroseconds);
    }
  }

  SchedulerBinding.instance.addTimingsCallback(onTimings);
  await Future<void>.delayed(const Duration(seconds: 4));
  SchedulerBinding.instance.removeTimingsCallback(onTimings);

  String stats(String label, List<int> xs) {
    if (xs.isEmpty) return '$label: no frames';
    xs.sort();
    final double mean = xs.reduce((int a, int b) => a + b) / xs.length / 1000;
    final double p50 = xs[xs.length ~/ 2] / 1000;
    final double p90 = xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)] / 1000;
    return '$label mean=${mean.toStringAsFixed(2)}ms '
        'p50=${p50.toStringAsFixed(2)}ms p90=${p90.toStringAsFixed(2)}ms';
  }

  stdout.writeln('PERF| screen=$_perfScreen frames=${build.length}');
  stdout.writeln('PERF| ${stats("build ", build)}');
  stdout.writeln('PERF| ${stats("raster", raster)}');
  await stdout.flush();
  exit(0);
}

class CatalogApp extends StatelessWidget {
  const CatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Backdrop Catalog',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        splashFactory: InkRipple.splashFactory,
        highlightColor: const Color(0x1A000000),
        splashColor: const Color(0x1A000000),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        splashFactory: InkRipple.splashFactory,
        highlightColor: const Color(0x1AFFFFFF),
        splashColor: const Color(0x1AFFFFFF),
      ),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: RepaintBoundary(key: _captureKey, child: const MainContent()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screenshot harness
// ---------------------------------------------------------------------------

Future<void> _captureAll() async {
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  await _shoot('00_home');
  for (final CatalogDestination destination in CatalogDestination.values) {
    if (destination == CatalogDestination.home) continue;
    catalogDebugNavigate?.call(destination);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _shoot('${destination.index.toString().padLeft(2, '0')}_${destination.name}');
  }
  stdout.writeln('SHOT| done');
  await stdout.flush();
  exit(0);
}

Future<void> _shoot(String name) async {
  final RenderRepaintBoundary? boundary =
      _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) return;
  final File file = File('$_shotDir/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png.buffer.asUint8List());
  stdout.writeln('SHOT| ${file.path}');
}
