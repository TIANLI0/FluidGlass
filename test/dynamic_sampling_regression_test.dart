import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/backdrops/layer_backdrop.dart'
    show PictureBackdropSource;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _scene = Key('scene');
const Size _size = Size(400, 800);

Widget _frame(LayerBackdrop backdrop, Widget background, List<Widget> glass) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: _scene,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(backdrop: backdrop, child: background),
              ),
              ...glass,
            ],
          ),
        ),
      ),
    );

Widget _glass(LayerBackdrop backdrop, double top, {Listenable? repaint}) =>
    Positioned(
      top: top,
      left: 0,
      right: 0,
      child: DrawBackdrop.plain(
        backdrop: backdrop,
        shape: () => const Rectangle(),
        effects: (BackdropEffectScope scope) {},
        repaint: repaint,
        child: const SizedBox(height: 40),
      ),
    );

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_scene),
  );
  final ui.Image image = boundary.toImageSync();
  try {
    final ByteData? bytes = await tester.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void _configure(WidgetTester tester) {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

RenderBackdropLayer _source(WidgetTester tester) =>
    tester.renderObject(find.byType(BackdropLayer));

void main() {
  setUp(() {
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets(
    'header and footer keep cached pixels during an unrelated animation',
    (WidgetTester tester) async {
      _configure(tester);
      final LayerBackdrop backdrop = LayerBackdrop();
      final ValueNotifier<int> tick = ValueNotifier<int>(0);
      addTearDown(backdrop.dispose);
      addTearDown(tick.dispose);
      await tester.pumpWidget(
        _frame(
          backdrop,
          Column(
            children: <Widget>[
              const SizedBox(height: 300),
              RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: tick,
                  builder: (_, int value, _) => SizedBox(
                    height: 100,
                    width: 400,
                    child: ColoredBox(
                      color: value.isEven ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          <Widget>[
            _glass(backdrop, 0, repaint: tick),
            _glass(backdrop, 760, repaint: tick),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final RenderBackdropLayer source = _source(tester);
      source.debugCaptureCount = 0;
      for (int i = 1; i <= 6; i++) {
        tick.value = i;
        await tester.pump();
        await tester.pump();
      }
      expect(source.debugIgnoredChanges, greaterThanOrEqualTo(6));
      expect(
        source.debugCaptureCount,
        0,
        reason: 'even repainting glass must reuse unaffected captures',
      );
      expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('moving glass never reuses a stale full-source capture', (
    WidgetTester tester,
  ) async {
    _configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    final ValueNotifier<bool> changed = ValueNotifier<bool>(false);
    final ValueNotifier<double> position = ValueNotifier<double>(760);
    addTearDown(backdrop.dispose);
    addTearDown(changed.dispose);
    addTearDown(position.dispose);
    await tester.pumpWidget(
      _frame(
        backdrop,
        Column(
          children: <Widget>[
            const SizedBox(height: 500),
            RepaintBoundary(
              child: ValueListenableBuilder<bool>(
                valueListenable: changed,
                builder: (_, bool value, _) => SizedBox(
                  height: 100,
                  width: 400,
                  child: ColoredBox(color: value ? Colors.blue : Colors.red),
                ),
              ),
            ),
          ],
        ),
        <Widget>[
          _glass(backdrop, 0),
          _glass(backdrop, 100),
          _glass(backdrop, 200),
          ValueListenableBuilder<double>(
            valueListenable: position,
            builder: (_, double top, _) => _glass(backdrop, top),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final RenderBackdropLayer source = _source(tester);
    source.debugCaptureCount = 0;
    changed.value = true;
    await tester.pump();
    await tester.pump();
    expect(
      source.debugCaptureCount,
      0,
      reason: 'changing pixels outside the glass must not capture eagerly',
    );
    position.value = 500;
    await tester.pumpAndSettle();
    expect(
      source.debugCaptureCount,
      greaterThan(0),
      reason: 'the old full-source image is no longer valid here',
    );
    final Uint8List automatic = await _pixels(tester);
    backdrop.invalidateSource();
    await tester.pump();
    expect(automatic, await _pixels(tester));
  });

  testWidgets('many panes share their envelope and shrink after removal', (
    WidgetTester tester,
  ) async {
    _configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    final ValueNotifier<bool> many = ValueNotifier<bool>(true);
    addTearDown(backdrop.dispose);
    addTearDown(many.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: many,
        builder: (_, bool value, _) =>
            _frame(backdrop, const ColoredBox(color: Colors.red), <Widget>[
              _glass(backdrop, 0),
              if (value) ...<Widget>[
                _glass(backdrop, 80),
                _glass(backdrop, 160),
                _glass(backdrop, 240),
              ],
            ]),
      ),
    );
    await tester.pumpAndSettle();
    final RenderBackdropLayer source = _source(tester);
    source.debugCaptureCount = 0;
    for (int i = 0; i < 3; i++) {
      backdrop.invalidateSource();
      await tester.pump();
      expect(
        source.debugLastCaptureRegion,
        const Rect.fromLTWH(0, 0, 400, 280),
      );
      expect(source.debugLastCapturePixelRatio, 1);
    }
    expect(
      source.debugCaptureCount,
      3,
      reason: 'four separated panes should share one capture per update',
    );
    many.value = false;
    await tester.pump();
    for (int i = 0; i < 3; i++) {
      backdrop.invalidateSource();
      await tester.pump();
    }
    expect(
      source.debugLastCaptureRegion,
      const Rect.fromLTWH(0, 0, 400, 40),
      reason: 'removed panes must not leave a permanent large capture',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('exported glass updates its nested consumer in the same frame', (
    WidgetTester tester,
  ) async {
    _configure(tester);
    final LayerBackdrop backdrop = LayerBackdrop();
    final LayerBackdrop exported = LayerBackdrop();
    final ValueNotifier<bool> changed = ValueNotifier<bool>(false);
    addTearDown(backdrop.dispose);
    addTearDown(exported.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      _frame(
        backdrop,
        RepaintBoundary(
          child: ValueListenableBuilder<bool>(
            valueListenable: changed,
            builder: (_, bool value, _) =>
                ColoredBox(color: value ? Colors.blue : Colors.red),
          ),
        ),
        <Widget>[
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            child: DrawBackdrop.plain(
              backdrop: backdrop,
              exportedBackdrop: exported,
              shape: () => const Rectangle(),
              effects: (BackdropEffectScope scope) {},
              child: DrawBackdrop.plain(
                backdrop: exported,
                shape: () => const Rectangle(),
                effects: (BackdropEffectScope scope) {},
                child: const SizedBox(height: 80),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final PictureBackdropSource picture =
        exported.source! as PictureBackdropSource;
    final int before = picture.samplingRevision;
    changed.value = true;
    await tester.pump();
    expect(picture.samplingRevision, greaterThan(before));
    final Uint8List automatic = await _pixels(tester);
    const int center = (240 * 400 + 200) * 4;
    expect(automatic[center + 2], greaterThan(automatic[center]));
    backdrop.invalidateSource();
    await tester.pump();
    expect(automatic, await _pixels(tester));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'composited sampling matches direct blur tint and shadow pixels',
    (WidgetTester tester) async {
      _configure(tester);
      final LayerBackdrop backdrop = LayerBackdrop();
      final LayerBackdrop enclosing = LayerBackdrop();
      addTearDown(backdrop.dispose);
      addTearDown(enclosing.dispose);
      Widget scene() => _frame(
        backdrop,
        Column(
          children: <Widget>[
            for (int i = 0; i < 20; i++)
              Expanded(
                child: ColoredBox(color: i.isEven ? Colors.red : Colors.blue),
              ),
          ],
        ),
        <Widget>[
          Positioned(
            top: 210,
            left: 60,
            width: 280,
            child: DrawBackdrop(
              backdrop: backdrop,
              shape: () => const RoundedRectangle(24),
              effects: (BackdropEffectScope scope) => scope
                ..vibrancy()
                ..blur(8),
              onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
                Offset.zero & size,
                Paint()..color = const Color(0x40FFFFFF),
              ),
              onDrawFront: (Canvas canvas, Size size) => canvas.drawRect(
                const Rect.fromLTWH(20, 20, 40, 20),
                Paint()..color = Colors.green,
              ),
              child: const SizedBox(height: 90),
            ),
          ),
        ],
      );
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      final Uint8List composited = await _pixels(tester);
      // Captured glass retains the direct paint path. The unused outer source
      // changes that path without changing any scene coordinates or effects.
      await tester.pumpWidget(
        BackdropLayer(backdrop: enclosing, child: scene()),
      );
      await tester.pumpAndSettle();
      expect(composited, await _pixels(tester));
    },
  );

  for (final String effect in <String>[
    'image filter',
    'clip path',
    'shader mask',
    'stack order',
    'backdrop filter',
    'follower transform',
  ]) {
    testWidgets('retained children track changing $effect without liveness', (
      WidgetTester tester,
    ) async {
      _configure(tester);
      final LayerBackdrop backdrop = LayerBackdrop();
      final ValueNotifier<bool> changed = ValueNotifier<bool>(false);
      addTearDown(backdrop.dispose);
      addTearDown(changed.dispose);
      final LayerLink link = LayerLink();
      final Widget background = RepaintBoundary(
        child: ValueListenableBuilder<bool>(
          valueListenable: changed,
          child: const RepaintBoundary(child: ColoredBox(color: Colors.red)),
          builder: (_, bool value, Widget? child) {
            switch (effect) {
              case 'backdrop filter':
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const RepaintBoundary(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: ColoredBox(color: Colors.red)),
                          Expanded(child: ColoredBox(color: Colors.blue)),
                        ],
                      ),
                    ),
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: value ? 20 : 1,
                        sigmaY: value ? 20 : 1,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ],
                );
              case 'follower transform':
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CompositedTransformTarget(
                      link: link,
                      child: const SizedBox.expand(),
                    ),
                    CompositedTransformFollower(
                      link: link,
                      offset: Offset(value ? 100 : 0, 0),
                      child: child,
                    ),
                  ],
                );
              case 'stack order':
                const Widget red = RepaintBoundary(
                  key: ValueKey<String>('red'),
                  child: ColoredBox(color: Colors.red),
                );
                const Widget blue = RepaintBoundary(
                  key: ValueKey<String>('blue'),
                  child: ColoredBox(color: Colors.blue),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: value ? <Widget>[blue, red] : <Widget>[red, blue],
                );
              case 'image filter':
                return ImageFiltered(
                  imageFilter: ui.ImageFilter.matrix(
                    Matrix4.translationValues(value ? 100 : 0, 0, 0).storage,
                  ),
                  child: child,
                );
              case 'clip path':
                return ClipPath(
                  clipper: _InsetClipper(value ? 100 : 0),
                  child: child,
                );
              default:
                return ShaderMask(
                  shaderCallback: (Rect bounds) => ui.Gradient.linear(
                    bounds.topLeft,
                    bounds.bottomRight,
                    <Color>[
                      value ? Colors.blue : Colors.green,
                      value ? Colors.blue : Colors.green,
                    ],
                  ),
                  blendMode: BlendMode.srcIn,
                  child: child,
                );
            }
          },
        ),
      );
      await tester.pumpWidget(
        _frame(backdrop, background, <Widget>[_glass(backdrop, 200)]),
      );
      await tester.pumpAndSettle();
      final Uint8List before = await _pixels(tester);
      _source(tester).debugCaptureCount = 0;
      changed.value = true;
      await tester.pump();
      final int capturesThisFrame = _source(tester).debugCaptureCount;
      expect(
        capturesThisFrame,
        greaterThan(0),
        reason: 'the actual frame must sample before a screenshot is requested',
      );
      final Uint8List automatic = await _pixels(tester);
      expect(
        _source(tester).debugCaptureCount,
        capturesThisFrame,
        reason: 'taking a screenshot must not hide a delayed update',
      );
      expect(automatic, isNot(before));
      backdrop.invalidateSource();
      await tester.pump();
      expect(
        automatic,
        await _pixels(tester),
        reason: 'automatic sampling must match an explicitly fresh capture',
      );
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.hasScheduledFrame, isFalse);
    });
  }
}

class _InsetClipper extends CustomClipper<Path> {
  const _InsetClipper(this.inset);
  final double inset;

  @override
  Path getClip(Size size) =>
      Path()..addRect(Rect.fromLTRB(inset, 0, size.width, size.height));

  @override
  bool shouldReclip(_InsetClipper oldClipper) => inset != oldClipper.inset;
}
