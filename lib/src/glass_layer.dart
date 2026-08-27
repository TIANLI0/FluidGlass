import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The mutable transform applied to a glass element, and the Flutter analogue
/// of Compose's `GraphicsLayerScope`.
///
/// A [GlassLayerBlock] receives a fresh scope every paint, reads whatever
/// animation values it needs and writes the transform fields.
class GlassLayer {
  /// The size of the glass element, in logical pixels. Read-only for the block.
  Size size = Size.zero;

  double scaleX = 1.0;
  double scaleY = 1.0;
  double alpha = 1.0;
  double translationX = 0.0;
  double translationY = 0.0;

  /// Rotation about the z axis, in degrees, clockwise on screen.
  double rotationZ = 0.0;

  /// The pivot for [scaleX], [scaleY] and [rotationZ], as a fraction of [size].
  Offset transformOrigin = const Offset(0.5, 0.5);

  void reset(Size size) {
    this.size = size;
    scaleX = 1.0;
    scaleY = 1.0;
    alpha = 1.0;
    translationX = 0.0;
    translationY = 0.0;
    rotationZ = 0.0;
    transformOrigin = const Offset(0.5, 0.5);
  }

  /// Whether this layer transforms geometry at all.
  bool get hasTransform =>
      scaleX != 1.0 ||
      scaleY != 1.0 ||
      translationX != 0.0 ||
      translationY != 0.0 ||
      rotationZ != 0.0;

  /// Whether this layer changes anything about how the element is drawn.
  bool get isIdentity => !hasTransform && alpha == 1.0;

  /// The forward transform, matching Compose's
  /// `T(translation) * T(pivot) * R * S * T(-pivot)`.
  Matrix4 toMatrix() {
    final double pivotX = transformOrigin.dx * size.width;
    final double pivotY = transformOrigin.dy * size.height;
    final Matrix4 matrix = Matrix4.identity()
      ..translateByDouble(translationX + pivotX, translationY + pivotY, 0, 1);
    if (rotationZ != 0.0) {
      matrix.rotateZ(rotationZ * math.pi / 180.0);
    }
    matrix.scaleByDouble(scaleX, scaleY, 1.0, 1.0);
    matrix.translateByDouble(-pivotX, -pivotY, 0, 1);
    return matrix;
  }

  /// The inverse of the layer's linear part, taken about the element's
  /// top-left corner.
  ///
  /// Undoes a scale or rotation applied to a glass element, so that what it
  /// refracts does not scale or rotate with it. Only [scaleX], [scaleY] and
  /// [rotationZ] are inverted: translation is already accounted for by the
  /// element's new position.
  ///
  /// [LayerBackdrop] no longer needs this — it maps a consumer straight into
  /// its source's coordinates with the whole transform between them, which
  /// already includes this one. Kept for a [Backdrop] of your own that places
  /// itself from [BackdropDrawContext.layerBlock].
  Matrix4? inverseLinearTransformAtTopLeft() {
    if (rotationZ == 0.0) {
      if (scaleX == 1.0 && scaleY == 1.0) return null;
      if (scaleX == 0.0 || scaleY == 0.0) return null;
      return Matrix4.identity()..scaleByDouble(1.0 / scaleX, 1.0 / scaleY, 1.0, 1.0);
    }
    if (scaleX == 0.0 || scaleY == 0.0) return null;
    // inverse(R(theta) * S) == S^-1 * R(-theta)
    final Matrix4 matrix = Matrix4.identity()
      ..scaleByDouble(1.0 / scaleX, 1.0 / scaleY, 1.0, 1.0);
    matrix.rotateZ(-rotationZ * math.pi / 180.0);
    return matrix;
  }
}

/// Configures the transform of a glass element, once per paint.
typedef GlassLayerBlock = void Function(GlassLayer layer);
