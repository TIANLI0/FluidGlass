import 'dart:ui';

/// The geometry of a shape, kept in the most specific form available so that
/// clipping and stroking can use the fastest (and best anti-aliased) canvas
/// primitive.
sealed class GlassOutline {
  const GlassOutline();

  const factory GlassOutline.rect(Rect rect) = RectOutline;

  const factory GlassOutline.rrect(RRect rrect) = RRectOutline;

  factory GlassOutline.path(Path path) = PathOutline;

  /// Clips [canvas] to this outline.
  void clip(Canvas canvas);

  /// Fills or strokes this outline with [paint], depending on the paint style.
  void draw(Canvas canvas, Paint paint);

  /// This outline as a [Path]. Allocates for the rect/rrect cases, so prefer
  /// [clip] and [draw] on hot paths.
  Path toPath();
}

final class RectOutline extends GlassOutline {
  const RectOutline(this.rect);

  final Rect rect;

  @override
  void clip(Canvas canvas) => canvas.clipRect(rect);

  @override
  void draw(Canvas canvas, Paint paint) => canvas.drawRect(rect, paint);

  @override
  Path toPath() => Path()..addRect(rect);
}

final class RRectOutline extends GlassOutline {
  const RRectOutline(this.rrect);

  final RRect rrect;

  @override
  void clip(Canvas canvas) => canvas.clipRRect(rrect);

  @override
  void draw(Canvas canvas, Paint paint) => canvas.drawRRect(rrect, paint);

  @override
  Path toPath() => Path()..addRRect(rrect);
}

final class PathOutline extends GlassOutline {
  PathOutline(this.path);

  final Path path;

  @override
  void clip(Canvas canvas) => canvas.clipPath(path);

  @override
  void draw(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);

  @override
  Path toPath() => path;
}
