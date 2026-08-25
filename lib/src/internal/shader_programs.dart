import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads and caches the [ui.FragmentProgram]s shipped with this package.
///
/// Fragment programs can only be loaded asynchronously, but effects are
/// evaluated during paint. The store therefore starts loading on first access
/// and notifies its listeners once the programs are ready; render objects
/// listen and repaint, so the first frame or two simply renders without the
/// shader-based effects instead of throwing.
class FluidGlassPrograms extends ChangeNotifier {
  FluidGlassPrograms._();

  static final FluidGlassPrograms instance = FluidGlassPrograms._();

  static const String _refractionAsset = 'packages/fluid_glass/shaders/refraction.frag';
  static const String _dispersionAsset =
      'packages/fluid_glass/shaders/refraction_dispersion.frag';
  static const String _highlightDefaultAsset =
      'packages/fluid_glass/shaders/highlight_default.frag';
  static const String _highlightAmbientAsset =
      'packages/fluid_glass/shaders/highlight_ambient.frag';

  ui.FragmentProgram? _refraction;
  ui.FragmentProgram? _dispersion;
  ui.FragmentProgram? _highlightDefault;
  ui.FragmentProgram? _highlightAmbient;

  Future<void>? _loading;
  Object? _error;

  /// Whether every program has finished loading.
  bool get isReady =>
      _refraction != null &&
      _dispersion != null &&
      _highlightDefault != null &&
      _highlightAmbient != null;

  /// The error thrown while loading the programs, if any.
  Object? get error => _error;

  ui.FragmentProgram? get refraction {
    _kick();
    return _refraction;
  }

  ui.FragmentProgram? get dispersion {
    _kick();
    return _dispersion;
  }

  ui.FragmentProgram? get highlightDefault {
    _kick();
    return _highlightDefault;
  }

  ui.FragmentProgram? get highlightAmbient {
    _kick();
    return _highlightAmbient;
  }

  void _kick() {
    if (_loading == null && !isReady) {
      // ignore: discarded_futures
      load();
    }
  }

  /// Loads every program. Safe to call repeatedly; the same future is returned.
  Future<void> load() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final List<ui.FragmentProgram> programs = await Future.wait(<Future<ui.FragmentProgram>>[
        ui.FragmentProgram.fromAsset(_refractionAsset),
        ui.FragmentProgram.fromAsset(_dispersionAsset),
        ui.FragmentProgram.fromAsset(_highlightDefaultAsset),
        ui.FragmentProgram.fromAsset(_highlightAmbientAsset),
      ]);
      _refraction = programs[0];
      _dispersion = programs[1];
      _highlightDefault = programs[2];
      _highlightAmbient = programs[3];
    } catch (e, stack) {
      _error = e;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'fluid_glass',
          context: ErrorDescription('while loading the FluidGlass fragment programs'),
        ),
      );
    }
    notifyListeners();
  }
}

/// Whether the current backend can run the shader-based effects.
///
/// [ui.ImageFilter.shader] requires the Impeller rendering backend.
bool isRuntimeShaderSupported() => ui.ImageFilter.isShaderFilterSupported;

/// Whether the current backend can run image filters at all.
///
/// Always true: [ui.ImageFilter.blur] and colour filters work on every
/// backend.
bool isRenderEffectSupported() => true;

/// Caches [ui.FragmentShader] instances by key, so uniforms can be re-set every
/// frame without recompiling.
class FragmentShaderCache {
  final Map<String, ui.FragmentShader> _shaders = <String, ui.FragmentShader>{};

  /// Returns the cached shader for [key], creating it from [program] if needed.
  ui.FragmentShader obtain(String key, ui.FragmentProgram program) {
    return _shaders.putIfAbsent(key, program.fragmentShader);
  }

  /// Returns the cached shader for [key], or null when [program] is null.
  ui.FragmentShader? obtainOrNull(String key, ui.FragmentProgram? program) {
    if (program == null) return null;
    return obtain(key, program);
  }

  void clear() {
    for (final ui.FragmentShader shader in _shaders.values) {
      shader.dispose();
    }
    _shaders.clear();
  }
}
