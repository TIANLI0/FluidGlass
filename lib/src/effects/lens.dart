import 'dart:math' as math;
import 'dart:ui' as ui;

import '../backdrop_effect_scope.dart';
import '../internal/shader_programs.dart';
import '../shapes/rectangle_corner_radii.dart';

/// The refraction ("lens") effect that gives liquid glass its edge.
extension LensBackdropEffect on BackdropEffectScope {
  /// Bends the backdrop inwards along the element's edge.
  ///
  /// [refractionHeight] is how far in from the edge, in logical pixels, the
  /// bending reaches; [refractionAmount] is how far the sampled pixels travel.
  /// [depthEffect] blends the edge normal towards a radial one, which reads as
  /// a thicker piece of glass. [chromaticAberration] splits the sample into
  /// seven wavelengths for a prism fringe.
  void lens(
    double refractionHeight,
    double refractionAmount, {
    bool depthEffect = false,
    bool chromaticAberration = false,
  }) {
    if (!isRuntimeShaderSupported()) return;
    // The refraction is the expensive pass, so it is the first thing a cheaper
    // tier gives up. Everything else about the element is unchanged.
    if (!quality.hasRefraction) return;
    if (refractionHeight <= 0.0 || refractionAmount <= 0.0) return;

    // The refraction samples inwards, so it hands back the room a preceding
    // blur reserved.
    if (padding > 0.0) {
      padding = math.max(0.0, padding - refractionHeight);
    }

    final RectangleCorners corners = shape.corners(size, textDirection);
    final FluidGlassPrograms programs = FluidGlassPrograms.instance;

    addShaderEffect(
      chromaticAberration ? 'RefractionWithDispersion' : 'Refraction',
      chromaticAberration ? programs.dispersion : programs.refraction,
      (ui.FragmentShader shader, BackdropEffectGeometry geometry) {
        final ui.Size layerSize = geometry.layerSize;
        final ui.Offset offset = geometry.offset;
        shader
          // Floats 0..1 are uTextureSize, which the engine overwrites.
          ..setFloat(0, 0)
          ..setFloat(1, 0)
          ..setFloat(2, layerSize.width)
          ..setFloat(3, layerSize.height)
          ..setFloat(4, geometry.size.width)
          ..setFloat(5, geometry.size.height)
          ..setFloat(6, offset.dx)
          ..setFloat(7, offset.dy)
          ..setFloat(8, corners.topLeft)
          ..setFloat(9, corners.topRight)
          ..setFloat(10, corners.bottomRight)
          ..setFloat(11, corners.bottomLeft)
          ..setFloat(12, refractionHeight)
          // Negated so the refraction bends inwards.
          ..setFloat(13, -refractionAmount)
          ..setFloat(14, depthEffect ? 1.0 : 0.0);
        if (chromaticAberration) {
          shader.setFloat(15, 1.0);
        }
      },
    );
  }
}
