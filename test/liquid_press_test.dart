import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _capsule = Size(160, 48);

LiquidPressDeformation _press({
  Size size = _capsule,
  Offset offset = Offset.zero,
  double progress = 0.0,
}) => LiquidPressDeformation.resolve(
  size,
  offset: offset,
  pressProgress: progress,
);

void main() {
  test('an untouched element is not moved', () {
    expect(_press(), LiquidPressDeformation.none);
    expect(_press().isIdentity, isTrue);
  });

  test('a zero-sized element is not moved', () {
    expect(
      _press(size: Size.zero, offset: const Offset(40, 0), progress: 1.0),
      LiquidPressDeformation.none,
    );
  });

  test('holding it swells it by 4px of its height, on both axes', () {
    final LiquidPressDeformation held = _press(progress: 1.0);
    expect(held.scaleX, closeTo(1 + 4 / 48, 1e-9));
    expect(held.scaleY, closeTo(1 + 4 / 48, 1e-9));
    expect(held.translationX, 0.0);
    expect(held.translationY, 0.0);
  });

  test('the swell tracks the press progress', () {
    expect(_press(progress: 0.5).scaleY, closeTo(1 + 2 / 48, 1e-9));
  });

  test('it leans towards the finger, and tanh bounds the lean', () {
    final LiquidPressDeformation near = _press(
      offset: const Offset(20, 0),
      progress: 1.0,
    );
    expect(near.translationX, greaterThan(0.5));
    expect(
      near.translationX,
      lessThan(20.0),
      reason: 'it leans towards the pointer, it does not chase it',
    );

    // Off the end of the world: the lean can never exceed the short side.
    final LiquidPressDeformation far = _press(
      offset: const Offset(100000, 0),
      progress: 1.0,
    );
    expect(far.translationX, lessThanOrEqualTo(_capsule.shortestSide));
    expect(far.translationX, greaterThan(near.translationX));
  });

  test('the lean is signed, and each axis is its own', () {
    final LiquidPressDeformation up = _press(
      offset: const Offset(-20, -30),
      progress: 1.0,
    );
    expect(up.translationX, lessThan(0));
    expect(up.translationY, lessThan(0));
  });

  test('a horizontal drag stretches across, not down', () {
    final LiquidPressDeformation held = _press(progress: 1.0);
    final LiquidPressDeformation pulled = _press(
      offset: const Offset(60, 0),
      progress: 1.0,
    );
    expect(pulled.scaleX, greaterThan(held.scaleX));
    expect(pulled.scaleY, closeTo(held.scaleY, 1e-9));
  });

  test('a vertical drag stretches down, not across', () {
    final LiquidPressDeformation held = _press(progress: 1.0);
    final LiquidPressDeformation pulled = _press(
      offset: const Offset(0, 60),
      progress: 1.0,
    );
    expect(pulled.scaleY, greaterThan(held.scaleY));
    expect(pulled.scaleX, closeTo(held.scaleX, 1e-9));
  });

  test(
    'the matrix is the four numbers, scaled about the centre by Transform',
    () {
      final LiquidPressDeformation press = _press(
        offset: const Offset(24, 8),
        progress: 1.0,
      );
      final Matrix4 matrix = press.transform;

      expect(matrix.getTranslation().x, closeTo(press.translationX, 1e-9));
      expect(matrix.getTranslation().y, closeTo(press.translationY, 1e-9));
      // No pivot baked in: `Transform(alignment: Alignment.center)` supplies it,
      // which is what lets the same numbers drive a widget and a glass layer.
      expect(matrix.entry(0, 0), closeTo(press.scaleX, 1e-9));
      expect(matrix.entry(1, 1), closeTo(press.scaleY, 1e-9));
    },
  );

  test('value equality, so a repaint can be skipped', () {
    expect(_press(progress: 0.4), _press(progress: 0.4));
    expect(_press(progress: 0.4).hashCode, _press(progress: 0.4).hashCode);
    expect(_press(progress: 0.4), isNot(_press(progress: 0.6)));
  });
}
