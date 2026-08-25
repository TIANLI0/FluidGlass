import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

BackdropEffectScope _scope({Size size = const Size(200, 100)}) {
  return BackdropEffectScope()
    ..beginUpdate(
      size: size,
      textDirection: TextDirection.ltr,
      shape: const RoundedRectangle(24),
    );
}

void main() {
  group('blurRadiusToSigma', () {
    test('matches Skia ConvertRadiusToSigma', () {
      expect(blurRadiusToSigma(0), 0);
      expect(blurRadiusToSigma(-4), 0);
      expect(blurRadiusToSigma(10), closeTo(0.57735 * 10 + 0.5, 1e-9));
    });
  });

  group('blur padding', () {
    test('a leading clamped blur needs no padding', () {
      final BackdropEffectScope scope = _scope()..blur(8);
      expect(scope.padding, 0);
    });

    test('a blur after another effect reserves padding', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(8);
      expect(scope.padding, 8);
    });

    test('a decal blur reserves padding even when leading', () {
      final BackdropEffectScope scope = _scope()
        ..blur(6, edgeTreatment: TileMode.decal);
      expect(scope.padding, 6);
    });

    test('padding only ever grows', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(12)
        ..blur(4);
      expect(scope.padding, 12);
    });

    test('a zero radius is a no-op', () {
      final BackdropEffectScope scope = _scope()..blur(0);
      expect(scope.hasEffects, isFalse);
    });
  });

  group('lens', () {
    // lens() returns before touching padding when runtime shaders are
    // unavailable, so these assert both branches.
    test('hands back the padding a blur reserved', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(30)
        ..lens(16, 32);
      expect(scope.padding, isRuntimeShaderSupported() ? 14 : 30);
    });

    test('never drives padding negative', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(8)
        ..lens(16, 32);
      expect(scope.padding, isRuntimeShaderSupported() ? 0 : 8);
    });

    test('is a no-op for non-positive parameters', () {
      expect((_scope()..lens(0, 32)).hasEffects, isFalse);
      expect((_scope()..lens(16, 0)).hasEffects, isFalse);
    });

    test('adds a stage only where runtime shaders exist', () {
      final BackdropEffectScope scope = _scope()..lens(16, 32);
      expect(scope.hasEffects, isRuntimeShaderSupported());
    });
  });

  group('colorControls', () {
    test('is a no-op at its identity values', () {
      final BackdropEffectScope scope = _scope()..colorControls();
      expect(scope.hasEffects, isFalse);
    });

    test('builds the saturation colour matrix', () {
      // saturation 1.5, no brightness or contrast change.
      const double saturation = 1.5;
      final ui.ColorFilter filter =
          colorControlsColorFilter(saturation: saturation);
      const double invSat = 1 - saturation;
      final String expected = ui.ColorFilter.matrix(<double>[
        0.213 * invSat + saturation, 0.715 * invSat, 0.072 * invSat, 0, 0, //
        0.213 * invSat, 0.715 * invSat + saturation, 0.072 * invSat, 0, 0, //
        0.213 * invSat, 0.715 * invSat, 0.072 * invSat + saturation, 0, 0, //
        0, 0, 0, 1, 0, //
      ]).toString();
      expect(filter.toString(), expected);
    });

    test('brightness and contrast land in the translation column', () {
      // t = (0.5 - c * 0.5 + brightness) * 255
      final ui.ColorFilter filter =
          colorControlsColorFilter(brightness: 0.2, contrast: 0.5);
      expect(filter.toString(), contains('${(0.5 - 0.25 + 0.2) * 255.0}'));
    });
  });

  group('effect chain', () {
    test('merges consecutive non-shader filters into one stage', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(4);
      expect(scope.resolve().length, 1);
    });

    test('keeps stages in the order they were declared', () {
      final BackdropEffectScope scope = _scope()
        ..vibrancy()
        ..blur(4)
        ..imageFilterEffect(ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1));
      expect(scope.resolve().length, 1);
    });
  });

  group('BackdropEffectGeometry', () {
    test('derives the padded layer from the element', () {
      const BackdropEffectGeometry geometry =
          BackdropEffectGeometry(size: Size(100, 60), padding: 8);
      expect(geometry.layerSize, const Size(116, 76));
      expect(geometry.offset, const Offset(-8, -8));
    });
  });
}
