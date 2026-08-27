// Throwaway: what can Dart actually tell us about this device, with no plugin?
//
// A device-class heuristic is only as good as its inputs, so this prints every
// candidate before any of them get built into a policy.
//
//   flutter build apk --release -t lib/probe_device_signals.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FluidGlass.ensureInitialized();
  runApp(const MaterialApp(home: ColoredBox(color: Color(0xFF102030))));
  unawaited(_report());
}

Future<void> _report() async {
  await Future<void>.delayed(const Duration(milliseconds: 1500));

  final ui.PlatformDispatcher d = ui.PlatformDispatcher.instance;
  final ui.FlutterView? view = d.implicitView ??
      (d.views.isEmpty ? null : d.views.first);

  void p(String k, Object? v) => debugPrint('SIG| $k = $v');

  p('kIsWeb', kIsWeb);
  p('operatingSystem', Platform.operatingSystem);
  p('operatingSystemVersion', Platform.operatingSystemVersion);
  p('version', Platform.version);
  p('numberOfProcessors', Platform.numberOfProcessors);
  p('localeName', Platform.localeName);
  p('isShaderFilterSupported', ui.ImageFilter.isShaderFilterSupported);
  p('isRuntimeShaderSupported()', isRuntimeShaderSupported());
  p('GlassQuality.ceiling', GlassQuality.ceiling.name);

  if (view != null) {
    p('physicalSize', view.physicalSize);
    p('devicePixelRatio', view.devicePixelRatio);
    p('logicalSize',
        '${view.physicalSize.width / view.devicePixelRatio}x'
        '${view.physicalSize.height / view.devicePixelRatio}');
    p('display.refreshRate', view.display.refreshRate);
    p('display.size', view.display.size);
    p('display.devicePixelRatio', view.display.devicePixelRatio);
    final double mpx =
        view.physicalSize.width * view.physicalSize.height / 1000000;
    p('megapixels', mpx.toStringAsFixed(2));
    p('fill demand Mpx/s',
        (mpx * view.display.refreshRate).toStringAsFixed(0));
  } else {
    p('view', 'none');
  }

  p('displays', d.displays.length);
  p('accessibilityFeatures.reduceMotion',
      d.accessibilityFeatures.reduceMotion);
  p('accessibilityFeatures.disableAnimations',
      d.accessibilityFeatures.disableAnimations);

  // Android exposes a lot through the environment on some ROMs; worth a look.
  final Map<String, String> env = Platform.environment;
  p('env keys', env.keys.length);
  for (final String key in env.keys) {
    if (key.toLowerCase().contains('android') ||
        key.toLowerCase().contains('cpu') ||
        key.toLowerCase().contains('arch')) {
      p('env.$key', env[key]);
    }
  }

  debugPrint('SIG| done');
  exit(0);
}
