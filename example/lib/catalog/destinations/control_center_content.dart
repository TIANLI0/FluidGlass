import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../flight_icon.dart';
import '../utils/progress_converter.dart';
import '../utils/ui_sensor.dart';

/// An iOS-style control centre you drag down into place, every tile a piece of
/// glass lit from the direction of gravity.
class ControlCenterContent extends StatefulWidget {
  const ControlCenterContent({super.key});

  @override
  State<ControlCenterContent> createState() => _ControlCenterContentState();
}

class _ControlCenterContentState extends State<ControlCenterContent>
    with TickerProviderStateMixin {
  static const double _itemSpacing = 16;
  static const double _itemSize = 68;
  static const double _itemTwoSpanSize = _itemSize * 2 + _itemSpacing;
  static const double _innerItemSize = 56;
  static const double _innerItemIconScale = 0.8;
  static const double _maxDragHeight = 1000;

  static const RoundedRectangle _itemShape = RoundedRectangle(_itemSize / 2);
  static const Capsule _innerItemShape = Capsule();

  static const Color _containerColor = Color(0x0D000000); // black, alpha 0.05
  static const Color _dimColor = Color(0x66000000); // black, alpha 0.4
  static const Color _inactiveItemColor = Color(0x33FFFFFF); // white, alpha 0.2

  late final SpringValue _enterProgress =
      SpringValue(vsync: this, value: 1, visibilityThreshold: 0.5 / _maxDragHeight);
  late final SpringValue _safeEnterProgress =
      SpringValue(vsync: this, value: 1, visibilityThreshold: 0.01);
  final UISensor _uiSensor = UISensor();

  late final Listenable _repaint =
      Listenable.merge(<Listenable>[_enterProgress, _safeEnterProgress, _uiSensor]);

  @override
  void initState() {
    super.initState();
    _uiSensor.start();
  }

  @override
  void dispose() {
    _uiSensor.stop();
    _uiSensor.dispose();
    _enterProgress.dispose();
    _safeEnterProgress.dispose();
    super.dispose();
  }

  /// The drag progress, eased past both ends.
  double get _progress {
    final double progress = _enterProgress.value;
    if (progress < 0) return convertProgress(progress);
    if (progress <= 1) return progress;
    return 1 + convertProgress(progress - 1);
  }

  double get _overshoot => math.max(0.0, _progress - 1);

  void _onDragUpdate(DragUpdateDetails details) {
    final double target = _enterProgress.value + details.delta.dy / _maxDragHeight;
    _enterProgress.snapTo(target);
    _safeEnterProgress.snapTo(target.clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double target;
    if (velocity < 0) {
      target = 0;
    } else if (velocity > 0) {
      target = 1;
    } else {
      target = _enterProgress.value < 0.5 ? 0 : 1;
    }
    _enterProgress.animateTo(
      target,
      target > 0.5 ? springOf(0.5, 300.0) : springOf(1.0, 300.0),
      withVelocity: velocity / _maxDragHeight,
    );
    _safeEnterProgress.animateTo(target, springOf(1.0, 300.0));
  }

  void _glassLayer(GlassLayer layer) {
    final double progress = _progress;
    final double safeProgress = _safeEnterProgress.value;
    layer.translationY = -48.0 * (1 - progress);
    layer.alpha = Curves.easeIn.transform(safeProgress.clamp(0.0, 1.0));
    layer.scaleX /= 1 + 0.1 * math.max(0.0, progress - 1);
    layer.scaleY *= 1 + 0.1 * math.max(0.0, progress - 1);
  }

  void _glassEffects(BackdropEffectScope scope) {
    final double progress = _safeEnterProgress.value;
    scope
      ..vibrancy()
      ..lens(24 * progress, 48 * progress, depthEffect: true);
  }

  Highlight _glassHighlight() {
    return Highlight(
      style: DefaultHighlightStyle(angle: _uiSensor.gravityAngle, falloff: 2),
    );
  }

  void _glassSurface(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _containerColor);
  }

  /// One glass tile.
  Widget _tile({
    required Backdrop backdrop,
    required double width,
    required double height,
    bool surface = true,
    Widget? child,
  }) {
    return DrawBackdrop(
      backdrop: backdrop,
      shape: () => _itemShape,
      effects: _glassEffects,
      highlight: _glassHighlight,
      shadow: null,
      layerBlock: _glassLayer,
      onDrawSurface: surface ? _glassSurface : null,
      repaint: _repaint,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _iconTile({required Backdrop backdrop}) {
    return _tile(
      backdrop: backdrop,
      width: _itemSize,
      height: _itemSize,
      child: const FlightIcon(size: _itemSize, color: Color(0xFFFFFFFF)),
    );
  }

  Widget _innerItem(Color color) {
    return ClipPath(
      clipper: const GlassShapeClipper(_innerItemShape),
      child: ColoredBox(
        color: color,
        child: SizedBox(
          width: _innerItemSize,
          height: _innerItemSize,
          child: Transform.scale(
            scale: _innerItemIconScale,
            child: const FlightIcon(size: _innerItemSize, color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }

  Widget _spacer(double extra) {
    return ListenableBuilder(
      listenable: _repaint,
      builder: (BuildContext context, Widget? _) {
        return SizedBox(height: _itemSpacing + extra * _overshoot);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color accentColor =
        isLight ? const Color(0xFF0088FF) : const Color(0xFF0091FF);
    final EdgeInsets insets = MediaQuery.paddingOf(context);

    return BackdropDemoScaffold(
      decorate: (Widget wallpaper) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ListenableBuilder(
          listenable: _repaint,
          builder: (BuildContext context, Widget? _) {
            final double progress = _safeEnterProgress.value.clamp(0.0, 1.0);
            final double sigma = blurRadiusToSigma(
              4 * progress,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            Widget content = wallpaper;
            if (sigma > 0) {
              content = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: content,
              );
            }
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: <Widget>[
                content,
                ColoredBox(color: _dimColor.withValues(alpha: 0.4 * progress)),
              ],
            );
          },
        ),
      ),
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: 80 + insets.top,
                left: insets.left,
                right: insets.right,
                bottom: insets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: _itemSpacing,
                    children: <Widget>[
                      _tile(
                        backdrop: backdrop,
                        width: _itemTwoSpanSize,
                        height: _itemTwoSpanSize,
                        child: Padding(
                          padding: const EdgeInsets.all(_itemSpacing),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Align(
                                alignment: Alignment.topLeft,
                                child: _innerItem(_inactiveItemColor),
                              ),
                              Align(
                                alignment: Alignment.topRight,
                                child: _innerItem(accentColor),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: _innerItem(accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _tile(
                        backdrop: backdrop,
                        width: _itemTwoSpanSize,
                        height: _itemTwoSpanSize,
                      ),
                    ],
                  ),
                  _spacer(32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: _itemSpacing,
                    children: <Widget>[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: _itemSpacing,
                            children: <Widget>[
                              _iconTile(backdrop: backdrop),
                              _iconTile(backdrop: backdrop),
                            ],
                          ),
                          _spacer(16),
                          _tile(
                            backdrop: backdrop,
                            width: _itemTwoSpanSize,
                            height: _itemSize,
                            surface: false,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: _itemSpacing,
                        children: <Widget>[
                          _tile(
                            backdrop: backdrop,
                            width: _itemSize,
                            height: _itemTwoSpanSize,
                          ),
                          _tile(
                            backdrop: backdrop,
                            width: _itemSize,
                            height: _itemTwoSpanSize,
                          ),
                        ],
                      ),
                    ],
                  ),
                  _spacer(32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: _itemSpacing,
                    children: <Widget>[
                      _tile(
                        backdrop: backdrop,
                        width: _itemTwoSpanSize,
                        height: _itemTwoSpanSize,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: _itemSpacing,
                            children: <Widget>[
                              _iconTile(backdrop: backdrop),
                              _iconTile(backdrop: backdrop),
                            ],
                          ),
                          _spacer(16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: _itemSpacing,
                            children: <Widget>[
                              _iconTile(backdrop: backdrop),
                            ],
                          ),
                        ],
                      ),
                    ],
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
