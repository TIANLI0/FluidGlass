import 'dart:math' as math;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// [LiquidAdaptivePanel]: glass that measures the average luminance of what it
/// sits on and retunes its brightness, contrast and blur to stay legible.
///
/// Drag, pinch and rotate the slab over the wallpaper — the reading, the tuning
/// and the colour of the label on it all follow. The measuring is the
/// component's ([BackdropLuminance] underneath); the gesture state below is
/// this page's, handed over as [LiquidAdaptivePanel.layerBlock].
class AdaptiveLuminanceGlassContent extends StatefulWidget {
  const AdaptiveLuminanceGlassContent({super.key});

  @override
  State<AdaptiveLuminanceGlassContent> createState() =>
      _AdaptiveLuminanceGlassContentState();
}

class _AdaptiveLuminanceGlassContentState
    extends State<AdaptiveLuminanceGlassContent>
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
  late final Listenable _gestureRepaint = Listenable.merge(<Listenable>[
    _offsetAnimation,
    _zoomAnimation,
    _rotationAnimation,
  ]);

  double _previousScale = 1;
  double _previousRotation = 0;

  @override
  void dispose() {
    _offsetAnimation.dispose();
    _zoomAnimation.dispose();
    _rotationAnimation.dispose();
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
          LiquidAdaptivePanel(
            backdrop: backdrop,
            layerBlock: _layerBlock,
            repaint: _gestureRepaint,
            builder: (BuildContext context, Color contentColor) {
              // The gestures live inside the glass so panning the slab carries
              // its touch target along.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Center(
                    child: Text(
                      'adaptive glass',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: contentColor, fontSize: 16),
                    ),
                  ),
                ),
              );
            },
          ),
        ];
      },
    );
  }
}
