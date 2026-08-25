import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Offset _apply(Matrix4 matrix, Offset point) => MatrixUtils.transformPoint(matrix, point);

void main() {
  group('GlassLayer', () {
    test('is the identity when untouched', () {
      final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
      expect(layer.hasTransform, isFalse);
      expect(layer.isIdentity, isTrue);
    });

    test('scales about the centre by default', () {
      final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
      layer.scaleX = 2;
      layer.scaleY = 2;
      final Matrix4 matrix = layer.toMatrix();
      // The centre is a fixed point.
      final Offset centre = _apply(matrix, const Offset(50, 25));
      expect(centre.dx, closeTo(50, 1e-6));
      expect(centre.dy, closeTo(25, 1e-6));
      // The top-left moves out by half the growth.
      final Offset topLeft = _apply(matrix, Offset.zero);
      expect(topLeft.dx, closeTo(-50, 1e-6));
      expect(topLeft.dy, closeTo(-25, 1e-6));
    });

    test('honours a custom transform origin', () {
      final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
      layer.scaleX = 2;
      layer.scaleY = 2;
      layer.transformOrigin = Offset.zero;
      final Offset topLeft = _apply(layer.toMatrix(), Offset.zero);
      expect(topLeft.dx, closeTo(0, 1e-6));
      expect(topLeft.dy, closeTo(0, 1e-6));
    });

    test('applies translation after the pivoted scale', () {
      final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
      layer.scaleX = 2;
      layer.translationX = 10;
      final Offset centre = _apply(layer.toMatrix(), const Offset(50, 25));
      expect(centre.dx, closeTo(60, 1e-6));
    });

    test('rotates clockwise on screen for a positive angle', () {
      final GlassLayer layer = GlassLayer()..reset(const Size(100, 100));
      layer.rotationZ = 90;
      // (100, 50) is to the right of the centre; a clockwise quarter turn puts
      // it below the centre.
      final Offset rotated = _apply(layer.toMatrix(), const Offset(100, 50));
      expect(rotated.dx, closeTo(50, 1e-6));
      expect(rotated.dy, closeTo(100, 1e-6));
    });

    group('inverseLinearTransformAtTopLeft', () {
      test('is null when there is nothing to undo', () {
        final GlassLayer layer = GlassLayer()..reset(const Size(10, 10));
        expect(layer.inverseLinearTransformAtTopLeft(), isNull);
        layer.translationX = 20;
        expect(layer.inverseLinearTransformAtTopLeft(), isNull,
            reason: 'translation is handled by the element position');
      });

      test('undoes a scale about the origin', () {
        final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
        layer.scaleX = 2;
        layer.scaleY = 4;
        final Offset point =
            _apply(layer.inverseLinearTransformAtTopLeft()!, const Offset(20, 20));
        expect(point.dx, closeTo(10, 1e-6));
        expect(point.dy, closeTo(5, 1e-6));
      });

      test('inverts the rotation and scale together', () {
        final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
        layer.scaleX = 2;
        layer.scaleY = 3;
        layer.rotationZ = 30;

        // Forward linear part: rotate(theta) * scale.
        final double radians = 30 * math.pi / 180;
        final Matrix4 forward = Matrix4.identity()
          ..rotateZ(radians)
          ..scaleByDouble(2, 3, 1, 1);

        const Offset point = Offset(7, -11);
        final Offset roundTrip =
            _apply(layer.inverseLinearTransformAtTopLeft()!, _apply(forward, point));
        expect(roundTrip.dx, closeTo(point.dx, 1e-6));
        expect(roundTrip.dy, closeTo(point.dy, 1e-6));
      });

      test('gives up on a degenerate scale', () {
        final GlassLayer layer = GlassLayer()..reset(const Size(100, 50));
        layer.scaleX = 0;
        expect(layer.inverseLinearTransformAtTopLeft(), isNull);
      });
    });
  });
}
