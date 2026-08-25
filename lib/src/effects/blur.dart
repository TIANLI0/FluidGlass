import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../backdrop_effect_scope.dart';
import '../internal/blur_sigma.dart';
import '../internal/shader_programs.dart';

/// The Gaussian blur effect.
extension BlurBackdropEffect on BackdropEffectScope {
  /// Blurs the backdrop by [radius] logical pixels.
  ///
  /// [radius] is an Android-style blur *radius*, converted internally to the
  /// Gaussian sigma Flutter expects.
  void blur(double radius, {TileMode edgeTreatment = TileMode.clamp}) {
    if (!isRenderEffectSupported()) return;
    if (radius <= 0.0) return;

    // Clamped blurs that start the chain can read the layer's own edge pixels,
    // so they need no extra room; anything else does.
    if (edgeTreatment != TileMode.clamp || hasPrecedingEffect) {
      if (radius > padding) {
        padding = radius;
      }
    }

    final double sigma =
        blurRadiusToSigma(radius, devicePixelRatio: devicePixelRatio);
    addImageFilter(
      ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: edgeTreatment),
    );
  }
}
