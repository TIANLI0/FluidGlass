import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The drop shadow cast by a glass element.
///
/// Named `GlassShadow` rather than `Shadow` so it does not collide with
/// `dart:ui`'s [Shadow].
@immutable
class GlassShadow {
  const GlassShadow._({
    required this.radius,
    required this.offset,
    required this.color,
    required this.alpha,
    required this.blendMode,
  });

  /// [offset] defaults to `Offset(0, radius / 6)`.
  factory GlassShadow({
    double radius = 24.0,
    Offset? offset,
    Color color = const Color(0x1A000000), // black, alpha 0.1
    double alpha = 1.0,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    return GlassShadow._(
      radius: radius,
      offset: offset ?? Offset(0.0, radius / 6.0),
      color: color,
      alpha: alpha,
      blendMode: blendMode,
    );
  }

  /// The blur radius, in logical pixels.
  final double radius;

  /// How far the shadow is displaced from the element, in logical pixels.
  final Offset offset;

  final Color color;

  /// An overall opacity applied to the shadow.
  final double alpha;

  final BlendMode blendMode;

  static const GlassShadow standard = GlassShadow._(
    radius: 24.0,
    offset: Offset(0.0, 4.0),
    color: Color(0x1A000000),
    alpha: 1.0,
    blendMode: BlendMode.srcOver,
  );

  GlassShadow copyWith({
    double? radius,
    Offset? offset,
    Color? color,
    double? alpha,
    BlendMode? blendMode,
  }) {
    return GlassShadow._(
      radius: radius ?? this.radius,
      offset: offset ?? this.offset,
      color: color ?? this.color,
      alpha: alpha ?? this.alpha,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassShadow &&
      other.radius == radius &&
      other.offset == offset &&
      other.color == color &&
      other.alpha == alpha &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(radius, offset, color, alpha, blendMode);
}

/// The shadow cast *inside* a glass element, which reads as thickness.
@immutable
class GlassInnerShadow {
  const GlassInnerShadow._({
    required this.radius,
    required this.offset,
    required this.color,
    required this.alpha,
    required this.blendMode,
  });

  /// [offset] defaults to `Offset(0, radius)`.
  factory GlassInnerShadow({
    double radius = 24.0,
    Offset? offset,
    Color color = const Color(0x26000000), // black, alpha 0.15
    double alpha = 1.0,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    return GlassInnerShadow._(
      radius: radius,
      offset: offset ?? Offset(0.0, radius),
      color: color,
      alpha: alpha,
      blendMode: blendMode,
    );
  }

  final double radius;
  final Offset offset;
  final Color color;
  final double alpha;
  final BlendMode blendMode;

  static const GlassInnerShadow standard = GlassInnerShadow._(
    radius: 24.0,
    offset: Offset(0.0, 24.0),
    color: Color(0x26000000),
    alpha: 1.0,
    blendMode: BlendMode.srcOver,
  );

  GlassInnerShadow copyWith({
    double? radius,
    Offset? offset,
    Color? color,
    double? alpha,
    BlendMode? blendMode,
  }) {
    return GlassInnerShadow._(
      radius: radius ?? this.radius,
      offset: offset ?? this.offset,
      color: color ?? this.color,
      alpha: alpha ?? this.alpha,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  static GlassInnerShadow lerp(
    GlassInnerShadow start,
    GlassInnerShadow stop,
    double fraction,
  ) {
    return GlassInnerShadow._(
      radius: lerpDouble(start.radius, stop.radius, fraction)!,
      offset: Offset.lerp(start.offset, stop.offset, fraction)!,
      color: Color.lerp(start.color, stop.color, fraction)!,
      alpha: lerpDouble(start.alpha, stop.alpha, fraction)!,
      blendMode: fraction < 0.5 ? start.blendMode : stop.blendMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassInnerShadow &&
      other.radius == radius &&
      other.offset == offset &&
      other.color == color &&
      other.alpha == alpha &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(radius, offset, color, alpha, blendMode);
}
