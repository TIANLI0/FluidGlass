import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'glass_outline.dart';
import 'rectangle_corner_radii.dart';
import 'rounded_corner_style.dart';
import 'rounded_rectangle_outline.dart';

/// A rectangle-like shape whose corner radii are known analytically, so the
/// refraction and highlight shaders can build a signed-distance field for it.
///
///
/// Unlike Flutter's [ShapeBorder], this exposes [corners] separately from
/// [createOutline]: the outline may be a G2-continuous squircle path while the
/// shaders approximate it with the circular radii returned by [corners].
@immutable
abstract class RoundedRectangularShape {
  const RoundedRectangularShape();

  RoundedCornerStyle? get style => null;

  /// The four corner radii, in logical pixels, resolved against
  /// [textDirection].
  RectangleCorners corners(Size size, TextDirection textDirection);

  /// The geometry used for clipping and for stroking the highlight.
  GlassOutline createOutline(Size size, TextDirection textDirection);

  /// Returns a copy of this shape with a different corner [style].
  RoundedRectangularShape copyWithStyle(RoundedCornerStyle style);
}

/// A plain rectangle.
class Rectangle extends RoundedRectangularShape {
  const Rectangle();

  @override
  RectangleCorners corners(Size size, TextDirection textDirection) {
    return const RectangleCorners(
      topLeft: 0,
      topRight: 0,
      bottomRight: 0,
      bottomLeft: 0,
    );
  }

  @override
  GlassOutline createOutline(Size size, TextDirection textDirection) {
    return GlassOutline.rect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  RoundedRectangularShape copyWithStyle(RoundedCornerStyle style) => this;

  @override
  bool operator ==(Object other) => other is Rectangle;

  @override
  int get hashCode => (Rectangle).hashCode;

  @override
  String toString() => 'Rectangle';
}

/// A rounded rectangle with a uniform corner radius, in logical pixels.
class RoundedRectangle extends RoundedRectangularShape {
  const RoundedRectangle(
    this.cornerRadius, {
    this.style = RoundedCornerStyle.continuous,
  });

  final double cornerRadius;

  @override
  final RoundedCornerStyle style;

  double _radius(Size size) {
    final double max = size.shortestSide * 0.5;
    return cornerRadius < 0.0 ? 0.0 : (cornerRadius > max ? max : cornerRadius);
  }

  @override
  RectangleCorners corners(Size size, TextDirection textDirection) {
    final double radius = _radius(size);
    return RectangleCorners(
      topLeft: radius,
      topRight: radius,
      bottomRight: radius,
      bottomLeft: radius,
    );
  }

  @override
  GlassOutline createOutline(Size size, TextDirection textDirection) {
    return roundedRectangleOutline(
      size: size,
      radius: _radius(size),
      style: style,
    );
  }

  @override
  RoundedRectangle copyWithStyle(RoundedCornerStyle style) =>
      RoundedRectangle(cornerRadius, style: style);

  RoundedRectangle copyWith({double? cornerRadius, RoundedCornerStyle? style}) =>
      RoundedRectangle(cornerRadius ?? this.cornerRadius, style: style ?? this.style);

  @override
  bool operator ==(Object other) =>
      other is RoundedRectangle &&
      other.cornerRadius == cornerRadius &&
      other.style == style;

  @override
  int get hashCode => Object.hash(cornerRadius, style);

  @override
  String toString() => 'RoundedRectangle(cornerRadius: $cornerRadius, style: $style)';
}

/// A rectangle rounded by half of its shortest side.
class Capsule extends RoundedRectangularShape {
  const Capsule({this.style = RoundedCornerStyle.continuous});

  @override
  final RoundedCornerStyle style;

  @override
  RectangleCorners corners(Size size, TextDirection textDirection) {
    final double radius = size.shortestSide * 0.5;
    return RectangleCorners(
      topLeft: radius,
      topRight: radius,
      bottomRight: radius,
      bottomLeft: radius,
    );
  }

  @override
  GlassOutline createOutline(Size size, TextDirection textDirection) {
    return roundedRectangleOutline(
      size: size,
      radius: size.shortestSide * 0.5,
      style: style,
    );
  }

  @override
  Capsule copyWithStyle(RoundedCornerStyle style) => Capsule(style: style);

  @override
  bool operator ==(Object other) => other is Capsule && other.style == style;

  @override
  int get hashCode => Object.hash((Capsule).hashCode, style);

  @override
  String toString() => 'Capsule(style: $style)';
}

/// A rounded rectangle with independent corner radii, in logical pixels.
class UnevenRoundedRectangle extends RoundedRectangularShape {
  const UnevenRoundedRectangle(
    this.cornerRadii, {
    this.style = RoundedCornerStyle.continuous,
  });

  UnevenRoundedRectangle.only({
    double topStart = 0.0,
    double topEnd = 0.0,
    double bottomEnd = 0.0,
    double bottomStart = 0.0,
    this.style = RoundedCornerStyle.continuous,
  }) : cornerRadii = RectangleCornerRadii(
          topStart: topStart,
          topEnd: topEnd,
          bottomEnd: bottomEnd,
          bottomStart: bottomStart,
        );

  final RectangleCornerRadii cornerRadii;

  @override
  final RoundedCornerStyle style;

  @override
  RectangleCorners corners(Size size, TextDirection textDirection) {
    final double maxRadius = size.shortestSide * 0.5;
    double clamp(double v) => v < 0.0 ? 0.0 : (v > maxRadius ? maxRadius : v);

    final double topStart = clamp(cornerRadii.topStart);
    final double topEnd = clamp(cornerRadii.topEnd);
    final double bottomEnd = clamp(cornerRadii.bottomEnd);
    final double bottomStart = clamp(cornerRadii.bottomStart);

    switch (textDirection) {
      case TextDirection.ltr:
        return RectangleCorners(
          topLeft: topStart,
          topRight: topEnd,
          bottomRight: bottomEnd,
          bottomLeft: bottomStart,
        );
      case TextDirection.rtl:
        return RectangleCorners(
          topLeft: topEnd,
          topRight: topStart,
          bottomRight: bottomStart,
          bottomLeft: bottomEnd,
        );
    }
  }

  @override
  GlassOutline createOutline(Size size, TextDirection textDirection) {
    final RectangleCorners c = corners(size, textDirection);
    return unevenRoundedRectangleOutline(
      size: size,
      topLeft: c.topLeft,
      topRight: c.topRight,
      bottomRight: c.bottomRight,
      bottomLeft: c.bottomLeft,
      style: style,
    );
  }

  @override
  UnevenRoundedRectangle copyWithStyle(RoundedCornerStyle style) =>
      UnevenRoundedRectangle(cornerRadii, style: style);

  UnevenRoundedRectangle copyWith({
    RectangleCornerRadii? cornerRadii,
    RoundedCornerStyle? style,
  }) =>
      UnevenRoundedRectangle(cornerRadii ?? this.cornerRadii, style: style ?? this.style);

  @override
  bool operator ==(Object other) =>
      other is UnevenRoundedRectangle &&
      other.cornerRadii == cornerRadii &&
      other.style == style;

  @override
  int get hashCode => Object.hash(cornerRadii, style);

  @override
  String toString() => 'UnevenRoundedRectangle(cornerRadii: $cornerRadii, style: $style)';
}

/// Linearly interpolates between two [RoundedRectangle]s.
RoundedRectangle lerpRoundedRectangle(
  RoundedRectangle start,
  RoundedRectangle stop,
  double fraction,
) {
  return RoundedRectangle(
    lerpDouble(start.cornerRadius, stop.cornerRadius, fraction)!,
    style: fraction < 0.5 ? start.style : stop.style,
  );
}
