import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/spring.dart';

/// Glass that measures the average luminance of what it sits on and retunes its
/// brightness, contrast and blur to stay legible.
class AdaptiveLuminanceGlassContent extends StatefulWidget {
  const AdaptiveLuminanceGlassContent({super.key});

  @override
  State<AdaptiveLuminanceGlassContent> createState() =>
      _AdaptiveLuminanceGlassContentState();
}

class _AdaptiveLuminanceGlassContentState
    extends State<AdaptiveLuminanceGlassContent>
    with TickerProviderStateMixin {
  static const int _thumbnail = 5;

  late final SpringValue _luminanceAnimation;
  late final TweenColor _contentColorAnimation;

  late final SpringOffset _offsetAnimation = SpringOffset(
    vsync: this,
    value: Offset.zero,
  );
  late final SpringValue _zoomAnimation = SpringValue(
    vsync: this,
    value: 1,
    visibilityThreshold: 0.001,
  );
  late final SpringValue _rotationAnimation = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.01,
  );
  late final Listenable _repaint;

  ui.Picture? _thumbPicture;
  /// Set by the sampling loop so the paint pass records one thumbnail per
  /// sample rather than one per frame.
  bool _wantsThumbnail = true;
  bool _running = true;
  double _previousScale = 1;
  double _previousRotation = 0;

  @override
  void initState() {
    super.initState();
    final bool isLight =
        MediaQueryData.fromView(
          WidgetsBinding.instance.platformDispatcher.views.first,
        ).platformBrightness ==
        Brightness.light;
    _luminanceAnimation = SpringValue(
      vsync: this,
      value: isLight ? 1 : 0,
      visibilityThreshold: 0.001,
    );
    _contentColorAnimation = TweenColor(
      vsync: this,
      value: isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    );
    _repaint = Listenable.merge(<Listenable>[
      _luminanceAnimation,
      _offsetAnimation,
      _zoomAnimation,
      _rotationAnimation,
    ]);
    unawaited(_luminanceLoop());
  }

  @override
  void dispose() {
    _running = false;
    _thumbPicture?.dispose();
    _luminanceAnimation.dispose();
    _contentColorAnimation.dispose();
    _offsetAnimation.dispose();
    _zoomAnimation.dispose();
    _rotationAnimation.dispose();
    super.dispose();
  }

  Future<void> _luminanceLoop() async {
    while (_running) {
      await _measureLuminance();
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }
  }

  Future<void> _measureLuminance() async {
    final ui.Picture? picture = _thumbPicture;
    if (picture == null) {
      _wantsThumbnail = true;
      return;
    }
    final ui.Image image = picture.toImageSync(_thumbnail, _thumbnail);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (bytes == null || !_running) return;

    final Uint8List data = bytes.buffer.asUint8List();
    double sum = 0;
    final int count = _thumbnail * _thumbnail;
    for (int i = 0; i < count; i++) {
      final double r = data[i * 4] / 255.0;
      final double g = data[i * 4 + 1] / 255.0;
      final double b = data[i * 4 + 2] / 255.0;
      sum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }
    final double average = sum / count;

    _contentColorAnimation.animateTo(
      average > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      const Duration(milliseconds: 1000),
    );
    _luminanceAnimation.tweenTo(average, const Duration(milliseconds: 1000));
    _wantsThumbnail = true;
  }

  /// Draws the backdrop, then records a 5x5 thumbnail of it for the loop above.
  void _onDrawBackdrop(
    BackdropDrawContext context,
    void Function() drawBackdrop,
  ) {
    drawBackdrop();

    if (!_wantsThumbnail || context.size.isEmpty) return;
    _wantsThumbnail = false;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(
      _thumbnail / context.size.width,
      _thumbnail / context.size.height,
    );
    context.backdrop.drawBackdrop(context.copyWith(canvas: canvas));
    _thumbPicture?.dispose();
    _thumbPicture = recorder.endRecording();
  }

  static Offset _rotateBy(Offset offset, double degrees) {
    final double radians = degrees * math.pi / 180.0;
    final double cos = math.cos(radians);
    final double sin = math.sin(radians);
    return Offset(
      offset.dx * cos - offset.dy * sin,
      offset.dx * sin + offset.dy * cos,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _previousScale = 1;
    _previousRotation = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final double gestureZoom = _previousScale == 0
        ? 1
        : details.scale / _previousScale;
    final double gestureRotate =
        (details.rotation - _previousRotation) * 180.0 / math.pi;
    _previousScale = details.scale;
    _previousRotation = details.rotation;

    final double targetZoom = _zoomAnimation.value * gestureZoom;
    final double targetRotation = _rotationAnimation.value + gestureRotate;
    final Offset targetOffset =
        _offsetAnimation.value +
        _rotateBy(details.focalPointDelta, targetRotation) * targetZoom;

    _offsetAnimation.snapTo(targetOffset);
    _zoomAnimation.snapTo(targetZoom);
    _rotationAnimation.snapTo(targetRotation);
  }

  void _layerBlock(GlassLayer layer) {
    final Offset offset = _offsetAnimation.value;
    layer.translationX = offset.dx;
    layer.translationY = offset.dy;
    layer.scaleX = _zoomAnimation.value;
    layer.scaleY = _zoomAnimation.value;
    layer.rotationZ = _rotationAnimation.value;
    layer.transformOrigin = const Offset(0.5, 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          // The gestures live inside the glass so panning the slab carries its
          // touch target along.
          DrawBackdrop(
            backdrop: backdrop,
            shape: () => const RoundedRectangle(24),
            effects: (BackdropEffectScope scope) {
              final double raw = _luminanceAnimation.value * 2 - 1;
              final double l = raw.sign * raw * raw;
              scope
                ..colorControls(
                  brightness: l > 0 ? _lerp(0.1, 0.5, l) : _lerp(0.1, -0.2, -l),
                  contrast: l > 0 ? _lerp(1, 0, l) : 1,
                  saturation: 1.5,
                )
                ..blur(l > 0 ? _lerp(8, 16, l) : _lerp(8, 2, -l))
                ..lens(24, scope.size.shortestSide / 2, depthEffect: true);
            },
            highlight: () => Highlight.plain,
            layerBlock: _layerBlock,
            onDrawBackdrop: _onDrawBackdrop,
            repaint: _repaint,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _luminanceAnimation,
                      _contentColorAnimation,
                    ]),
                    builder: (BuildContext context, Widget? _) {
                      final double rounded =
                          (_luminanceAnimation.value * 100).round() / 100.0;
                      return Text(
                        'luminance:\n$rounded',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _contentColorAnimation.value,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
