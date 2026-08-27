import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// A slab of glass you can pan, pinch and rotate, over a sheet of sliders that
/// refracts itself.
class GlassPlaygroundContent extends StatefulWidget {
  const GlassPlaygroundContent({super.key});

  @override
  State<GlassPlaygroundContent> createState() => _GlassPlaygroundContentState();
}

class _GlassPlaygroundContentState extends State<GlassPlaygroundContent>
    with TickerProviderStateMixin {
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
  late final Listenable _transformRepaint = Listenable.merge(<Listenable>[
    _offsetAnimation,
    _zoomAnimation,
    _rotationAnimation,
  ]);

  final LayerBackdrop _sheetBackdrop = LayerBackdrop();

  bool _isSheetExpanded = true;

  double _cornerRadiusFrac = 0.5;
  double _blurRadiusDp = 0;
  double _refractionHeightFrac = 0.2;
  double _refractionAmountFrac = 0.2;
  double _chromaticAberration = 0;

  double _previousScale = 1;
  double _previousRotation = 0;

  @override
  void dispose() {
    _offsetAnimation.dispose();
    _zoomAnimation.dispose();
    _rotationAnimation.dispose();
    _sheetBackdrop.dispose();
    super.dispose();
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
    // Compose reports per-event increments; Flutter reports cumulative values.
    final double gestureZoom = _previousScale == 0
        ? 1
        : details.scale / _previousScale;
    final double gestureRotate =
        (details.rotation - _previousRotation) * 180.0 / math.pi;
    _previousScale = details.scale;
    _previousRotation = details.rotation;

    final Offset offset = _offsetAnimation.value;
    final double zoom = _zoomAnimation.value;
    final double rotation = _rotationAnimation.value;

    final double targetZoom = zoom * gestureZoom;
    final double targetRotation = rotation + gestureRotate;
    final Offset targetOffset =
        offset +
        _rotateBy(details.focalPointDelta, targetRotation) * targetZoom;

    _offsetAnimation.snapTo(targetOffset);
    _zoomAnimation.snapTo(targetZoom);
    _rotationAnimation.snapTo(targetRotation);
  }

  void _reset() {
    _offsetAnimation.animateTo(Offset.zero, springOf(1.0, 1500.0));
    _zoomAnimation.animateTo(1, springOf(1.0, 1500.0));
    _rotationAnimation.animateTo(0, springOf(1.0, 1500.0));
    setState(() {
      _cornerRadiusFrac = 0.5;
      _blurRadiusDp = 0;
      _refractionHeightFrac = 0.2;
      _refractionAmountFrac = 0.2;
      _chromaticAberration = 0;
    });
  }

  void _slabLayerBlock(GlassLayer layer) {
    final Offset offset = _offsetAnimation.value;
    layer.translationX = offset.dx;
    layer.translationY = offset.dy;
    layer.scaleX = _zoomAnimation.value;
    layer.scaleY = _zoomAnimation.value;
    layer.rotationZ = _rotationAnimation.value;
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required ({double start, double end}) range,
    required double threshold,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Color(0xFF000000), fontSize: 14),
        ),
        LiquidSlider(
          value: value,
          onValueChanged: onChanged,
          valueRange: range,
          visibilityThreshold: threshold,
          backdrop: _sheetBackdrop,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.paddingOf(context);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          // The padding sits outside the alignment, and the gestures inside the
          // glass, so panning the slab takes its touch target with it: Flutter
          // bounds-checks every ancestor before descending into it.
          Padding(
            padding: EdgeInsets.only(top: 48 + insets.top),
            child: Align(
              alignment: Alignment.topCenter,
              child: DrawBackdrop(
                backdrop: backdrop,
                shape: () => RoundedRectangle(256 / 2 * _cornerRadiusFrac),
                effects: (BackdropEffectScope scope) {
                  final double minDimension = scope.size.shortestSide;
                  scope
                    ..vibrancy()
                    ..blur(_blurRadiusDp)
                    ..lens(
                      _refractionHeightFrac * minDimension * 0.5,
                      _refractionAmountFrac * minDimension,
                      depthEffect: true,
                      chromaticAberration: _chromaticAberration > 0,
                    );
                },
                highlight: () => Highlight.plain,
                layerBlock: _slabLayerBlock,
                repaint: _transformRepaint,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: const SizedBox(width: 256, height: 256),
                ),
              ),
            ),
          ),
          if (_isSheetExpanded)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + 72 + insets.bottom,
                ),
                child: DrawBackdrop(
                  backdrop: backdrop,
                  shape: () => const RoundedRectangle(32),
                  effects: (BackdropEffectScope scope) => scope
                    ..vibrancy()
                    ..blur(4)
                    ..lens(16, 32),
                  highlight: () => Highlight.plain,
                  exportedBackdrop: _sheetBackdrop,
                  onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
                    Offset.zero & size,
                    Paint()
                      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 16,
                      children: <Widget>[
                        _sliderRow(
                          label: 'Corner radius',
                          value: _cornerRadiusFrac,
                          onChanged: (double v) =>
                              setState(() => _cornerRadiusFrac = v),
                          range: (start: 0, end: 1),
                          threshold: 0.001,
                        ),
                        _sliderRow(
                          label: 'Blur radius',
                          value: _blurRadiusDp,
                          onChanged: (double v) =>
                              setState(() => _blurRadiusDp = v),
                          range: (start: 0, end: 32),
                          threshold: 0.01,
                        ),
                        _sliderRow(
                          label: 'Refraction height',
                          value: _refractionHeightFrac,
                          onChanged: (double v) =>
                              setState(() => _refractionHeightFrac = v),
                          range: (start: 0, end: 1),
                          threshold: 0.001,
                        ),
                        _sliderRow(
                          label: 'Refraction amount',
                          value: _refractionAmountFrac,
                          onChanged: (double v) =>
                              setState(() => _refractionAmountFrac = v),
                          range: (start: 0, end: 1),
                          threshold: 0.001,
                        ),
                        _sliderRow(
                          label: 'Chromatic aberration',
                          value: _chromaticAberration,
                          onChanged: (double v) =>
                              setState(() => _chromaticAberration = v),
                          range: (start: 0, end: 1),
                          threshold: 0.001,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + insets.bottom,
              ),
              child: LiquidButton(
                onPressed: () =>
                    setState(() => _isSheetExpanded = !_isSheetExpanded),
                backdrop: backdrop,
                tint: const Color(0xFFFF8D28),
                children: <Widget>[
                  Text(
                    _isSheetExpanded ? '\u{1F53D}' : '\u{1F53C}',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + insets.bottom,
              ),
              child: LiquidButton(
                onPressed: _reset,
                backdrop: backdrop,
                tint: const Color(0xFFFF8D28),
                children: const <Widget>[
                  Text(
                    'Reset',
                    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
    );
  }
}
