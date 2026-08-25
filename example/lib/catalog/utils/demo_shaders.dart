import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads the fragment programs that belong to the demo itself, rather than to
/// the library: the press highlight, the lock-screen SDF and the progressive
/// blur.
class DemoShaders extends ChangeNotifier {
  DemoShaders._();

  static final DemoShaders instance = DemoShaders._();

  ui.FragmentProgram? interactiveHighlight;
  ui.FragmentProgram? sdf;
  ui.FragmentProgram? progressiveBlur;

  Future<void>? _loading;

  bool get isReady =>
      interactiveHighlight != null && sdf != null && progressiveBlur != null;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final List<ui.FragmentProgram> programs =
          await Future.wait(<Future<ui.FragmentProgram>>[
        ui.FragmentProgram.fromAsset('shaders/interactive_highlight.frag'),
        ui.FragmentProgram.fromAsset('shaders/sdf.frag'),
        ui.FragmentProgram.fromAsset('shaders/progressive_blur.frag'),
      ]);
      interactiveHighlight = programs[0];
      sdf = programs[1];
      progressiveBlur = programs[2];
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fluid_glass_example',
        context: ErrorDescription('while loading the demo fragment programs'),
      ));
    }
    notifyListeners();
  }
}
