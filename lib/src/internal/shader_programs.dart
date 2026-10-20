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

  /// How a dependent app addresses this package's assets.
  ///
  /// Inside this package's own test and tooling context the asset bundle is
  /// rooted here instead, and the same file is simply `shaders/…`, so both
  /// spellings are tried — see [_programFromAsset].
  static const String _packagePrefix = 'packages/fluid_glass/';

  static const String _refractionAsset =
      'packages/fluid_glass/shaders/refraction.frag';
  static const String _dispersionAsset =
      'packages/fluid_glass/shaders/refraction_dispersion.frag';
  static const String _highlightDefaultAsset =
      'packages/fluid_glass/shaders/highlight_default.frag';
  static const String _highlightAmbientAsset =
      'packages/fluid_glass/shaders/highlight_ambient.frag';
  static const String _interactiveHighlightAsset =
      'packages/fluid_glass/shaders/interactive_highlight.frag';
  static const String _fusionAsset = 'packages/fluid_glass/shaders/fusion.frag';
  static const String _progressiveBlurAsset =
      'packages/fluid_glass/shaders/progressive_blur.frag';

  ui.FragmentProgram? _refraction;
  ui.FragmentProgram? _dispersion;
  ui.FragmentProgram? _highlightDefault;
  ui.FragmentProgram? _highlightAmbient;
  ui.FragmentProgram? _interactiveHighlight;
  ui.FragmentProgram? _fusion;
  ui.FragmentProgram? _progressiveBlur;

  Future<void>? _loading;
  Object? _error;

  /// Whether every program has finished loading.
  bool get isReady =>
      _refraction != null &&
      _dispersion != null &&
      _highlightDefault != null &&
      _highlightAmbient != null &&
      _interactiveHighlight != null &&
      _fusion != null &&
      _progressiveBlur != null;

  /// The first error thrown while loading the programs, if any. The programs
  /// that did load are still used.
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

  /// The glow a pressed component paints under the finger.
  ui.FragmentProgram? get interactiveHighlight {
    _kick();
    return _interactiveHighlight;
  }

  /// Several rounded rectangles drawn as one fused, commonly lit body.
  ui.FragmentProgram? get fusion {
    _kick();
    return _fusion;
  }

  /// The alpha ramp that fades one band of a progressive blur in along its
  /// length, so a stack of Gaussians reads as one blur that grows — chrome that
  /// dissolves into the content it sits over instead of ending on a line.
  ui.FragmentProgram? get progressiveBlur {
    _kick();
    return _progressiveBlur;
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

  /// Loads [asset], retrying without the `packages/fluid_glass/` prefix.
  ///
  /// The prefixed spelling is the one a dependent app resolves; the bare one is
  /// what resolves when the bundle is rooted at this package, as it is in its
  /// own tests. The prefixed error is the one reported if neither works, since
  /// that is the spelling a consumer is failing on.
  static Future<ui.FragmentProgram> _programFromAsset(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } catch (error, stack) {
      try {
        return await ui.FragmentProgram.fromAsset(
          asset.replaceFirst(_packagePrefix, ''),
        );
      } catch (_) {
        // The prefixed spelling's failure, not the fallback's: `rethrow` here
        // would report the bare path, which no consumer ever asked for.
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  /// Loads one program, reporting and swallowing a failure.
  ///
  /// Each on its own: loaded together, one program that failed to compile on
  /// some driver took every effect down with it — the refraction, the rim and
  /// the fused body all stayed flat because, say, the progressive blur did not
  /// build. Now only the effect whose program failed falls back.
  Future<ui.FragmentProgram?> _loadOne(String asset) async {
    try {
      return await _programFromAsset(asset);
    } catch (e, stack) {
      _error ??= e;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
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

  Future<void> _load() async {
    final List<ui.FragmentProgram?> programs =
        await Future.wait(<Future<ui.FragmentProgram?>>[
          _loadOne(_refractionAsset),
          _loadOne(_dispersionAsset),
          _loadOne(_highlightDefaultAsset),
          _loadOne(_highlightAmbientAsset),
          _loadOne(_interactiveHighlightAsset),
          _loadOne(_fusionAsset),
          _loadOne(_progressiveBlurAsset),
        ]);
    _refraction = programs[0];
    _dispersion = programs[1];
    _highlightDefault = programs[2];
    _highlightAmbient = programs[3];
    _interactiveHighlight = programs[4];
    _fusion = programs[5];
    _progressiveBlur = programs[6];
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
  final Map<String, ui.FragmentProgram> _programs =
      <String, ui.FragmentProgram>{};

  /// Returns the cached shader for [key], creating it from [program] if needed.
  ///
  /// A key names one program: asked for with a different one — a custom
  /// effect that happens to share a built-in effect's name — the old shader is
  /// replaced rather than handed out, which would run the wrong program.
  ui.FragmentShader obtain(String key, ui.FragmentProgram program) {
    final ui.FragmentShader? cached = _shaders[key];
    if (cached != null && identical(_programs[key], program)) return cached;
    cached?.dispose();
    _programs[key] = program;
    return _shaders[key] = program.fragmentShader();
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
    _programs.clear();
  }
}
