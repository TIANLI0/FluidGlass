import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// However cool it looks, a reader who has asked the system for more contrast
// has asked the glass to stand down. Two things answer that, and they are on
// opposite sides of the library, so both are pinned here:
//
//   * the tint goes opaque      (LiquidGlassTheme.of)
//   * the refraction goes away  (DrawBackdrop's resolved tier)
//
// Dropping the refraction is also the cheap path — `plain` hands the chain to
// the compositor instead of capturing the source — so this is the one place
// where legibility and cost ask for the same thing.

/// Records the tier the element actually painted at.
class _TierProbe extends StatelessWidget {
  const _TierProbe({required this.sink, this.quality});

  final List<GlassQuality> sink;
  final GlassQuality? quality;

  @override
  Widget build(BuildContext context) {
    return DrawBackdrop.plain(
      backdrop: emptyBackdrop,
      shape: () => const RoundedRectangle(12),
      quality: quality,
      effects: (BackdropEffectScope scope) {
        sink.add(scope.quality);
        scope.blur(8);
      },
      child: const SizedBox(width: 80, height: 40),
    );
  }
}

Widget _host({required bool highContrast, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(child: child),
      ),
    ),
  );
}

void main() {
  // flutter_test runs on Skia: the backend ceiling is `plain` AND the
  // classifier sees no runtime shaders, so every element lands on `plain`
  // regardless — which would make the tier tests below pass while testing
  // nothing. Both have to be lifted for the accessibility clamp to be visible
  // at all.
  setUp(() {
    GlassDeviceTier.instance
      ..debugCeiling = GlassQuality.liquid
      ..debugInfo = const GlassDeviceInfo(
        supportsRuntimeShaders: true,
        processorCount: 8,
        architecture: 'arm64',
        platform: 'android',
        platformVersion: '',
        devicePixelRatio: 3.0,
        physicalSize: Size(1080, 2400),
        refreshRate: 120,
      );
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('high contrast makes the surface tint opaque', (
    WidgetTester tester,
  ) async {
    late LiquidGlassColors plain;
    late LiquidGlassColors contrast;

    await tester.pumpWidget(
      _host(
        highContrast: false,
        child: Builder(
          builder: (BuildContext context) {
            plain = LiquidGlassTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        highContrast: true,
        child: Builder(
          builder: (BuildContext context) {
            contrast = LiquidGlassTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(plain.container.a, lessThan(1.0), reason: 'glass is translucent');
    expect(
      contrast.container.a,
      1.0,
      reason:
          'a reader asking for contrast should not have legibility '
          'decided by whatever is behind the surface',
    );
    // Only the alpha moves: the app's colour is still the app's colour.
    expect(
      contrast.container.toARGB32() & 0x00FFFFFF,
      plain.container.toARGB32() & 0x00FFFFFF,
    );
    expect(contrast.accent, plain.accent);
  });

  testWidgets('high contrast applies to an app-supplied palette too', (
    WidgetTester tester,
  ) async {
    late LiquidGlassColors seen;
    await tester.pumpWidget(
      _host(
        highContrast: true,
        child: LiquidGlassTheme(
          colors: LiquidGlassColors.light.copyWith(
            container: const Color(0x66FF0000),
          ),
          child: Builder(
            builder: (BuildContext context) {
              seen = LiquidGlassTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen.container.a, 1.0);
    expect(
      seen.container.toARGB32() & 0x00FFFFFF,
      0xFF0000,
      reason: 'the brand hue survives; only the transparency goes',
    );
  });

  testWidgets('high contrast drops the refraction to the plain tier', (
    WidgetTester tester,
  ) async {
    final List<GlassQuality> normal = <GlassQuality>[];
    final List<GlassQuality> contrast = <GlassQuality>[];

    await tester.pumpWidget(
      _host(highContrast: false, child: _TierProbe(sink: normal)),
    );
    await tester.pumpWidget(
      _host(highContrast: true, child: _TierProbe(sink: contrast)),
    );

    expect(
      normal.last,
      GlassQuality.liquid,
      reason:
          'without the flag the element keeps its refraction, or this '
          'test proves nothing',
    );
    expect(contrast.last, GlassQuality.plain);
  });

  testWidgets('an explicitly pinned tier still wins', (
    WidgetTester tester,
  ) async {
    final List<GlassQuality> sink = <GlassQuality>[];
    await tester.pumpWidget(
      _host(
        highContrast: true,
        child: _TierProbe(sink: sink, quality: GlassQuality.liquid),
      ),
    );
    expect(
      sink.last,
      GlassQuality.liquid,
      reason: 'a showcase screen may hold the liquid tier deliberately',
    );
  });
}
