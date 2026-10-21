import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion, devicePixelRatio: 2),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SoftTheme(
      data: const SoftThemeData.light(),
      child: Center(child: child),
    ),
  ),
);

void main() {
  usePhoneSurface();

  testWidgets(
    'continuous pointer updates move the surface and rebound past rest',
    (tester) async {
      final SoftTouchMotionState state = SoftTouchMotionState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _host(
          SoftTouchMotion(
            state: state,
            child: const SizedBox(width: 160, height: 80),
          ),
        ),
      );
      final Offset centre = tester.getCenter(find.byType(SoftTouchMotion));
      final TestGesture gesture = await tester.startGesture(centre);
      for (int frame = 1; frame <= 30; frame++) {
        await gesture.moveTo(
          centre + Offset(frame * 4, 0),
          timeStamp: Duration(milliseconds: frame * 16),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.translation.dx, greaterThan(3.5));
      expect(state.scaleX, greaterThan(state.scaleY));
      await gesture.up(timeStamp: const Duration(milliseconds: 500));
      double minimum = 0;
      for (int frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (state.translation.dx < minimum) minimum = state.translation.dx;
      }
      expect(minimum, lessThan(-0.7));
      await tester.pumpAndSettle();
      expect(state.translation.dx, 0);
    },
  );

  testWidgets('light-only feedback does not invalidate surrounding geometry', (
    tester,
  ) async {
    final SoftTouchMotionState state = SoftTouchMotionState();
    addTearDown(state.dispose);
    int geometryChanges = 0;
    state.transformChanges.addListener(() => geometryChanges++);
    await tester.pumpWidget(
      _host(
        SoftTouchMotion(
          state: state,
          pressScale: false,
          followFinger: false,
          light: SoftSpotLightParams.capsule2Light,
          child: const SizedBox(width: 160, height: 80),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SoftTouchMotion)),
    );
    await tester.pumpAndSettle();
    expect(state.lightProgress, 1);
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(geometryChanges, 0);
    expect(state.lightProgress, 0);
  });

  test('spotlight extinguishes towards twice the end radius', () {
    const SoftSpotLightParams params = SoftSpotLightParams.capsule2Light;
    expect(softSpotLightRadius(params, 1, extinguishing: true), 500);
    expect(softSpotLightRadius(params, 0.5, extinguishing: true), 750);
    expect(softSpotLightRadius(params, 0, extinguishing: true), 1000);
    expect(softSpotLightRadius(params, 0.5, extinguishing: false), 300);
    expect(softSpotLightRadius(params, -1, extinguishing: true), 1000);
  });

  test('spotlight presets can override each lighting parameter', () {
    final SoftSpotLightParams params = SoftSpotLightParams.capsule2Light
        .copyWith(
          blendMode: BlendMode.plus,
          startIntensity: 0.1,
          endIntensity: 0.8,
          startRadius: 50,
          endRadius: 700,
          lightHeight: 120,
          ambientStrength: 0.2,
          diffuseStrength: 0.6,
          ditherN: 0,
          noise: 0.05,
        );
    expect(params.blendMode, BlendMode.plus);
    expect(params.startIntensity, 0.1);
    expect(params.endIntensity, 0.8);
    expect(params.startRadius, 50);
    expect(params.endRadius, 700);
    expect(params.lightHeight, 120);
    expect(params.ambientStrength, 0.2);
    expect(params.diffuseStrength, 0.6);
    expect(params.ditherN, 0);
    expect(params.noise, 0.05);
    expect(SoftSpotLightParams.capsule2Light.endRadius, 500);
  });

  testWidgets(
    'press, drag, light diffusion and release share observable state',
    (tester) async {
      final SoftTouchMotionState state = SoftTouchMotionState();
      addTearDown(state.dispose);
      final List<bool> presses = <bool>[];
      await tester.pumpWidget(
        _host(
          SoftTouchMotion(
            state: state,
            light: SoftSpotLightParams.capsule2Light,
            onPressedChanged: presses.add,
            child: const SizedBox(width: 160, height: 80),
          ),
        ),
      );
      final Offset centre = tester.getCenter(find.byType(SoftTouchMotion));
      final TestGesture gesture = await tester.startGesture(centre);
      expect(state.pressed, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.lightProgress, greaterThan(0.9));
      expect(state.scaleX, lessThan(1));
      await gesture.moveBy(const Offset(50, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.translation.dx, greaterThan(0));
      expect(state.lightPosition.dx, greaterThan(0.5));
      await gesture.up();
      expect(state.pressed, isFalse);
      expect(state.extinguishing, isTrue);
      await tester.pumpAndSettle();
      expect(state.translation.distance, closeTo(0, 0.01));
      expect(state.scaleX, closeTo(1, 0.001));
      expect(state.lightProgress, 0);
      expect(presses, <bool>[true, false]);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'reduced motion retains light feedback without moving the surface',
    (tester) async {
      final SoftTouchMotionState state = SoftTouchMotionState();
      addTearDown(state.dispose);
      Widget surface() => SoftTouchMotion(
        state: state,
        light: SoftSpotLightParams.capsule2Light,
        child: const SizedBox(width: 160, height: 80),
      );
      await tester.pumpWidget(_host(surface(), reduceMotion: true));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SoftTouchMotion)),
      );
      await gesture.moveBy(const Offset(50, 10));
      await tester.pump();
      expect(state.pressed, isTrue);
      expect(state.lightProgress, 1);
      expect(state.lightPosition.dx, greaterThan(0.5));
      expect(state.translation, Offset.zero);
      expect(state.scaleX, 1);
      expect(state.scaleY, 1);
      await gesture.up();
      await tester.pump();
      expect(state.lightProgress, 0);
      expect(state.pressed, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('turning reduced motion on stops an in-flight drag', (
    tester,
  ) async {
    final SoftTouchMotionState state = SoftTouchMotionState();
    addTearDown(state.dispose);
    final Widget surface = SoftTouchMotion(
      state: state,
      child: const SizedBox(width: 160, height: 80),
    );
    await tester.pumpWidget(_host(surface));
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SoftTouchMotion)),
    );
    await gesture.moveBy(const Offset(50, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(state.translation.dx, greaterThan(0));
    await tester.pumpWidget(_host(surface, reduceMotion: true));
    expect(state.translation, Offset.zero);
    expect(state.scaleX, 1);
    expect(state.pressed, isTrue);
    await gesture.up();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('secondary mouse buttons do not start touch motion', (
    tester,
  ) async {
    final SoftTouchMotionState state = SoftTouchMotionState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      _host(
        SoftTouchMotion(
          state: state,
          child: const SizedBox(width: 160, height: 80),
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SoftTouchMotion)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(state.pressed, isFalse);
    expect(state.scaleX, 1);
    await gesture.up();
  });

  testWidgets('disabling a pending press cancels delayed feedback', (
    tester,
  ) async {
    final List<bool> presses = <bool>[];
    Widget surface(bool enabled) => SoftPressable(
      enabled: enabled,
      onTap: () {},
      onPressedChanged: presses.add,
      child: const SizedBox(width: 160, height: 80),
    );
    await tester.pumpWidget(_host(surface(true)));
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(SoftPressable)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(_host(surface(false)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(presses, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, isEmpty);
  });
}
