import 'dart:ui';

import 'continuous_curvature_corner_builder.dart';
import 'glass_outline.dart';
import 'rounded_corner_style.dart';

/// Builds the outline of a rounded rectangle with a single radius.
GlassOutline roundedRectangleOutline({
  required Size size,
  required double radius,
  required RoundedCornerStyle style,
}) {
  final double width = size.width;
  final double height = size.height;
  final double maxRadius = size.shortestSide * 0.5;

  if (radius == 0.0) {
    return GlassOutline.rect(Rect.fromLTWH(0, 0, width, height));
  }
  if (style == RoundedCornerStyle.circular || (width == height && radius >= maxRadius)) {
    return GlassOutline.rrect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(radius),
      ),
    );
  }
  return GlassOutline.path(_continuousCurvatureRoundedRectanglePath(size, radius));
}

/// Builds the outline of a rounded rectangle with per-corner radii.
GlassOutline unevenRoundedRectangleOutline({
  required Size size,
  required double topLeft,
  required double topRight,
  required double bottomRight,
  required double bottomLeft,
  required RoundedCornerStyle style,
}) {
  final double width = size.width;
  final double height = size.height;
  final double maxRadius = size.shortestSide * 0.5;

  if (topLeft == 0.0 && topRight == 0.0 && bottomRight == 0.0 && bottomLeft == 0.0) {
    return GlassOutline.rect(Rect.fromLTWH(0, 0, width, height));
  }
  if (style == RoundedCornerStyle.circular ||
      (width == height &&
          topLeft >= maxRadius &&
          topRight >= maxRadius &&
          bottomRight >= maxRadius &&
          bottomLeft >= maxRadius)) {
    return GlassOutline.rrect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, width, height),
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomRight: Radius.circular(bottomRight),
        bottomLeft: Radius.circular(bottomLeft),
      ),
    );
  }
  return GlassOutline.path(
    _continuousCurvatureUnevenRoundedRectanglePath(
      size,
      topLeft,
      topRight,
      bottomRight,
      bottomLeft,
    ),
  );
}

double _coerceIn(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

Path _continuousCurvatureRoundedRectanglePath(Size size, double radius) {
  final double width = size.width;
  final double height = size.height;
  final Path path = Path();

  final ContinuousCurvatureRoundedRectangleCornerBuilder cornerBuilder =
      ContinuousCurvatureRoundedRectangleCornerBuilder.instance;
  final double w = width;
  final double h = height;

  final double r = radius;
  final double tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  final double tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  final List<double> p = cornerBuilder.getCornerBezierPoints(tW, tH);
  if (p.length < 20) return path;

  double x = w - r;
  double y = 0.0;
  path.moveTo(x + p[0] * r, y + p[1] * r);
  path.cubicTo(
    x + p[2] * r, y + p[3] * r,
    x + p[4] * r, y + p[5] * r,
    x + p[6] * r, y + p[7] * r,
  );
  path.cubicTo(
    x + p[8] * r, y + p[9] * r,
    x + p[10] * r, y + p[11] * r,
    x + p[12] * r, y + p[13] * r,
  );
  path.cubicTo(
    x + p[14] * r, y + p[15] * r,
    x + p[16] * r, y + p[17] * r,
    x + p[18] * r, y + p[19] * r,
  );

  x = w - r;
  y = h;
  path.lineTo(x + p[18] * r, y - p[19] * r);
  path.cubicTo(
    x + p[16] * r, y - p[17] * r,
    x + p[14] * r, y - p[15] * r,
    x + p[12] * r, y - p[13] * r,
  );
  path.cubicTo(
    x + p[10] * r, y - p[11] * r,
    x + p[8] * r, y - p[9] * r,
    x + p[6] * r, y - p[7] * r,
  );
  path.cubicTo(
    x + p[4] * r, y - p[5] * r,
    x + p[2] * r, y - p[3] * r,
    x + p[0] * r, y - p[1] * r,
  );

  x = r;
  y = h;
  path.lineTo(x - p[0] * r, y - p[1] * r);
  path.cubicTo(
    x - p[2] * r, y - p[3] * r,
    x - p[4] * r, y - p[5] * r,
    x - p[6] * r, y - p[7] * r,
  );
  path.cubicTo(
    x - p[8] * r, y - p[9] * r,
    x - p[10] * r, y - p[11] * r,
    x - p[12] * r, y - p[13] * r,
  );
  path.cubicTo(
    x - p[14] * r, y - p[15] * r,
    x - p[16] * r, y - p[17] * r,
    x - p[18] * r, y - p[19] * r,
  );

  x = r;
  y = 0.0;
  path.lineTo(x - p[18] * r, y + p[19] * r);
  path.cubicTo(
    x - p[16] * r, y + p[17] * r,
    x - p[14] * r, y + p[15] * r,
    x - p[12] * r, y + p[13] * r,
  );
  path.cubicTo(
    x - p[10] * r, y + p[11] * r,
    x - p[8] * r, y + p[9] * r,
    x - p[6] * r, y + p[7] * r,
  );
  path.cubicTo(
    x - p[4] * r, y + p[5] * r,
    x - p[2] * r, y + p[3] * r,
    x - p[0] * r, y + p[1] * r,
  );

  path.close();
  return path;
}

Path _continuousCurvatureUnevenRoundedRectanglePath(
  Size size,
  double topLeft,
  double topRight,
  double bottomRight,
  double bottomLeft,
) {
  final double width = size.width;
  final double height = size.height;
  final Path path = Path();

  final ContinuousCurvatureRoundedRectangleCornerBuilder cornerBuilder =
      ContinuousCurvatureRoundedRectangleCornerBuilder.instance;
  final double w = width;
  final double h = height;

  double r = topRight;
  double tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  double tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  List<double> p = cornerBuilder.getCornerBezierPoints(tW, tH);
  if (p.length < 20) return path;

  double x = w - r;
  double y = 0.0;
  path.moveTo(x + p[0] * r, y + p[1] * r);
  path.cubicTo(
    x + p[2] * r, y + p[3] * r,
    x + p[4] * r, y + p[5] * r,
    x + p[6] * r, y + p[7] * r,
  );
  path.cubicTo(
    x + p[8] * r, y + p[9] * r,
    x + p[10] * r, y + p[11] * r,
    x + p[12] * r, y + p[13] * r,
  );
  path.cubicTo(
    x + p[14] * r, y + p[15] * r,
    x + p[16] * r, y + p[17] * r,
    x + p[18] * r, y + p[19] * r,
  );

  r = bottomRight;
  tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  p = cornerBuilder.getCornerBezierPoints(tW, tH);
  if (p.length < 20) return path;

  x = w - r;
  y = h;
  path.lineTo(x + p[18] * r, y - p[19] * r);
  path.cubicTo(
    x + p[16] * r, y - p[17] * r,
    x + p[14] * r, y - p[15] * r,
    x + p[12] * r, y - p[13] * r,
  );
  path.cubicTo(
    x + p[10] * r, y - p[11] * r,
    x + p[8] * r, y - p[9] * r,
    x + p[6] * r, y - p[7] * r,
  );
  path.cubicTo(
    x + p[4] * r, y - p[5] * r,
    x + p[2] * r, y - p[3] * r,
    x + p[0] * r, y - p[1] * r,
  );

  r = bottomLeft;
  tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  p = cornerBuilder.getCornerBezierPoints(tW, tH);
  if (p.length < 20) return path;

  x = r;
  y = h;
  path.lineTo(x - p[0] * r, y - p[1] * r);
  path.cubicTo(
    x - p[2] * r, y - p[3] * r,
    x - p[4] * r, y - p[5] * r,
    x - p[6] * r, y - p[7] * r,
  );
  path.cubicTo(
    x - p[8] * r, y - p[9] * r,
    x - p[10] * r, y - p[11] * r,
    x - p[12] * r, y - p[13] * r,
  );
  path.cubicTo(
    x - p[14] * r, y - p[15] * r,
    x - p[16] * r, y - p[17] * r,
    x - p[18] * r, y - p[19] * r,
  );

  r = topLeft;
  tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  p = cornerBuilder.getCornerBezierPoints(tW, tH);
  if (p.length < 20) return path;

  x = r;
  y = 0.0;
  path.lineTo(x - p[18] * r, y + p[19] * r);
  path.cubicTo(
    x - p[16] * r, y + p[17] * r,
    x - p[14] * r, y + p[15] * r,
    x - p[12] * r, y + p[13] * r,
  );
  path.cubicTo(
    x - p[10] * r, y + p[11] * r,
    x - p[8] * r, y + p[9] * r,
    x - p[6] * r, y + p[7] * r,
  );
  path.cubicTo(
    x - p[4] * r, y + p[5] * r,
    x - p[2] * r, y + p[3] * r,
    x - p[0] * r, y + p[1] * r,
  );

  path.close();
  return path;
}
