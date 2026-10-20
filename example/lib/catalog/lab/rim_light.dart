import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';

/// Light drawn *along* a glass element's outline, by arc length.
///
/// Everything here is ordinary canvas work — strokes of extracted path
/// segments, a mask blur for the bloom — so it draws the same on the `plain`
/// tier, on Skia and on the emulator, where no fragment shader runs.
///
/// Arc length rather than angle, because angle lies on anything that is not a
/// circle: seen from the centre of a wide capsule, the two long sides cover
/// almost every angle and the round ends almost none, so a light moved by
/// angle races around the ends and crawls along the sides.
class RimPath {
  RimPath(this.shape, this.size)
    : path = shape.createOutline(size, TextDirection.ltr).toPath() {
    metric = path.computeMetrics().first;
    length = metric.length;
    topCentre = _nearest(Offset(size.width / 2, 0));
    // Whichever way the outline was wound, "forward" is clockwise on screen:
    // just past the top centre, the outline heads right.
    final Offset ahead = metric
        .getTangentForOffset((topCentre + 2) % length)!
        .position;
    _clockwise = ahead.dx >= size.width / 2;
  }

  final RoundedRectangularShape shape;
  final Size size;
  final Path path;
  late final ui.PathMetric metric;
  late final double length;

  /// The arc length of the point at the top centre of the outline.
  late final double topCentre;

  late final bool _clockwise;

  /// The arc length [distance] clockwise from [from].
  double advance(double from, double distance) {
    final double s = _clockwise ? from + distance : from - distance;
    return s % length;
  }

  /// The arc length of the outline point nearest [point], in element space.
  double nearest(Offset point) => _nearest(point);

  double _nearest(Offset point) {
    const int samples = 160;
    double best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < samples; i++) {
      final double s = length * i / samples;
      final double d =
          (metric.getTangentForOffset(s)!.position - point).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = s;
      }
    }
    return best;
  }

  Offset pointAt(double s) => metric.getTangentForOffset(s % length)!.position;

  /// The outline from [from], [distance] clockwise, as one path — split in
  /// two if it crosses the point where the outline starts.
  Path segment(double from, double distance) {
    final double d = distance.clamp(0.0, length);
    final Path out = Path();
    if (d <= 0) return out;
    double a;
    double b;
    if (_clockwise) {
      a = from % length;
      b = a + d;
    } else {
      b = from % length;
      a = b - d;
    }
    if (a < 0) {
      out.addPath(metric.extractPath(a + length, length), Offset.zero);
      out.addPath(metric.extractPath(0, b), Offset.zero);
    } else if (b > length) {
      out.addPath(metric.extractPath(a, length), Offset.zero);
      out.addPath(metric.extractPath(0, b - length), Offset.zero);
    } else {
      out.addPath(metric.extractPath(a, b), Offset.zero);
    }
    return out;
  }
}

/// Caches one [RimPath] per shape and size, since extracting a metric is the
/// only non-trivial part of drawing a rim light and the geometry of a resting
/// element never changes.
class RimPathCache {
  RimPath? _last;

  RimPath of(RoundedRectangularShape shape, Size size) {
    final RimPath? last = _last;
    if (last != null && last.size == size && last.shape == shape) return last;
    return _last = RimPath(shape, size);
  }
}

Paint _core(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..color = color
  ..blendMode = BlendMode.plus;

Paint _bloom(Color color, double width, double sigma) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..color = color
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
  ..blendMode = BlendMode.plus;

/// The whole outline lit evenly: a crisp core with a soft bloom around it.
void paintRimGlow(Canvas canvas, RimPath rim, Color color, double strength) {
  if (strength <= 0) return;
  final double a = strength.clamp(0.0, 1.0);
  canvas.drawPath(
    rim.path,
    _bloom(color.withValues(alpha: color.a * 0.55 * a), 6, 4),
  );
  canvas.drawPath(rim.path, _core(color.withValues(alpha: color.a * a), 1.4));
}

/// A lit stretch of the outline, [distance] clockwise from [from], evenly
/// bright — what a filling progress rim is.
void paintRimSpan(
  Canvas canvas,
  RimPath rim,
  double from,
  double distance,
  Color color, {
  double strength = 1,
}) {
  if (distance <= 0 || strength <= 0) return;
  final Path span = rim.segment(from, distance);
  canvas.drawPath(
    span,
    _bloom(color.withValues(alpha: color.a * 0.5 * strength), 6, 4),
  );
  canvas.drawPath(
    span,
    _core(color.withValues(alpha: color.a * strength), 1.6),
  );
}

/// A comet: a bright head at arc length [head] with a tail [tail] long
/// behind it, fading towards its end. [clockwise] is the direction it
/// travels in.
void paintRimComet(
  Canvas canvas,
  RimPath rim,
  double head,
  double tail,
  Color color, {
  bool clockwise = true,
  double strength = 1,
}) {
  if (strength <= 0 || tail <= 0) return;
  const int steps = 12;
  final double piece = tail / steps;
  for (int i = 0; i < steps; i++) {
    // i = 0 is the far end of the tail, steps - 1 is the head.
    final double t = (i + 1) / steps;
    final double fade = t * t;
    final double start = clockwise
        ? rim.advance(head, -tail + piece * i)
        : rim.advance(head, tail - piece * (i + 1));
    final Path p = rim.segment(start, piece + 0.6);
    final double a = color.a * fade * strength;
    if (i >= steps ~/ 2) {
      canvas.drawPath(p, _bloom(color.withValues(alpha: a * 0.6), 7, 4.5));
    }
    canvas.drawPath(p, _core(color.withValues(alpha: a), 1.2 + 1.0 * t));
  }
  // The spark at the head: the one place the light is concentrated, which is
  // what makes it read as travelling rather than as a gradient that shifts.
  final Offset at = rim.pointAt(head);
  canvas.drawCircle(
    at,
    5,
    Paint()
      ..color = color.withValues(alpha: color.a * 0.55 * strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..blendMode = BlendMode.plus,
  );
  canvas.drawCircle(
    at,
    1.6,
    Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * strength)
      ..blendMode = BlendMode.plus,
  );
}

/// A faint wash over the element's face, clipped to it — the light the rim is
/// giving off, landing on the glass.
void paintFaceWash(
  Canvas canvas,
  RimPath rim,
  Color color,
  double strength, {
  Offset? centre,
  double? radius,
}) {
  if (strength <= 0) return;
  final Offset c = centre ?? rim.size.center(Offset.zero);
  final double r = radius ?? rim.size.longestSide * 0.75;
  canvas.save();
  canvas.clipPath(rim.path);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(c, r, <Color>[
        color.withValues(alpha: color.a * strength),
        color.withValues(alpha: 0),
      ])
      ..blendMode = BlendMode.plus,
  );
  canvas.restore();
}

/// Spring-free easing helpers for the scripted light phases.
double easeOutCubic(double t) {
  final double u = 1 - t.clamp(0.0, 1.0);
  return 1 - u * u * u;
}

double easeInOutSine(double t) =>
    -(math.cos(math.pi * t.clamp(0.0, 1.0)) - 1) / 2;

/// A lab screen's backdrop: the catalog wallpaper, dimmed so that light drawn
/// over the glass has something to be brighter than.
class LabWallpaper extends StatelessWidget {
  const LabWallpaper({super.key, this.dim = 0.45});

  final double dim;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF000000).withValues(alpha: dim),
          BlendMode.srcATop,
        ),
        child: Image.asset('assets/wallpaper_light.webp', fit: BoxFit.cover),
      ),
    );
  }
}
