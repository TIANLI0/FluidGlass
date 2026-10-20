import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The cubic handle ratio of a smooth corner.
///
/// One cubic per corner, tuned to the 45° inset of the Lp superellipse
/// `|x|^n + |y|^n = r^n` with `n = 2.5`; the corner tile is exactly the
/// radius, so the straight edges start where a circular corner's would.
const double softSquircleControl = 0.6877;

/// Appends a smooth-cornered rectangle at [rect] with one radius per corner.
///
/// Each radius is clamped to half the shorter side. With [smooth] false the
/// corners are plain circular arcs of the same radii.
void addSoftSquircle(
  Path path,
  Rect rect, {
  required double topLeft,
  required double topRight,
  required double bottomRight,
  required double bottomLeft,
  bool smooth = true,
}) {
  final double width = rect.width;
  final double height = rect.height;
  if (width <= 0 || height <= 0) return;
  final double halfMin = math.min(width, height) * 0.5;
  double clamp(double r) => r.clamp(0.0, halfMin);
  final double tl = clamp(topLeft);
  final double tr = clamp(topRight);
  final double br = clamp(bottomRight);
  final double bl = clamp(bottomLeft);
  if (tl <= 0 && tr <= 0 && br <= 0 && bl <= 0) {
    path.addRect(rect);
    return;
  }
  if (!smooth) {
    path.addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomRight: Radius.circular(br),
        bottomLeft: Radius.circular(bl),
      ),
    );
    return;
  }
  double handle(double tile) => tile * (1 - softSquircleControl);
  final double l = rect.left;
  final double t = rect.top;
  final double r = rect.right;
  final double b = rect.bottom;
  path
    ..moveTo(l + tl, t)
    ..lineTo(r - tr, t)
    ..cubicTo(r - handle(tr), t, r, t + handle(tr), r, t + tr)
    ..lineTo(r, b - br)
    ..cubicTo(r, b - handle(br), r - handle(br), b, r - br, b)
    ..lineTo(l + bl, b)
    ..cubicTo(l + handle(bl), b, l, b - handle(bl), l, b - bl)
    ..lineTo(l, t + tl)
    ..cubicTo(l, t + handle(tl), l + handle(tl), t, l + tl, t)
    ..close();
}

/// A smooth-cornered rectangle path at [rect].
Path softSquirclePath(Rect rect, BorderRadius radius, {bool smooth = true}) {
  final Path path = Path();
  addSoftSquircle(
    path,
    rect,
    topLeft: radius.topLeft.x,
    topRight: radius.topRight.x,
    bottomRight: radius.bottomRight.x,
    bottomLeft: radius.bottomLeft.x,
    smooth: smooth,
  );
  return path;
}

/// The smooth-corner silhouette as a [ShapeBorder], for [ShapeDecoration],
/// [ClipPath.shape], [Material.shape] and the like.
///
/// [radius] may differ per corner. With [smooth] false the outline is a plain
/// rounded rectangle.
class SoftSquircleBorder extends OutlinedBorder {
  const SoftSquircleBorder({
    this.radius = BorderRadius.zero,
    this.smooth = true,
    super.side,
  });

  /// Four equal corners of [radius].
  SoftSquircleBorder.all(
    double radius, {
    bool smooth = true,
    BorderSide side = BorderSide.none,
  }) : this(radius: BorderRadius.circular(radius), smooth: smooth, side: side);

  final BorderRadius radius;
  final bool smooth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final double inset = side.strokeInset;
    final Rect inner = rect.deflate(inset);
    final BorderRadius r = BorderRadius.only(
      topLeft: _shrink(radius.topLeft, inset),
      topRight: _shrink(radius.topRight, inset),
      bottomRight: _shrink(radius.bottomRight, inset),
      bottomLeft: _shrink(radius.bottomLeft, inset),
    );
    return softSquirclePath(inner, r, smooth: smooth);
  }

  static Radius _shrink(Radius r, double by) =>
      Radius.circular(math.max(0, r.x - by));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return softSquirclePath(rect, radius, smooth: smooth);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    // The stroke's centre line: half a width inside for an inside stroke, on
    // the edge for a centred one, half a width outside for an outside one.
    final double delta = side.strokeOffset / 2;
    final Rect centre = rect.inflate(delta);
    final BorderRadius r = BorderRadius.only(
      topLeft: _shrink(radius.topLeft, -delta),
      topRight: _shrink(radius.topRight, -delta),
      bottomRight: _shrink(radius.bottomRight, -delta),
      bottomLeft: _shrink(radius.bottomLeft, -delta),
    );
    canvas.drawPath(
      softSquirclePath(centre, r, smooth: smooth),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => SoftSquircleBorder(
    radius: radius * t,
    smooth: smooth,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SoftSquircleBorder) {
      return SoftSquircleBorder(
        radius: BorderRadius.lerp(a.radius, radius, t)!,
        smooth: smooth,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SoftSquircleBorder) {
      return SoftSquircleBorder(
        radius: BorderRadius.lerp(radius, b.radius, t)!,
        smooth: b.smooth,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  SoftSquircleBorder copyWith({
    BorderSide? side,
    BorderRadius? radius,
    bool? smooth,
  }) {
    return SoftSquircleBorder(
      radius: radius ?? this.radius,
      smooth: smooth ?? this.smooth,
      side: side ?? this.side,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftSquircleBorder &&
      other.radius == radius &&
      other.smooth == smooth &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, smooth, side);

  @override
  String toString() => 'SoftSquircleBorder($radius, smooth: $smooth)';
}

/// Clips [canvas] to a smooth-cornered [rect].
void clipSoftSquircle(
  Canvas canvas,
  Rect rect,
  BorderRadius radius, {
  bool smooth = true,
  bool antiAlias = true,
}) {
  canvas.clipPath(
    softSquirclePath(rect, radius, smooth: smooth),
    doAntiAlias: antiAlias,
  );
}

/// Fills a smooth-cornered [rect].
void drawSoftSquircle(
  Canvas canvas,
  Rect rect,
  BorderRadius radius,
  Paint paint, {
  bool smooth = true,
}) {
  canvas.drawPath(softSquirclePath(rect, radius, smooth: smooth), paint);
}
