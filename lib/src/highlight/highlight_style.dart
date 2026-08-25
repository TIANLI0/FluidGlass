import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../internal/shader_programs.dart';
import '../shapes/rectangle_corner_radii.dart';

/// How the bright rim along a glass element's edge is generated.
@immutable
abstract class HighlightStyle {
  const HighlightStyle();

  /// The colour of the rim.
  Color get color;

  /// How the rim is composited over the element.
  BlendMode get blendMode;

  /// Builds the shader that shades the rim, or null for a flat colour.
  ///
  /// [corners] are the element's corner radii and [origin] is where the
  /// element's top-left sits in the canvas' local space (zero when the caller
  /// has already translated to the element).
  ui.FragmentShader? createShader({
    required Size size,
    required RectangleCorners corners,
    required Offset origin,
    required FragmentShaderCache cache,
  });

  /// A flat rim, with no directional shading.
  static const PlainHighlightStyle plain = PlainHighlightStyle();

  /// A rim lit from [DefaultHighlightStyle.angle].
  static const DefaultHighlightStyle standard = DefaultHighlightStyle();

  /// A rim that is white on the lit side and black on the other.
  static const AmbientHighlightStyle ambient = AmbientHighlightStyle();
}

/// A rim of uniform colour.
class PlainHighlightStyle extends HighlightStyle {
  const PlainHighlightStyle({
    this.color = const Color(0x61FFFFFF), // white, alpha 0.38
    this.blendMode = BlendMode.plus,
  });

  @override
  final Color color;

  @override
  final BlendMode blendMode;

  @override
  ui.FragmentShader? createShader({
    required Size size,
    required RectangleCorners corners,
    required Offset origin,
    required FragmentShaderCache cache,
  }) =>
      null;

  PlainHighlightStyle copyWith({Color? color, BlendMode? blendMode}) =>
      PlainHighlightStyle(color: color ?? this.color, blendMode: blendMode ?? this.blendMode);

  @override
  bool operator ==(Object other) =>
      other is PlainHighlightStyle && other.color == color && other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(color, blendMode);
}

/// A rim lit from a given direction, brightest where the edge normal faces the
/// light.
class DefaultHighlightStyle extends HighlightStyle {
  const DefaultHighlightStyle({
    this.color = const Color(0x80FFFFFF), // white, alpha 0.5
    this.blendMode = BlendMode.plus,
    this.angle = 45.0,
    this.falloff = 1.0,
  });

  @override
  final Color color;

  @override
  final BlendMode blendMode;

  /// The direction of the light, in degrees.
  final double angle;

  /// How sharply the rim fades away from the lit direction.
  final double falloff;

  @override
  ui.FragmentShader? createShader({
    required Size size,
    required RectangleCorners corners,
    required Offset origin,
    required FragmentShaderCache cache,
  }) {
    if (!isRuntimeShaderSupported()) return null;
    final ui.FragmentShader? shader =
        cache.obtainOrNull('Default', FluidGlassPrograms.instance.highlightDefault);
    if (shader == null) return null;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, corners.topLeft)
      ..setFloat(5, corners.topRight)
      ..setFloat(6, corners.bottomRight)
      ..setFloat(7, corners.bottomLeft)
      ..setFloat(8, color.r)
      ..setFloat(9, color.g)
      ..setFloat(10, color.b)
      ..setFloat(11, color.a)
      ..setFloat(12, angle * math.pi / 180.0)
      ..setFloat(13, falloff);
    return shader;
  }

  DefaultHighlightStyle copyWith({
    Color? color,
    BlendMode? blendMode,
    double? angle,
    double? falloff,
  }) =>
      DefaultHighlightStyle(
        color: color ?? this.color,
        blendMode: blendMode ?? this.blendMode,
        angle: angle ?? this.angle,
        falloff: falloff ?? this.falloff,
      );

  @override
  bool operator ==(Object other) =>
      other is DefaultHighlightStyle &&
      other.color == color &&
      other.blendMode == blendMode &&
      other.angle == angle &&
      other.falloff == falloff;

  @override
  int get hashCode => Object.hash(color, blendMode, angle, falloff);
}

/// A rim that is white where the edge faces the light and black where it faces
/// away, composited normally rather than added.
class AmbientHighlightStyle extends HighlightStyle {
  const AmbientHighlightStyle({this.intensity = 0.38});

  /// The opacity of the rim.
  final double intensity;

  @override
  Color get color => Color.fromARGB((intensity * 255).round(), 255, 255, 255);

  @override
  BlendMode get blendMode => BlendMode.srcOver;

  @override
  ui.FragmentShader? createShader({
    required Size size,
    required RectangleCorners corners,
    required Offset origin,
    required FragmentShaderCache cache,
  }) {
    if (!isRuntimeShaderSupported()) return null;
    final ui.FragmentShader? shader =
        cache.obtainOrNull('Ambient', FluidGlassPrograms.instance.highlightAmbient);
    if (shader == null) return null;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, corners.topLeft)
      ..setFloat(5, corners.topRight)
      ..setFloat(6, corners.bottomRight)
      ..setFloat(7, corners.bottomLeft)
      ..setFloat(8, 45.0 * math.pi / 180.0)
      ..setFloat(9, 1.0)
      ..setFloat(10, intensity);
    return shader;
  }

  AmbientHighlightStyle copyWith({double? intensity}) =>
      AmbientHighlightStyle(intensity: intensity ?? this.intensity);

  @override
  bool operator ==(Object other) =>
      other is AmbientHighlightStyle && other.intensity == intensity;

  @override
  int get hashCode => intensity.hashCode;
}
