import 'package:flutter/rendering.dart';

import 'glass_outline.dart';
import 'rounded_rectangular_shape.dart';

/// Clips a widget to a [RoundedRectangularShape].
///
/// ```dart
/// ClipPath(
///   clipper: GlassShapeClipper(const Capsule()),
///   child: ColoredBox(color: trackColor),
/// )
/// ```
class GlassShapeClipper extends CustomClipper<Path> {
  const GlassShapeClipper(this.shape, {this.textDirection = TextDirection.ltr});

  final RoundedRectangularShape shape;
  final TextDirection textDirection;

  @override
  Path getClip(Size size) => shape.createOutline(size, textDirection).toPath();

  @override
  bool shouldReclip(covariant GlassShapeClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.textDirection != textDirection;
}

/// Adapts a [RoundedRectangularShape] to Flutter's [ShapeBorder], so it can be
/// used with [ShapeDecoration], `Material.shape`, `ClipPath.shape` and friends.
///
/// ```dart
/// DecoratedBox(
///   decoration: ShapeDecoration(
///     color: accentColor,
///     shape: GlassShapeBorder(const Capsule()),
///   ),
/// )
/// ```
class GlassShapeBorder extends OutlinedBorder {
  const GlassShapeBorder(this.shape, {super.side = BorderSide.none});

  final RoundedRectangularShape shape;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final double inset = side.strokeInset;
    final Rect inner = rect.deflate(inset);
    if (inner.isEmpty) return Path();
    return _pathFor(inner, textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _pathFor(rect, textDirection);
  }

  Path _pathFor(Rect rect, TextDirection? textDirection) {
    final GlassOutline outline =
        shape.createOutline(rect.size, textDirection ?? TextDirection.ltr);
    return outline.toPath().shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      _pathFor(rect.deflate(side.strokeOffset / 2), textDirection),
      side.toPaint(),
    );
  }

  @override
  GlassShapeBorder copyWith({BorderSide? side, RoundedRectangularShape? shape}) {
    return GlassShapeBorder(shape ?? this.shape, side: side ?? this.side);
  }

  @override
  ShapeBorder scale(double t) => GlassShapeBorder(shape, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is GlassShapeBorder && other.shape == shape && other.side == side;

  @override
  int get hashCode => Object.hash(shape, side);

  @override
  String toString() => 'GlassShapeBorder($shape, $side)';
}
