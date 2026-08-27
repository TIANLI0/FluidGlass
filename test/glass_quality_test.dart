import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the tier each glass element resolved to when it painted.
class _Probe extends StatelessWidget {
  const _Probe({required this.sink, this.quality});

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
        scope
          ..blur(8)
          ..lens(20, 28);
      },
      child: const SizedBox(width: 80, height: 40),
    );
  }
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(child: child),
      ),
    );

GlassDeviceInfo _info({
  bool shaders = true,
  int cores = 8,
  String arch = 'arm64',
}) {
  return GlassDeviceInfo(
    supportsRuntimeShaders: shaders,
    processorCount: cores,
    architecture: arch,
    platform: 'android',
    platformVersion: '',
    devicePixelRatio: 3.0,
    physicalSize: const Size(1080, 2400),
    refreshRate: 120,
  );
}

void main() {
  setUp(() => GlassDeviceTier.instance.reset());
  tearDown(() => GlassDeviceTier.instance.reset());

  group('GlassQuality', () {
    test('there are exactly two tiers, cheapest last', () {
      expect(GlassQuality.values,
          <GlassQuality>[GlassQuality.liquid, GlassQuality.plain]);
      expect(GlassQuality.liquid.index, lessThan(GlassQuality.plain.index));
    });

    test('liquid refracts and shades its rim; plain does neither', () {
      expect(GlassQuality.liquid.hasRefraction, isTrue);
      expect(GlassQuality.liquid.hasShadedRim, isTrue);
      expect(GlassQuality.plain.hasRefraction, isFalse);
      expect(GlassQuality.plain.hasShadedRim, isFalse);
    });

    test('atMost takes the cheaper of the two', () {
      expect(
          GlassQuality.liquid.atMost(GlassQuality.plain), GlassQuality.plain);
      expect(
          GlassQuality.plain.atMost(GlassQuality.liquid), GlassQuality.plain);
      expect(
          GlassQuality.liquid.atMost(GlassQuality.liquid), GlassQuality.liquid);
    });
  });

  group('the built-in classification', () {
    GlassQuality classify(GlassDeviceInfo info) =>
        GlassDeviceTier.classifyDevice(info);

    test('a modern 64-bit device with shaders gets liquid glass', () {
      expect(classify(_info()), GlassQuality.liquid);
    });

    test('no runtime shaders means plain, whatever else is true', () {
      expect(classify(_info(shaders: false, cores: 16)), GlassQuality.plain);
    });

    test('a 32-bit process gets plain', () {
      expect(classify(_info(arch: 'arm')), GlassQuality.plain);
      expect(classify(_info(arch: 'ia32')), GlassQuality.plain);
    });

    test('too few cores gets plain', () {
      expect(classify(_info(cores: 4)), GlassQuality.plain);
      expect(
          classify(
              _info(cores: GlassDeviceTier.minimumProcessorCount - 1)),
          GlassQuality.plain);
      expect(classify(_info(cores: GlassDeviceTier.minimumProcessorCount)),
          GlassQuality.liquid);
    });

    test('an unknown core count is not held against the device', () {
      // Zero means the platform would not say — the web stub, for one. Reading
      // that as "slow" would downgrade every such build silently.
      expect(classify(_info(cores: 0)), GlassQuality.liquid);
    });

    test('an unknown architecture is not held against the device', () {
      expect(classify(_info(arch: '')), GlassQuality.liquid);
    });
  });

  group('GlassDeviceTier', () {
    GlassDeviceTier tier({GlassDeviceInfo? info}) {
      final GlassDeviceTier t = GlassDeviceTier()
        ..debugCeiling = GlassQuality.liquid
        ..debugInfo = info ?? _info();
      addTearDown(t.dispose);
      return t;
    }

    test('classifies from the device, with no sampling', () {
      expect(tier().quality, GlassQuality.liquid);
      expect(tier(info: _info(cores: 2)).quality, GlassQuality.plain);
    });

    test('the answer is available immediately, with no frames at all', () {
      // The whole point of classifying rather than measuring: nothing has to
      // have rendered yet.
      final GlassDeviceTier t = tier();
      expect(t.deviceQuality, isNotNull);
      expect(t.quality, GlassQuality.liquid);
    });

    test('a pin beats the classification and notifies', () {
      final GlassDeviceTier t = tier();
      int notifications = 0;
      t.addListener(() => notifications++);
      t.pinnedQuality = GlassQuality.plain;
      expect(t.quality, GlassQuality.plain);
      expect(notifications, 1);
      t.pinnedQuality = null;
      expect(t.quality, GlassQuality.liquid);
      expect(notifications, 2);
    });

    test('a pin that changes nothing notifies nobody', () {
      final GlassDeviceTier t = tier();
      int notifications = 0;
      t.addListener(() => notifications++);
      t.pinnedQuality = GlassQuality.liquid;
      expect(notifications, 0, reason: 'already drawing at liquid');
    });

    test('a custom classifier replaces the decision and takes effect at once',
        () {
      final GlassDeviceTier t = tier();
      expect(t.quality, GlassQuality.liquid);
      int notifications = 0;
      t.addListener(() => notifications++);
      t.classifier = (GlassDeviceInfo info) => GlassQuality.plain;
      expect(t.quality, GlassQuality.plain);
      expect(notifications, 1);
    });

    test('a custom classifier sees the real device facts', () {
      GlassDeviceInfo? seen;
      final GlassDeviceTier t = tier(info: _info(cores: 3, arch: 'arm'));
      t.classifier = (GlassDeviceInfo info) {
        seen = info;
        return GlassQuality.liquid;
      };
      expect(t.quality, GlassQuality.liquid,
          reason: 'a classifier may overrule what the built-in rules say');
      expect(seen!.processorCount, 3);
      expect(seen!.architecture, 'arm');
    });

    test('the backend ceiling clamps the classification and any pin', () {
      final GlassDeviceTier t = tier()..debugCeiling = GlassQuality.plain;
      expect(t.deviceQuality, GlassQuality.liquid,
          reason: 'the device itself is capable');
      expect(t.quality, GlassQuality.plain,
          reason: 'but this backend has no runtime shaders');
      t.pinnedQuality = GlassQuality.liquid;
      expect(t.quality, GlassQuality.plain,
          reason: 'pinning cannot conjure a shader the backend has not got');
    });

    test('describe explains the verdict', () {
      expect(tier().describe(), contains('liquid'));
      expect(tier(info: _info(shaders: false)).describe(),
          contains('no runtime shaders'));
      expect(tier(info: _info(arch: 'arm')).describe(), contains('32-bit'));
      expect(tier(info: _info(cores: 2)).describe(), contains('cores'));
      final GlassDeviceTier pinned = tier()
        ..pinnedQuality = GlassQuality.plain;
      expect(pinned.describe(), contains('pinned'));
    });

    test('fill demand is reported but deliberately unused', () {
      final GlassDeviceInfo info = _info();
      // 1080 x 2400 at 120 Hz.
      expect(info.fillDemandMegapixelsPerSecond, closeTo(311.04, 0.01));
      expect(GlassDeviceTier.classifyDevice(info), GlassQuality.liquid,
          reason: 'a big high-refresh screen usually means a fast device, so '
              'judging by demand would downgrade exactly the wrong ones');
    });
  });

  group('resolution', () {
    testWidgets('an element follows the device tier by default',
        (WidgetTester tester) async {
      final GlassDeviceTier t = GlassDeviceTier()
        ..debugCeiling = GlassQuality.liquid
        ..debugInfo = _info();
      GlassDeviceTier.instance = t;
      addTearDown(() {
        GlassDeviceTier.instance = GlassDeviceTier();
        t.dispose();
      });

      final List<GlassQuality> seen = <GlassQuality>[];
      await tester.pumpWidget(_host(_Probe(sink: seen)));
      expect(seen.last, GlassQuality.liquid);

      // A change has to reach the paint without any rebuild.
      seen.clear();
      t.pinnedQuality = GlassQuality.plain;
      await tester.pump();
      expect(seen, isNotEmpty,
          reason: 'changing the tier must repaint the element');
      expect(seen.last, GlassQuality.plain);
    });

    testWidgets('a scope overrides the device tier', (WidgetTester tester) async {
      final List<GlassQuality> seen = <GlassQuality>[];
      await tester.pumpWidget(_host(
        GlassQualityScope(
          quality: GlassQuality.plain,
          child: _Probe(sink: seen),
        ),
      ));
      expect(seen.last, GlassQuality.plain);
    });

    testWidgets('the element itself wins over the scope',
        (WidgetTester tester) async {
      final List<GlassQuality> seen = <GlassQuality>[];
      await tester.pumpWidget(_host(
        GlassQualityScope(
          quality: GlassQuality.plain,
          child: _Probe(sink: seen, quality: GlassQuality.liquid),
        ),
      ));
      expect(seen.last,
          GlassQuality.liquid.atMost(GlassDeviceTier.instance.ceiling));
    });

    testWidgets('a scope change repaints the elements under it',
        (WidgetTester tester) async {
      final List<GlassQuality> seen = <GlassQuality>[];
      Widget build(GlassQuality quality) => _host(
            GlassQualityScope(
              quality: quality,
              child: _Probe(sink: seen),
            ),
          );

      await tester.pumpWidget(build(GlassQuality.plain));
      seen.clear();
      await tester.pumpWidget(build(GlassQuality.liquid));
      expect(seen.last,
          GlassQuality.liquid.atMost(GlassDeviceTier.instance.ceiling));
    });
  });

  group('the plain tier runs no fragment programs', () {
    // The tier's contract is not "fewer shaders", it is *none*: the lens, the
    // rim's directional shading and the glow under a finger all fall back to a
    // flat fill. The glow was the one that leaked — it was gated on whether the
    // program had loaded, never on the tier, so a device that gave up the
    // refraction to keep its frame budget still paid a shader pass on every
    // press.
    testWidgets('no paint carries a shader, pressed or not',
        (WidgetTester tester) async {
      final GlassDeviceTier t = GlassDeviceTier.instance
        ..debugCeiling = GlassQuality.liquid
        ..pinnedQuality = GlassQuality.plain;
      addTearDown(t.reset);

      final LayerBackdrop backdrop = LayerBackdrop();
      addTearDown(backdrop.dispose);

      await tester.pumpWidget(_host(
        SizedBox(
          height: 56,
          child: LiquidButton(
            onPressed: () {},
            backdrop: backdrop,
            children: const <Widget>[Text('press me')],
          ),
        ),
      ));
      await tester.pump();

      // Hold the press so the glow is at full strength.
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('press me')));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byType(LiquidButton),
        paints..everything((Symbol method, List<dynamic> arguments) {
          for (final dynamic argument in arguments) {
            if (argument is Paint && argument.shader != null) {
              throw 'a $method on the plain tier used a Paint with a shader';
            }
          }
          return true;
        }),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
