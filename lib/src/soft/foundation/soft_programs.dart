import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads the soft components' fragment programs: the press spotlight, the
/// glass rim, and the floating bars' merged silhouette and caustic light.
///
/// Like the liquid family's programs they load on first use; until then the
/// light and the rim are simply not drawn, and listeners are notified when
/// they arrive.
class SoftPrograms extends ChangeNotifier {
  SoftPrograms._();

  static final SoftPrograms instance = SoftPrograms._();

  static const String _prefix = 'packages/fluid_glass/';
  static const String _spotLightAsset =
      'packages/fluid_glass/shaders/soft_spot_light.frag';
  static const String _bloomStrokeAsset =
      'packages/fluid_glass/shaders/soft_bloom_stroke.frag';
  static const String _metaBallAsset =
      'packages/fluid_glass/shaders/soft_meta_ball.frag';
  static const String _causticAsset =
      'packages/fluid_glass/shaders/soft_caustic.frag';

  ui.FragmentProgram? _spotLight;
  ui.FragmentProgram? _bloomStroke;
  ui.FragmentProgram? _metaBall;
  ui.FragmentProgram? _caustic;
  Future<void>? _loading;

  bool get isReady =>
      _spotLight != null &&
      _bloomStroke != null &&
      _metaBall != null &&
      _caustic != null;

  ui.FragmentProgram? get spotLight {
    _kick();
    return _spotLight;
  }

  ui.FragmentProgram? get bloomStroke {
    _kick();
    return _bloomStroke;
  }

  /// The merged silhouette of the floating bars.
  ui.FragmentProgram? get metaBall {
    _kick();
    return _metaBall;
  }

  /// The caustic light beneath the floating bars.
  ui.FragmentProgram? get caustic {
    _kick();
    return _caustic;
  }

  void _kick() {
    if (_loading == null && !isReady) {
      // ignore: discarded_futures
      load();
    }
  }

  Future<void> load() => _loading ??= _load();

  static Future<ui.FragmentProgram?> _loadOne(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (error, stack) {
      try {
        return await ui.FragmentProgram.fromAsset(
          asset.replaceFirst(_prefix, ''),
        );
      } catch (_) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'fluid_glass',
            context: ErrorDescription(
              'while loading the fragment program $asset',
            ),
          ),
        );
        return null;
      }
    }
  }

  Future<void> _load() async {
    final List<ui.FragmentProgram?> programs =
        await Future.wait(<Future<ui.FragmentProgram?>>[
          _loadOne(_spotLightAsset),
          _loadOne(_bloomStrokeAsset),
          _loadOne(_metaBallAsset),
          _loadOne(_causticAsset),
        ]);
    _spotLight = programs[0];
    _bloomStroke = programs[1];
    _metaBall = programs[2];
    _caustic = programs[3];
    notifyListeners();
  }
}
