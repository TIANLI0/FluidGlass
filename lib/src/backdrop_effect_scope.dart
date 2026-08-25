import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'internal/shader_programs.dart';
import 'shapes/rounded_rectangular_shape.dart';

/// The geometry a shader-based effect needs in order to place itself.
///
/// [padding] is the amount the backdrop layer is inflated by on every side, so
/// blurs and refractions have pixels to reach for. It is only final once every
/// effect in the block has run, which is why shader uniforms are configured
/// through a callback rather than eagerly.
@immutable
class BackdropEffectGeometry {
  const BackdropEffectGeometry({required this.size, required this.padding});

  /// The size of the glass element, in logical pixels.
  final Size size;

  /// How far the sampled layer extends beyond the element on every side.
  final double padding;

  /// The size of the (padded) layer the effect filters.
  Size get layerSize => Size(size.width + padding * 2, size.height + padding * 2);

  /// The offset from layer space to element space, i.e. `(-padding, -padding)`.
  Offset get offset => Offset(-padding, -padding);
}

/// Configures a shader's uniforms once the layer geometry is known.
typedef ShaderEffectConfigurator = void Function(
  ui.FragmentShader shader,
  BackdropEffectGeometry geometry,
);

/// One filter inside a stage.
class _Item {
  _Item.filter(this.filter, {required this.expandsCoverage})
      : shader = null,
        configure = null;

  _Item.shader(this.shader, this.configure)
      : filter = null,
        expandsCoverage = false;

  final ui.ImageFilter? filter;
  final ui.FragmentShader? shader;
  final ShaderEffectConfigurator? configure;

  /// Whether the filter reads beyond the pixel it writes, which grows the
  /// texture handed to anything composed after it.
  final bool expandsCoverage;
}

/// A run of filters that share one save-layer.
class _Stage {
  final List<_Item> items = <_Item>[];

  /// A fragment shader is handed the whole input texture, so it can only share
  /// a stage with filters that leave the texture's bounds alone.
  bool get expandsCoverage => items.any((_Item item) => item.expandsCoverage);
}

/// Collects the effects applied to a glass element's backdrop.
///
/// The engine hands a fragment shader the whole input texture, so a shader
/// needs a save-layer boundary after anything that grows that texture — a blur,
/// in practice. A colour filter leaves it alone and rides along in the same
/// layer. Hence the chain is kept as stages, rather than as one filter or one
/// layer per effect.
class BackdropEffectScope {
  BackdropEffectScope();

  /// The size of the glass element, in logical pixels.
  Size get size => _size;
  Size _size = Size.zero;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection = TextDirection.ltr;

  /// The shape of the glass element, as passed to the glass widget.
  RoundedRectangularShape get shape => _shape;
  RoundedRectangularShape _shape = const Rectangle();

  /// Device pixels per logical pixel, needed to convert blur radii to sigmas
  /// the way Skia does.
  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio = 1.0;

  /// How far the sampled backdrop extends beyond the element on every side.
  ///
  /// Effects grow this so they have pixels to reach for, and `lens` shrinks it
  /// again by its refraction height.
  double padding = 0.0;

  final List<_Stage> _stages = <_Stage>[];
  final FragmentShaderCache _shaderCache = FragmentShaderCache();

  /// Adds an [ui.ImageFilter] to the chain.
  ///
  /// The filter is applied after everything already in the chain. Set
  /// [expandsCoverage] when the filter reads beyond the pixel it writes — a
  /// blur, a dilate — so a fragment shader added later gets its own layer and
  /// still sees the element's exact bounds.
  void addImageFilter(ui.ImageFilter filter, {bool expandsCoverage = true}) {
    _currentStage().items.add(_Item.filter(filter, expandsCoverage: expandsCoverage));
  }

  /// Adds a fragment-shader stage to the chain.
  ///
  /// [key] identifies the shader so it can be reused across frames instead of
  /// being recreated. [configure] is called every frame, once the final layer
  /// geometry is known; the shader's first `vec2` uniform is overwritten by the
  /// engine with the input texture size and must not be set here.
  ///
  /// Does nothing when the shader is unavailable, so an app degrades to its
  /// unrefracted appearance rather than throwing.
  void addShaderEffect(
    String key,
    ui.FragmentProgram? program,
    ShaderEffectConfigurator configure,
  ) {
    if (!isRuntimeShaderSupported()) return;
    final ui.FragmentShader? shader = _shaderCache.obtainOrNull(key, program);
    if (shader == null) return;
    // Only a coverage-growing filter forces a new layer.
    if (_stages.isNotEmpty && _stages.last.expandsCoverage) {
      _stages.add(_Stage());
    }
    _currentStage().items.add(_Item.shader(shader, configure));
  }

  _Stage _currentStage() {
    if (_stages.isEmpty) _stages.add(_Stage());
    return _stages.last;
  }

  /// Whether any effect has been added.
  bool get hasEffects => _stages.any((_Stage stage) => stage.items.isNotEmpty);

  /// True when at least one effect has already been added.
  bool get hasPrecedingEffect => hasEffects;

  void beginUpdate({
    required Size size,
    required TextDirection textDirection,
    required RoundedRectangularShape shape,
    double devicePixelRatio = 1.0,
  }) {
    _size = size;
    _textDirection = textDirection;
    _shape = shape;
    _devicePixelRatio = devicePixelRatio;
    padding = 0.0;
    _stages.clear();
  }

  /// Resolves the collected stages into the save-layer filters to apply,
  /// innermost first.
  List<ui.ImageFilter> resolve() {
    if (!hasEffects) return const <ui.ImageFilter>[];
    final BackdropEffectGeometry geometry =
        BackdropEffectGeometry(size: _size, padding: padding);

    final List<ui.ImageFilter> filters = <ui.ImageFilter>[];
    for (final _Stage stage in _stages) {
      ui.ImageFilter? composed;
      for (final _Item item in stage.items) {
        final ui.ImageFilter? next = _resolveItem(item, geometry);
        if (next == null) continue;
        composed = composed == null
            ? next
            : ui.ImageFilter.compose(outer: next, inner: composed);
      }
      if (composed != null) filters.add(composed);
    }
    return filters;
  }

  ui.ImageFilter? _resolveItem(_Item item, BackdropEffectGeometry geometry) {
    if (item.filter != null) return item.filter;
    final ui.FragmentShader shader = item.shader!;
    item.configure!(shader, geometry);
    try {
      return ui.ImageFilter.shader(shader);
    } catch (error) {
      // A shader whose uniforms were never set, or an unsupported backend.
      assert(() {
        debugPrint('fluid_glass: skipping shader effect - $error');
        return true;
      }());
      return null;
    }
  }

  void dispose() {
    _shaderCache.clear();
    _stages.clear();
  }
}
