import 'dart:ui';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoundedRectangle', () {
    test('clamps its radius to half the shortest side', () {
      const RoundedRectangle shape = RoundedRectangle(100);
      final RectangleCorners corners =
          shape.corners(const Size(40, 200), TextDirection.ltr);
      expect(corners.topLeft, 20);
      expect(corners.bottomRight, 20);
    });

    test('is a plain rectangle at radius zero', () {
      const RoundedRectangle shape = RoundedRectangle(0);
      expect(
        shape.createOutline(const Size(100, 50), TextDirection.ltr),
        isA<RectOutline>(),
      );
    });

    test('uses an RRect for circular corners and a path for continuous ones', () {
      const Size size = Size(100, 50);
      expect(
        const RoundedRectangle(16, style: RoundedCornerStyle.circular)
            .createOutline(size, TextDirection.ltr),
        isA<RRectOutline>(),
      );
      expect(
        const RoundedRectangle(16).createOutline(size, TextDirection.ltr),
        isA<PathOutline>(),
      );
    });

    test('continuous outline stays inside its bounds and spans them', () {
      const Size size = Size(200, 120);
      final GlassOutline outline =
          const RoundedRectangle(32).createOutline(size, TextDirection.ltr);
      final Rect bounds = outline.toPath().getBounds();
      expect(bounds.left, closeTo(0, 0.5));
      expect(bounds.top, closeTo(0, 0.5));
      expect(bounds.right, closeTo(size.width, 0.5));
      expect(bounds.bottom, closeTo(size.height, 0.5));
    });

    test('a continuous corner blends into the edge later than a circular one', () {
      // The signature of a G2-continuous corner: it reaches the same depth on
      // the diagonal as a circular corner of the same radius, but starts
      // curving further along the straight edges.
      const Size size = Size(200, 120);
      final Path continuous =
          const RoundedRectangle(40).createOutline(size, TextDirection.ltr).toPath();
      final Path circular =
          const RoundedRectangle(40, style: RoundedCornerStyle.circular)
              .createOutline(size, TextDirection.ltr)
              .toPath();

      double firstInside(Path path, Offset Function(double) at) {
        for (double t = 0; t < 100; t += 0.05) {
          if (path.contains(at(t))) return t;
        }
        return double.infinity;
      }

      final double continuousDiagonal =
          firstInside(continuous, (double t) => Offset(t, t));
      final double circularDiagonal =
          firstInside(circular, (double t) => Offset(t, t));
      expect(continuousDiagonal, closeTo(circularDiagonal, 0.2));

      final double continuousEdge =
          firstInside(continuous, (double t) => Offset(t, 0.6));
      final double circularEdge = firstInside(circular, (double t) => Offset(t, 0.6));
      expect(continuousEdge, greaterThan(circularEdge + 2));
    });
  });

  group('Capsule', () {
    test('rounds by half the shortest side', () {
      final RectangleCorners corners =
          const Capsule().corners(const Size(120, 40), TextDirection.ltr);
      expect(corners.topLeft, 20);
      expect(corners.topRight, 20);
      expect(corners.bottomRight, 20);
      expect(corners.bottomLeft, 20);
    });

    test('is a true circle when square', () {
      final GlassOutline outline =
          const Capsule().createOutline(const Size(64, 64), TextDirection.ltr);
      expect(outline, isA<RRectOutline>());
    });
  });

  group('UnevenRoundedRectangle', () {
    test('resolves start/end against the text direction', () {
      final UnevenRoundedRectangle shape =
          UnevenRoundedRectangle.only(topStart: 10, bottomEnd: 20);
      const Size size = Size(200, 100);

      final RectangleCorners ltr = shape.corners(size, TextDirection.ltr);
      expect(ltr.topLeft, 10);
      expect(ltr.bottomRight, 20);

      final RectangleCorners rtl = shape.corners(size, TextDirection.rtl);
      expect(rtl.topRight, 10);
      expect(rtl.bottomLeft, 20);
    });
  });

  group('Rectangle', () {
    test('has no corners', () {
      final RectangleCorners corners =
          const Rectangle().corners(const Size(10, 10), TextDirection.ltr);
      expect(corners.topLeft, 0);
      expect(corners.bottomLeft, 0);
    });
  });

  group('GlassShapeBorder', () {
    test('produces the shape outline shifted to the rect', () {
      const GlassShapeBorder border = GlassShapeBorder(RoundedRectangle(16));
      final Rect rect = const Offset(30, 40) & const Size(100, 60);
      final Rect bounds =
          border.getOuterPath(rect, textDirection: TextDirection.ltr).getBounds();
      expect(bounds.left, closeTo(30, 0.5));
      expect(bounds.top, closeTo(40, 0.5));
    });
  });
}
