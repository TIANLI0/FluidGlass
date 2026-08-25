import 'dart:ui' as ui;

import '../backdrop_effect_scope.dart';
import '../internal/shader_programs.dart';

/// Escape hatches for effects the library does not ship.
extension CustomBackdropEffects on BackdropEffectScope {
  /// Appends an arbitrary [ui.ImageFilter] to the chain.
  void imageFilterEffect(ui.ImageFilter filter) {
    if (!isRenderEffectSupported()) return;
    addImageFilter(filter);
  }

  /// Appends a fragment shader to the chain.
  ///
  /// The shader must declare a `vec2` as its first uniform (the engine
  /// overwrites it with the input texture size) and at least one `sampler2D`
  /// (the engine binds the chain's current output to the first one). [key]
  /// identifies the shader across frames so it is not recreated on every paint.
  void fragmentShaderEffect(
    String key,
    ui.FragmentProgram? program,
    ShaderEffectConfigurator configure,
  ) {
    addShaderEffect(key, program, configure);
  }
}
