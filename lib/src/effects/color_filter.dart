import 'dart:ui' as ui;

import '../backdrop_effect_scope.dart';
import '../internal/shader_programs.dart';

/// Colour adjustments applied to the backdrop.
///
/// [ui.ColorFilter.matrix] takes a row-major 4x5 matrix whose translation
/// column is in 0..255 space, matching Android's `ColorMatrix`.
extension ColorBackdropEffects on BackdropEffectScope {
  /// Applies an arbitrary colour filter.
  void colorFilterEffect(ui.ColorFilter colorFilter) {
    if (!isRenderEffectSupported()) return;
    // A colour filter reads only the pixel it writes, so it can share a
    // save-layer with a fragment shader added after it.
    addImageFilter(colorFilter, expandsCoverage: false);
  }

  /// Scales the backdrop's alpha by [alpha].
  void opacity(double alpha) {
    colorFilterEffect(ui.ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, alpha, 0, //
    ]));
  }

  /// Adjusts brightness, contrast and saturation in one pass.
  ///
  /// [brightness] is additive around 0; [contrast] and [saturation] are
  /// multiplicative around 1.
  void colorControls({
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    if (brightness == 0.0 && contrast == 1.0 && saturation == 1.0) {
      return;
    }
    colorFilterEffect(
      colorControlsColorFilter(
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      ),
    );
  }

  /// Boosts saturation to 1.5.
  void vibrancy() {
    colorFilterEffect(_vibrantColorFilter);
  }
}

final ui.ColorFilter _vibrantColorFilter = colorControlsColorFilter(saturation: 1.5);

/// Builds the brightness/contrast/saturation matrix used by
/// [ColorBackdropEffects.colorControls].
ui.ColorFilter colorControlsColorFilter({
  double brightness = 0.0,
  double contrast = 1.0,
  double saturation = 1.0,
}) {
  final double invSat = 1.0 - saturation;
  final double r = 0.213 * invSat;
  final double g = 0.715 * invSat;
  final double b = 0.072 * invSat;

  final double c = contrast;
  final double t = (0.5 - c * 0.5 + brightness) * 255.0;
  final double s = saturation;

  final double cr = c * r;
  final double cg = c * g;
  final double cb = c * b;
  final double cs = c * s;

  return ui.ColorFilter.matrix(<double>[
    cr + cs, cg, cb, 0, t, //
    cr, cg + cs, cb, 0, t, //
    cr, cg, cb + cs, 0, t, //
    0, 0, 0, 1, 0, //
  ]);
}
