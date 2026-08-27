import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 120;
const int _h = 120;

/// The panel sits in the middle, clear of its own rim and shadow.
const Rect _inside = Rect.fromLTWH(50, 50, 20, 20);

Future<List<double>> _meanRgb(WidgetTester tester, Rect box) async {
  final RenderRepaintBoundary render =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = render.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  final List<double> sum = <double>[0, 0, 0];
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      sum[0] += p[i];
      sum[1] += p[i + 1];
      sum[2] += p[i + 2];
      count += 1;
    }
  }
  return <double>[sum[0] / count, sum[1] / count, sum[2] / count];
}

/// A frame whose boundary really is [_w]x[_h].
///
/// Without the [Align] the [SizedBox] is handed the surface's tight
/// constraints and grows to fill it, and every sampled index below then points
/// at the wrong pixel.
Widget _frame({required Brightness brightness, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Theme(
        data: ThemeData(brightness: brightness),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: _w.toDouble(),
              height: _h.toDouble(),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A panel over a mid-grey source, with [panelBuilder] free to wrap it.
Widget _host({
  Brightness brightness = Brightness.light,
  LiquidGlassColors? colors,
  Color? surfaceColor,
}) {
  final LayerBackdrop backdrop = LayerBackdrop();
  Widget panel = LiquidPanel(
    backdrop: backdrop,
    shape: const Rectangle(),
    showShadow: false,
    surfaceColor: surfaceColor,
    child: const SizedBox(width: 80, height: 80),
  );
  if (colors != null) {
    panel = LiquidGlassTheme(colors: colors, child: panel);
  }
  return _frame(
    brightness: brightness,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(
            backdrop: backdrop,
            child: const ColoredBox(color: Color(0xFF808080)),
          ),
        ),
        Positioned(left: 20, top: 20, child: panel),
      ],
    ),
  );
}

void main() {
  group('LiquidGlassColors', () {
    test('the defaults are the values the components used to inline', () {
      expect(LiquidGlassColors.light.accent, const Color(0xFF0088FF));
      expect(LiquidGlassColors.light.toggleAccent, const Color(0xFF34C759));
      expect(
        LiquidGlassColors.light.container,
        const Color(0xFFFAFAFA).withValues(alpha: 0.4),
      );
      expect(LiquidGlassColors.light.content, const Color(0xFF000000));
      expect(
        LiquidGlassColors.light.track,
        const Color(0xFF787878).withValues(alpha: 0.2),
      );
      expect(LiquidGlassColors.light.destructive, const Color(0xFFE5484D));

      expect(LiquidGlassColors.dark.accent, const Color(0xFF0091FF));
      expect(LiquidGlassColors.dark.toggleAccent, const Color(0xFF30D158));
      expect(
        LiquidGlassColors.dark.container,
        const Color(0xFF121212).withValues(alpha: 0.4),
      );
      expect(LiquidGlassColors.dark.content, const Color(0xFFFFFFFF));
      expect(
        LiquidGlassColors.dark.track,
        const Color(0xFF787880).withValues(alpha: 0.36),
      );
      expect(LiquidGlassColors.dark.destructive, const Color(0xFFFF6369));
    });

    test('forBrightness picks the pair', () {
      expect(
        LiquidGlassColors.forBrightness(Brightness.light),
        LiquidGlassColors.light,
      );
      expect(
        LiquidGlassColors.forBrightness(Brightness.dark),
        LiquidGlassColors.dark,
      );
    });

    test('copyWith replaces one field and keeps the rest', () {
      final LiquidGlassColors themed =
          LiquidGlassColors.light.copyWith(accent: const Color(0xFFD2603A));

      expect(themed.accent, const Color(0xFFD2603A));
      expect(themed.toggleAccent, LiquidGlassColors.light.toggleAccent);
      expect(themed.container, LiquidGlassColors.light.container);
      expect(themed.destructive, LiquidGlassColors.light.destructive);
      expect(themed, isNot(LiquidGlassColors.light));
    });

    test('equality is by value, so a theme only notifies on a real change', () {
      expect(
        LiquidGlassColors.light.copyWith(),
        LiquidGlassColors.light,
      );
      expect(
        LiquidGlassColors.light.copyWith().hashCode,
        LiquidGlassColors.light.hashCode,
      );
    });
  });

  group('LiquidGlassTheme.of', () {
    testWidgets('falls back to the default for the enclosing brightness',
        (WidgetTester tester) async {
      final List<LiquidGlassColors> seen = <LiquidGlassColors>[];
      for (final Brightness brightness in Brightness.values) {
        // A bare Theme, not a MaterialApp: that one wraps the theme in an
        // AnimatedTheme, so the frame right after a brightness change still
        // reads the old one.
        await tester.pumpWidget(
          _frame(
            brightness: brightness,
            child: Builder(
              builder: (BuildContext context) {
                seen.add(LiquidGlassTheme.of(context));
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      expect(seen, <LiquidGlassColors>[
        LiquidGlassColors.dark,
        LiquidGlassColors.light,
      ]);
    });

    testWidgets('returns the supplied palette', (WidgetTester tester) async {
      final LiquidGlassColors themed =
          LiquidGlassColors.light.copyWith(accent: const Color(0xFFD2603A));
      LiquidGlassColors? seen;

      await tester.pumpWidget(
        _frame(
          brightness: Brightness.light,
          child: LiquidGlassTheme(
            colors: themed,
            child: Builder(
              builder: (BuildContext context) {
                seen = LiquidGlassTheme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(seen, themed);
    });
  });

  group('a themed palette reaches what a component paints', () {
    setUp(() => GlassDeviceTier.instance.reset());
    tearDown(() => GlassDeviceTier.instance.reset());

    testWidgets('the panel tints with the theme, not with the default',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();
      final List<double> untinted = await _meanRgb(tester, _inside);

      // Opaque red so the assertion does not depend on how the tint composites.
      await tester.pumpWidget(
        _host(
          colors: LiquidGlassColors.light.copyWith(
            container: const Color(0xFFFF0000),
          ),
        ),
      );
      await tester.pump();
      final List<double> tinted = await _meanRgb(tester, _inside);

      // The default tint is neutral: red and blue land together.
      expect(untinted[0], closeTo(untinted[2], 4));
      expect(tinted[0], greaterThan(200));
      expect(tinted[1], lessThan(40));
      expect(tinted[2], lessThan(40));
    });

    testWidgets('a per-element surfaceColor still wins over the theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          colors: LiquidGlassColors.light.copyWith(
            container: const Color(0xFFFF0000),
          ),
          surfaceColor: const Color(0xFF00FF00),
        ),
      );
      await tester.pump();

      final List<double> rgb = await _meanRgb(tester, _inside);
      expect(rgb[1], greaterThan(200));
      expect(rgb[0], lessThan(40));
    });
  });
}
